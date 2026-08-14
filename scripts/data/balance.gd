class_name Balance
extends RefCounted

## Every tunable number in the game, loaded from data/balance.json.
##
## Nothing gameplay-affecting should be a `const` in a .gd file any more.
## Before this existed the numbers were scattered across five scripts, there
## was nowhere to put a difficulty curve, and a tuning change could not be
## diffed or simulated.
##
## Deliberately static + ensure_loaded() rather than an autoload: the
## headless simulator and the tests run without a SceneTree, and an autoload
## would not exist for them.

static var _loaded: bool = false
static var _data: Dictionary = {}

# --- grade model -------------------------------------------------------
static var room_base: float = 0.27
static var room_cap: float = 0.55
static var lesson_cap: float = 0.35
static var homework_cap: float = 0.12
## What an uncompleted collection is worth. Below 1.0, walking round picking
## the work up is worth doing; at 1.0 it would be the busywork it used to be.
static var uncollected_penalty: float = 0.5

# --- the lesson --------------------------------------------------------
static var work_seconds: float = 14.0
static var lesson_seconds: float = 60.0
static var stall_chance_per_second: float = 0.10
static var stall_grace_seconds: float = 1.5
static var attention_per_help: float = 0.06
static var entry_stagger: float = 0.35

# --- economy -----------------------------------------------------------
static var coins_per_grade_point: float = 26.0
static var sell_fraction: float = 0.5
static var start_coins: int = 80

# --- class -------------------------------------------------------------
static var class_start: int = 4
static var class_cap: int = 8
static var enrol_every_days: int = 3
static var enrol_min_average: float = 0.62

# --- homework ----------------------------------------------------------
static var term_days: int = 20
static var exam_pass: float = 0.62
static var upkeep_per_item: int = 3
static var affinity_bonus: float = 0.25
# --- teacher ------------------------------------------------------------
static var teacher_speed: float = 60.0
static var teacher_pick_radius: float = 20.0
static var teacher_xp_per_day: int = 12
static var teacher_xp_per_grade_point: int = 25
static var teacher_xp_per_graduation: int = 45
static var teacher_xp_per_level: int = 100
static var teacher_max_level: int = 12

# --- students -----------------------------------------------------------
static var stu_xp_per_lesson: int = 18
static var stu_xp_per_work_done: int = 12
static var stu_xp_per_homework: int = 14
static var stu_xp_per_help: int = 4
static var stu_xp_per_level: int = 60
static var stu_max_level: int = 10
static var stu_aptitude_step: float = 0.025
static var stu_diligence_step: float = 0.02
static var stu_ready_level: int = 5
static var stu_hold_grace: int = 2

# --- being inspected -----------------------------------------------------
static var insp_grant: int = 420
static var insp_pass: float = 0.55
static var insp_w_room: float = 0.35
static var insp_w_lesson: float = 0.45
static var insp_w_knowledge: float = 0.20

# --- raising your voice --------------------------------------------------
static var voice_range: int = 5
static var voice_cost: float = 0.34
static var voice_recharge: float = 0.055
static var voice_unheard_seconds: float = 3.0

# --- messing about -------------------------------------------------------
static var dis_boredom: float = 0.030
static var dis_frustration: float = 0.018
static var dis_frustration_after: float = 8.0
static var dis_spread: float = 0.045
static var dis_neighbour_stall_mult: float = 2.0
static var dis_settle_xp: int = 3

# --- knowing your material ----------------------------------------------
static var concept_bonus: float = 0.012
static var concept_bonus_cap: float = 0.12

# --- buying floor space --------------------------------------------------
static var room_expand_cost_per_tile: int = 26
static var room_expand_growth: float = 1.45

# --- the end-of-unit test ------------------------------------------------
static var test_requires_taught: int = 3
static var test_cap: float = 0.5
static var test_seconds: float = 30.0

# --- the in-lesson quiz --------------------------------------------------
static var quiz_questions: int = 4
static var quiz_seconds_cost: float = 10.0
static var quiz_flag_below: float = 0.5
static var quiz_retrieval_seconds: float = 1.5
static var quiz_resolve_seconds: float = 6.0
static var quiz_affinity_bonus: float = 0.15
static var quiz_misjudged_penalty: float = 0.2

# --- graduation & coaching ----------------------------------------------
static var grad_base_coins: int = 90
static var grad_coins_per_level: int = 45
static var grad_teacher_xp: int = 45
static var coach_tuition_cost: int = 90
static var coach_tuition_step: float = 0.07
static var coach_parents_cost: int = 70
static var coach_parents_step: float = 0.07
static var coach_cost_growth: float = 1.7
static var coach_max_per_student: int = 4

# --- perks --------------------------------------------------------------
static var perks: Dictionary = {}
static var perk_brisk_walk_speed: float = 15.0
static var perk_long_reach_radius: float = 8.0
static var perk_calm_presence_radius: float = 40.0
static var perk_calm_presence_mult: float = 0.7
static var perk_practised_marker_sheets: int = 2

static var not_done_forgiveness: bool = true
static var verdict_weight: float = 0.5

