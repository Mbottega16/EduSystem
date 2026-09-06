extends Node
## Screenshot the art forge in edit mode, for verifying UI changes.
##   godot --path . res://tools/curator_shot.tscn -- <out.png> [sprite] [zoomdelta]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://curator_shot.png"
	var sprite: String = args[1] if args.size() > 1 else "cabinet"
	var zd: int = int(args[2]) if args.size() > 2 else 0
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1180, 820)
	var c: Control = load("res://tools/curator.tscn").instantiate()
	get_tree().root.add_child.call_deferred(c)
	await get_tree().process_frame
	await get_tree().process_frame
	c._open_editor(sprite, false)
	await get_tree().process_frame
	if zd != 0:
		c.canvas.set_zoom(c.canvas.zoom + zd)
		c._update_status()
	c._cur_colour = Color(0.9, 0.2, 0.3, 1.0)
	c._tool = "brush"
	c._on_pixel_down(Vector2i(4, 4))
	c._on_pixel_drag(Vector2i(20, 12))
	c._on_pixel_up()
	c._on_pixel_hover(Vector2i(12, 8))
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_window().get_texture().get_image()
	img.save_png(out)
	print("shot: ", out, "  ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
