extends Node

## Walk a real day, the way a player does, and print what happens.
##
## The test suite TELEPORTS the player and presses keys straight into the
## InputMap. That is fine for logic and useless for "can I actually ring the
## bell", because it skips walking, collision, prompt text and every piece
## of state that only exists once a real day has run its course.
##
## This drives movement through the same actions a keyboard drives, waits
## for what a player would wait for, and reports the phase, the prompt and
## the targets at each step. Run it when the game says one thing and the
## suite says another.
##
##   godot --path . res://tools/playtrace.tscn

const MAIN := preload("res://scenes/main.tscn")

var main: Node = null
var world: Node = null
var hud: Node = null
var player: Node = null
var _step := 0


func _ready() -> void:
	Balance.ensure_loaded()
	Game.new_run(12345)
	main = MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	world = main.get_node("World")
	hud = main.get_node("UI/HUD")
	player = world.player
	await _trace()
	get_tree().quit()


func say(what: String) -> void:
	_step += 1
	print("%2d. %s" % [_step, what])


func state() -> String:
	var phase: String = ["MORNING", "LESSON", "AFTERNOON"][Game.phase]
	var use: String = _prompt_of("interact")
	var man: String = _prompt_of("manage")
	return "day %d  %s  hud=%s  locked=%s  E=[%s]  F=[%s]" % [
		Game.day, phase, hud.mode,
		player.input_locked, use, man]


func _prompt_of(action: String) -> String:
	var t: Variant = player.targets.get(action)
	if t == null or not is_instance_valid(t):
		return "-"
	return (t as Interactable).prompt_text()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Walk to a tile the way a keyboard does, and report if we never arrive.
func walk_to(tile: Vector2i, limit: int = 900) -> bool:
	var target := Grid.tile_to_world(tile)
	for i in limit:
		var here: Vector2 = player.global_position
		var d: Vector2 = target - here
		if d.length() < 5.0:
			_release_all()
			await frames(4)
			return true
		_release_all()
		if absf(d.x) > 3.0:
			Input.action_press("move_right" if d.x > 0.0 else "move_left")
		if absf(d.y) > 3.0:
			Input.action_press("move_down" if d.y > 0.0 else "move_up")
		await get_tree().physics_frame
	_release_all()
	return false


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(3)
	Input.action_release(action)
	await frames(3)


func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await frames(int(seconds * 60.0) + 6)
	Input.action_release(action)
	await frames(4)


func _trace() -> void:
	print("\n==================== A REAL DAY ====================")
	await frames(6)          # the very first moment of the day
	say("class in: " + state())
	say("   students=%d  seated=%d  everyone_seated=%s" % [
		world.students.size(),
		world.students.filter(func(n: Actor) -> bool: return n.seated).size(),
		world.everyone_seated()])
	for n: Actor in world.students:
		say("   %-14s at %s  seat %s  seated=%s" % [
			n.data.display_name if n.data != null else "?",
			Grid.world_to_tile(n.global_position),
			Layout.seat(n.data.seat_index) if n.data != null else "-",
			n.seated])
	say("   pick radius = %.1f" % Progress.pick_radius(Game.perk_ranks))
	say("   podium.can_interact=%s  board=%s  bell=%s" % [
		world.podium.can_interact(), world.noticeboard.can_interact(),
		world.bell.can_interact()])

	if not await walk_to(Layout.PODIUM + Vector2i(0, 1)):
		say("!! COULD NOT WALK TO THE PODIUM")
	say("at podium: " + state())

	await tap("manage")
	# The podium draws a hand of papers now; the lesson starts when you
	# take one. Two presses, not one.
	if hud.mode == hud.Mode.HAND:
		await tap("interact")
		await frames(4)
	say("tapped F, took a paper: " + state())

	# let the clock run all the way out, the way an idle player would
	var guard := 0
	while Game.phase == Game.Phase.LESSON and guard < 5000:
		await get_tree().physics_frame
		guard += 1
	say("lesson over after %d frames: %s" % [guard, state()])

	if hud.mode != hud.Mode.NONE:
		await tap("interact")
		say("closed the report: " + state())

	if not await walk_to(Layout.BELL + Vector2i(0, 1)):
		say("!! COULD NOT WALK TO THE BELL — stuck at %s" % [
			Grid.world_to_tile(player.global_position)])
	say("at bell: " + state())
	say("   bell.can_interact = %s   hold_time = %.2f  key = %s" % [
		world.bell.can_interact(), world.bell.hold_time,
		world.bell.action_name()])

	var day_before: int = Game.day
	await hold("manage", 1.0)
	say("held F: " + state())
	if Game.day == day_before:
		say("!! THE BELL DID NOT RING")
	else:
		say("the bell rang. Day is now %d" % Game.day)
	print("====================================================\n")
