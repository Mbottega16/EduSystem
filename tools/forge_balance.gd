extends Control

const BALANCE_FILE := "res://data/balance.json"
var _data: Dictionary = {}

@onready var container: VBoxContainer = $BalanceUI/V

func _ready() -> void:
	_load_data()
	_build_ui()

func _load_data() -> void:
	var f := FileAccess.open(BALANCE_FILE, FileAccess.READ)
	if f:
		var text := f.get_as_text()
		f.close()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
		else:
			push_error("Failed to parse balance.json")

func _save_data() -> void:
	var f := FileAccess.open(BALANCE_FILE, FileAccess.WRITE)
	if f:
		# Format the JSON nicely
		f.store_string(JSON.stringify(_data, "  "))
		f.close()

func _build_ui() -> void:
	for c in container.get_children():
		c.queue_free()
	container.add_theme_constant_override("separation", 12)

	# This tab looked like a different program: blue headers, bare spinboxes,
	# walls of grey text, no padding. It is the same card-and-heading system
	# the other four tabs use now.
	var intro := Label.new()
	intro.text = "Balance — the game's tunable numbers"
	intro.add_theme_font_size_override("font_size", 16)
	intro.add_theme_color_override("font_color", ForgeTheme.ACCENT)
	container.add_child(intro)
	container.add_child(ForgeTheme.caption(
		"Every change writes straight to data/balance.json as you type — there is "
		+ "no Forge button here. The game reads it on the next launch."))

	for section: String in _data.keys():
		var val: Variant = _data[section]
		if section == "_note" or section == "_contract":
			continue
		if typeof(val) == TYPE_DICTIONARY and section != "items":
			_build_section(section, val)

	container.add_child(ForgeTheme.gap(0, 24))


func _build_section(title: String, section_data: Dictionary) -> void:
	var card := ForgeTheme.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var header := Label.new()
	header.text = title.to_upper()
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", ForgeTheme.ACCENT)
	col.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)

	for key: String in section_data.keys():
		var val: Variant = section_data[key]
		if key.begins_with("_"):
			# A note that belongs with this section. Spans the value column.
			grid.add_child(Control.new())
			var note := ForgeTheme.caption(str(val))
			note.custom_minimum_size = Vector2(520, 0)
			grid.add_child(note)
			continue

		var label := Label.new()
		label.text = key
		grid.add_child(label)

		var t := typeof(val)
		if t == TYPE_FLOAT or t == TYPE_INT:
			var spin := SpinBox.new()
			spin.max_value = 1000000.0 if t == TYPE_FLOAT else 1000000
			spin.min_value = -1000000.0 if t == TYPE_FLOAT else -1000000
			spin.step = 0.01 if t == TYPE_FLOAT else 1
			spin.value = val
			spin.custom_minimum_size = Vector2(150, 0)
			spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			spin.value_changed.connect(func(v: float) -> void:
				section_data[key] = int(v) if t == TYPE_INT else float(v)
				_save_data())
			grid.add_child(spin)
		elif t == TYPE_BOOL:
			var chk := CheckBox.new()
			chk.button_pressed = val
			chk.toggled.connect(func(pressed: bool) -> void:
				section_data[key] = pressed
				_save_data())
			grid.add_child(chk)
		else:
			var text := LineEdit.new()
			text.text = str(val)
			text.custom_minimum_size = Vector2(240, 0)
			text.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			text.text_changed.connect(func(new_text: String) -> void:
				section_data[key] = new_text
				_save_data())
			grid.add_child(text)
