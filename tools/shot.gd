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
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("shot: %s  %dx%d  err=%d  (%d frames)" % [
		out, img.get_width(), img.get_height(), err, frames])
	get_tree().quit(0 if err == OK else 1)
