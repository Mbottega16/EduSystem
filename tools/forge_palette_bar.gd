class_name ForgePaletteBar
extends VBoxContainer

## The house palette, as clickable swatches, above a forge tab's parameter box.
##
## Every tab of the Master Forge except Balance drives a `forge_*.py` script
## by typing `KEY=#rrggbb` lines into a TextEdit. That is the honest
## interface -- the scripts take exactly those arguments -- but it means the
## only way to recolour anything was to know a constant's name by heart and
## then type a hex code you had picked somewhere else. Both halves of that
## are now one click: pick the constant from a list, pick the colour from a
## swatch or the wheel, and the line is written for you.
##
## Shared by the Art, Items and HUD tabs rather than copy-pasted into each,
## for the reason `tools/playdrive.gd` exists: the last thing this project
## did three times over got fixed in one copy only.

## Emitted when the user has chosen a key and a colour. The tab decides
## what to do with it -- all three currently append or replace a line.
signal param_chosen(key: String, hex: String)

const PALETTE_PATH := "res://tools/palette.json"

## Which generator module's constants this bar offers. "" means all of
## them -- what the Art tab wants, since forge_art.py reaches both the
## character palettes and the shared item colours.
var module_filter: String = ""

var _key_pick: OptionButton
var _colour_btn: ColorPickerButton
var _swatches: HFlowContainer
var _pen: ScrollContainer
var _entries: Array[Dictionary] = []


func setup(filter: String = "") -> void:
	module_filter = filter
	_build()
	_load()


func _build() -> void:
	add_theme_constant_override("separation", 6)

	var row := HBoxContainer.new()
	add_child(row)

	var lbl := Label.new()
	lbl.text = "colour"
	lbl.add_theme_color_override("font_color", ForgeTheme.DIM)
	row.add_child(lbl)

	_key_pick = OptionButton.new()
	_key_pick.custom_minimum_size = Vector2(180, 0)
	_key_pick.tooltip_text = "Which colour constant to set"
	row.add_child(_key_pick)

	_colour_btn = ColorPickerButton.new()
	_colour_btn.custom_minimum_size = Vector2(52, 0)
	_colour_btn.color = Color(0.61, 0.43, 0.26)
	_colour_btn.tooltip_text = "Pick any colour"
	row.add_child(_colour_btn)

	var add := ForgeTheme.secondary(Button.new())
	add.text = "Set"
	add.tooltip_text = "Write this KEY=#hex into the parameters below"
	add.pressed.connect(_emit_current)
	row.add_child(add)

	add_child(ForgeTheme.caption(
		"Or click a house swatch below to set the chosen key straight away."))

	# The Art tab's swatches were a ~90-tile wall that pushed the parameter
	# box off the bottom of the panel. Cap it and let it scroll -- the box
	# you type into matters more than seeing every colour at once. Tabs with
	# only a handful of swatches (Items, HUD) shrink to fit instead; see
	# _fit_pen().
	_pen = ScrollContainer.new()
	_pen.custom_minimum_size = Vector2(0, 28)
	_pen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_pen)
	_swatches = HFlowContainer.new()
	_swatches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pen.add_child(_swatches)


func _emit_current() -> void:
	if _key_pick.get_selected_id() < 0 or _key_pick.item_count == 0:
		return
	param_chosen.emit(_key_pick.get_item_text(_key_pick.selected),
		"#" + _colour_btn.color.to_html(false))


## Read tools/palette.json (written by tools/make_palette.py). A missing
## file is not fatal: the bar simply offers the wheel and no swatches, and
## the tab's typed parameter box still works exactly as it did.
func _load() -> void:
	var f := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if f == null:
		push_warning("tools/palette.json missing — run python tools/make_palette.py")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var data := parsed as Dictionary
	var modules: Dictionary = data.get("_modules", {})
	for group: String in data.keys():
		if group.begins_with("_"):
			continue
		if module_filter != "" and str(modules.get(group, "")) != module_filter:
			continue
		var row: Variant = data[group]
		if not (row is Dictionary):
			continue
		for cname: String in (row as Dictionary).keys():
			var hex := str((row as Dictionary)[cname])
			if not hex.begins_with("#"):
				continue
			_entries.append({"group": group, "name": cname, "hex": hex,
				"colour": Color.from_string(hex, Color.MAGENTA)})
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"]))
	for e: Dictionary in _entries:
		_key_pick.add_item(str(e["name"]))
	_build_swatches()
	if _entries.size() > 0:
		_key_pick.select(0)
		_colour_btn.color = _entries[0]["colour"]
	# One module's worth of swatches (Items, HUD) is a row or two -- give it
	# just that. The Art tab offers every module at once (~90) and needs the
	# scroll. Sized off the count so it never clips or leaves a dead band.
	_pen.custom_minimum_size.y = 104.0 if _entries.size() > 30 else 60.0


func _build_swatches() -> void:
	for c in _swatches.get_children():
		c.queue_free()
	# Grouped in the file's own order, not the alphabetical order the
	# dropdown uses: a dropdown is searched by name, a swatch row is
	# scanned by eye, and material neighbours are what the eye wants.
	var by_group := {}
	for e: Dictionary in _entries:
		var g := str(e["group"])
		if not by_group.has(g):
			by_group[g] = []
		(by_group[g] as Array).append(e)
	for g: String in by_group.keys():
		var strip := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = g
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.54, 0.6))
		strip.add_child(name_lbl)
		var colours := HBoxContainer.new()
		strip.add_child(colours)
		for e: Dictionary in by_group[g]:
			var sw := ColorRect.new()
			sw.color = e["colour"]
			sw.custom_minimum_size = Vector2(16, 16)
			sw.tooltip_text = "%s  %s" % [e["name"], e["hex"]]
			sw.mouse_filter = Control.MOUSE_FILTER_STOP
			sw.gui_input.connect(func(ev: InputEvent) -> void:
				if not (ev is InputEventMouseButton) \
						or not (ev as InputEventMouseButton).pressed:
					return
				_colour_btn.color = e["colour"]
				# Left-click sets the CHOSEN key to this colour. Right-click
				# selects the swatch's OWN key first, which is what you want
				# when you are retinting the thing the colour is named for.
				if (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
					for i in _key_pick.item_count:
						if _key_pick.get_item_text(i) == str(e["name"]):
							_key_pick.select(i)
							break
				_emit_current())
			colours.add_child(sw)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(12, 0)
		strip.add_child(pad)
		_swatches.add_child(strip)
