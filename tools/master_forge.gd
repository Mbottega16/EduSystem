extends Control

## The Master Forge shell -- the header, the tabs, and Sync & Reimport.
##
## The shell used to be a gold title, a spacer, and a borderless word that
## ran a whole import pass. Pressing it printed "Syncing..." to a stdout
## nobody sees (the launcher uses `start`, so there is no console) and
## returned instantly, because OS.execute with blocking=false does not
## wait -- so the one button that fixes CLAUDE.md's "seam that bites" gave
## no sign it had done anything at all. It reports on screen now, and says
## what it is for before you press it.

const SYNC_HINT := "Godot cannot load a PNG or WAV it has not imported. \
Press this after forging or saving art, then relaunch the game."

@onready var sync_btn: Button = %SyncBtn
@onready var status: Label = %SyncStatus
@onready var tabs: TabContainer = %Tabs


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1400, 900))
	get_window().title = "Master Forge - EDUSystem"

	# One theme on the root; every tab, button and field below inherits it.
	theme = ForgeTheme.build()
	ForgeTheme.primary(sync_btn)
	sync_btn.tooltip_text = SYNC_HINT
	sync_btn.pressed.connect(_on_sync_pressed)
	status.text = ""

	# A forge run rewrites a PNG the gallery is already showing. Without
	# this the thumbnail stayed on the old pixels until you found Rescan.
	var curator := get_node_or_null("%Curator")
	for tab: Node in [%ArtForgeUI, %ItemsUI, %HUDUI]:
		if tab is ForgeTab and curator != null:
			(tab as ForgeTab).forged.connect(
				func(_n: String) -> void: curator.call("_rescan"))

	# The Art tab keeps no picker of its own: the gallery is its target.
	# Keep the two in lockstep so what you select is what Forge rebuilds.
	var art_tab := %ArtForgeUI as ForgeTab
	if curator != null and art_tab != null:
		curator.connect("sprite_selected", Callable(art_tab, "set_external_target"))


func _on_sync_pressed() -> void:
	sync_btn.disabled = true
	status.add_theme_color_override("font_color", ForgeTheme.DIM)
	status.text = "Importing…"
	# Let the disabled button and the label actually paint before the
	# blocking call below freezes the frame.
	await get_tree().process_frame
	await get_tree().process_frame

	var bat := ProjectSettings.globalize_path("res://").path_join("Reimport Art.bat")
	var lines: Array = []
	# Blocking, so there is something true to report. The old call passed
	# blocking=false and then printed "Sync complete." unconditionally,
	# which was a claim it had no way to check.
	var code := OS.execute(bat, [], lines, true)

	sync_btn.disabled = false
	if code == 0:
		status.add_theme_color_override("font_color", ForgeTheme.GOOD)
		status.text = "Imported. Relaunch the game to see the change."
	else:
		status.add_theme_color_override("font_color", ForgeTheme.BAD)
		status.text = "Reimport Art.bat exited %d — run it from a console." % code
