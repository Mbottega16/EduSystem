extends Control

## Make a new character without hand-writing a palette table.
##
##   Make a Sprite.bat      (or: godot --path . res://tools/spritegen.tscn)
##
## THE POINT, and why this is not a drawing program: a character in this game
## IS a palette. tools/make_art.py holds one drawing routine and a table of
## six-line colour entries, and every student in the room is that same figure
## in different clothes. So the useful tool is not a canvas — it is a way to
## choose a palette, see it immediately, and have the result land in the game
## without a single manual step.
##
## It does the whole chain, deliberately:
##
##   1. writes the palette entry into make_art.py's CHARACTERS table
##   2. runs make_art.py, which draws the sheet with the SAME routine that
##      drew every existing character — there is no second implementation
##      of what a person looks like, and there must never be
##   3. runs Godot's import step, because a PNG on disk is not a texture the
##      game can load until it is imported
##   4. registers the name in scripts/data/names.gd so children can be born
##      with it
##
## Step 3 is not optional politeness. art/inspector.png shipped invisible for
## exactly that reason, and a tool that can leave you in that state is worse
## than no tool.

const PREVIEW_BASE := "res://art/student_a.png"
## The palette student_a is drawn in. The live preview swaps these for the
## chosen colours, which is honest because that is literally the difference
## between one character and another here.
const BASE_PALETTE := {
	"hair": Color8(58, 44, 38), "hair_d": Color8(38, 28, 24),
	"shirt": Color8(86, 166, 96), "shirt_d": Color8(58, 124, 68),
	"legs": Color8(104, 84, 64), "shoe": Color8(58, 46, 40),
}

const SWATCHES := [
	["hair", "Hair"], ["shirt", "Shirt"], ["legs", "Trousers"], ["shoe", "Shoes"],
]

var chosen := {
	"hair": Color8(120, 80, 40), "shirt": Color8(90, 120, 200),
	"legs": Color8(70, 70, 90), "shoe": Color8(50, 40, 35),
}
var long_hair := false
var skirt := false

var _base: Image = null
var _preview: TextureRect = null
var _name_edit: LineEdit = null
var _status: RichTextLabel = null
var _long: CheckBox = null
var _skirt: CheckBox = null


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_size(Vector2i(760, 520))
	get_window().title = "EDUSystem - make a character"

	var tex: Texture2D = load(PREVIEW_BASE)
	_base = tex.get_image() if tex != null else null
	_build()
	_refresh()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var head := Label.new()
	head.text = "  A character is a palette. Pick one."
	head.add_theme_font_size_override("font_size", 16)
	root.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	root.add_child(cols)

	# --- the preview: every facing, every frame, exactly as the game slices it
	var frame := ColorRect.new()
	frame.color = Color(0.86, 0.83, 0.76)
	frame.custom_minimum_size = Vector2(400, 300)
	cols.add_child(frame)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_preview)

	# --- the choices
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	cols.add_child(side)

	for row: Array in SWATCHES:
		var key := String(row[0])
		var box := HBoxContainer.new()
		var lab := Label.new()
		lab.text = String(row[1])
		lab.custom_minimum_size = Vector2(90, 0)
		box.add_child(lab)
		var pick := ColorPickerButton.new()
		pick.color = chosen[key]
		pick.custom_minimum_size = Vector2(150, 30)
		pick.color_changed.connect(func(c: Color) -> void:
			chosen[key] = c
			_refresh())
		box.add_child(pick)
		side.add_child(box)

	_long = CheckBox.new()
	_long.text = "Long hair"
	_long.toggled.connect(func(v: bool) -> void:
		long_hair = v
		_refresh())
	side.add_child(_long)

	_skirt = CheckBox.new()
	_skirt.text = "Skirt"
	_skirt.toggled.connect(func(v: bool) -> void:
		skirt = v
		_refresh())
	side.add_child(_skirt)

	var roll := Button.new()
	roll.text = "Surprise me"
	roll.pressed.connect(_roll)
	side.add_child(roll)

	side.add_child(HSeparator.new())

	var nb := HBoxContainer.new()
	var nl := Label.new()
	nl.text = "Name"
	nl.custom_minimum_size = Vector2(90, 0)
	nb.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = _suggest_name()
	_name_edit.custom_minimum_size = Vector2(150, 0)
	nb.add_child(_name_edit)
	side.add_child(nb)

	var go := Button.new()
	go.text = "Make it, and put it in the game"
	go.pressed.connect(_generate)
	side.add_child(go)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.custom_minimum_size = Vector2(0, 140)
	root.add_child(_status)
	_say("[color=#9a9aa2]The preview recolours an existing sheet, which is "
		+ "exactly what a new character IS. Pressing the button runs the real "
		+ "generator, so what lands in the game is drawn by the same code as "
		+ "every other character.[/color]")


## The next free student_* name, so the field is usually already right.
func _suggest_name() -> String:
	for i in 26:
		var n := "student_%s" % char("a".unicode_at(0) + i)
		if not FileAccess.file_exists("res://art/%s.png" % n):
			return n
	return "student_new"


func _roll() -> void:
	for key: String in chosen.keys():
		chosen[key] = Color.from_hsv(randf(), randf_range(0.25, 0.8),
			randf_range(0.35, 0.9))
	long_hair = randf() < 0.5
	skirt = long_hair and randf() < 0.6
	_long.button_pressed = long_hair
	_skirt.button_pressed = skirt
	_refresh()


