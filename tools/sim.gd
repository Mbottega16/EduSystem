extends Node

## Headless term simulator.
##
##   godot --headless --path . res://tools/sim.tscn -- [days] [policy]
##
## Plays whole terms with a scripted player policy and prints the curves.
## Drives the DATA MODEL directly — no rendering, no window, as fast as the
## machine manages.
##
## Run as a SCENE, not with --script: autoloads (Game) do not exist under a
## custom MainLoop.
##
## WHY THIS EXISTS. 218 unit tests passed while the grade model was broken in
## four separate ways: attention could never reach its own cap, collecting
## work fed into nothing, a homework verdict was never read, and the economy
## paid 16 coins a day against a 60-coin item so the class could not grow
## until roughly day 25. None of that is visible in a unit test, because each
## piece was individually consistent. All of it is obvious the moment you
## look at a hundred days of play in a table.
##
## Policies model a player, not an optimum:
##   ideal    — reaches every stuck student instantly, collects everything
##   good     — a realistic attentive player: a few seconds to walk over
##   lazy     — starts the lesson and wanders off
##   nobody   — never helps, never collects (the floor of the game)
##   quizzer  — exactly 'good', except it spends lesson seconds on a quiz
##              and then goes over it with whoever it flags
##
## That last pair is the point: 'good' and 'quizzer' differ in ONE decision,
## so the gap between their two rows is roughly what the quiz is worth.
##
## READ IT AS A DIRECTION, NOT A MEASUREMENT. The quiz consumes rng draws
## that 'good' never makes, so from the first quiz onward the two runs are
## on different random sequences and part of any gap is simply that. It is
## enough to answer "is this worth doing at all" -- it was paying about ten
## times the coins at an identical grade, which is why a quiz now costs 14
## seconds of a 45-second lesson rather than 10 -- but do not tune a number
## to two significant figures against it.

const POLICIES := ["ideal", "good", "lazy", "nobody", "quizzer"]

## How long the player takes to notice and walk to a stuck student.
const REACTION := {
	"ideal": 0.5, "good": 4.0, "lazy": 15.0, "nobody": 999.0, "quizzer": 4.0}
## Whether they bother picking the finished work up.
const COLLECTS := {
	"ideal": true, "good": true, "lazy": false, "nobody": false, "quizzer": true}
## Coins they will spend on furniture at the end of a day.
const BUYS := {
	"ideal": true, "good": true, "lazy": true, "nobody": false, "quizzer": true}
## Whether they stop the lesson for a quiz.
const QUIZZES := {
	"ideal": false, "good": false, "lazy": false, "nobody": false,
	"quizzer": true}
## How far into the lesson the quiz is called. Early enough that there is
## still time to act on it, which is the entire argument for the instrument.
const QUIZ_AT := 0.25

## WHY 'ideal' AND 'good' BOTH FINISH ON AN A, which looks at first glance
## like a flat skill curve and is not.
##
## The `work` and `done` columns are what settle it: both policies sit at
## 1.00 and 8/8 on every single day of the term. A 45-second lesson against
## 20 seconds of work leaves so much slack that a four-second reaction is
## absorbed entirely, so the lesson term is pinned at its cap for both and
## the letter cannot tell them apart. Only 'lazy', at fifteen seconds, ever
## fails to finish.
##
## Tried and REVERTED, because none of it was an improvement: longer work
## (26s), a higher stall rate (0.24/s), and both together. Even at the point
## where 'good' starts dropping work, both still land on an A -- because by
## the end of a term the room is fully furnished, room_score is at its cap,
## and the room alone is most of the grade.
##
## The letter saturating is the DESIGN, not a fault: "room and teaching
## together earn an A" is the pillar, and a player who does both has earned
## it. The skill signal is in the economy instead, and it is large -- across
## the same term 'ideal' finishes several hundred coins ahead of 'good',
## which is another wing of furniture, or perks, or coaching. Look at the
## coins column, not the letter, to see how well someone played.

const DT := 1.0 / 60.0


