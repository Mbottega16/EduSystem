extends Control

## The sprite browser.
##
##   Browse Art.bat        (or: godot --path . res://tools/curator.tscn)
##
## Every image the game owns, on one screen. Until this existed the only way
## to look at the art was to open PNGs one at a time, which is why a
## two-frame sprite sheet sat in the game for weeks rendering as a magenta
## block before anyone noticed.
##
## Deliberately a VIEWER, not an editor. Sprites are authored as text grids
## in tools/sprites/ and as code in tools/make_art.py; this is for seeing
## what came out.
##
## The two lists at the bottom are the point of the tool:
##   UNREFERENCED - art on disk that no script or data file mentions
##   MISSING      - art that scripts or data DO mention but which is not
##                  there. That one is a crash waiting to happen, and
##                  nothing else in the project checks for it.

const ART_DIR := "res://art"
const BG_LIGHT := Color(0.86, 0.83, 0.76)
const BG_DARK := Color(0.11, 0.10, 0.13)
## Magenta, because unstripped chroma key is the specific defect this
## project has actually shipped. It is invisible against both other grounds.
const BG_CHROMA := Color(1, 0, 1)

var _grounds := [BG_LIGHT, BG_DARK, BG_CHROMA]
var _ground := 0
var _zoom := 3
var _files: Array[String] = []
var _referenced := {}      ## art name -> where it is mentioned
var _missing: Array[String] = []

@onready var grid: GridContainer = $V/Scroll/Grid
@onready var header: Label = $V/Header
@onready var report: RichTextLabel = $V/Report


func _ready() -> void:
	# The project renders at 320x176 with viewport stretch; a dev tool wants
	# a real window and real pixels.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(1180, 780))
	get_window().title = "PixelRoom - art"

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


func _build() -> void:
	for c in grid.get_children():
		c.queue_free()

	var unused: Array[String] = []
	for name: String in _files:
		if not _referenced.has(name):
			unused.append(name)
		grid.add_child(_card(name))

	header.text = "%d images    zoom x%d    [1] ground: %s    [+/-] zoom    [R] rescan" % [
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


func _card(art_name: String) -> Control:
	var tex: Texture2D = load("%s/%s.png" % [ART_DIR, art_name])
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

	var frame := ColorRect.new()
	frame.color = _grounds[_ground]
	frame.custom_minimum_size = Vector2(cell, cell)

	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(pic)
	box.add_child(frame)

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


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.is_pressed() or e.is_echo():
		return
	var k := (e as InputEventKey).keycode
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
	elif k == KEY_ESCAPE:
		get_tree().quit()
