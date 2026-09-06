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
var _referenced := {}      ## art name -> where it is mentioned
var _missing: Array[String] = []
var _sel := -1
var _cards: Array[Control] = []

# --- edit mode ---
var _editing := false
var _edit_name := ""
var _edit_is_new := false
var _edit_img: Image = null
var _undo: Array[Image] = []
var _redo: Array[Image] = []
var _last_pixel := Vector2i(-1, -1)
var _tool := "brush"
var _cur_colour := Color(0.1, 0.1, 0.1, 1.0)
var _palette: Array[Color] = []
var _swatch_row: HBoxContainer
var _status: Label

@onready var grid: GridContainer = $V/Scroll/Grid
@onready var header: Label = $V/Header
@onready var report: RichTextLabel = $V/Report
@onready var scroll: ScrollContainer = $V/Scroll
@onready var editor: VBoxContainer = $V/Editor
@onready var canvas: Control = $V/Editor/Body/CanvasWrap/Canvas
@onready var _btn_brush: Button = $V/Editor/Toolbar/Brush
@onready var _btn_eraser: Button = $V/Editor/Toolbar/Eraser
@onready var _btn_fill: Button = $V/Editor/Toolbar/Fill
@onready var _btn_eyedrop: Button = $V/Editor/Toolbar/Eyedrop


func _ready() -> void:
	# The project renders at 320x176 with viewport stretch; a dev tool wants
	# a real window and real pixels.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1180, 820))
	get_window().title = "EDUSystem - art"

	_swatch_row = $V/Editor/SwatchRow
	_status = $V/Editor/Status

	canvas.pixel_down.connect(_on_pixel_down)
	canvas.pixel_drag.connect(_on_pixel_drag)
	canvas.pixel_up.connect(_on_pixel_up)

	_btn_brush.pressed.connect(func() -> void: _set_tool("brush"))
	_btn_eraser.pressed.connect(func() -> void: _set_tool("eraser"))
	_btn_fill.pressed.connect(func() -> void: _set_tool("fill"))
	_btn_eyedrop.pressed.connect(func() -> void: _set_tool("eyedrop"))
	$V/Editor/Toolbar/Undo.pressed.connect(_undo_action)
	$V/Editor/Toolbar/Redo.pressed.connect(_redo_action)
	$V/Editor/Toolbar/Save.pressed.connect(_save_editor)
	$V/Editor/Toolbar/Cancel.pressed.connect(_close_editor)

	_scan_references()
	_scan_files()
	_build()


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
	_sel = clampi(_sel, -1, _files.size() - 1)


func _build() -> void:
	for c in grid.get_children():
		c.queue_free()
	_cards.clear()

	var unused: Array[String] = []
	for i in _files.size():
		var name: String = _files[i]
		if not _referenced.has(name):
			unused.append(name)
		var card := _card(name, i)
		grid.add_child(card)
		_cards.append(card)

	header.text = ("%d images    zoom x%d    ground: %s    [1] ground  " +
		"[+/-] zoom  [R] rescan  [arrows] select  [Enter] edit  [N] new") % [
		_files.size(), _zoom,
		["light", "dark", "magenta"][_ground]]

	var lines: Array[String] = []
	if not _missing.is_empty():
		lines.append("[color=#ff8a80]MISSING (%d) - named in code or data, no file. This will fail at runtime:[/color]"
			% _missing.size())
		lines.append("   " + ", ".join(_missing))
	if not unused.is_empty():
		lines.append("[color=#ffd08a]UNREFERENCED (%d) - on disk, nothing mentions it:[/color]"
			% unused.size())
		lines.append("   " + ", ".join(unused))
	if lines.is_empty():
		lines.append("[color=#a5d6a7]Every image is referenced, and everything referenced exists.[/color]")
	report.text = "\n".join(lines)


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
	var cell := 48 + _zoom * 26
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(cell, 0)

	var panel := PanelContainer.new()
	if index == _sel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(1, 0.85, 0.3)
		sb.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", sb)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(3)
		sb.border_color = Color(0, 0, 0, 0)
		panel.add_theme_stylebox_override("panel", sb)

	var frame := ColorRect.new()
	frame.color = _grounds[_ground]
	frame.custom_minimum_size = Vector2(cell, cell)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_card_input.bind(index))

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
	label.text = "%s\n%dx%d%s" % [art_name, w, h,
		"" if not used.is_empty() else "   UNUSED"]
	label.add_theme_color_override("font_color",
		Color(1, 0.82, 0.54) if used.is_empty() else Color(0.9, 0.9, 0.9))
	box.add_child(label)

	var where := Label.new()
	where.add_theme_font_size_override("font_size", 9)
	where.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	where.text = ", ".join(used).substr(0, 34)
	box.add_child(where)
	return box