func _ready() -> void:
	# Not the player's save -- advance_day() autosaves and this plays whole
	# terms. See the note on Game.save_path.
	Game.save_path = "user://pixelroom_SIM_save.json"
	Balance.ensure_loaded()
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 40
	var only := String(args[1]) if args.size() > 1 else ""

	print("\nPixelRoom term simulator - %d days" % days)
	print("work %.0fs  lesson %.0fs  stall %.2f/s  room %.2f-%.2f  lesson_cap %.2f"
		% [Balance.work_seconds, Balance.lesson_seconds,
		   Balance.stall_chance_per_second, Balance.room_base, Balance.room_cap,
		   Balance.lesson_cap])

	for policy: String in POLICIES:
		if only != "" and policy != only:
			continue
		_run(policy, days)

	if Game.cheated:
		# A balance reading taken after a cheat is worse than no
		# reading: it looks authoritative and is not.
		print("")
		print("REFUSING TO REPORT - cheats were used on this run.")
		get_tree().quit(1)
		return

	print("\nCONTRACT CHECK (simulated, not hand-set)")
	_contract()
	get_tree().quit()


func _run(policy: String, days: int) -> void:
	Game.new_run(12345)
	print("\n--- %s ---" % policy.to_upper())
	print(" day  avg  letter   coins  items  class   stuck-left  hw   work  done  noise")

	var first_enrol := -1
	var first_buy := -1
	for day in days:
		var stats := _play_day(policy)
		if BUYS[policy]:
			var bought := _shop()
			if bought and first_buy < 0:
				first_buy = Game.day
		var before := Game.roster.size()
		var report := Game.advance_day()
		if Game.roster.size() > before and first_enrol < 0:
			first_enrol = Game.day

		if day < 6 or day % 5 == 0 or day == days - 1:
			print("%4d  %.2f    %s   %5d  %5d  %5d   %9d  %d/%d  %.2f  %d/%d  %d/%d" % [
				report["day"], report["average"],
				Game.grade_letter(float(report["average"])),
				Game.coins, Game.room_items.size(), before,
				stats["still_stuck"], report["homework_done"], before,
				stats["work"], stats["finished"], stats["of"],
				stats["settled"], stats["noisy"]])

	print("  first purchase: day %s     first new student: day %s" % [
		"never" if first_buy < 0 else str(first_buy),
		"never" if first_enrol < 0 else str(first_enrol)])
	print("  final: %d coins, %d items, %d students, avg %s" % [
		Game.coins, Game.room_items.size(), Game.roster.size(),
		Game.grade_letter(Game.class_average())])


## One lesson, ticked at the real physics rate so the numbers match play.
func _play_day(policy: String) -> Dictionary:
	var reaction: float = REACTION[policy]
	var stuck_since := {}
	var flagged_since := {}
	var noisy_since := {}
	var settled := 0
	for s: StudentData in Game.roster:
		s.assign_work()

	# The quiz is PAID FOR out of the lesson, so the clock it runs against
	# shortens. Charging it anywhere else would make it free, and a free
	# diagnostic is not a decision.
	Game.quiz_done = false
	var lesson_len := Balance.lesson_seconds
	var quiz_at: float = lesson_len * QUIZ_AT if QUIZZES[policy] else -1.0
	var flagged_total := 0
	var resolved := 0

	var t := 0.0
	while t < lesson_len:
		t += DT
		if quiz_at > 0.0 and not Game.quiz_done and t >= quiz_at:
			var result := Game.run_quiz()
			flagged_total = int(result.get("flagged", 0))
			lesson_len -= Balance.quiz_seconds_cost
		# Who is next to whom, and who has started playing up. Without this
		# the simulator cannot see disruption at all, and a system the
		# simulator cannot see is the exact thing it exists to catch.
		Game.tick_class(DT, Game.rng)
		for s: StudentData in Game.roster:
			s.tick_work(DT, Game.rng)
			# Settling comes first, as it does at the desk: it is the one
			# that gets worse while you are dealing with something else.
			if s.disrupting:
				if not noisy_since.has(s.id):
					noisy_since[s.id] = t
				elif t - float(noisy_since[s.id]) >= reaction:
					if s.settle():
						settled += 1
					noisy_since.erase(s.id)
				continue
			noisy_since.erase(s.id)
			if s.is_struggling():
				if not stuck_since.has(s.id):
					stuck_since[s.id] = t
				elif t - float(stuck_since[s.id]) >= reaction:
					s.help()
					stuck_since.erase(s.id)
			else:
				stuck_since.erase(s.id)
				# Going over the quiz only ever happens to someone who is
				# NOT currently stuck: a frozen work timer outranks it, the
				# same priority the desk itself applies.
				if s.quiz_flagged:
					if not flagged_since.has(s.id):
						flagged_since[s.id] = t
					elif t - float(flagged_since[s.id]) >= reaction:
						if s.resolve_quiz():
							resolved += 1
						flagged_since.erase(s.id)

	var still := 0
	var noisy := 0
	var work_total := 0.0
	var finished := 0
	for s: StudentData in Game.roster:
		work_total += s.work_fraction()
		if s.work_fraction() >= 0.999:
			finished += 1
		if s.is_struggling():
			still += 1
		if s.disrupting:
			noisy += 1
		if COLLECTS[policy]:
			s.collect_work()
		# mark whatever homework came in; assume the player judges well
		if s.hw_state == StudentData.HW.DONE:
			s.hw_state = StudentData.HW.MARKED
			s.hw_player_verdict = 1 if Questions.sheet_is_good(s.hw_sheet) else 0

	Game.grade_class()
	Game.assign_homework()
	return {"still_stuck": still, "flagged": flagged_total, "resolved": resolved,
		"work": work_total / maxf(1.0, float(Game.roster.size())),
		"finished": finished, "of": Game.roster.size(),
		"noisy": noisy, "settled": settled}


