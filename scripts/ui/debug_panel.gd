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

const FONT := preload("res://fonts/Galmuri9.ttf")
const FRAME := preload("res://art/ui_frame.png")
const FRAME_MARGIN := 12
const SIZE := 20
## Rows shown at once. The list scrolls so the cursor row is always inside.
const WINDOW := 8

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
	{"label": "EVERYTHING (dev room)", "id": "all"},
	{"label": "Unlimited coins", "id": "coins"},
	{"label": "Max teacher + all perks", "id": "teacher"},
	{"label": "Max every student", "id": "students"},
	{"label": "Everyone ready to graduate", "id": "ready"},
	{"label": "One of every item, placed", "id": "furnish"},
	{"label": "Fill the class to capacity", "id": "enrol"},
	{"label": "Bigger room (+1 wide, +1 long)", "id": "grow"},
	{"label": "Skip a day", "id": "day"},
	{"label": "End the term now", "id": "term"},
	{"label": "Boss paper now (Reading Paper)", "id": "boss"},
]

var open: bool = false
var _backtick_was_down: bool = false
var _shift_d_was_down: bool = false
var page: int = Page.TUNING
var _sel: int = 0
var _panel: ColorRect = null
var _label: Label = null
var _msg: String = ""


## Opens straight onto the cheats page. The pause menu's Cheats row calls it.
func open_cheats() -> void:
	page = Page.CHEATS
	_toggle(true)
	page = Page.CHEATS


func _ready() -> void:
	add_to_group("debug_panel")
	layer = 20
	# Dressed like the game's own screens: the dark overlay, LimeZu's bamboo
	# frame, and the pixel font at 20, so it reads as part of the game.
	_panel = ColorRect.new()
	_panel.color = Color(0.06, 0.05, 0.08, 0.93)
	_panel.size = Vector2(640, 352)
	_panel.visible = false
	add_child(_panel)

	var frame := NinePatchRect.new()
	frame.texture = FRAME
	frame.position = Vector2(2, 2)
	frame.size = Vector2(636, 348)
	for side in ["left", "top", "right", "bottom"]:
		frame.set("patch_margin_" + side, FRAME_MARGIN)
	frame.draw_center = false
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(frame)

	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.size = Vector2(592, 320)
	_label.clip_text = true
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", SIZE)
	_label.add_theme_constant_override("line_spacing", 6)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_panel.add_child(_label)


func _process(_d: float) -> void:
	if Input.is_key_pressed(KEY_F1) and not open:
		_toggle(true)
	elif Input.is_key_pressed(KEY_F2) and open:
		_toggle(false)
	# Backtick TOGGLES, on the edge of the press rather than the hold --
	# F1/F2 can afford a held check because they are two different keys,
	# one for each direction, but one key doing both jobs needs edge
	# detection or it would open and close every frame the key stayed
	# down. It exists because an F-row key is exactly the one a laptop's
	# own OEM shortcuts (brightness, mute, a vendor "help" binding) are
	# most likely to eat before Godot ever sees it, and there is no way
	# to tell that happened from in here. Backtick is the conventional
	# dev-console key for a reason: almost nothing else claims it.
	if _backtick_edge(Input.is_key_pressed(KEY_QUOTELEFT)):
		_toggle(not open)
	# Shift+D as a third way in -- F1 is reportedly not reaching Godot at
	# all on at least one machine (an OEM binding eating it before the
	# engine sees it, the same failure mode backtick already exists to
	# route around), so this is a second fallback while that gets sorted
	# rather than a replacement for either existing key.
	if _shift_d_edge(Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_D)):
		_toggle(not open)
	if not open:
		return
	_handle()
	_render()


## True exactly on the frame backtick goes from up to down. Split out from
## _process() so the toggle logic can be tested directly, without going
## through Input's raw key state -- which real hardware fills reliably but
## a headless test's synthetic InputEventKey does not always reproduce the
## same way, and this logic is the part a bug could actually hide in.
func _backtick_edge(down: bool) -> bool:
	var edge := down and not _backtick_was_down
	_backtick_was_down = down
	return edge


