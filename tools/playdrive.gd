extends Node

## The keyboard and the boot sequence, shared by both walkthroughs.
##
## WHY THIS FILE EXISTS. walk_to() lived twice, byte-identical, once in
## playterm.gd and once in playtrace.gd. In Sep 2026 a real bug in it was
## found and fixed in ONE copy; playtrace.gd's own comment recorded the
## split ("playterm.gd had the same fix; this did not") and left it
## standing. Two copies of one function is exactly how one gets fixed and
## the other does not, so there is one copy now and both tools inherit it.
## tests/run.gd's WALKTHROUGH section fails if a second one reappears.
##
## Nothing here knows what a term or a day is. This is boot, movement and
## keypresses; what each tool DOES with them stays in that tool.

const MAIN := preload("res://scenes/main.tscn")

## How much faster than real time this tool runs.
##
## Engine.time_scale makes each physics frame worth more SIMULATED seconds,
## so a properly-taught twenty-day term fits in a couple of minutes instead
## of running past any sensible timeout. Every duration is therefore
## divided by it -- the game thinks in seconds, a walkthrough thinks in
## frames, and the two only agree if the conversion happens in one place.
var speed := 1.0

var main: Node = null
var world: Node = null
var hud: Node = null
var player: Node = null


## Boot the real game scene on a fixed seed, at `at_speed`.
func boot(run_seed: int, at_speed: float = 1.0) -> void:
	speed = at_speed
	# NEVER the player's save. advance_day() autosaves and a walkthrough
	# advances twenty days, so every run of either tool was overwriting a
	# real save file -- which CLAUDE.md bans outright ("a dev tool must
	# never write the player's save"). sim.gd and schoolsim.gd have always
	# redirected; these two never did. Found while wiring the walkthrough
	# into pre-push, where it would have cost the player their run on
	# every single push.
	Game.save_path = "user://edusystem_WALKTHROUGH_save.json"
	Balance.ensure_loaded()
	Engine.time_scale = speed
	Game.new_run(run_seed)
	# Both tools drive the EVERYDAY loop, not the once-per-career storyline
	# cutscene, and both drive input by simulating key presses -- neither
	# ever presses E through the intro slate. A fresh new_run() would
	# otherwise leave main.gd's cutscene holding player input locked
	# forever. Found by running playtrace.gd and reading its output: every
	# line after boot showed locked=true, and every action after that was
	# silently a no-op.
	Game.intro_seen = true
	main = MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	world = main.get_node("World")
	hud = main.get_node("UI/HUD")
	player = world.player


func secs(seconds: float) -> int:
	return maxi(1, int(seconds * 60.0 / speed))


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
			# Three, not four. The two copies of this function disagreed by
			# one settle frame, and one frame moves the whole run: merged at
			# four, seed 777's term came out with different coins and a
			# different front-of-room split on every day. playterm.gd is the
			# one with a pass bar, so the merged copy keeps ITS number and
			# its baseline run stays comparable across the change.
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


## Never let a walkthrough hang the thing that is waiting on it.
##
## Both tools are bounded by frame budgets, but every one of those budgets
## only ticks while physics ticks. This one does not: ignore_time_scale is
## on, so `real_seconds` really is wall-clock, at any Engine.time_scale.
## A gate that can hang forever is worse than no gate -- the pre-push hook
## learned the same lesson from Godot hanging as a hook child.
func watchdog(real_seconds: float, verdict_line: String) -> void:
	get_tree().create_timer(real_seconds, true, false, true).timeout.connect(
		func() -> void:
			print("\n%s - it hung: no verdict within %ds of wall clock."
				% [verdict_line, int(real_seconds)])
			get_tree().quit(1))
