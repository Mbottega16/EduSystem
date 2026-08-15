extends Node

## Stand at every landmark, in every phase, and write down what is on offer.
##
## Three bugs in a row have been of one kind: something the player walks up
## to that offers nothing, or offers the wrong thing, while the test suite
## stayed green because it never actually stood there. The podium gate made
## the game unplayable; the prompt bar hid the shop; the curriculum board
## answered from the bell's own square.
##
## So this walks the teacher to each landmark IN TURN, in each phase, and
## prints a matrix of what both buttons say. A blank cell is not proof of a
## bug -- plenty of things are correctly unavailable -- but it is the list
## worth reading, and no unit test produces it.
##
##   godot --path . res://tools/audit.tscn

const MAIN := preload("res://scenes/main.tscn")

var main: Node = null
var world: Node = null
var player: Node = null


func _ready() -> void:
	Balance.ensure_loaded()
	Game.new_run(4242)
	main = MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	world = main.get_node("World")
	player = world.player
	await _audit()
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Put the teacher on a tile and let the physics settle, so the interact
## zone reports against where they now are rather than where they were.
func stand_at(tile: Vector2i, facing: int) -> void:
	player.global_position = Grid.tile_to_world(tile)
	player.facing = facing
	await frames(4)


func offer(action: String) -> String:
	var t: Variant = player.targets.get(action)
	if t == null or not is_instance_valid(t):
		return ""
	var it := t as Interactable
	return it.prompt_text() if it.can_interact() else ""


func row(label: String, tile: Vector2i, facing: int) -> void:
	await stand_at(tile, facing)
	var e := offer("interact")
	var f := offer("manage")
	print("   %-16s E: %-30s F: %s" % [label, e if e != "" else "-",
		f if f != "" else "-"])


func _audit() -> void:
	print("\n============ WHAT IS ON OFFER, EVERYWHERE ============")

	await frames(400)                 # let the class sit down
	for phase: int in [Game.Phase.MORNING, Game.Phase.LESSON,
			Game.Phase.AFTERNOON]:
		if phase == Game.Phase.LESSON:
			world.start_lesson()
			await frames(30)
			# give the room something to react to
			Game.roster[0].confusion = 1.0
			Game.roster[1].disrupting = true
			Game.roster[2].work_state = StudentData.Work.DONE
			await frames(4)
		elif phase == Game.Phase.AFTERNOON:
			world.end_lesson()
			main.get_node("UI/HUD").close()
			await frames(4)
		else:
			Game.set_phase(phase)

		print("\n-- %s --" % ["MORNING", "LESSON", "AFTERNOON"][Game.phase])
		await row("podium", Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)
		await row("your desk", Layout.TEACHER_DESK[0] + Vector2i(0, 1),
			Actor.DIR_UP)
		await row("bell", Layout.BELL + Vector2i(0, 1), Actor.DIR_UP)
		await row("noticeboard", Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
		for i in mini(3, Layout.seat_count()):
			await row("desk %d" % (i + 1), Layout.seat(i) + Vector2i(1, 1),
				Actor.DIR_LEFT)

	print("\n-- CARRYING WORK, at your desk --")
	player.carry_work(3)
	await row("your desk", Layout.TEACHER_DESK[0] + Vector2i(0, 1),
		Actor.DIR_UP)
	player.drop_all_work()

	print("\n-- LAST DAY OF TERM, at the bell --")
	Game.day = Balance.term_days
	Game.set_phase(Game.Phase.AFTERNOON)
	await row("bell", Layout.BELL + Vector2i(0, 1), Actor.DIR_UP)

	print("\n-- A UNIT YOU HAVE TAUGHT, in the morning --")
	for i in Balance.test_requires_taught:
		Game.record_taught(String(Game.lesson.get("id", "")))
	Game.set_phase(Game.Phase.MORNING)
	await row("podium", Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)

	print("======================================================\n")
