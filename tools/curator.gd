extends Control

## The sprite browser, and now the sprite editor.
##
##   Browse Art.bat        (or: godot --path . res://tools/curator.tscn)
##
## Every image the game owns, on one screen. Until this existed the only way
## to look at the art was to open PNGs one at a time, which is why a
## two-frame sprite sheet sat in the game for weeks rendering as a magenta
## block before anyone noticed.
##
## It used to be deliberately a VIEWER, not an editor -- sprites were
## authored as text grids in tools/sprites/ or as code in tools/make_art.py,
## and this was for seeing what came out. There was no way to fix what you
## saw without leaving the tool. Select a sprite and press Enter to edit it
## in place; N starts a new one. Saving writes a tools/sprites/<name>.txt
## source (so the edit survives the next `python tools/make_art.py`, which
## now stands down for anything with a hand-edited source -- see
## save_png() there) and the PNG itself.
##
## Saving does NOT re-import: this tool runs as a child of Godot, and a
## `--headless --import` spawned from here has hung outright on this
## machine, freezing the editor on save (see _save_editor). The import is a
## separate, reliable step instead -- `Browse Art.bat` runs one before it
## launches this tool, and `Reimport Art.bat` makes the game pick up an
## edit. A brand-new sprite will not load until one of those runs.
##
## The two lists at the bottom are still the point of the browsing half:
##   UNREFERENCED - art on disk that no script or data file mentions
##   MISSING      - art that scripts or data DO mention but which is not
##                  there. That one is a crash waiting to happen, and
##                  nothing else in the project checks for it.

const ART_DIR := "res://art"
const SPRITE_SRC_DIR := "res://tools/sprites"
const BG_LIGHT := Color(0.86, 0.83, 0.76)
const BG_DARK := Color(0.11, 0.10, 0.13)
## Magenta, because unstripped chroma key is the specific defect this
## project has actually shipped. It is invisible against both other grounds.
const BG_CHROMA := Color(1, 0, 1)

## A character sheet is a fixed 9x4 grid of 32x48 frames -- see
## scenes/actors/student.tscn (hframes=9, vframes=4) and actor.gd's
## SIT_FRAME/POSE_* constants. Detected by size so the editor can draw cell
## boundaries rather than presenting an unreadable slab.
const CHAR_CW := 32
const CHAR_CH := 48
const CHAR_COLS := 9
const CHAR_ROWS := 4
const CHAR_W := CHAR_CW * CHAR_COLS
const CHAR_H := CHAR_CH * CHAR_ROWS

## One character per colour in a saved .txt source. Excludes '.' and ' '
## (transparent, by the format's own rule) and '#' (a comment/header line).
const CHARSET := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@$%^&*-_=+[]{}|;:,<>?/~"

var _grounds := [BG_LIGHT, BG_DARK, BG_CHROMA]
var _ground := 0
var _zoom := 3
var _files: Array[String] = []
## The filtered subset actually on screen. Everything about selection and
## arrow-key navigation counts in THIS, not in _files.
var _view: Array[String] = []
var _filter_text := ""
var _referenced := {}      ## art name -> where it is mentioned
var _missing: Array[String] = []
## The selection is held as a NAME, not an index. An index into a list that
## a filter can reshuffle stops meaning anything the moment you type.
var _sel_name := ""
var _cards: Array[Control] = []
## The selection frame of each card, parallel to _cards. Kept so changing
## the selection can repaint two borders instead of rebuilding the grid --
## see _select(), and the scroll jump that rebuilding caused.
var _frames: Array[PanelContainer] = []

## Emitted whenever the selected sprite changes (name, or "" for none).
## Inside the Master Forge the Art tab has no picker of its own and listens
## to this -- the gallery is that tab's target. See master_forge.gd.
signal sprite_selected(sprite_name: String)

# --- edit mode ---
var _editing := false
var _edit_name := ""
var _edit_is_new := false
var _edit_img: Image = null
var _undo: Array[Image] = []
var _redo: Array[Image] = []
var _last_pixel := Vector2i(-1, -1)
var _hover_px := Vector2i(-1, -1)
var _tool := "brush"
var _brush_size := 1
var _brush_round := false
var _mirror := 0                        ## 0 off, 1 X, 2 Y, 3 both
var _shape_filled := false
var _shape_anchor := Vector2i(-1, -1)   ## line/rect/ellipse anchor; -1 = none
var _shape_last := Vector2i(-1, -1)
var _cur_colour := Color(0.1, 0.1, 0.1, 1.0)
var _palette: Array[Color] = []
## The house palette (tools/palette.json), as [{group, name, colour}].
## Always on screen while the editor is open, so painting in the game's own
## colours is one click rather than "open another sprite and eyedrop it".
## Empty if the file is missing -- the editor still works, it just offers
## nothing but the sprite's own colours, which is what it did before.
var _house: Array[Dictionary] = []
var _house_row: HFlowContainer
var _swatch_row: HBoxContainer
var _status: Label
var _size_label: Label
var _tool_btns := {}                     ## tool name -> toggle Button

## Node lookups go through % unique names rather than literal paths. The
## toolbar was one flat row of twenty buttons and is now grouped; with
## paths, regrouping it would have meant rewriting thirty lines of $V/...
@onready var grid: GridContainer = %Grid
@onready var report: RichTextLabel = %Report
@onready var scroll: ScrollContainer = %Scroll
@onready var browse: VBoxContainer = %Browse
@onready var editor: VBoxContainer = %Editor
@onready var canvas: Control = $V/Editor/Body/CanvasWrap/Canvas
@onready var _btn_brush: Button = %Brush
@onready var _btn_eraser: Button = %Eraser
@onready var _btn_fill: Button = %Fill
@onready var _btn_eyedrop: Button = %Eyedrop
@onready var _size_btns := {1: %Size1, 2: %Size2, 4: %Size4, 8: %Size8, 16: %Size16}


## True when this tool owns the window -- launched as the main scene by
## Browse Art.bat, or dropped straight under the root by curator_shot.gd.
## Inside the Master Forge it is one pane among several: it must not resize
## the window, paint its own ground over the forge's, or quit on Escape.
func _standalone() -> bool:
	return get_tree().current_scene == self or get_parent() == get_tree().root