## Buy the item with the best bonus-per-coin that we can afford and that
## actually reaches a seat. A real player would do something like this.
func _shop() -> bool:
	var best := ""
	var best_value := 0.0
	for id: String in Items.order():
		var d := Items.get_def(id)
		if not Game.can_afford(int(d["cost"])):
			continue
		var value := float(d["bonus"]) / float(d["cost"])
		if value > best_value:
			best_value = value
			best = id
	if best == "":
		return false
	# put it where it reaches the most students who are not yet capped
	var best_spot := Vector2i(-1, -1)
	var best_reach := 0
	for ty in range(2, 10):
		for tx in range(1, 19):
			var spot := Vector2i(tx, ty)
			if not Game.item_at(spot).is_empty():
				continue
			var reach := 0
			for i: int in Items.seats_in_range(best, spot):
				if Game.student_in_seat(i) != null 						and Game.room_score(i) < Balance.room_cap - 0.001:
					reach += 1
			if reach > best_reach:
				best_reach = reach
				best_spot = spot
	if best_reach == 0:
		return false
	return Game.place_item(best, best_spot)


## The three rows of the balance contract, measured from simulated play
## rather than from hand-assigned state.
func _contract() -> void:
	var bare_perfect := _one_lesson(false, true)
	var rich_absent := _one_lesson(true, false)
	var rich_perfect := _one_lesson(true, true)
	_row("bare room, perfect teaching", bare_perfect, "C")
	_row("full room, never helped   ", rich_absent, "C")
	_row("full room, perfect teaching", rich_perfect, "A")


## Averaged over many students. A single lesson is dominated by one
## student's stall luck -- sampling one swung this between a C and a B on
## seed alone, which would make the contract meaningless.
func _one_lesson(furnish: bool, teach: bool) -> float:
	var total := 0.0
	var n := 0
	for offset in 6:
		Game.new_run(900 + offset)
		if furnish:
			var guard := 0
			while Game.room_score(0) < Balance.room_cap - 0.001 and guard < 60:
				Game.room_items.append({
					"id": Items.order()[guard % Items.order().size()],
					"tile": Layout.seat(0) + Vector2i(0, 1)})
				guard += 1
		for s: StudentData in Game.roster:
			s.seat_index = 0 if furnish else s.seat_index
			s.assign_work()
		var t := 0.0
		while t < Balance.lesson_seconds:
			t += DT
			for s: StudentData in Game.roster:
				s.tick_work(DT, Game.rng)
				if teach and s.is_struggling():
					s.help()
		for s: StudentData in Game.roster:
			if teach:
				s.collect_work()
			total += Game.grade_for(s)
			n += 1
	return total / float(n)


func _row(label: String, value: float, want: String) -> void:
	var got := Game.grade_letter(value)
	print("  %s  %.2f  %s   %s" % [
		label, value, got, "ok" if got == want else "WANT " + want])