# --- items -------------------------------------------------------------
static var items: Dictionary = {}
static var traits: Dictionary = {}
static var item_order: Array = []
static var item_categories: Array = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if f == null:
		push_warning("balance.json missing — using built-in defaults")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("balance.json is malformed — using built-in defaults")
		return
	_data = parsed as Dictionary
	apply(_data)


## Split out so the debug panel and the simulator can push a modified table
## in at runtime without touching the file.
static func apply(d: Dictionary) -> void:
	var g: Dictionary = d.get("grade", {})
	room_base = float(g.get("room_base", room_base))
	room_cap = float(g.get("room_cap", room_cap))
	lesson_cap = float(g.get("lesson_cap", lesson_cap))
	homework_cap = float(g.get("homework_cap", homework_cap))
	uncollected_penalty = float(g.get("uncollected_penalty", uncollected_penalty))

	var l: Dictionary = d.get("lesson", {})
	work_seconds = float(l.get("work_seconds", work_seconds))
	lesson_seconds = float(l.get("lesson_seconds", lesson_seconds))
	stall_chance_per_second = float(l.get("stall_chance_per_second", stall_chance_per_second))
	stall_grace_seconds = float(l.get("stall_grace_seconds", stall_grace_seconds))
	attention_per_help = float(l.get("attention_per_help", attention_per_help))
	entry_stagger = float(l.get("entry_stagger", entry_stagger))
	affinity_bonus = float(l.get("affinity_bonus", affinity_bonus))

	var e: Dictionary = d.get("economy", {})
	coins_per_grade_point = float(e.get("coins_per_grade_point", coins_per_grade_point))
	sell_fraction = float(e.get("sell_fraction", sell_fraction))
	start_coins = int(e.get("start_coins", start_coins))

	var c: Dictionary = d.get("class", {})
	class_start = int(c.get("start_size", class_start))
	class_cap = int(c.get("cap", class_cap))
	enrol_every_days = int(c.get("enrol_every_days", enrol_every_days))
	enrol_min_average = float(c.get("enrol_min_average", enrol_min_average))

	var tm: Dictionary = d.get("term", {})
	term_days = int(tm.get("days", term_days))
	exam_pass = float(tm.get("exam_pass", exam_pass))

	var up: Dictionary = d.get("upkeep", {})
	upkeep_per_item = int(up.get("per_item_per_day", upkeep_per_item))

	var tc: Dictionary = d.get("teacher", {})
	teacher_speed = float(tc.get("speed", teacher_speed))
	teacher_pick_radius = float(tc.get("pick_radius", teacher_pick_radius))
	teacher_xp_per_day = int(tc.get("xp_per_day", teacher_xp_per_day))
	teacher_xp_per_grade_point = int(tc.get("xp_per_grade_point", teacher_xp_per_grade_point))
	teacher_xp_per_graduation = int(tc.get("xp_per_graduation", teacher_xp_per_graduation))
	teacher_xp_per_level = int(tc.get("xp_per_level", teacher_xp_per_level))
	teacher_max_level = int(tc.get("max_level", teacher_max_level))

	var st: Dictionary = d.get("student", {})
	stu_xp_per_lesson = int(st.get("xp_per_lesson", stu_xp_per_lesson))
	stu_xp_per_work_done = int(st.get("xp_per_work_done", stu_xp_per_work_done))
	stu_xp_per_homework = int(st.get("xp_per_homework", stu_xp_per_homework))
	stu_xp_per_help = int(st.get("xp_per_help", stu_xp_per_help))
	stu_xp_per_level = int(st.get("xp_per_level", stu_xp_per_level))
	stu_max_level = int(st.get("max_level", stu_max_level))
	stu_aptitude_step = float(st.get("level_aptitude_step", stu_aptitude_step))
	stu_diligence_step = float(st.get("level_diligence_step", stu_diligence_step))
	stu_ready_level = int(st.get("ready_level", stu_ready_level))
	stu_hold_grace = int(st.get("hold_grace_levels", stu_hold_grace))

	traits = d.get("traits", {})

	var ins: Dictionary = d.get("inspection", {})
	insp_grant = int(ins.get("grant", insp_grant))
	insp_pass = float(ins.get("pass_mark", insp_pass))
	insp_w_room = float(ins.get("weight_room", insp_w_room))
	insp_w_lesson = float(ins.get("weight_lesson", insp_w_lesson))
	insp_w_knowledge = float(ins.get("weight_knowledge", insp_w_knowledge))

	var vc: Dictionary = d.get("voice", {})
	voice_range = int(vc.get("range_tiles", voice_range))
	voice_cost = float(vc.get("cost", voice_cost))
	voice_recharge = float(vc.get("recharge_per_second", voice_recharge))
	voice_unheard_seconds = float(vc.get("unheard_stall_seconds",
		voice_unheard_seconds))

	var ds: Dictionary = d.get("disruption", {})
	dis_boredom = float(ds.get("from_boredom_per_second", dis_boredom))
	dis_frustration = float(ds.get("from_frustration_per_second", dis_frustration))
	dis_frustration_after = float(ds.get("frustration_after_seconds",
		dis_frustration_after))
	dis_spread = float(ds.get("spread_per_second", dis_spread))
	dis_neighbour_stall_mult = float(ds.get("neighbour_stall_mult",
		dis_neighbour_stall_mult))
	dis_settle_xp = int(ds.get("xp_for_settling", dis_settle_xp))

	var cn: Dictionary = d.get("concepts", {})
	concept_bonus = float(cn.get("bonus", concept_bonus))
	concept_bonus_cap = float(cn.get("bonus_cap", concept_bonus_cap))

	var rm: Dictionary = d.get("room", {})
	room_expand_cost_per_tile = int(rm.get("expand_cost_per_tile", room_expand_cost_per_tile))
	room_expand_growth = float(rm.get("expand_growth", room_expand_growth))

	var ts: Dictionary = d.get("test", {})
	test_requires_taught = int(ts.get("requires_taught", test_requires_taught))
	test_cap = float(ts.get("cap", test_cap))
	test_seconds = float(ts.get("seconds", test_seconds))

	var qz: Dictionary = d.get("quiz", {})
	quiz_questions = int(qz.get("questions", quiz_questions))
	quiz_seconds_cost = float(qz.get("seconds_cost", quiz_seconds_cost))
	quiz_flag_below = float(qz.get("flag_below", quiz_flag_below))
	quiz_retrieval_seconds = float(qz.get("retrieval_seconds", quiz_retrieval_seconds))
	quiz_resolve_seconds = float(qz.get("resolve_seconds", quiz_resolve_seconds))
	quiz_affinity_bonus = float(qz.get("affinity_bonus", quiz_affinity_bonus))
	quiz_misjudged_penalty = float(qz.get("misjudged_penalty", quiz_misjudged_penalty))

	var gr: Dictionary = d.get("graduation", {})
	grad_base_coins = int(gr.get("base_coins", grad_base_coins))
	grad_coins_per_level = int(gr.get("coins_per_extra_level", grad_coins_per_level))
	grad_teacher_xp = int(gr.get("teacher_xp", grad_teacher_xp))

	var co: Dictionary = d.get("coaching", {})
	coach_tuition_cost = int(co.get("tuition_cost", coach_tuition_cost))
	coach_tuition_step = float(co.get("tuition_step", coach_tuition_step))
	coach_parents_cost = int(co.get("parents_cost", coach_parents_cost))
	coach_parents_step = float(co.get("parents_step", coach_parents_step))
	coach_cost_growth = float(co.get("cost_growth", coach_cost_growth))
	coach_max_per_student = int(co.get("max_per_student", coach_max_per_student))

	if d.has("perks"):
		perks = d["perks"]
	var pe: Dictionary = d.get("perk_effects", {})
	perk_brisk_walk_speed = float(pe.get("brisk_walk_speed", perk_brisk_walk_speed))
	perk_long_reach_radius = float(pe.get("long_reach_radius", perk_long_reach_radius))
	perk_calm_presence_radius = float(pe.get("calm_presence_radius", perk_calm_presence_radius))
	perk_calm_presence_mult = float(pe.get("calm_presence_mult", perk_calm_presence_mult))
	perk_practised_marker_sheets = int(pe.get("practised_marker_sheets", perk_practised_marker_sheets))

	var h: Dictionary = d.get("homework", {})
	not_done_forgiveness = bool(h.get("not_done_forgiveness", not_done_forgiveness))
	verdict_weight = float(h.get("verdict_weight", verdict_weight))

	if d.has("items"):
		items = d["items"]
	if d.has("item_order"):
		item_order = d["item_order"]
	if d.has("item_categories"):
		item_categories = d["item_categories"]


