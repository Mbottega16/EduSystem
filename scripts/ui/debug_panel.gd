extends CanvasLayer

## Developer panel, bound to F1. Two pages, Tab between them.
##
##   TUNING  live balance numbers, so an experiment does not cost an edit,
##           a restart and a replay to the interesting bit.
##   CHEATS  skip straight to whatever state you want to look at.
##
## THE ONE RULE: using a cheat sets Game.cheated, which is saved, shown on
## the end-of-term screen, and makes the term simulator refuse to run. A
## balance reading taken after a cheat is a lie, and the simulator exists
## precisely to stop balance being guesswork.

enum Page { TUNING, CHEATS }

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

const CHEATS := [
	{"label": "Unlimited coins", "id": "coins"},
	{"label": "Max teacher + all perks", "id": "teacher"},
	{"label": "Max every student", "id": "students"},
	{"label": "Everyone ready to graduate", "id": "ready"},
	{"label": "One of every item, placed", "id": "furnish"},
	{"label": "Fill the class to capacity", "id": "enrol"},
	{"label": "Skip a day", "id": "day"},
	{"label": "End the term now", "id": "term"},
]

var open: bool = false
var page: int = Page.TUNING
var _sel: int = 0
var _panel: ColorRect = null
var _label: Label = null
var _msg: String = ""


func _ready() -> void:
	layer = 20
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.05, 0.08, 0.94)
	_panel.size = Vector2(230, 168)
	_panel.position = Vector2(4, 6)
	_panel.visible = false
	add_child(_panel)

	_label = Label.new()
	_label.position = Vector2(6, 3)
	_label.size = Vector2(222, 162)
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
	_sel = 0
	_msg = ""
	var p := get_tree().get_first_node_in_group("carrier")
	if p != null:
		p.input_locked = v


func _rows() -> Array:
	return ROWS if page == Page.TUNING else CHEATS


func _handle() -> void:
	var n: int = _rows().size()
	if Input.is_action_just_pressed("menu"):
		page = (page + 1) % 2
		_sel = 0
		_msg = ""
	elif Input.is_action_just_pressed("move_down"):
		_sel = (_sel + 1) % n
	elif Input.is_action_just_pressed("move_up"):
		_sel = (_sel - 1 + n) % n
	elif page == Page.TUNING:
		if Input.is_action_just_pressed("move_right"):
			_nudge(1.0)
		elif Input.is_action_just_pressed("move_left"):
			_nudge(-1.0)
	elif Input.is_action_just_pressed("interact"):
		_do_cheat(String(CHEATS[_sel]["id"]))


func _nudge(dir: float) -> void:
	var row: Dictionary = ROWS[_sel]
	var key := String(row["key"])
	Balance.set_value(key, Balance.get_value(key) + float(row["step"]) * dir)


func _do_cheat(id: String) -> void:
	Balance.ensure_loaded()
	Game.cheated = true          # permanent, saved, and shown at term end
	match id:
		"coins":
			Game.unlimited_coins = not Game.unlimited_coins
			if Game.unlimited_coins:
				Game.add_coins(999999)
			_msg = "unlimited coins %s" % ("ON" if Game.unlimited_coins else "off")
		"teacher":
			Game.add_teacher_xp(Balance.teacher_xp_per_level * Balance.teacher_max_level)
			for pid: String in Progress.perk_order():
				while Game.perk_rank(pid) < Progress.max_rank(pid):
					Game.perk_ranks[pid] = Game.perk_rank(pid) + 1
			_msg = "teacher maxed"
		"students":
			for s: StudentData in Game.roster:
				while s.level < Balance.stu_max_level:
					s.level += 1
					s.aptitude = clampf(s.aptitude + Balance.stu_aptitude_step, 0.0, 1.0)
					s.diligence = clampf(s.diligence + Balance.stu_diligence_step, 0.0, 1.0)
			_msg = "every student maxed"
		"ready":
			for s: StudentData in Game.roster:
				s.level = maxi(s.level, Balance.stu_ready_level)
			_msg = "all ready to send up"
		"furnish":
			var placed := 0
			for iid: String in Items.order():
				var spot := _free_spot(iid)
				if spot.x >= 0:
					Game.add_item(iid, spot)
					placed += 1
			_msg = "placed %d items" % placed
		"enrol":
			var n := 0
			while Game.enrol() != null:
				n += 1
			_msg = "enrolled %d" % n
		"day":
			Game.advance_day()
			_msg = "now day %d" % Game.day
		"term":
			Game.day = Balance.term_days
			_msg = "last day of term"


## Somewhere this item actually fits, or (-1,-1).
func _free_spot(id: String) -> Vector2i:
	var room := get_tree().get_first_node_in_group("classroom")
	for ty in range(2, Grid.H - 1):
		for tx in range(1, Grid.W - 1):
			var t := Vector2i(tx, ty)
			if not Game.item_at(t).is_empty():
				continue
			var ok := true
			for f: Vector2i in Items.footprint(id, t):
				if room != null and not room.grid.is_free(f):
					ok = false
			if ok:
				return t
	return Vector2i(-1, -1)


func _render() -> void:
	var lines: Array[String] = [
		"F1 open  F2 close  Tab page  %s" % (
			"[TUNING] cheats" if page == Page.TUNING else "tuning [CHEATS]"),
		"",
	]
	if page == Page.TUNING:
		for i in ROWS.size():
			var row: Dictionary = ROWS[i]
			lines.append("%s %-15s %s" % [
				">" if i == _sel else " ", String(row["label"]),
				"%.3f" % Balance.get_value(String(row["key"]))])
		lines.append("")
		lines.append("Left/Right adjust")
	else:
		for i in CHEATS.size():
			var mark := ""
			if String(CHEATS[i]["id"]) == "coins" and Game.unlimited_coins:
				mark = "  ON"
			lines.append("%s %s%s" % [">" if i == _sel else " ",
				String(CHEATS[i]["label"]), mark])
		lines.append("")
		lines.append("E to use.  " + ("CHEATED" if Game.cheated else "clean run"))
	lines.append("")
	lines.append("day %d  coins %d  items %d  lv %d" % [
		Game.day, Game.coins, Game.room_items.size(), Game.teacher_level])
	if _msg != "":
		lines.append(_msg)
	_label.text = "\n".join(lines)