func _on_card_input(e: InputEvent, index: int) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select(index)
		if (e as InputEventMouseButton).double_click:
			_open_editor(_files[index], false)


func _select(index: int) -> void:
	_sel = clampi(index, 0, _files.size() - 1)
	_build()
	if _sel >= 0 and _sel < _cards.size():
		scroll.ensure_control_visible(_cards[_sel])


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
		return
	var k := (e as InputEventKey).keycode
	var ctrl := (e as InputEventKey).ctrl_pressed

	if _editing:
		_editor_input(k, ctrl)
		return

	if k == KEY_1:
		_ground = (_ground + 1) % _grounds.size()
		_build()
	elif k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD:
		_zoom = mini(_zoom + 1, 10)
		_build()
	elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		_zoom = maxi(_zoom - 1, 1)
		_build()
	elif k == KEY_R:
		_scan_references()
		_scan_files()
		_build()
	elif k == KEY_LEFT:
		_select(maxi(0, (_sel if _sel >= 0 else 0) - 1))
	elif k == KEY_RIGHT:
		_select(mini(_files.size() - 1, (_sel if _sel >= 0 else -1) + 1))
	elif k == KEY_UP:
		_select(maxi(0, (_sel if _sel >= 0 else 0) - grid.columns))
	elif k == KEY_DOWN:
		_select(mini(_files.size() - 1, (_sel if _sel >= 0 else -grid.columns) + grid.columns))
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		if _sel >= 0:
			_open_editor(_files[_sel], false)
	elif k == KEY_N:
		_prompt_new_sprite()
	elif k == KEY_ESCAPE:
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

	_palette = _extract_palette(_edit_img)
	if _palette.is_empty():
		_palette = [Color(0.1, 0.1, 0.1, 1), Color(1, 1, 1, 1)]
	_cur_colour = _palette[0]

	canvas.set_image(_edit_img)
	if _edit_img.get_width() == CHAR_W and _edit_img.get_height() == CHAR_H:
		canvas.cell_w = CHAR_CW
		canvas.cell_h = CHAR_CH
	else:
		canvas.cell_w = 0
		canvas.cell_h = 0
	canvas.set_zoom(clampi(720 / maxi(_edit_img.get_width(), 1), 4, 24))

	_editing = true
	grid.get_parent().visible = false
	report.visible = false
	editor.visible = true
	_rebuild_palette_row()
	_set_tool("brush")
	_update_status()


func _close_editor() -> void:
	_editing = false
	editor.visible = true
	editor.visible = false
	grid.get_parent().visible = true
	report.visible = true
	_edit_img = null


func _set_tool(t: String) -> void:
	_tool = t
	_btn_brush.button_pressed = (t == "brush")
	_btn_eraser.button_pressed = (t == "eraser")
	_btn_fill.button_pressed = (t == "fill")
	_btn_eyedrop.button_pressed = (t == "eyedrop")
	_update_status()


func _update_status() -> void:
	if _status == null:
		return
	var news := " (new)" if _edit_is_new else ""
	_status.text = "%s%s   %dx%d   tool: %s [1 brush 2 eraser 3 fill 4 eyedrop]   Ctrl+Z/Y undo/redo   Ctrl+S save   Esc cancel" % [
		_edit_name, news, _edit_img.get_width(), _edit_img.get_height(), _tool]


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

func _on_pixel_down(p: Vector2i) -> void:
	if not _in_bounds(p):
		return
	_push_undo()
	_apply_tool(p)
	_last_pixel = p
	canvas.queue_redraw()


func _on_pixel_drag(p: Vector2i) -> void:
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
			if _in_bounds(step):
				_apply_tool(step)
	elif _in_bounds(p):
		_apply_tool(p)
	_last_pixel = p
	canvas.queue_redraw()


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
	_last_pixel = Vector2i(-1, -1)


func _in_bounds(p: Vector2i) -> bool:
	return _edit_img != null and p.x >= 0 and p.y >= 0 \
		and p.x < _edit_img.get_width() and p.y < _edit_img.get_height()


func _apply_tool(p: Vector2i) -> void:
	match _tool:
		"brush":
			_edit_img.set_pixelv(p, _cur_colour)
		"eraser":
			_edit_img.set_pixelv(p, Color(0, 0, 0, 0))
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


func _redo_action() -> void:
	if _redo.is_empty():
		return
	_undo.append(_edit_img.duplicate())
	_edit_img = _redo.pop_back()
	canvas.set_image(_edit_img)


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
	_sel = _files.find(saved_name)
	_build()

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
