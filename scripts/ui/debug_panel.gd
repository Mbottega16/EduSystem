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
## Dark ink on cream paper, same as the pause menu (hud.gd INK).
const INK := Color(0.13, 0.12, 0.17)
## A centred cream paper panel, like the pause menu. No full-screen tint.
const PANEL_RECT := Rect2(100, 24, 440, 304)
## Rows shown at once. The list scrolls so the cursor row is always inside.
const WINDOW := 7

const ICONS := {
	"all": preload("res://art/icon_cheat_all.png"),
	"coins": preload("res://art/icon_cheat_coins.png"),
	"teacher": preload("res://art/icon_cheat_teacher.png"),
	"students": preload("res://art/icon_cheat_students.png"),
	"ready": preload("res://art/icon_cheat_ready.png"),
	"furnish": preload("res://art/icon_cheat_furnish.png"),
	"enrol": preload("res://art/icon_cheat_enrol.png"),
	"grow": preload("res://art/icon_cheat_grow.png"),
	"day": preload("res://art/icon_cheat_day.png"),
	"term": preload("res://art/icon_cheat_term.png"),
	"boss": preload("res://art/icon_cheat_boss.png"),
}

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
	{
		"label": "EVERYTHING (dev room)",
		"id": "all",
		"title": "Dev Room (EVERYTHING)",
		"desc": "All perks, max coins, full room & items",
	},
	{
		"label": "Unlimited coins",
		"id": "coins",
		"title": "Unlimited Coins",
		"desc": "Toggle infinite coin supply (+999k)",
	},
	{
		"label": "Max teacher + all perks",
		"id": "teacher",
		"title": "Master Teacher",
		"desc": "Max teacher level & unlock all perks",
	},
	{
		"label": "Max every student",
		"id": "students",
		"title": "Honour Students",
		"desc": "Max student level, aptitude & diligence",
	},
	{
		"label": "Everyone ready to graduate",
		"id": "ready",
		"title": "Ready to Graduate",
		"desc": "Set all students ready to send up",
	},
	{
		"label": "One of every item, placed",
		"id": "furnish",
		"title": "Furnish Classroom",
		"desc": "Place one of every classroom item",
	},
	{
		"label": "Fill the class to capacity",
		"id": "enrol",
		"title": "Full Enrollment",
		"desc": "Fill every open seat with students",
	},
	{
		"label": "Bigger room (+1 wide, +1 long)",
		"id": "grow",
		"title": "Expand Classroom",
		"desc": "Grow room boundaries (+1W, +1L)",
	},
	{
		"label": "Skip a day",
		"id": "day",
		"title": "Skip a Day",
		"desc": "Advance calendar by 1 teaching day",
	},
	{
		"label": "End the term now",
		"id": "term",
		"title": "End Term Now",
		"desc": "Jump directly to the final term day",
	},
	{
		"label": "Boss paper now (Reading Paper)",
		"id": "boss",
		"title": "Spawn Boss Paper",
		"desc": "Spawn Reading exam paper at podium",
	},
]

var open: bool = false
var _backtick_was_down: bool = false
var _shift_d_was_down: bool = false
var page: int = Page.TUNING
var _sel: int = 0
var _panel: Control = null
var _label: Label = null
var _msg: String = ""

# Visual overhaul nodes
var _tab_cheats: Label = null
var _tab_tuning: Label = null
var _tab_hint: Label = null
var _tab_badge: ColorRect = null
var _header_rule: ColorRect = null
var _footer_rule: ColorRect = null
var _footer_hint: Label = null
var _footer_status: Label = null

var _row_controls: Array[Control] = []
var _row_bgs: Array[ColorRect] = []
var _row_badges: Array[ColorRect] = []
var _row_icons: Array[TextureRect] = []
var _row_titles: Array[Label] = []
var _row_descs: Array[Label] = []
var _row_tags: Array[Label] = []


## Opens straight onto the cheats page. The pause menu's Cheats row calls it.
func open_cheats() -> void:
	page = Page.CHEATS
	_toggle(true)
	page = Page.CHEATS


func _ready() -> void:
	add_to_group("debug_panel")
	layer = 20

	# Procedural cream paper sheet from the design system
	_panel = Panel.new()
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	UITheme.wear(_panel, &"PaperSheet")
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)

	# Legacy/headless test label: kept for test assertions & contract
	_label = Label.new()
	_label.position = Vector2(28, 28)
	_label.size = Vector2(PANEL_RECT.size.x - 56, PANEL_RECT.size.y - 52)
	_label.clip_text = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", SIZE)
	_label.add_theme_constant_override("line_spacing", 2)
	_label.add_theme_color_override("font_color", INK)
	_label.visible = false
	_panel.add_child(_label)

	_build_visuals()


