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
static var not_done_forgiveness: bool = true
static var verdict_weight: float = 0.5

# --- items -------------------------------------------------------------
static var items: Dictionary = {}
static var item_order: Array = []


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

	var e: Dictionary = d.get("economy", {})
	coins_per_grade_point = float(e.get("coins_per_grade_point", coins_per_grade_point))
	sell_fraction = float(e.get("sell_fraction", sell_fraction))
	start_coins = int(e.get("start_coins", start_coins))

	var c: Dictionary = d.get("class", {})
	class_start = int(c.get("start_size", class_start))
	class_cap = int(c.get("cap", class_cap))
	enrol_every_days = int(c.get("enrol_every_days", enrol_every_days))
	enrol_min_average = float(c.get("enrol_min_average", enrol_min_average))

	var h: Dictionary = d.get("homework", {})
	not_done_forgiveness = bool(h.get("not_done_forgiveness", not_done_forgiveness))
	verdict_weight = float(h.get("verdict_weight", verdict_weight))

	if d.has("items"):
		items = d["items"]
	if d.has("item_order"):
		item_order = d["item_order"]


## The theoretical best grade, so the contract can be asserted rather than
## hoped for.
static func max_grade() -> float:
	ensure_loaded()
	return minf(1.0, room_cap + lesson_cap + homework_cap)
