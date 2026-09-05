extends Node

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
##   godot --path . res://tools/playterm.tscn

const MAIN := preload("res://scenes/main.tscn")
## There used to be a bare TEACH_SECONDS here (1.2, then 14), after which
## the harness ended the lesson early with nothing collected. Fourteen
## seconds finishes no assignment (work_seconds is 20) and uncollected
## work counts half, so every child landed in the F band, every term
## missed its target, and the run silently restarted four times in a
## row -- "the term never resolves" when the game was working exactly as
## designed. A walkthrough has to PLAY well enough to reach the thing it
## is checking, so it now plays the lesson out; see _play_lesson().

## Run the whole thing faster than real time.
##
## Engine.time_scale makes each physics frame worth more SIMULATED seconds,
## so a properly-taught twenty-day term fits in a couple of minutes instead
## of running past any sensible timeout. Every duration below is therefore
## divided by it -- the game still thinks in seconds, this file thinks in
## frames, and the two only agree if the conversion is done in one place.
const SPEED := 6.0


func secs(seconds: float) -> int:
	return maxi(1, int(seconds * 60.0 / SPEED))

var main: Node = null
var world: Node = null
var hud: Node = null
var player: Node = null


func _ready() -> void:
	Balance.ensure_loaded()
	Engine.time_scale = SPEED
	Game.new_run(777)
	# Same reasoning as playtrace.gd: this drives twenty real days through
	# the real buttons, not the once-per-career storyline cutscene, and
	# nothing here presses E to advance it -- a fresh new_run() would
	# otherwise leave the player permanently input_locked on day 1.
	Game.intro_seen = true
	main = MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	world = main.get_node("World")
	hud = main.get_node("UI/HUD")
	player = world.player
	await _play()
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Walk to a tile by pressing directions, the way a player does.
##
## Arrival is "standing ON the tile", not "within 5px of its exact centre".
## That distinction is the whole bug this used to have: walking to the bell
## put the player inside tile (18, 3) but a few pixels off its centre,
## pressed against the bell's own collider. The old 5px test then never
## fired, the press-toward-centre never moved anything, and after 900
## frames it reported "could not reach the bell" -- while the prompt
## "Ring the bell — end day 18" was on screen and one keypress away. The
## room was fine, the game was fine, and the walkthrough called it a
## failure for four days of real confusion.
##
## The centre test is kept as the fast path; the tile test is what makes it
## honest. Tile equality is strictly more permissive, so this can only turn
## former false failures into successes -- it cannot make walk_to claim an
## arrival it did not make.
func walk_to(tile: Vector2i, limit: int = 900) -> bool:
	var target := Grid.tile_to_world(tile)
	for i in limit:
		var d: Vector2 = target - player.global_position
		if d.length() < 5.0 or Grid.world_to_tile(player.global_position) == tile:
			_release()
			await frames(3)
			return true
		_release()
		if absf(d.x) > 3.0:
			Input.action_press("move_right" if d.x > 0.0 else "move_left")
		if absf(d.y) > 3.0:
			Input.action_press("move_down" if d.y > 0.0 else "move_up")
		await get_tree().physics_frame
	_release()
	return false


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(3)
	Input.action_release(action)
	await frames(3)


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await frames(secs(seconds) + 8)
	Input.action_release(action)
	await frames(4)


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
		if Game.run_over:
			print("!! the run ended: a term missed its target of %d"
				% Game.term_target())
			break
		var day: int = Game.day

		if not await walk_to(Layout.PODIUM + Vector2i(0, 1)):
			print("!! day %d: could not reach the podium" % day)
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
			print("!! day %d: the lesson would not start (phase %d, L=[%s])"
				% [day, Game.phase, _offer("teach")])
			break

		# Play the lesson the way a competent player does: teach from the
		# front, and when a child is stuck or has finished, walk over,
		# press E, walk back. The clock ends the lesson.
		await _play_lesson()
		await clear_screens()

		if Game.phase != Game.Phase.AFTERNOON:
			print("!! day %d: the lesson would not end (phase %d, hud %d, locked %s, E=[%s] F=[%s], at %s)"
				% [day, Game.phase, hud.mode, player.input_locked,
					_offer("interact"), _offer("manage"),
					Grid.world_to_tile(player.global_position)])
			break

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
			print("!! day %d: could not reach the bell" % day)
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

		if Game.day == day and not Game.term_over and Game.term == 1:
			print("!! day %d: the bell did not ring (F=[%s])"
				% [day, _offer("manage")])
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
	print("==========================================\n")


func _offer(action: String) -> String:
	var t: Variant = player.targets.get(action)
	if t == null or not is_instance_valid(t):
		return "-"
	var it := t as Interactable
	return it.prompt_text() if it.can_interact() else "-"