func _build_visuals() -> void:
	# Header Tabs
	_tab_badge = ColorRect.new()
	_tab_badge.position = Vector2(18, 12)
	_tab_badge.size = Vector2(74, 20)
	_tab_badge.color = UITheme.faded(&"amber", 0.22)
	_tab_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_tab_badge)

	_tab_cheats = Label.new()
	_tab_cheats.position = Vector2(24, 14)
	_tab_cheats.size = Vector2(70, 16)
	_tab_cheats.add_theme_font_override("font", FONT)
	_tab_cheats.add_theme_font_size_override("font_size", 14)
	_tab_cheats.add_theme_color_override("font_color", INK)
	_tab_cheats.text = "CHEATS"
	_panel.add_child(_tab_cheats)

	_tab_tuning = Label.new()
	_tab_tuning.position = Vector2(104, 14)
	_tab_tuning.size = Vector2(70, 16)
	_tab_tuning.add_theme_font_override("font", FONT)
	_tab_tuning.add_theme_font_size_override("font_size", 14)
	_tab_tuning.add_theme_color_override("font_color", UITheme.color(&"pencil"))
	_tab_tuning.text = "TUNING"
	_panel.add_child(_tab_tuning)

	_tab_hint = Label.new()
	_tab_hint.position = Vector2(240, 15)
	_tab_hint.size = Vector2(180, 14)
	_tab_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tab_hint.add_theme_font_override("font", FONT)
	_tab_hint.add_theme_font_size_override("font_size", 11)
	_tab_hint.add_theme_color_override("font_color", UITheme.color(&"pencil"))
	_tab_hint.text = "[Tab] Switch Page"
	_panel.add_child(_tab_hint)

	# Ruled separator under header
	_header_rule = ColorRect.new()
	_header_rule.position = Vector2(18, 36)
	_header_rule.size = Vector2(404, 1)
	_header_rule.color = UITheme.color(&"sand")
	_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_header_rule)

	# 7 windowed rows
	for r in WINDOW:
		var row := Control.new()
		row.position = Vector2(18, 42 + r * 30)
		row.size = Vector2(404, 28)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(row)
		_row_controls.append(row)

		# Active row background card
		var bg := ColorRect.new()
		bg.position = Vector2(0, 0)
		bg.size = Vector2(404, 28)
		bg.color = UITheme.faded(&"amber", 0.16)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.visible = false
		row.add_child(bg)
		_row_bgs.append(bg)

		# Leading accent badge
		var badge := ColorRect.new()
		badge.position = Vector2(0, 0)
		badge.size = Vector2(3, 28)
		badge.color = UITheme.color(&"amber")
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		row.add_child(badge)
		_row_badges.append(badge)

		# 20x20 pixel icon
		var icon := TextureRect.new()
		icon.position = Vector2(8, 4)
		icon.size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		_row_icons.append(icon)

		# Title label
		var title := Label.new()
		title.position = Vector2(34, 1)
		title.size = Vector2(260, 14)
		title.add_theme_font_override("font", FONT)
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", INK)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		_row_titles.append(title)

		# Effect description label
		var desc := Label.new()
		desc.position = Vector2(34, 15)
		desc.size = Vector2(285, 12)
		desc.add_theme_font_override("font", FONT)
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", UITheme.color(&"pencil"))
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(desc)
		_row_descs.append(desc)

		# Status / action tag
		var tag := Label.new()
		tag.position = Vector2(310, 6)
		tag.size = Vector2(88, 16)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.add_theme_font_override("font", FONT)
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", UITheme.color(&"pencil"))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		_row_tags.append(tag)

	# Ruled separator above footer
	_footer_rule = ColorRect.new()
	_footer_rule.position = Vector2(18, 254)
	_footer_rule.size = Vector2(404, 1)
	_footer_rule.color = UITheme.color(&"sand")
	_footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_footer_rule)

	# Footer navigation hint
	_footer_hint = Label.new()
	_footer_hint.position = Vector2(18, 258)
	_footer_hint.size = Vector2(404, 14)
	_footer_hint.add_theme_font_override("font", FONT)
	_footer_hint.add_theme_font_size_override("font_size", 11)
	_footer_hint.add_theme_color_override("font_color", UITheme.color(&"pencil"))
	_footer_hint.text = "[E] Activate Cheat    [▲/▼] Scroll    [Tab] Tuning    [Esc] Close"
	_panel.add_child(_footer_hint)

	# Footer status & message
	_footer_status = Label.new()
	_footer_status.position = Vector2(18, 276)
	_footer_status.size = Vector2(404, 16)
	_footer_status.add_theme_font_override("font", FONT)
	_footer_status.add_theme_font_size_override("font_size", 12)
	_footer_status.add_theme_color_override("font_color", INK)
	_panel.add_child(_footer_status)


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
	if v and UITheme.motion:
		_panel.position = PANEL_RECT.position + Vector2(0, -float(UITheme.space(&"space_s")))
		_panel.modulate.a = 0.5
		var t := create_tween()
		t.tween_property(_panel, "position", PANEL_RECT.position, 0.08)
		t.parallel().tween_property(_panel, "modulate:a", 1.0, 0.08)


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

	# 1. Update legacy test label contract so assertions stay 100% green
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
	lines.append(_msg if _msg != "" else "Day %d  coins %d   Esc closes" % [
		Game.day, Game.coins])
	_label.text = "\n".join(lines)

	# 2. Update visual tab headers
	if page == Page.CHEATS:
		_tab_cheats.add_theme_color_override("font_color", INK)
		_tab_tuning.add_theme_color_override("font_color", UITheme.color(&"pencil"))
		_tab_badge.position = Vector2(18, 12)
		_tab_badge.size = Vector2(74, 20)
		_tab_hint.text = "[Tab] Tuning"
	else:
		_tab_cheats.add_theme_color_override("font_color", UITheme.color(&"pencil"))
		_tab_tuning.add_theme_color_override("font_color", INK)
		_tab_badge.position = Vector2(98, 12)
		_tab_badge.size = Vector2(74, 20)
		_tab_hint.text = "[Tab] Cheats"

	# 3. Update the 7 row controls
	for r in WINDOW:
		var idx := first + r
		var row_ctrl := _row_controls[r]
		if idx >= rows.size():
			row_ctrl.visible = false
			continue
		row_ctrl.visible = true

		var is_selected := (idx == _sel)
		_row_bgs[r].visible = is_selected
		_row_badges[r].visible = is_selected

		if page == Page.CHEATS:
			var cheat_data: Dictionary = CHEATS[idx]
			var cid := String(cheat_data["id"])
			_row_icons[r].visible = true
			if ICONS.has(cid):
				_row_icons[r].texture = ICONS[cid]
			_row_titles[r].text = String(cheat_data.get("title", cheat_data["label"]))
			_row_descs[r].text = String(cheat_data.get("desc", ""))

			if cid == "coins" and Game.unlimited_coins:
				_row_tags[r].text = "(ACTIVE)"
				_row_tags[r].add_theme_color_override("font_color", UITheme.color(&"olive"))
			elif is_selected:
				_row_tags[r].text = "[E] ACTIVATE"
				_row_tags[r].add_theme_color_override("font_color", UITheme.color(&"amber"))
			else:
				_row_tags[r].text = ""
		else:
			var tuning_data: Dictionary = ROWS[idx]
			_row_icons[r].visible = false
			_row_titles[r].text = String(tuning_data["label"])
			var val: float = Balance.get_value(String(tuning_data["key"]))
			var step_val: float = float(tuning_data["step"])
			_row_descs[r].text = "Value: %.3f    (step %.2f)" % [val, step_val]

			if is_selected:
				_row_tags[r].text = "[◄/►] Nudge"
				_row_tags[r].add_theme_color_override("font_color", UITheme.color(&"amber"))
			else:
				_row_tags[r].text = "%.3f" % val
				_row_tags[r].add_theme_color_override("font_color", UITheme.color(&"pencil"))

	# 4. Update footer
	if page == Page.CHEATS:
		_footer_hint.text = "[E] Activate Cheat    [▲/▼] Scroll %s    [Tab] Tuning" % more
	else:
		_footer_hint.text = "[◄/►] Adjust Value    [▲/▼] Scroll %s    [Tab] Cheats" % more

	if _msg != "":
		_footer_status.text = _msg
		_footer_status.add_theme_color_override("font_color", UITheme.color(&"amber"))
	else:
		var mode_str := "CHEATED RUN" if Game.cheated else "Clean run"
		var mode_col := UITheme.color(&"destructive") if Game.cheated else UITheme.color(&"olive")
		_footer_status.text = "%s  ·  Day %d  ·  %d coins  ·  Esc closes" % [
			mode_str, Game.day, Game.coins]
		_footer_status.add_theme_color_override("font_color", mode_col)
