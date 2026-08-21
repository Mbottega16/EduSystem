extends Node

## Screenshot harness for the TITLE scene specifically.
##
## tools/shot.gd always loads scenes/main.tscn, so it has never been able
## to see the title screen, Settings, Controls or Credits at all -- a real
## gap, found while adding three new rebindable actions and having no way
## to confirm the Controls list (a plain, non-scrolling Label) still fits
## the panel rather than assuming the maths work out.
##
##   godot --path . res://tools/title_shot.tscn -- out.png [page]
##
## `page` is one of Title.Page's names, case-insensitive: main settings
## controls howto credits confirm_wipe. Defaults to "main".

const TITLE_SCENE := "res://scenes/ui/title.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://title_shot.png"
	var page_name: String = args[1] if args.size() > 1 else "main"

	get_window().content_scale_size = Vector2i(640, 352)
	get_window().size = Vector2i(1920, 1056)

	# Untyped on purpose: title.gd has no class_name, so a Node-typed
	# reference cannot see its Page enum or _go() at parse time.
	var t = load(TITLE_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(t)
	await get_tree().process_frame
	await get_tree().process_frame

	t._go(t.Page[page_name.to_upper()])

	for i in 4:
		await get_tree().physics_frame

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("title_shot: %s  %dx%d  err=%d" % [out, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
