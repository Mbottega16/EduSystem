extends "res://tools/playdrive.gd"

## Play a WHOLE TERM through the real buttons, and see if the game ends.
##
## playtrace.gd proves one day can be played. Nothing has ever checked that
## the twenty of them reach the exam -- which is the only thing in the game
## that resolves anything, and would be a poor thing to discover is broken
## on day twenty of a real run.
##
## Every day is driven the way a player drives it: walk to the podium, start
## the lesson, teach for a bit, end it, close the report, walk to the bell,
## ring it. Nothing calls end_day() behind the game's back.
##
##   godot --headless --path . res://tools/playterm.tscn
##
## WHAT IT GATES ON. Three different questions live in here, and they do not
## share a pass bar:
##
##   liveness    every day reaches the bell and the exam fires    GATED
##   carry-on    a second term begins                             reported
##   competence  the class meets the term's target                reported
##
## Only liveness decides the exit code today. This bot marks homework now
## (see _mark_homework(), 2026-09-14) -- accurately, against Questions'
## own sheet_is_good() -- but a measured run still missed the term's
## target, so marking alone was not the whole gap. Gating on a bar it is
## not reliably equipped to clear would leave the gate permanently red,
## and a gate that is always red is not a gate. Both other answers are
## printed on every run, and GATE_COMPETENCE below is the one-line switch
## to flip once a measured run actually clears the bar -- not before.
##
## THE EXIT CODE IS THE POINT. It used to quit() with no argument, so a
## failed day, a clean run, and a script that never compiled all exited 0,
## and nothing downstream could tell them apart -- which is how a
## walkthrough regression sat unnoticed for four days behind a green suite.
## Now: 0 only when liveness passed, 1 otherwise, with the day and the
## reason named on the WALKTHROUGH FAILED line. The launcher and the
## pre-push hook both read that LINE rather than trusting the code alone,
## because a GDScript parse error still exits 0 having never run at all.

## The one-line switch. Flip it when a marking policy exists; until then,
## the class failing its target is REPORTED, never a failed exit.
const GATE_COMPETENCE := false

## The verdict line. Grepped for by "Play a Whole Term.bat" and by
## .githooks/pre-push -- keep all three in step if this ever changes.
const VERDICT_PASS := "WALKTHROUGH PASSED"
const VERDICT_FAIL := "WALKTHROUGH FAILED"

## Wall clock, not game time: a whole term takes about three minutes.
const WATCHDOG_SECONDS := 600.0

## There used to be a bare TEACH_SECONDS here (1.2, then 14), after which
## the harness ended the lesson early with nothing collected. Fourteen
## seconds finishes no assignment (work_seconds is 20) and uncollected
## work counts half, so every child landed in the F band, every term
## missed its target, and the run silently restarted four times in a
## row -- "the term never resolves" when the game was working exactly as
## designed. A walkthrough has to PLAY well enough to reach the thing it
## is checking, so it now plays the lesson out; see _play_lesson().

## Run the whole thing faster than real time -- see playdrive.gd's speed.
const SPEED := 6.0

## The FIRST liveness failure and the day it happened on. First, not last:
## everything after a broken day is downstream noise.
var _fail_day := 0
var _fail_why := ""

## Competence, kept apart from liveness on purpose -- see the header.
var _missed_target := false
var _missed_by := 0


func _ready() -> void:
	watchdog(WATCHDOG_SECONDS, VERDICT_FAIL)
	await boot(777, SPEED)
	await _play()
	get_tree().quit(0 if _verdict() else 1)


## Record a liveness failure, and say which day broke.
func _fail(day: int, why: String) -> void:
	if _fail_why == "":
		_fail_day = day
		_fail_why = why
	print("!! day %d: %s" % [day, why])


## Close whatever is on screen, however many screens deep it goes.
##
## STOPS on run_over. Closing the exam calls next_term(), which sets
## run_over on a missed target; the NEXT press closes the run-over screen
## and starts a fresh run -- which clears run_over again. Pressing through
## both inside one call erased the flag before the loop ever read it, so
## a run that ended four times printed as "the term never resolved".
func clear_screens(limit: int = 6) -> void:
	for i in limit:
		if hud.mode == hud.Mode.NONE or Game.run_over:
			return
		await tap("interact")
	if hud.mode != hud.Mode.NONE:
		hud.close()
		await frames(2)


## The desk that needs the teacher right now, by the desk's own priority
## (settle, unstick, collect), or -1 when the room is fine.
func _desk_needing_me() -> int:
	var best := -1
	var best_rank := 99
	for s: StudentData in Game.roster:
		if s.seat_index < 0:
			continue
		var r: int = s.attention_rank()
		if r > 0 and r < best_rank:
			best_rank = r
			best = s.seat_index
	return best


## Per-lesson accounting, so "the class always gets an F" is answerable
## rather than arguable. Work advances while you TEACH, so the question is
## whether this bot teaches or just commutes: how much of the lesson does
## it stand at the front, versus walking to desks and back?
var _lesson_trips := 0
var _lesson_helped := 0
var _lesson_front_frames := 0
var _lesson_walk_frames := 0


