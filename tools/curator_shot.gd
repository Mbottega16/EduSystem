extends Node
## Screenshot the art forge in edit mode, for verifying UI changes.
##   godot --path . res://tools/curator_shot.tscn -- <out.png> [sprite] [demo]
## demo: strokes (default) | shapes
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://curator_shot.png"
	var sprite: String = args[1] if args.size() > 1 else "cabinet"
	var demo: String = args[2] if args.size() > 2 else "strokes"
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1180, 820)
	var c: Control = load("res://tools/curator.tscn").instantiate()
	get_tree().root.add_child.call_deferred(c)
	await get_tree().process_frame
	await get_tree().process_frame
	c._open_editor(sprite, false)
	await get_tree().process_frame
	c._cur_colour = Color(0.9, 0.2, 0.3, 1.0)
	if demo == "shapes":
		c._set_tool("rect")
		c._on_pixel_down(Vector2i(2, 2))
		c._on_pixel_drag(Vector2i(12, 10))
		c._on_pixel_up()
		c._set_tool("ellipse")
		c._shape_filled = true
		c._cur_colour = Color(0.2, 0.6, 0.9, 1.0)
		c._on_pixel_down(Vector2i(16, 4))
		c._on_pixel_drag(Vector2i(28, 16))
		c._on_pixel_up()
		c._set_tool("line")
		c._set_brush_size(3)
		c._cur_colour = Color(0.95, 0.85, 0.2, 1.0)
		c._on_pixel_down(Vector2i(3, 24))
		c._on_pixel_drag(Vector2i(28, 30))
		c._on_pixel_up()
		# leave a live preview of a rect mid-drag
		c._set_tool("rect")
		c._shape_filled = false
		c._on_pixel_down(Vector2i(6, 34))
		c._on_pixel_drag(Vector2i(24, 40))
	else:
		c._set_tool("brush")
		c._set_brush_size(3)
		c._on_pixel_down(Vector2i(4, 4))
		c._on_pixel_drag(Vector2i(24, 14))
		c._on_pixel_up()
	c._on_pixel_hover(Vector2i(12, 8))
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_window().get_texture().get_image()
	img.save_png(out)
	print("shot: ", out, "  ", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
