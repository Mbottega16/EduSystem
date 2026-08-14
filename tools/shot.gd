extends Node

## Screenshot harness.
##
##   godot --path . res://tools/shot.tscn -- out.png [frames] [width] [height]
##
## Runs the REAL game scene for a few frames and saves what it drew. Not
## headless — headless has no renderer, so it can only ever prove that code
## does not crash, never that anything is on screen.
##
## That distinction has already cost this project once: a broken hud.gd
## survived a headless boot check because the game opens on the title screen
## and never instantiates the HUD. Every UI panel so far has also needed two
## or three passes to stop overflowing 288x128, and no assertion catches a
## panel that merely looks wrong.

const MAIN := "res://scenes/main.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 30

	# An explicit size lets a grown room be shot whole rather than cropped to
	# whatever the project's viewport happens to be.
	if args.size() > 3:
		var w := int(args[2])
		var h := int(args[3])
		get_window().content_scale_size = Vector2i(w, h)
		get_window().size = Vector2i(w * 3, h * 3)

	# Deferred: the root is still setting up its own children while _ready()
	# runs here, and a direct add_child() is refused outright.
	# Optional: grow the room first, so a screenshot can show a size the
	# opening classroom never reaches.
	var grow: int = int(args[4]) if args.size() > 4 else 0

	var main: Node = load(MAIN).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	# Optional: open a named screen before shooting. Every overlay in this
	# project has needed two or three passes to stop running off the bottom
	# of a 288x128 panel, and no assertion catches text that merely overflows.
	var screen: String = args[5] if args.size() > 5 else ""

	if grow > 0:
		Game.coins = 99999999
		for i in grow:
			Game.expand_room("wide")
			Game.expand_room("tall")
		await get_tree().physics_frame

	# Physics frames, not a timer: the whole game runs on the physics tick,
	# and students walk to their chairs on a stagger.
	for i in frames:
		await get_tree().physics_frame

	if screen != "":
		_open_screen(main, screen)
		await get_tree().physics_frame
		await get_tree().physics_frame

	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("shot: %s  %dx%d  err=%d  (%d frames)" % [
		out, img.get_width(), img.get_height(), err, frames])
	get_tree().quit(0 if err == OK else 1)


## Drive the HUD straight to a screen, rather than trying to walk the teacher
## across the room and press the right buttons in the right phase.
func _open_screen(main: Node, screen: String) -> void:
	var hud: Node = main.get_node("UI/HUD")
	var world: Node = main.get_node("World")
	match screen:
		"quiz":
			world.start_lesson()
			hud.show_quiz_report(world.run_quiz())
		"curriculum":
			for l: Dictionary in Curriculum.lessons:
				for i in 4:
					Game.record_taught(String(l.get("id", "")))
			hud.show_curriculum()
		"unit_test":
			for i in 5:
				Game.record_taught("basic_arithmetic")
			world.start_test("basic_arithmetic")
			hud.show_test_report(world.end_test())
		"student":
			var s: StudentData = Game.roster[0]
			Game.lesson = Curriculum.by_id("basic_arithmetic")
			Game.grade_class()
			Game.lesson = Curriculum.by_id("reading_fluency")
			Game.grade_class()
			hud.show_student(s)
		"shop":
			Game.add_coins(3000)
			hud.open_catalogue()
		"room":
			Game.add_coins(50000)
			hud.open_catalogue()
			hud._shop = hud.Shop.ROOM
			hud._render_catalogue()
		"staff":
			Game.add_teacher_xp(4000)
			hud.open_catalogue()
			hud._shop = hud.Shop.STAFF
			hud._render_catalogue()
		"class_list":
			hud.show_class_list()
		_:
			push_error("unknown screen: " + screen)