## Named access for the live debug panel. Object.get()/set() cannot be
## called on a class directly, only on an instance, and these are statics.
static func get_value(key: String) -> float:
	ensure_loaded()
	match key:
		"work_seconds": return work_seconds
		"lesson_seconds": return lesson_seconds
		"stall_chance_per_second": return stall_chance_per_second
		"room_base": return room_base
		"room_cap": return room_cap
		"lesson_cap": return lesson_cap
		"coins_per_grade_point": return coins_per_grade_point
		"upkeep_per_item": return float(upkeep_per_item)
		"term_days": return float(term_days)
	return 0.0


static func set_value(key: String, v: float) -> void:
	ensure_loaded()
	v = maxf(0.0, v)
	match key:
		"work_seconds": work_seconds = v
		"lesson_seconds": lesson_seconds = v
		"stall_chance_per_second": stall_chance_per_second = v
		"room_base": room_base = v
		"room_cap": room_cap = v
		"lesson_cap": lesson_cap = v
		"coins_per_grade_point": coins_per_grade_point = v
		"upkeep_per_item": upkeep_per_item = int(v)
		"term_days": term_days = maxi(1, int(v))


## The theoretical best grade, so the contract can be asserted rather than
## hoped for.
static func max_grade() -> float:
	ensure_loaded()
	return minf(1.0, room_cap + lesson_cap + homework_cap)
