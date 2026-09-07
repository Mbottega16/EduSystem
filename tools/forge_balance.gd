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
	
	for section in _data.keys():
		var val = _data[section]
		if section == "_note" or section == "_contract":
			# Skip root notes, or display them
			continue
		
		if typeof(val) == TYPE_DICTIONARY and section != "items":
			_build_section(section, val)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer)

func _build_section(title: String, section_data: Dictionary) -> void:
	var header := Label.new()
	header.text = "--- " + title.to_upper() + " ---"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	container.add_child(header)
	
	var grid := GridContainer.new()
	grid.columns = 2
	container.add_child(grid)
	
	for key in section_data.keys():
		var val = section_data[key]
		if key.begins_with("_"):
			# It's a note
			var note := Label.new()
			note.text = str(val)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			note.custom_minimum_size = Vector2(500, 0)
			
			var empty := Control.new()
			grid.add_child(empty)
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
			spin.value_changed.connect(func(v: float):
				if t == TYPE_INT:
					section_data[key] = int(v)
				else:
					section_data[key] = float(v)
				_save_data()
			)
			grid.add_child(spin)
		elif t == TYPE_BOOL:
			var chk := CheckBox.new()
			chk.button_pressed = val
			chk.toggled.connect(func(pressed: bool):
				section_data[key] = pressed
				_save_data()
			)
			grid.add_child(chk)
		else:
			var text := LineEdit.new()
			text.text = str(val)
			text.text_changed.connect(func(new_text: String):
				section_data[key] = new_text
				_save_data()
			)
			grid.add_child(text)
	
	var sep := HSeparator.new()
	container.add_child(sep)