func _ready() -> void:
	# Standalone (Browse Art.bat) this owns the window; inside the Master
	# Forge it is one pane of a bigger tool and must not resize anything.
	if _standalone():
		# The project renders at 320x176 with viewport stretch; a dev tool
		# wants a real window and real pixels.
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		DisplayServer.window_set_size(Vector2i(1180, 820))
		get_window().title = "EDUSystem - art"
		theme = ForgeTheme.build()
		($Bg as ColorRect).color = ForgeTheme.BG
	else:
		# The forge draws its own ground behind this pane; a second opaque
		# rectangle over it just made the seam visible.
		($Bg as ColorRect).color = Color(0, 0, 0, 0)

	_swatch_row = %SwatchRow
	_house_row = %HouseRow
	_status = %Status
	_load_house_palette()

	%Filter.text_changed.connect(_on_filter_changed)
	%GroundBtn.pressed.connect(_cycle_ground)
	%ZoomIn.pressed.connect(_zoom_by.bind(1))
	%ZoomOut.pressed.connect(_zoom_by.bind(-1))
	%Rescan.pressed.connect(_rescan)
	%NewBtn.pressed.connect(_prompt_new_sprite)
	%EditBtn.pressed.connect(func() -> void:
		if _sel_name != "":
			_open_editor(_sel_name, false))
	# The grid used a hard-coded 7 columns. In the Master Forge the gallery
	# shares the window with a forge panel and 7 columns did not fit, so the
	# right-hand column of sprites was simply cut off the edge -- there was
	# no horizontal scrollbar to find, because a GridContainer just
	# overflowed its parent.
	scroll.resized.connect(_reflow)

	canvas.pixel_down.connect(_on_pixel_down)
	canvas.pixel_right_click.connect(_on_pixel_right_click)
	canvas.pixel_drag.connect(_on_pixel_drag)
	canvas.pixel_up.connect(_on_pixel_up)
	canvas.pixel_hover.connect(_on_pixel_hover)
	canvas.zoom_changed.connect(func(_z: int) -> void: _update_status())

	_tool_btns = {
		"brush": _btn_brush, "eraser": _btn_eraser, "fill": _btn_fill,
		"eyedrop": _btn_eyedrop,
		"line": %Line, "rect": %Rect, "ellipse": %Ellipse,
	}
	for tname: String in _tool_btns:
		var b: Button = _tool_btns[tname]
		b.pressed.connect(_set_tool.bind(tname))
	_size_label = %SizeLabel
	%SizeMinus.pressed.connect(func() -> void: _set_brush_size(_brush_size - 1))
	%SizePlus.pressed.connect(func() -> void: _set_brush_size(_brush_size + 1))
	# One click to a wide nib. [ and ] still step one at a time, but going
	# from 1 to 16 that way is fifteen presses, which is why nobody did it.
	for n: int in _size_btns:
		(_size_btns[n] as Button).pressed.connect(_set_brush_size.bind(n))
	(%Round as CheckButton).toggled.connect(
		func(on: bool) -> void: _brush_round = on)
	(%Filled as CheckButton).toggled.connect(
		func(on: bool) -> void: _shape_filled = on)
	%Mirror.pressed.connect(_cycle_mirror)
	%Undo.pressed.connect(_undo_action)
	%Redo.pressed.connect(_redo_action)
	%Save.pressed.connect(_save_editor)
	%Cancel.pressed.connect(_close_editor)
	_style_widgets()

	_scan_references()
	_scan_files()
	_build()


## Which buttons matter, said in colour rather than in a tooltip nobody
## hovers. Exactly one filled button per mode: Edit while browsing, Save
## while editing.
func _style_widgets() -> void:
	ForgeTheme.primary(%EditBtn)
	ForgeTheme.primary(%Save)
	for b: Button in [%NewBtn, %Rescan, %GroundBtn, %ZoomIn, %ZoomOut,
			%Undo, %Redo, %Cancel, %SizeMinus, %SizePlus]:
		ForgeTheme.secondary(b)
	for tname: String in _tool_btns:
		ForgeTheme.tool_toggle(_tool_btns[tname])
	for n: int in _size_btns:
		var b: Button = _size_btns[n]
		ForgeTheme.tool_toggle(b)
		b.custom_minimum_size = Vector2(30, 0)
	ForgeTheme.tool_toggle(%Mirror)
	%Mirror.toggle_mode = false