func _reset_lesson_tally() -> void:
	_lesson_trips = 0
	_lesson_helped = 0
	_lesson_front_frames = 0
	_lesson_walk_frames = 0


func _lesson_tally() -> String:
	var total: int = _lesson_front_frames + _lesson_walk_frames
	var pct: int = 0 if total == 0 else int(round(100.0 * _lesson_front_frames / total))
	return "front %d%%  trips %d  helped %d" % [pct, _lesson_trips, _lesson_helped]


## One lesson, played: at the front until somebody needs me, then to that
## desk and back. The clock ends the lesson.
func _play_lesson() -> void:
	var guard := 0
	_reset_lesson_tally()
	while Game.phase == Game.Phase.LESSON and guard < 4000:
		guard += 1
		var seat := _desk_needing_me()
		if seat < 0:
			_lesson_front_frames += secs(0.5)
			await frames(secs(0.5))
			continue
		var stand: Vector2i = Layout.seat(seat) + Layout.DESK_OFFSET + Vector2i(0, 1)
		_lesson_trips += 1
		var before: int = Engine.get_physics_frames()
		if not await walk_to(stand, 240):
			_lesson_walk_frames += Engine.get_physics_frames() - before
			await frames(4)
			continue
		await tap("interact")
		_lesson_helped += 1
		await walk_to(Layout.PODIUM + Vector2i(0, 1), 300)
		_lesson_walk_frames += Engine.get_physics_frames() - before
	if Game.phase == Game.Phase.LESSON:
		await hold("teach", 0.8)                # the clock did not end it; we do


## Marks whatever homework you're carrying, at the teacher's desk, after
## the lesson and before the bell -- the trip this bot never made until
## now (see the file's own header). Marked ACCURATELY, against
## Questions.sheet_is_good() -- the only verdict policy that doesn't need
## a judgement call invented for a bot standing in for "competent
## teaching": a diligent teacher marking honestly is exactly that.
## Fails soft (just returns) rather than calling _fail() -- a missed
## marking trip is a competence question, not a liveness one, and this
## bot's liveness gate has never been about how well it plays.
func _mark_homework() -> void:
	if player.carrying_hw <= 0:
		return
	if not await walk_to(Layout.TEACHER_DESK[0] + Vector2i(0, 1), 240):
		return
	await tap("homework")
	if hud.mode != hud.Mode.MARKING:
		return
	var guard := 0
	while hud.mode == hud.Mode.MARKING and not hud._marking.is_empty() and guard < 200:
		guard += 1
		var s: StudentData = hud._marking[0]
		await tap("move_right" if Questions.sheet_is_good(s.hw_sheet) else "move_left")
		# _marking_hold (hud.gd) ignores input until the stamp animation
		# clears -- wait it out, the way a real player watching it would.
		await frames(secs(hud.MARKING_STAMP_SECONDS) + 2)
	await clear_screens()


