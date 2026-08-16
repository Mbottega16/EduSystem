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
## Seconds actually spent at the front before ending the lesson early.
##
## This was 1.2, which taught almost nothing -- so the trace failed every
## term's target, the run ended, and it silently started a NEW one. Four
## restarts in a row read as "the term never resolves" when the game was
## working exactly as designed. A walkthrough has to play well enough to
## reach the thing it is meant to be checking.
const TEACH_SECONDS := 14.0

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


func walk_to(tile: Vector2i, limit: int = 900) -> bool:
	var target := Grid.tile_to_world(tile)
	for i in limit:
		var d: Vector2 = target - player.global_position
		if d.length() < 5.0:
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
func clear_screens(limit: int = 6) -> void:
	for i in limit:
		if hud.mode == hud.Mode.NONE:
			return
		await tap("interact")
	if hud.mode != hud.Mode.NONE:
		hud.close()
		await frames(2)


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
			await tap("manage")
			# take whichever paper is on top of the hand
			if hud.mode == hud.Mode.HAND:
				await tap("interact")
				await frames(4)
		if Game.phase != Game.Phase.LESSON:
			print("!! day %d: the lesson would not start (phase %d, F=[%s])"
				% [day, Game.phase, _offer("manage")])
			break

		await frames(secs(TEACH_SECONDS))
		await hold("manage", 0.8)               # end the lesson early
		await clear_screens()

		if Game.phase != Game.Phase.AFTERNOON:
			print("!! day %d: the lesson would not end (phase %d, hud %d, locked %s, E=[%s] F=[%s], at %s)"
				% [day, Game.phase, hud.mode, player.input_locked,
					_offer("interact"), _offer("manage"),
					Grid.world_to_tile(player.global_position)])
			break

		if not await walk_to(Layout.BELL + Vector2i(0, 1)):
			print("!! day %d: could not reach the bell" % day)
			break
		await hold("manage", 0.9)

		if Game.day == day and not Game.term_over and Game.term == 1:
			print("!! day %d: the bell did not ring (F=[%s])"
				% [day, _offer("manage")])
			break
		if Game.day != last_day:
			last_day = Game.day
			if Game.day % 5 == 0 or Game.term_over:
				print("   day %-3d coins %-5d class %d  avg %s" % [
					day, Game.coins, Game.roster.size(),
					Game.grade_letter(Game.class_average())])
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
