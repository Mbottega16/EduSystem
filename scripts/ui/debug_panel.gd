extends CanvasLayer

## Live tuning, bound to F1.
##
## Every balance experiment used to cost an edit, a restart, and a replay to
## whatever bit was interesting. This changes the numbers in place, and lets
## you skip to the state you want to look at.
##
## Reads and writes Balance directly, so what you see here is exactly what
## the game and the simulator use.

const ROWS := [
	{"label": "work seconds", "key": "work_seconds", "step": 1.0},
	{"label": "lesson seconds", "key": "lesson_seconds", "step": 5.0},
	{"label": "stall / sec", "key": "stall_chance_per_second", "step": 0.02},
	{"label": "room base", "key": "room_base", "step": 0.01},
	{"label": "room cap", "key": "room_cap", "step": 0.01},
	{"label": "lesson cap", "key": "lesson_cap", "step": 0.01},
	{"label": "coins / grade", "key": "coins_per_grade_point", "step": 2.0},
	{"label": "upkeep / item", "key": "upkeep_per_item", "step": 1.0},
	{"label": "term days", "key": "term_days", "step": 1.0},
]

var open: bool = false
var _sel: int = 0
var _panel: ColorRect = null
var _label: Label = null


func _ready() -> void:
	layer = 20
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.05, 0.08, 0.92)
	_panel.size = Vector2(200, 150)
	_panel.position = Vector2(4, 16)
	_panel.visible = false
	add_child(_panel)

	_label = Label.new()
	_label.position = Vector2(6, 3)
	_label.size = Vector2(190, 144)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_panel.add_child(_label)


func _process(_d: float) -> void:
	if Input.is_key_pressed(KEY_F1) and not open:
		_toggle(true)
	elif Input.is_key_pressed(KEY_F2) and open:
		_toggle(false)
	if not open:
		return
	_handle()
	_render()


func _toggle(v: bool) -> void:
	open = v
	_panel.visible = v
	var p := get_tree().get_first_node_in_group("carrier")
	if p != null:
		p.input_locked = v


func _handle() -> void:
	if Input.is_action_just_pressed("move_down"):
		_sel = (_sel + 1) % ROWS.size()
	elif Input.is_action_just_pressed("move_up"):
		_sel = (_sel - 1 + ROWS.size()) % ROWS.size()
	elif Input.is_action_just_pressed("move_right"):
		_nudge(1.0)
	elif Input.is_action_just_pressed("move_left"):
		_nudge(-1.0)
	elif Input.is_key_pressed(KEY_F3):
		Game.add_coins(500)
	elif Input.is_key_pressed(KEY_F4):
		for s: StudentData in Game.roster:
			s.confusion = 1.0
	elif Input.is_key_pressed(KEY_F5):
		Game.enrol()


func _nudge(dir: float) -> void:
	var row: Dictionary = ROWS[_sel]
	var key := String(row["key"])
	Balance.set_value(key, Balance.get_value(key) + float(row["step"]) * dir)


func _render() -> void:
	var lines: Array[String] = ["F1 open  F2 close   arrows adjust",
		"F3 +500 coins  F4 stall all  F5 enrol", ""]
	for i in ROWS.size():
		var row: Dictionary = ROWS[i]
		lines.append("%s %-15s %s" % [
			">" if i == _sel else " ", String(row["label"]),
			"%.3f" % Balance.get_value(String(row["key"]))])
	lines.append("")
	lines.append("day %d  coins %d  items %d" % [
		Game.day, Game.coins, Game.room_items.size()])
	_label.text = "\n".join(lines)
