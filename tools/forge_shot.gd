extends Node
## Screenshot the Master Forge, for verifying its tabs without clicking.
##   godot --path . res://tools/forge_shot.tscn -- <out.png> [tab index]
##
## The forge is a dev tool, but CLAUDE.md's one golden rule does not stop
## at the game: two of its tabs shipped calling a method that does not
## exist, and nothing looked at them.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://forge_shot.png"
	var tab: int = int(args[1]) if args.size() > 1 else 0
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1400, 900)
	var c: Control = load("res://tools/master_forge.tscn").instantiate()
	get_tree().root.add_child.call_deferred(c)
	for i in 4:
		await get_tree().process_frame
	var tabs := c.get_node_or_null("V/Tabs") as TabContainer
	if tabs != null:
		tabs.current_tab = clampi(tab, 0, tabs.get_tab_count() - 1)
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var err := img.save_png(out)
	print("forge shot: %s  tab %d  err=%d" % [out, tab, err])
	get_tree().quit()