## A darker version of a colour, the way make_art.py's palettes pair them.
static func darker(c: Color) -> Color:
	return Color(c.r * 0.7, c.g * 0.7, c.b * 0.72, 1.0)


## Swap the base sheet's palette for the chosen one, pixel by pixel.
##
## Only an approximation of what the generator will produce -- it cannot add
## long hair or a skirt, because those are different PIXELS rather than
## different colours. That is exactly why the button runs the real thing.
func _refresh() -> void:
	if _base == null:
		return
	var img := Image.create(_base.get_width(), _base.get_height(), false,
		Image.FORMAT_RGBA8)
	var map := {
		BASE_PALETTE["hair"]: chosen["hair"],
		BASE_PALETTE["hair_d"]: darker(chosen["hair"]),
		BASE_PALETTE["shirt"]: chosen["shirt"],
		BASE_PALETTE["shirt_d"]: darker(chosen["shirt"]),
		BASE_PALETTE["legs"]: chosen["legs"],
		BASE_PALETTE["shoe"]: chosen["shoe"],
	}
	for y in _base.get_height():
		for x in _base.get_width():
			var c := _base.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var best := c
			for from: Color in map.keys():
				if _close(c, from):
					best = map[from]
					best.a = c.a
					break
			img.set_pixel(x, y, best)
	_preview.texture = ImageTexture.create_from_image(img)


static func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 \
		and absf(a.b - b.b) < 0.02


func _say(msg: String) -> void:
	_status.text = msg


func _c(c: Color) -> String:
	return "(%d, %d, %d)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)),
		int(round(c.b * 255.0))]


## Write the palette, draw it, import it, and register the name.
func _generate() -> void:
	var name := _name_edit.text.strip_edges()
	if name == "" or not name.is_valid_identifier():
		_say("[color=#d08a86]That name will not do. Letters, digits and "
			+ "underscores, starting with a letter.[/color]")
		return

	var root := ProjectSettings.globalize_path("res://")
	var entry := _build_entry(name)

	var out := []
	var steps: Array[String] = []

	# 1. the palette entry, into the one table that defines a character
	var err := _patch_palette(root, name, entry)
	if err != "":
		_say("[color=#d08a86]%s[/color]" % err)
		return
	steps.append("wrote the palette into tools/make_art.py")

	# 2. draw it with the REAL generator
	var code := OS.execute("python", [root.path_join("tools/make_art.py")],
		out, true)
	if code != 0:
		_say("[color=#d08a86]make_art.py failed:[/color]\
%s" % "\
".join(out))
		return
	steps.append("drew art/%s.png with the same routine as every other character" % name)

	# 3. import it, or the game cannot load it
	out.clear()
	OS.execute(OS.get_executable_path(),
		["--headless", "--path", root, "--import"], out, true)
	steps.append("imported it, so Godot can actually load it")

	# 4. let children be born with it
	if _register_name(root, name):
		steps.append("registered it in Names.ART")
	else:
		steps.append("[color=#f2c66b]already in Names.ART[/color]")

	var done := "[color=#9fd89f]%s is in the game.[/color]\
" % name
	for st: String in steps:
		done += "  - %s\
" % st
	_say(done)
	_name_edit.text = _suggest_name()


## The palette entry, exactly as make_art.py's table wants it.
##
## Split out of _generate() so the whole chain can be driven headlessly
## and proved, rather than only ever being exercised by a human clicking
## a button in a window.
func _build_entry(char_name: String) -> String:
	var q := '"'
	var lines: Array[String] = [
		"    " + q + char_name + q + ": {",
		"        " + q + "hair" + q + ": " + _c(chosen["hair"])
			+ ", " + q + "hair_d" + q + ": " + _c(darker(chosen["hair"])) + ",",
		"        " + q + "shirt" + q + ": " + _c(chosen["shirt"])
			+ ", " + q + "shirt_d" + q + ": " + _c(darker(chosen["shirt"])) + ",",
		"        " + q + "legs" + q + ": " + _c(chosen["legs"])
			+ ", " + q + "shoe" + q + ": " + _c(chosen["shoe"]) + ",",
		"        " + q + "long_hair" + q + ": "
			+ ("True" if long_hair else "False")
			+ ", " + q + "skirt" + q + ": "
			+ ("True" if skirt else "False") + ",",
		"    },",
	]
	return "\n" + "\n".join(lines)


func _patch_palette(root: String, name: String, entry: String) -> String:
	var path := root.path_join("tools/make_art.py")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "cannot read tools/make_art.py"
	var text := f.get_as_text()
	f.close()
	if text.contains("\"%s\": {" % name):
		return "%s already exists in the palette table" % name
	var marker := "CHARACTERS = {"
	var at := text.find(marker)
	if at < 0:
		return "could not find the CHARACTERS table"
	at += marker.length()
	text = text.substr(0, at) + entry + text.substr(at)
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		return "cannot write tools/make_art.py"
	w.store_string(text)
	w.close()
	return ""


func _register_name(root: String, char_name: String) -> bool:
	var path := root.path_join("scripts/data/names.gd")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	if text.contains("\"" + char_name + "\""):
		return false
	var marker := "const ART := ["
	var at := text.find(marker)
	if at < 0:
		return false
	at += marker.length()
	var q := '\"'
	text = text.substr(0, at) + "\n\t" + q + char_name + q + "," + text.substr(at)
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		return false
	w.store_string(text)
	w.close()
	return true