## Same edge-detect as backtick, same reason: Shift+D toggles both ways on
## one combo, so it needs the edge of the press, not the hold.
func _shift_d_edge(down: bool) -> bool:
	var edge := down and not _shift_d_was_down
	_shift_d_was_down = down
	return edge


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
	if Input.is_action_just_pressed("cancel"):
		_toggle(false)
	elif Input.is_action_just_pressed("menu"):
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
		"all":
			# Everything, in the order that makes each step actually land:
			# the room has to be BIGGER before there is anywhere to enrol
			# or furnish into, and the class has to exist before "every
			# student" has anyone in it to max.
			var msgs: Array[String] = []
			msgs.append(_cheat_coins(true))
			msgs.append(_cheat_grow())
			msgs.append(_cheat_grow())
			msgs.append(_cheat_enrol())
			msgs.append(_cheat_students())
			msgs.append(_cheat_teacher())
			msgs.append(_cheat_furnish())
			_msg = "dev room: " + ", ".join(msgs)
		"coins":
			_msg = _cheat_coins()
		"teacher":
			_msg = _cheat_teacher()
		"students":
			_msg = _cheat_students()
		"ready":
			for s: StudentData in Game.roster:
				s.level = maxi(s.level, Balance.stu_ready_level)
			_msg = "all ready to send up"
		"furnish":
			_msg = _cheat_furnish()
		"enrol":
			_msg = _cheat_enrol()
		"grow":
			_msg = _cheat_grow()
		"day":
			Game.advance_day()
			_msg = "now day %d" % Game.day
		"term":
			Game.day = Balance.term_days
			_msg = "last day of term"
		"boss":
			# The last day of a boss term, so the podium offers the paper.
			# The ELA card, deterministically -- this is a way to LOOK at
			# the fight, not to roll one.
			if not Balance.bosses.is_empty():
				Game.term_path = (Balance.bosses[0] as Dictionary).duplicate()
			Game.day = Balance.term_days
			Game.fight_done = false
			Game.set_phase(Game.Phase.MORNING)
			_msg = "boss paper at the podium"


## `force_on`: for "all", where toggling would be the wrong verb -- a
## dev room means coins ARE unlimited, not "whatever they happened to be".
func _cheat_coins(force_on: bool = false) -> String:
	if force_on:
		Game.unlimited_coins = true
	else:
		Game.unlimited_coins = not Game.unlimited_coins
	if Game.unlimited_coins:
		Game.add_coins(999999)
	return "unlimited coins %s" % ("ON" if Game.unlimited_coins else "off")


func _cheat_teacher() -> String:
	Game.add_teacher_xp(Balance.teacher_xp_per_level * Balance.teacher_max_level)
	for pid: String in Progress.perk_order():
		while Game.perk_rank(pid) < Progress.max_rank(pid):
			Game.perk_ranks[pid] = Game.perk_rank(pid) + 1
	return "teacher maxed"


func _cheat_students() -> String:
	for s: StudentData in Game.roster:
		while s.level < Balance.stu_max_level:
			s.level += 1
			s.aptitude = clampf(s.aptitude + Balance.stu_aptitude_step, 0.0, 1.0)
			s.diligence = clampf(s.diligence + Balance.stu_diligence_step, 0.0, 1.0)
	return "every student maxed"


func _cheat_furnish() -> String:
	var placed := 0
	for iid: String in Items.order():
		var spot := _free_spot(iid)
		if spot.x >= 0:
			Game.add_item(iid, spot)
			placed += 1
	return "placed %d items" % placed


func _cheat_enrol() -> String:
	var n := 0
	while Game.enrol() != null:
		n += 1
	return "enrolled %d" % n


func _cheat_grow() -> String:
	var w := Game.expand_room("wide")
	var h := Game.expand_room("tall")
	if w != "" and h != "":
		return "room already at its cap"
	return "room grown"


## Somewhere this item actually fits, or (-1,-1).
func _free_spot(id: String) -> Vector2i:
	if Items.is_wall(id):
		return Game.free_wall_slot(id)       # (-1,-1) once the wall is full
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
	var rows: Array = _rows()
	var first := clampi(_sel - WINDOW / 2, 0, maxi(0, rows.size() - WINDOW))
	var lines: Array[String] = [
		"%s    Tab: %s" % [
			"CHEATS" if page == Page.CHEATS else "TUNING",
			"tuning" if page == Page.CHEATS else "cheats"]]
	for i in range(first, mini(first + WINDOW, rows.size())):
		var cur := ">" if i == _sel else " "
		if page == Page.TUNING:
			var row: Dictionary = ROWS[i]
			lines.append("%s %s  %s" % [cur, String(row["label"]),
				"%.3f" % Balance.get_value(String(row["key"]))])
		else:
			var mark := ""
			if String(CHEATS[i]["id"]) == "coins" and Game.unlimited_coins:
				mark = "  (on)"
			lines.append("%s %s%s" % [cur, String(CHEATS[i]["label"]), mark])
	var more := ""
	if rows.size() > WINDOW:
		more = "  (%d-%d of %d)" % [first + 1, mini(first + WINDOW, rows.size()), rows.size()]
	lines.append("%s%s" % ["Left/Right adjusts." if page == Page.TUNING
		else "E uses it. %s." % ("CHEATED" if Game.cheated else "Clean run"), more])
	lines.append(_msg if _msg != "" else "Day %d  coins %d  level %d   Esc closes" % [
		Game.day, Game.coins, Game.teacher_level])
	_label.text = "\n".join(lines)