## Everything the game asks for by name, and where it asks.
##
## Scans the SOURCE rather than a hand-kept manifest, because a hand-kept
## list is exactly the thing that goes stale and stops being trusted.
func _scan_references() -> void:
	_referenced.clear()

	var rx := RegEx.new()
	rx.compile("art/([A-Za-z0-9_]+)\\.png")
	for path: String in _gd_files("res://scripts") + _gd_files("res://scenes"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		for m in rx.search_all(text):
			_note(m.get_string(1), path.get_file())

	# data tables name art too, and they are not code
	Balance.ensure_loaded()
	for id: String in Items.catalogue().keys():
		var art := String(Items.get_def(id).get("art", ""))
		if art != "":
			_note(art, "balance.json (%s)" % id)
		# an animated item names its strip too (room_builder.gd plays it)
		var anim: Variant = Items.get_def(id).get("anim", null)
		if anim is Dictionary and String((anim as Dictionary).get("art", "")) != "":
			_note(String((anim as Dictionary)["art"]), "balance.json (%s anim)" % id)
	for a: String in Names.ART:
		_note(a, "names.gd (student)")
	for h: Dictionary in Cosmetics.HATS:
		var art := String(h.get("art", ""))
		if art != "":
			_note(art, "cosmetics.gd (hat)")

	# Art loaded by a name BUILT AT RUNTIME, which no regex over the source
	# can see. The room is composed tile by tile from these, and without
	# this every one of them is reported as unreferenced -- eighteen false
	# alarms in a report whose entire value is that you believe it.
	for i in RoomBuilder.FLOOR_VARIANTS:
		_note("tile_floor_a%d" % i, "room_builder.gd (floor)")
		_note("tile_floor_b%d" % i, "room_builder.gd (floor)")
	for n: String in ["tile_wall_top0", "tile_wall_top1", "tile_wall_side",
			"tile_wall_bottom", "tile_window_l0", "tile_window_r0",
			"tile_window_l1", "tile_window_r1", "tile_door_top",
			"tile_door_bottom"]:
		_note(n, "room_builder.gd (walls)")
	# Same reasoning: show_student() loads "res://art/portrait_%s.png" %
	# s.art, one call site covering all eight, which is invisible to the
	# regex the same way the tiles above are.
	for n: String in Names.ART:
		_note("portrait_%s" % n, "hud.gd (show_student)")


func _note(art_name: String, where: String) -> void:
	if not _referenced.has(art_name):
		_referenced[art_name] = []
	if not _referenced[art_name].has(where):
		_referenced[art_name].append(where)


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [root]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			continue
		da.list_dir_begin()
		var n := da.get_next()
		while n != "":
			var full := d.path_join(n)
			if da.current_is_dir():
				dirs.append(full)
			elif n.ends_with(".gd") or n.ends_with(".tscn"):
				out.append(full)
			n = da.get_next()
		da.list_dir_end()
	return out


func _scan_files() -> void:
	_files.clear()
	_missing.clear()
	var da := DirAccess.open(ART_DIR)
	if da != null:
		da.list_dir_begin()
		var n := da.get_next()
		while n != "":
			if n.ends_with(".png"):
				_files.append(n.get_basename())
			n = da.get_next()
		da.list_dir_end()
	_files.sort()
	for want: String in _referenced.keys():
		if not _files.has(want):
			_missing.append(want)
	_missing.sort()
	if not _files.has(_sel_name):
		_sel_name = ""


## Everything on the toolbar, in one place, so the row and the state it
## reports cannot drift apart.
func _cycle_ground() -> void:
	_ground = (_ground + 1) % _grounds.size()
	%GroundBtn.text = "Ground: " + ["light", "dark", "magenta"][_ground]
	for c: Control in _cards:
		(c.get_meta("frame") as ColorRect).color = _grounds[_ground]


func _zoom_by(d: int) -> void:
	var z := clampi(_zoom + d, 1, 10)
	if z == _zoom:
		return
	_zoom = z
	_build(true)


func _rescan() -> void:
	_scan_references()
	_scan_files()
	_build(true)


func _on_filter_changed(_t: String) -> void:
	_filter_text = String(%Filter.text).strip_edges().to_lower()
	# A filter narrows the list to something new; the top is the right place
	# to be. Do NOT chase the old selection down the page on every keystroke.
	_build(false)


## `reveal_sel` brings the selected card back into view once the rebuilt
## grid has laid out -- wanted after Save, Rescan and zoom, not while typing
## a filter. Rebuilding used to drop you at the top every time regardless.
func _build(reveal_sel: bool = false) -> void:
	for c in grid.get_children():
		c.queue_free()
	_cards.clear()
	_frames.clear()

	_view.clear()
	var unused: Array[String] = []
	for name: String in _files:
		if not _referenced.has(name):
			unused.append(name)
		if _filter_text == "" or _filter_text in name:
			_view.append(name)

	for i in _view.size():
		var card := _card(_view[i], i)
		grid.add_child(card)
		_cards.append(card)

	_reflow()
	%ZoomLabel.text = "x%d" % _zoom
	%Count.text = ("%d images" % _files.size() if _filter_text == ""
		else "%d of %d match \"%s\"" % [_view.size(), _files.size(), _filter_text])
	_update_selbar()

	var lines: Array[String] = []
	if not _missing.is_empty():
		lines.append("[color=#ff8a80]MISSING (%d) — named in code or data, no file. This will fail at runtime:[/color]"
			% _missing.size())
		lines.append("   " + ", ".join(_missing))
	if not unused.is_empty():
		lines.append("[color=#ffd08a]UNREFERENCED (%d) — on disk, nothing mentions it:[/color]"
			% unused.size())
		lines.append("   " + ", ".join(unused))
	if lines.is_empty():
		lines.append("[color=#a5d6a7]Every image is referenced, and everything referenced exists.[/color]")
	report.text = "\n".join(lines)

	if reveal_sel and _sel_name != "":
		_reveal_selected_deferred()


## Bring the selected card back into view after a rebuild. The cards were
## just freed and remade, so their rects are not settled until the next
## layout pass -- ensure_control_visible() before that scrolls to (0, 0),
## which is the jump-to-top this file keeps having to fight.
func _reveal_selected_deferred() -> void:
	var idx := _view.find(_sel_name)
	if idx < 0:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_instance_valid(scroll):
		return
	if idx < _cards.size() and is_instance_valid(_cards[idx]):
		scroll.ensure_control_visible(_cards[idx])


## As many whole columns as the gallery is actually wide enough for.
## Recomputed on every resize, so dragging the forge's splitter reflows the
## grid instead of hiding sprites off the right-hand edge.
func _reflow() -> void:
	var avail := scroll.size.x - 16.0        # leave room for the scrollbar
	var step := _cell_size() + float(grid.get_theme_constant("h_separation"))
	var cols := maxi(1, int(avail / maxf(step, 1.0)))
	if cols == grid.columns:
		return
	# Changing the column count changes the grid's total height. The
	# ScrollContainer would keep its pixel offset, which is now a different
	# row of sprites. Hold the position PROPORTIONALLY instead, so dragging
	# the forge's splitter leaves you looking at roughly the same place.
	var vbar := scroll.get_v_scroll_bar()
	var ratio := (scroll.scroll_vertical / vbar.max_value) if vbar.max_value > 0.0 else 0.0
	grid.columns = cols
	_restore_scroll_ratio(ratio)


func _restore_scroll_ratio(ratio: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_instance_valid(scroll):
		return
	var vbar := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(round(ratio * vbar.max_value))


func _cell_size() -> int:
	return 48 + _zoom * 26


## A texture read straight off the PNG on disk, NOT through load() and the
## import cache. This tool's editor writes art/*.png without re-importing
## (see _save_editor -- a --import child of the running Godot has hung it),
## so load() would keep showing the pre-edit pixels until the next import.
## The gallery has to mirror what is actually on disk.
func _raw_texture(art_name: String) -> Texture2D:
	var img := _load_raw_image("%s/%s.png" % [ART_DIR, art_name])
	return ImageTexture.create_from_image(img) if img != null else null


## Decode a PNG straight from its bytes. Image.load() on a res:// path logs
## a "will not work on export" warning on every call, and this tool reads
## dozens at once; load_png_from_buffer() is silent and does the same job.
func _load_raw_image(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	return img if img.load_png_from_buffer(bytes) == OK else null


func _card(art_name: String, index: int) -> Control:
	var tex: Texture2D = _raw_texture(art_name)
	var w: int = tex.get_width() if tex != null else 16
	var h: int = tex.get_height() if tex != null else 16

	# A fixed cell with the texture letterboxed inside it.
	#
	# The first version scaled each TextureRect by the zoom factor. That
	# fought the Control layout (a scaled child of a FULL_RECT anchor draws
	# nowhere useful) and, worse, room.png is 320x176 -- at 3x it was a
	# thousand pixels wide and tore the grid apart. Letterboxing means one
	# cell size for a 10px paper and a whole room.
	var cell := _cell_size()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(cell, 0)
	box.add_theme_constant_override("separation", 2)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(art_name == _sel_name))

	var frame := ColorRect.new()
	frame.color = _grounds[_ground]
	frame.custom_minimum_size = Vector2(cell, cell)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_card_input.bind(index))
	frame.tooltip_text = "%s   %dx%d\nClick to select, double-click to edit." % [
		art_name, w, h]

	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	panel.add_child(frame)
	box.add_child(panel)

	var used: Array = _referenced.get(art_name, [])
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.text = art_name
	label.clip_text = true
	label.add_theme_color_override("font_color",
		ForgeTheme.ACCENT if art_name == _sel_name else Color(0.9, 0.9, 0.9))
	box.add_child(label)

	var where := Label.new()
	where.add_theme_font_size_override("font_size", 9)
	where.clip_text = true
	if used.is_empty():
		where.text = "%dx%d · unused" % [w, h]
		where.add_theme_color_override("font_color", ForgeTheme.WARN)
	else:
		where.text = "%dx%d" % [w, h]
		where.add_theme_color_override("font_color", ForgeTheme.FAINT)
	box.add_child(where)

	# _cycle_ground() and _select() reach back into the card to repaint one
	# thing without rebuilding it; these are how they find the parts.
	box.set_meta("panel", panel)
	box.set_meta("frame", frame)
	box.set_meta("label", label)
	_frames.append(panel)
	return box


# =====================================================================
# the editor's preview strip
# =====================================================================

## One live copy of the sprite per gallery ground, beside the canvas.
##
## Editing happens at x12 or more over a checkerboard, which is the one
## view that tells you nothing about how the sprite reads in the game. The
## grounds are the gallery's own three, magenta included, so the check that
## catches unstripped chroma key is available while you are still painting
## rather than only after you close the editor.
const PREVIEW_LABELS: Array[String] = ["light", "dark", "magenta"]

var _preview_tex: ImageTexture = null
var _preview_dirty := false


func _build_previews() -> void:
	for c in %Previews.get_children():
		c.queue_free()
	_preview_tex = ImageTexture.create_from_image(_edit_img)
	for i in _grounds.size():
		var box := ColorRect.new()
		box.color = _grounds[i]
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.tooltip_text = "The sprite on the %s ground" % PREVIEW_LABELS[i]
		var pic := TextureRect.new()
		pic.texture = _preview_tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pic)
		%Previews.add_child(box)