func _play() -> void:
	print("\n============== A WHOLE TERM ==============")
	await frames(secs(1.0))
	var last_day := 0

	# TWO terms, not one. The end of term is a doorway now -- closing the
	# exam opens the next -- so the question stopped being "does the game
	# end" and became "does the game CARRY ON", which is the harder one.
	# term_over cannot be the loop guard any more: next_term() clears it.
	for attempt in Balance.term_days * 4:
		if Game.term > 2:
			break
		# Missing a target ends the run and the next press starts a fresh
		# one. Without noticing that, the loop quietly replays term one over
		# and over and the report reads as if nothing ever resolved.
		#
		# This is COMPETENCE, not liveness. The exam fired and judged the
		# class, which is everything the gate asks of the GAME; what failed
		# is this bot's teaching. It stops the run and it is reported
		# plainly, but it does not fail the tool. See GATE_COMPETENCE.
		if Game.run_over:
			_missed_target = true
			_missed_by = Game.term_target()
			print("   the run ended: a term missed its target of %d" % _missed_by)
			break
		var day: int = Game.day

		if not await walk_to(Layout.PODIUM + Vector2i(0, 1)):
			_fail(day, "could not reach the podium")
			break
		if Game.phase == Game.Phase.MORNING:
			# Teaching split off onto its own key (L) in the Aug 2026 remap --
			# the podium's start/end verb is "teach" now, not "manage".
			await tap("teach")
			# take whichever paper is on top of the hand
			if hud.mode == hud.Mode.HAND:
				await tap("interact")
				await frames(4)
		if Game.phase != Game.Phase.LESSON:
			_fail(day, "the lesson would not start (phase %d, L=[%s])"
				% [Game.phase, _offer("teach")])
			break

		# Play the lesson the way a competent player does: teach from the
		# front, and when a child is stuck or has finished, walk over,
		# press E, walk back. The clock ends the lesson.
		await _play_lesson()
		await clear_screens()

		if Game.phase != Game.Phase.AFTERNOON:
			_fail(day, "the lesson would not end (phase %d, hud %d, locked %s, E=[%s] F=[%s], at %s)"
				% [Game.phase, hud.mode, player.input_locked,
					_offer("interact"), _offer("manage"),
					Grid.world_to_tile(player.global_position)])
			break

		await _mark_homework()

		var bell_tile: Vector2i = Layout.BELL + Vector2i(0, 1)
		if not await walk_to(bell_tile):
			# "could not reach the bell" on its own cannot tell you whether
			# the ROOM is broken or the WALKER is. walk_to() has no
			# pathfinding -- it presses a direction and gives up after 900
			# frames -- so it fails on geometry a real player walks around.
			# Grid knows the difference, so ask it.
			# tile_to_world / world_to_tile are static; is_free / reachable /
			# path are NOT -- they answer for one built room, so they need
			# the classroom's own Grid instance, not the class.
			var here: Vector2i = Grid.world_to_tile(player.global_position)
			var g = world.grid
			_fail(day, "could not reach the bell")
			print("     at %s, wanted %s | target free: %s | reachable: %s | path len: %d"
				% [here, bell_tile, g.is_free(bell_tile),
					g.reachable(here, bell_tile),
					g.path(here, bell_tile).size()])
			# If the tile is free and reachable, the room is fine and the
			# walker is not -- so the next question is whether the player
			# could move at all. input_locked and an open screen both pin
			# it in place while walk_to burns all 900 frames pressing a
			# direction that does nothing.
			print("     locked: %s | hud mode: %d | phase: %d | F=[%s]"
				% [player.input_locked, hud.mode, Game.phase, _offer("manage")])
			break
		await hold("manage", 0.9)
		# the last bell of a term asks which lesson from each subject the
		# paper covers: the cursor already sits on the most-taught one, so
		# a steady teacher just agrees four times and the bell then rings
		var picks_guard := 0
		while hud.mode == hud.Mode.EXAM_PICK and picks_guard < 8:
			picks_guard += 1
			await tap("interact")

		if Game.day == day and not Game.term_over and Game.term == 1:
			_fail(day, "the bell did not ring (F=[%s])" % _offer("manage"))
			break
		if Game.day != last_day:
			last_day = Game.day
			if Game.day % 5 == 0 or Game.term_over:
				print("   day %-3d coins %-5d class %d  avg %s   | %s" % [
					day, Game.coins, Game.roster.size(),
					Game.grade_letter(Game.class_average()), _lesson_tally()])
		await clear_screens()
		await frames(secs(0.5))                 # the class files back in

	print("\n-- how it finished --")
	print("   term        : %d" % Game.term)
	print("   terms played: %d" % Game.term_history.size())
	for row: Dictionary in Game.term_history:
		print("      term %d: %s, %d of %d passed, %d moved up" % [
			int(row["term"]), String(row["letter"]), int(row["passed"]),
			int(row["total"]), int(row["moved_up"])])
	print("   day reached : %d of %d" % [Game.day, Balance.term_days])
	print("   exam result : %s" % (
		"%s, %d of %d passed" % [
			String(Game.exam_result.get("letter", "?")),
			int(Game.exam_result.get("passed", 0)),
			(Game.exam_result.get("rows", []) as Array).size()]
		if not Game.exam_result.is_empty() else "NONE — the term never resolved"))
	print("   concepts    : %d of %d" % [
		Game.concepts.size(), Curriculum.concept_count()])
	print("   graduated   : %d" % Game.graduated.size())


## The three answers, said one at a time, and the one that decides the code.
func _verdict() -> bool:
	# A run that never reached an exam is a liveness failure even when no
	# single day reported one: the loop can simply run out of attempts.
	if _fail_why == "" and Game.exam_result.is_empty():
		_fail_day = Game.day
		_fail_why = "the term never resolved: no exam ever fired"
	var live := _fail_why == ""
	var carried := Game.term >= 2 or Game.term_history.size() >= 2

	print("")
	if live:
		print("   liveness    : ok - the bell every day, and the exam fired")
	else:
		print("   liveness    : FAILED")
	if carried:
		print("   carry-on    : ok - term %d began" % Game.term)
	else:
		print("   carry-on    : no second term began")
	if _missed_target:
		print("   competence  : the class missed its target of %d" % _missed_by)
		print("                 (marks homework now, still misses the bar - reported, not gated)")
	elif live:
		print("   competence  : ok - no term missed its target")
	else:
		print("   competence  : unknown - the run broke before it could say")
	print("==========================================")
	print("")

	var ok := live
	if GATE_COMPETENCE:
		ok = live and carried and not _missed_target
	if ok:
		print("%s - %d term(s) played, every day reached the bell."
			% [VERDICT_PASS, Game.term_history.size()])
		return true
	if not live:
		print("%s - day %d: %s" % [VERDICT_FAIL, _fail_day, _fail_why])
	else:
		print("%s - term %d missed its target of %d"
			% [VERDICT_FAIL, Game.term, _missed_by])
	return false


func _offer(action: String) -> String:
	var t: Variant = player.targets.get(action)
	if t == null or not is_instance_valid(t):
		return "-"
	var it := t as Interactable
	return it.prompt_text() if it.can_interact() else "-"