## Once a frame at most, and only while something has actually changed --
## a texture upload per painted pixel would cost more than the painting.
func _process(_dt: float) -> void:
	if not _preview_dirty or not _editing or _edit_img == null:
		return
	_preview_dirty = false
	if _preview_tex == null:
		return
	if _preview_tex.get_size() != Vector2(_edit_img.get_size()):
		_preview_tex.set_image(_edit_img)
	else:
		_preview_tex.update(_edit_img)


func _card_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.85, 0.3, 0.10) if selected else Color(0, 0, 0, 0)
	sb.border_color = ForgeTheme.ACCENT if selected else Color(0, 0, 0, 0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	# A PanelContainer lays its child out INSIDE the content margins, so a
	# zero margin puts the thumbnail on top of the very border that shows
	# the selection. Reserve the border's own width, on both states, so the
	# frame stays visible and the card does not resize when you select it.
	sb.set_content_margin_all(3)
	return sb


func _on_card_input(e: InputEvent, index: int) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# `false`: do NOT scroll. The card you just clicked is by definition
		# already on screen, and scrolling to it is what made picking a
		# sprite at the bottom of the gallery throw you back to the top.
		_select(index, false)
		if (e as InputEventMouseButton).double_click:
			_open_editor(_view[index], false)


## Move the selection to display position `index`.
##
## This used to call _build(), which frees every card and makes new ones,
## and THEN asked the ScrollContainer to reveal the new card. A container
## has not laid its children out in the frame they are added, so every one
## of those cards was still sitting at (0, 0) -- ensure_control_visible()
## dutifully scrolled to the top of the list, every single time, and
## clicking a sprite at the bottom of the gallery bounced you to the first
## row. Nothing about a selection needs the grid rebuilt: repaint the two
## frames that changed and leave the layout, and the scroll position, alone.
func _select(index: int, reveal: bool = true) -> void:
	if _view.is_empty():
		_sel_name = ""
		_update_selbar()
		return
	index = clampi(index, 0, _view.size() - 1)
	var was := _view.find(_sel_name)
	if was == index:
		return
	if was >= 0 and was < _frames.size():
		_frames[was].add_theme_stylebox_override("panel", _card_style(false))
		(_cards[was].get_meta("label") as Label).add_theme_color_override(
			"font_color", Color(0.9, 0.9, 0.9))
	_sel_name = _view[index]
	if index < _frames.size():
		_frames[index].add_theme_stylebox_override("panel", _card_style(true))
		(_cards[index].get_meta("label") as Label).add_theme_color_override(
			"font_color", ForgeTheme.ACCENT)
		# Only the keyboard needs this, and only then because the arrow keys
		# can walk the selection off the visible rows.
		if reveal:
			scroll.ensure_control_visible(_cards[index])
	_update_selbar()


## What is selected and what would happen if you pressed Edit. The gallery
## had no such line: the only feedback for a click was a border you had to
## hunt for among 131 thumbnails.
func _update_selbar() -> void:
	# One place the selection is reported out. Covers click, arrow keys and
	# the post-save rebuild -- anything that lands here has settled _sel_name.
	sprite_selected.emit(_sel_name)
	var has := _sel_name != ""
	(%EditBtn as Button).disabled = not has
	if not has:
		(%SelName as Label).text = "Nothing selected"
		(%SelWhere as Label).add_theme_color_override("font_color", ForgeTheme.FAINT)
		(%SelWhere as Label).text = ("No sprite matches \"%s\"." % _filter_text
			if _view.is_empty() and _filter_text != ""
			else "Click a sprite, or use the arrow keys.")
		return
	var img := _load_raw_image("%s/%s.png" % [ART_DIR, _sel_name])
	var dims := "%dx%d" % [img.get_width(), img.get_height()] if img != null else "?"
	(%SelName as Label).text = "%s   %s" % [_sel_name, dims]
	var used: Array = _referenced.get(_sel_name, [])
	(%SelWhere as Label).text = ("used by " + ", ".join(used) if not used.is_empty()
		else "Nothing in the code or data mentions this file.")
	(%SelWhere as Label).add_theme_color_override("font_color",
		ForgeTheme.FAINT if not used.is_empty() else ForgeTheme.WARN)


# =====================================================================
# navigation and top-level input
# =====================================================================

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	# _input() fires BEFORE Godot's own GUI dispatch, so without this guard
	# every keystroke typed into the "new sprite" dialog's name field would
	# ALSO hit these shortcuts underneath it -- N reopening the dialog on
	# itself, Enter opening an editor, and Escape quitting the whole tool
	# out from under a player trying to cancel just the popup.
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit:
		# Esc leaves the filter box rather than quitting the tool from
		# under someone who only meant to stop typing.
		if (e as InputEventKey).keycode == KEY_ESCAPE and focused == %Filter:
			(%Filter as LineEdit).text = ""
			_on_filter_changed("")
			(%Filter as LineEdit).release_focus()
		return
	var k := (e as InputEventKey).keycode
	var ctrl := (e as InputEventKey).ctrl_pressed

	if _editing:
		_editor_input(k, ctrl)
		return

	# Positions count in _view (what is on screen), not in _files: with a
	# filter typed they are different lists, and the arrow keys have to walk
	# the one you can see.
	var at := _view.find(_sel_name)
	if k == KEY_1:
		_cycle_ground()
	elif k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD:
		_zoom_by(1)
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_zoom_by(-1)
	elif k == KEY_R:
		_rescan()
	elif k == KEY_SLASH:
		(%Filter as LineEdit).grab_focus()
		(%Filter as LineEdit).select_all()
	elif k == KEY_LEFT:
		_select(maxi(0, at - 1) if at >= 0 else 0)
	elif k == KEY_RIGHT:
		_select(at + 1 if at >= 0 else 0)
	elif k == KEY_UP:
		_select(maxi(0, at - grid.columns) if at >= 0 else 0)
	elif k == KEY_DOWN:
		_select(at + grid.columns if at >= 0 else 0)
	elif k == KEY_HOME:
		_select(0)
	elif k == KEY_END:
		_select(_view.size() - 1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		if _sel_name != "":
			_open_editor(_sel_name, false)
	elif k == KEY_N:
		_prompt_new_sprite()
	elif k == KEY_ESCAPE:
		# One pane of the Master Forge must not take the whole tool down
		# with it; standalone, Esc is still how you leave.
		if _standalone():
			get_tree().quit()


func _editor_input(k: Key, ctrl: bool) -> void:
	if k == KEY_ESCAPE:
		_close_editor()
	elif ctrl and k == KEY_S:
		_save_editor()
	elif ctrl and k == KEY_Z:
		_undo_action()
	elif ctrl and k == KEY_Y:
		_redo_action()
	elif k == KEY_1:
		_set_tool("brush")
	elif k == KEY_2:
		_set_tool("eraser")
	elif k == KEY_3:
		_set_tool("fill")
	elif k == KEY_4:
		_set_tool("eyedrop")
	elif k == KEY_5:
		_set_tool("line")
	elif k == KEY_6:
		_set_tool("rect")
	elif k == KEY_7:
		_set_tool("ellipse")
	elif k == KEY_BRACKETLEFT:
		_set_brush_size(_brush_size - 1)
	elif k == KEY_BRACKETRIGHT:
		_set_brush_size(_brush_size + 1)
	elif k == KEY_M:
		_cycle_mirror()
	elif k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD:
		canvas.set_zoom(canvas.zoom + 1)
		_update_status()
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		canvas.set_zoom(canvas.zoom - 1)
		_update_status()
	elif k == KEY_UP:
		_nudge(0, -1)
	elif k == KEY_DOWN:
		_nudge(0, 1)
	elif k == KEY_LEFT:
		_nudge(-1, 0)
	elif k == KEY_RIGHT:
		_nudge(1, 0)

func _nudge(dx: int, dy: int) -> void:
	_push_undo()
	var new_img = Image.create(_edit_img.get_width(), _edit_img.get_height(), false, _edit_img.get_format())
	new_img.fill(Color(0, 0, 0, 0))
	var src_rect = Rect2i(0, 0, _edit_img.get_width(), _edit_img.get_height())
	new_img.blit_rect(_edit_img, src_rect, Vector2i(dx, dy))
	_edit_img.copy_from(new_img)
	canvas.queue_redraw()
	_preview_dirty = true



# =====================================================================
# new sprite
# =====================================================================

func _prompt_new_sprite() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "New sprite"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)

	box.add_child(Label.new())
	(box.get_child(0) as Label).text = "name (snake_case)"
	var name_edit := LineEdit.new()
	name_edit.text = "new_sprite"
	box.add_child(name_edit)

	var size_label := Label.new()
	size_label.text = "size, e.g. 16x22 (288x192 for a character sheet)"
	box.add_child(size_label)
	var size_edit := LineEdit.new()
	size_edit.text = "16x16"
	box.add_child(size_edit)

	dlg.add_child(box)
	add_child(dlg)
	dlg.get_ok_button().text = "Create"
	dlg.confirmed.connect(func() -> void:
		_create_new_sprite(name_edit.text.strip_edges(), size_edit.text.strip_edges())
		dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	dlg.popup_centered()
	name_edit.grab_focus()


func _create_new_sprite(name: String, size_text: String) -> void:
	if not _is_valid_name(name):
		push_warning("not a usable name: %r (lowercase, digits, underscores)" % name)
		return
	if _files.has(name):
		push_warning("%s already exists -- open it from the gallery instead" % name)
		return
	var parts := size_text.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_warning("size should look like 16x22, got %r" % size_text)
		return
	var w := clampi(int(parts[0]), 1, 512)
	var h := clampi(int(parts[1]), 1, 512)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_open_editor_with_image(name, img, true)


func _is_valid_name(name: String) -> bool:
	if name.is_empty():
		return false
	for c in name:
		if not (c in "abcdefghijklmnopqrstuvwxyz0123456789_"):
			return false
	return true


# =====================================================================
# edit mode
# =====================================================================

func _open_editor(art_name: String, is_new: bool) -> void:
	# Straight off disk, not through the import cache -- so editing a sprite
	# you just saved picks up the real current pixels, not a stale import.
	var img := _load_raw_image("%s/%s.png" % [ART_DIR, art_name])
	if img == null:
		img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_open_editor_with_image(art_name, img, is_new)


func _open_editor_with_image(art_name: String, img: Image, is_new: bool) -> void:
	_edit_name = art_name
	_edit_is_new = is_new
	_edit_img = img
	_undo.clear()
	_redo.clear()
	_last_pixel = Vector2i(-1, -1)
	_shape_anchor = Vector2i(-1, -1)
	(%Mirror as Button).text = "Mirror: " + MIRROR_NAMES[_mirror]
	if canvas != null:
		canvas.clear_preview()

	_palette = _extract_palette(_edit_img)
	if _palette.is_empty():
		_palette = [Color(0.1, 0.1, 0.1, 1), Color(1, 1, 1, 1)]
	_cur_colour = _palette[0]

	canvas.set_image(_edit_img)
	_preview_dirty = true
	if _edit_img.get_width() == CHAR_W and _edit_img.get_height() == CHAR_H:
		canvas.cell_w = CHAR_CW
		canvas.cell_h = CHAR_CH
	else:
		canvas.cell_w = 0
		canvas.cell_h = 0
	canvas.set_zoom(clampi(720 / maxi(_edit_img.get_width(), 1), 4, 24))

	_editing = true
	browse.visible = false
	editor.visible = true
	(%EditTitle as Label).text = "Editing  %s%s" % [art_name,
		"   (new — nothing loads it until you Sync & Reimport)" if is_new else ""]
	_rebuild_palette_row()
	_build_previews()
	_set_tool("brush")
	_set_brush_size(_brush_size)
	_update_status()


func _close_editor() -> void:
	_editing = false
	editor.visible = false
	browse.visible = true
	_edit_img = null


func _set_tool(t: String) -> void:
	_tool = t
	for tname: String in _tool_btns:
		(_tool_btns[tname] as Button).button_pressed = (tname == t)
	_update_status()


func _set_brush_size(n: int) -> void:
	_brush_size = clampi(n, 1, 16)
	if _size_label != null:
		_size_label.text = str(_brush_size)
	for k: int in _size_btns:
		(_size_btns[k] as Button).button_pressed = (k == _brush_size)
	_update_status()


func _is_shape_tool() -> bool:
	return _tool == "line" or _tool == "rect" or _tool == "ellipse"


const MIRROR_NAMES: Array[String] = ["off", "X", "Y", "XY"]


func _cycle_mirror() -> void:
	_mirror = (_mirror + 1) % 4
	(%Mirror as Button).text = "Mirror: " + MIRROR_NAMES[_mirror]
	_update_status()


## `p` plus its reflection(s) for the current mirror mode. Mirrors within
## the character cell on a sheet, across the whole sprite otherwise.
func _mirror_points(p: Vector2i) -> Array[Vector2i]:
	if _mirror == 0 or _edit_img == null:
		return [p]
	var cw: int = canvas.cell_w if canvas.cell_w > 0 else _edit_img.get_width()
	var ch: int = canvas.cell_h if canvas.cell_h > 0 else _edit_img.get_height()
	var cx0 := (p.x / cw) * cw
	var cy0 := (p.y / ch) * ch
	var mx := cx0 + cw - 1 - (p.x - cx0)
	var my := cy0 + ch - 1 - (p.y - cy0)
	var pts: Array[Vector2i] = [p]
	if _mirror == 1 or _mirror == 3:
		pts.append(Vector2i(mx, p.y))
	if _mirror == 2 or _mirror == 3:
		pts.append(Vector2i(p.x, my))
	if _mirror == 3:
		pts.append(Vector2i(mx, my))
	return pts


## Pixel offsets for the current brush nib, centred on the anchor.
func _brush_mask() -> Array[Vector2i]:
	if _brush_size <= 1:
		return [Vector2i.ZERO]
	var lo := -(_brush_size - 1) / 2
	var hi := _brush_size / 2
	var rad := _brush_size / 2.0
	var out: Array[Vector2i] = []
	for dy in range(lo, hi + 1):
		for dx in range(lo, hi + 1):
			if _brush_round and Vector2(dx, dy).length() > rad:
				continue
			out.append(Vector2i(dx, dy))
	return out


func _stamp(p: Vector2i, col: Color) -> void:
	for base: Vector2i in _mirror_points(p):
		for off: Vector2i in _brush_mask():
			var q := base + off
			if _in_bounds(q):
				_edit_img.set_pixelv(q, col)


## The shape's pixels plus their mirror reflections -- for the on-canvas
## preview. The real commit mirrors through _stamp() instead.
func _preview_pixels(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var raw := _shape_pixels(a, b)
	if _mirror == 0:
		return raw
	var out: Array[Vector2i] = []
	for q: Vector2i in raw:
		out.append_array(_mirror_points(q))
	return out


func _shape_pixels(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	match _tool:
		"line":
			var out: Array[Vector2i] = [a]
			out.append_array(_line_points(a, b))
			return out
		"rect":
			return _rect_pixels(a, b, _shape_filled)
		"ellipse":
			return _ellipse_pixels(a, b, _shape_filled)
	return []


func _rect_pixels(a: Vector2i, b: Vector2i, filled: bool) -> Array[Vector2i]:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	var out: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if filled or x == x0 or x == x1 or y == y0 or y == y1:
				out.append(Vector2i(x, y))
	return out


func _ellipse_pixels(a: Vector2i, b: Vector2i, filled: bool) -> Array[Vector2i]:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	var cx := (x0 + x1) / 2.0
	var cy := (y0 + y1) / 2.0
	var rx := maxf(0.5, (x1 - x0) / 2.0)
	var ry := maxf(0.5, (y1 - y0) / 2.0)
	var inside := func(x: int, y: int) -> bool:
		var nx := (x - cx) / rx
		var ny := (y - cy) / ry
		return nx * nx + ny * ny <= 1.0
	var out: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not inside.call(x, y):
				continue
			if filled or not (inside.call(x - 1, y) and inside.call(x + 1, y) \
					and inside.call(x, y - 1) and inside.call(x, y + 1)):
				out.append(Vector2i(x, y))
	return out


func _update_status() -> void:
	if _status == null or _edit_img == null:
		return
	var news := " (new)" if _edit_is_new else ""
	var at := "  -,-"
	if _hover_px.x >= 0 and _hover_px.x < _edit_img.get_width() \
			and _hover_px.y >= 0 and _hover_px.y < _edit_img.get_height():
		at = "  %d,%d" % [_hover_px.x, _hover_px.y]
	var nib := "%s%d" % ["round " if _brush_round else "", _brush_size]
	var mir := "" if _mirror == 0 else "   mirror " + MIRROR_NAMES[_mirror]
	# The keyboard reference used to be stapled to the end of this line and
	# redrawn on every mouse move. It is a fixed Hints label now; what is
	# left here is only what actually changes as you paint.
	_status.text = "%s%s   %dx%d   zoom x%d   %s, nib %s%s   colour #%s   at%s" % [
		_edit_name, news, _edit_img.get_width(), _edit_img.get_height(),
		canvas.zoom if canvas != null else 0,
		_tool, nib, mir, _cur_colour.to_html(false), at]


func _extract_palette(img: Image) -> Array[Color]:
	var seen := {}
	var out: Array[Color] = []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var key := c.to_html(false)
			if not seen.has(key):
				seen[key] = true
				out.append(Color(c.r, c.g, c.b, 1.0))
	return out


## Read tools/palette.json, written by tools/make_palette.py from the
## generators' own colour constants. Missing or malformed is not an error:
## the editor predates this row and works without it.
func _load_house_palette() -> void:
	_house.clear()
	var f := FileAccess.open("res://tools/palette.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("tools/palette.json is not readable — house swatches are off")
		return
	for group: String in (parsed as Dictionary).keys():
		if group.begins_with("_"):
			continue                      # metadata, not a group of colours
		var row: Variant = (parsed as Dictionary)[group]
		if not (row is Dictionary):
			continue
		for cname: String in (row as Dictionary).keys():
			var hex := str((row as Dictionary)[cname])
			if not hex.begins_with("#"):
				continue
			_house.append({"group": group, "name": cname,
				"colour": Color.from_string(hex, Color.MAGENTA)})
	_rebuild_house_row()


## One clickable square per house colour, grouped, with the constant's own
## name on the tooltip -- the name is what you type into the other forge
## tabs (WOOD=#hex), so the two halves of the tool agree on vocabulary.
func _rebuild_house_row() -> void:
	if _house_row == null:
		return
	for c in _house_row.get_children():
		c.queue_free()
	var last_group := ""
	for entry: Dictionary in _house:
		if entry["group"] != last_group:
			last_group = entry["group"]
			if _house_row.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(10, 0)
				_house_row.add_child(gap)
		var col: Color = entry["colour"]
		var sw := ColorRect.new()
		sw.color = col
		sw.custom_minimum_size = Vector2(18, 18)
		sw.tooltip_text = "%s  %s  (%s)" % [entry["name"], col.to_html(false),
			entry["group"]]
		sw.mouse_filter = Control.MOUSE_FILTER_STOP
		sw.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				_cur_colour = col
				_update_status())
		_house_row.add_child(sw)


func _rebuild_palette_row() -> void:
	for c in _swatch_row.get_children():
		c.queue_free()
	for col: Color in _palette:
		var sw := ColorRect.new()
		sw.color = col
		sw.custom_minimum_size = Vector2(22, 22)
		sw.mouse_filter = Control.MOUSE_FILTER_STOP
		sw.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				_cur_colour = col
				_update_status())
		_swatch_row.add_child(sw)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(22, 22)
	picker.color = _cur_colour
	picker.color_changed.connect(func(c: Color) -> void:
		_cur_colour = Color(c.r, c.g, c.b, 1.0)
		if not _palette.any(func(p: Color) -> bool: return p.is_equal_approx(_cur_colour)):
			_palette.append(_cur_colour)
			_rebuild_palette_row())
	_swatch_row.add_child(picker)


# --- painting ---

func _on_pixel_right_click(p: Vector2i) -> void:
	if not _in_bounds(p): return
	var c := _edit_img.get_pixelv(p)
	if c.a > 0.01:
		_cur_colour = Color(c.r, c.g, c.b, 1.0)
		_update_status()

func _on_pixel_down(p: Vector2i) -> void:
	if not _in_bounds(p):
		return
	if _is_shape_tool():
		# line / rect / ellipse: anchor now, preview on drag, commit on up.
		_shape_anchor = p
		_shape_last = p
		canvas.set_preview(_preview_pixels(p, p))
		return
	_push_undo()
	_apply_tool(p)
	_last_pixel = p
	canvas.queue_redraw()
	_preview_dirty = true


func _on_pixel_drag(p: Vector2i) -> void:
	if _is_shape_tool():
		if _shape_anchor.x >= 0:
			_shape_last = _shape_constrain(_shape_anchor, p)
			canvas.set_preview(_preview_pixels(_shape_anchor, _shape_last))
		return
	if _tool != "brush" and _tool != "eraser":
		return
	if p == _last_pixel:
		return
	# Paint every pixel BETWEEN the last sample and this one. A mouse-move
	# is sampled every few pixels at speed, so applying the tool only at
	# the samples left a dotted trail on a fast drag; walk the line so the
	# stroke is solid.
	if _last_pixel.x >= 0:
		for step: Vector2i in _line_points(_last_pixel, p):
			_apply_tool(step)
	else:
		_apply_tool(p)
	_last_pixel = p
	canvas.queue_redraw()
	_preview_dirty = true


## Hold Shift while dragging a LINE to snap it to horizontal, vertical or
## 45 degrees.
func _shape_constrain(a: Vector2i, b: Vector2i) -> Vector2i:
	if _tool != "line" or not Input.is_key_pressed(KEY_SHIFT):
		return b
	var d := b - a
	if absi(d.x) > absi(d.y) * 2:
		return Vector2i(b.x, a.y)
	if absi(d.y) > absi(d.x) * 2:
		return Vector2i(a.x, b.y)
	var m := maxi(absi(d.x), absi(d.y))
	return a + Vector2i(signi(d.x) * m, signi(d.y) * m)


## Integer points along the line a -> b, inclusive of b, EXCLUSIVE of a
## (a was painted on the previous sample or on pixel_down). Bresenham.
func _line_points(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		if not (x == a.x and y == a.y):
			pts.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return pts


func _on_pixel_up() -> void:
	if _is_shape_tool() and _shape_anchor.x >= 0:
		_push_undo()
		for q: Vector2i in _shape_pixels(_shape_anchor, _shape_last):
			_stamp(q, _cur_colour)
		_shape_anchor = Vector2i(-1, -1)
		canvas.clear_preview()
		canvas.queue_redraw()
		_preview_dirty = true
	_last_pixel = Vector2i(-1, -1)


func _on_pixel_hover(p: Vector2i) -> void:
	if p != _hover_px:
		_hover_px = p
		_update_status()


func _in_bounds(p: Vector2i) -> bool:
	return _edit_img != null and p.x >= 0 and p.y >= 0 \
		and p.x < _edit_img.get_width() and p.y < _edit_img.get_height()


func _apply_tool(p: Vector2i) -> void:
	match _tool:
		"brush":
			_stamp(p, _cur_colour)
		"eraser":
			_stamp(p, Color(0, 0, 0, 0))
		"eyedrop":
			var c := _edit_img.get_pixelv(p)
			if c.a > 0.01:
				_cur_colour = Color(c.r, c.g, c.b, 1.0)
			_set_tool("brush")
			_update_status()
		"fill":
			_flood_fill(p, _edit_img.get_pixelv(p), _cur_colour)


## 4-directional flood fill. Flat colours, no anti-aliasing, so an exact
## match is the right comparison -- there is nothing to tolerate.
func _flood_fill(start: Vector2i, target: Color, replacement: Color) -> void:
	if target.is_equal_approx(replacement):
		return
	var w := _edit_img.get_width()
	var h := _edit_img.get_height()
	var stack: Array[Vector2i] = [start]
	var seen := {}
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen.has(p):
			continue
		if not _edit_img.get_pixelv(p).is_equal_approx(target):
			continue
		seen[p] = true
		_edit_img.set_pixelv(p, replacement)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))


# --- undo/redo: one snapshot per STROKE (pushed on pixel_down), not per
# pixel, so a whole brush drag is one undo step. ---

const UNDO_LIMIT := 60


func _push_undo() -> void:
	_undo.append(_edit_img.duplicate())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()


func _undo_action() -> void:
	if _undo.is_empty():
		return
	_redo.append(_edit_img.duplicate())
	_edit_img = _undo.pop_back()
	canvas.set_image(_edit_img)
	_preview_dirty = true


func _redo_action() -> void:
	if _redo.is_empty():
		return
	_undo.append(_edit_img.duplicate())
	_edit_img = _redo.pop_back()
	canvas.set_image(_edit_img)
	_preview_dirty = true


# --- saving ---

func _save_editor() -> void:
	if _edit_img == null:
		return
	var saved_name := _edit_name
	var had_import := FileAccess.file_exists("res://art/%s.png.import" % saved_name)

	_write_grid_source(saved_name, _edit_img)
	# The PNG is written directly from the edited Image, so the result does
	# not depend on the .txt -> PNG round trip through make_art.py being
	# correct at the moment you hit save.
	var err := _edit_img.save_png("res://art/%s.png" % saved_name)
	if err != OK:
		push_error("could not write art/%s.png (%d)" % [saved_name, err])
		return

	# DO NOT shell out to `godot --headless --import` and wait on it here.
	# A Godot import spawned as a child of a running Godot has hung outright
	# on this machine instead of exiting -- the same fault .githooks and
	# AGENTS.md call out -- and _save_editor() blocking on it froze this
	# whole editor on save, with no way out but killing it.
	#
	# Writing the two files is the reliable half. Making Godot SEE the new
	# pixels is a separate, guaranteed step and never this tool's job to
	# wait on:
	#   - `Browse Art.bat` runs `--import` before it launches this tool, so
	#     the gallery is up to date every time you open it;
	#   - `Reimport Art.bat` is the one click that makes the GAME pick up
	#     what you just changed.
	_close_editor()
	_scan_references()
	_scan_files()
	_sel_name = saved_name
	# Land back on the sprite you just saved, not at the top of the gallery.
	_build(true)

	var note := "[color=#a5d6a7]Saved art/%s.png + tools/sprites/%s.txt.[/color]  " % [
		saved_name, saved_name]
	if had_import:
		note += "Run [b]Reimport Art.bat[/b] (or relaunch the game) to see it in play."
	else:
		note += "[color=#ffd08a]NEW asset -- run [b]Reimport Art.bat[/b] before anything loads it.[/color]"
	report.text = note + "\n" + report.text


## The inverse of make_art.py's parse_grid_sprite() -- writes exactly the
## final pixels as a text grid, so it is a faithful round trip: reopening
## the same sprite in this editor, or running make_art.py, reproduces the
## same PNG. No `# outline:`/`# shadow:` directive is emitted -- those are
## POST-processing steps applied after parsing, and this file already IS
## the post-processed result.
func _write_grid_source(name: String, img: Image) -> void:
	var char_of := {}
	var palette_bits: Array[String] = []
	var next_char := 0
	var rows: Array[String] = []

	for y in img.get_height():
		var row := ""
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				row += "."
				continue
			var key := c.to_html(false)
			if not char_of.has(key):
				if next_char >= CHARSET.length():
					push_warning("%s: more than %d colours; reusing the last character"
						% [name, CHARSET.length()])
					char_of[key] = CHARSET[CHARSET.length() - 1]
				else:
					char_of[key] = CHARSET[next_char]
					next_char += 1
					palette_bits.append("%s = #%s" % [char_of[key], key])
			row += char_of[key]
		rows.append(row)

	var dir := DirAccess.open(SPRITE_SRC_DIR)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(SPRITE_SRC_DIR))

	var f := FileAccess.open("%s/%s.txt" % [SPRITE_SRC_DIR, name], FileAccess.WRITE)
	if f == null:
		push_error("could not write tools/sprites/%s.txt" % name)
		return
	f.store_line("# name: %s" % name)
	f.store_line("# palette: %s" % ", ".join(palette_bits))
	for row: String in rows:
		f.store_line(row)
	f.close()
