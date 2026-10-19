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

## Where a numeric grade (0..1) lands as a letter. See the note on
## grade_bands in balance.json for why these are not the EduSystems
## originals any more -- the contract's own bare-room row sat a single
## point above the old C floor.
static var grade_band_a: float = 0.88
static var grade_band_b: float = 0.75
static var grade_band_c: float = 0.62
static var grade_band_d: float = 0.50
static var grade_band_e: float = 0.38

# --- the lesson --------------------------------------------------------
static var work_seconds: float = 14.0
static var lesson_seconds: float = 60.0
static var stall_chance_per_second: float = 0.10
static var supplies_stall_mult: float = 0.7
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
## A desk you bought. `class_cap` is now the STARTING number of desks, and
## `class_hard_cap` is the ceiling however many you buy.
static var desk_cost: int = 180
static var desk_cost_growth: float = 1.3
static var class_hard_cap: int = 24
static var enrol_every_days: int = 3
static var enrol_min_average: float = 0.62

# --- homework ----------------------------------------------------------
static var term_days: int = 20
static var exam_pass: float = 0.62
## What a fully furnished room is worth ON TOP of a child's own record.
static var exam_room_bonus: float = 0.08
## Does passing move a child up and out of your class at the end of term?
static var term_pass_moves_up: bool = true
## How many must pass in term 1, and how much that rises each term after.
static var term_target_base: int = 2
static var term_target_growth: int = 1
static var upkeep_per_item: int = 3
# --- pacing (ten-commits.md step 3) --------------------------------------
## Expected new concepts per day, on the term's OWN new ground -- not the
## whole curriculum's total, which is a many-term tally. Coins and XP
## only; this never feeds a grade, so it needs no new contract guard.
static var pace_concepts_per_day: float = 0.2
static var pace_bonus_coins: int = 15
static var pace_bonus_xp: int = 6
## Days left at or below which "behind" escalates from a nudge to a
## warning -- the same number of days a term-1 class needs to be
## genuinely running out of road.
static var pace_escalate_days_left: int = 5
## The spread guarantee (ten-commits.md step 5): this many consecutive
## "none" days is the ceiling before DayEvent.roll() excludes "none"
## outright.
static var event_none_streak_cap: int = 2
static var affinity_bonus: float = 0.25
# --- teacher ------------------------------------------------------------
static var teacher_speed: float = 120.0   ## doubled Aug 2026
static var teacher_pick_radius: float = 40.0   ## doubled Aug 2026
static var teacher_xp_per_day: int = 12
static var teacher_xp_per_grade_point: int = 25
static var teacher_xp_per_graduation: int = 45
static var teacher_xp_per_level: int = 100
static var teacher_max_level: int = 12
## The tap-dash that replaced the old held sprint (const SPRINT, actor.gd).
## Burst multiplier, how long the burst lasts, and the wait after it before
## the next dash -- the cooldown is the only limiter, there is no stamina.
static var teacher_dash_speed_multiplier: float = 2.6
static var teacher_dash_duration: float = 0.2
static var teacher_dash_cooldown: float = 1.3
## Trigger: double-tap a direction within this many seconds of the first
## press, or use the dedicated `dash` action (Shift) -- either fires the
## same burst. See player.gd's _tick_double_tap_dash().
static var teacher_dash_double_tap_window: float = 0.28
## Dash-cancel: for this long after a burst ends, the pick zone is widened
## by teacher_dash_cancel_reach px, so a dash that stops just short still
## reaches the desk. Reach only -- nothing a delegated room is graded on.
static var teacher_dash_cancel_grace: float = 0.2
static var teacher_dash_cancel_reach: float = 24.0
## Furniture lanes: dashing along a tile beside a "lane" item lets the burst
## carry -- up to dash_lane_extend extra seconds across one dash. Dashing
## beside a "clutter" item kills the burst dead and adds dash_clutter_penalty
## to the cooldown. Layout only: neither touches anything a room is graded on.
static var teacher_dash_lane_extend: float = 0.25
static var teacher_dash_clutter_penalty: float = 0.35
## The launch puff. Decoration, but tunable because the Light Feet perk
## scales all four -- see teacher._dash_smoke_note in balance.json.
static var teacher_dash_smoke_count: int = 8
static var teacher_dash_smoke_spread: float = 16.0
static var teacher_dash_smoke_scale: float = 2.2
static var teacher_dash_smoke_seconds: float = 0.5
## The chain dash (taught by the mentor): a dash that reaches a visible
## raised hand answers it on arrival, and the next dash is ready after
## chain_dash_cooldown instead of the ordinary wait. See
## teacher._chain_dash_note in balance.json and player.gd's _tick_chain().
static var teacher_chain_dash_cooldown: float = 0.12
static var teacher_chain_dash_reach: float = 48.0
static var teacher_chain_dash_max_links: int = 5
static var teacher_chain_dash_window: float = 1.2

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

# --- the teacher's aide --------------------------------------------------
static var aide_cost: int = 260
static var aide_wage: int = 18
static var aide_collect: float = 2.2

# --- the janitor -----------------------------------------------------------
static var janitor_cost: int = 220
static var janitor_wage: int = 15
static var janitor_clean: float = 3.0

# --- levelling the aide/janitor up ----------------------------------------
static var staff_level_max: int = 5
static var staff_level_cost_base: int = 40
static var staff_level_cost_growth: float = 1.6
static var staff_speedup_per_level: float = 0.15

# --- autopilot -----------------------------------------------------------
static var auto_speed: float = 1.35
static var auto_arrive: int = 1

# --- what the school is thought of ---------------------------------------
static var rep_start: int = 50
static var rep_per_grade_point: float = 6.0
static var rep_drift_to: float = 50.0
static var rep_drift: float = 0.35
static var rep_target_hit: int = 8
static var rep_target_missed: int = 14
static var rep_inspection: int = 6
static var rep_per_room: int = 20
static var rep_closes_below: int = 5

# --- rooms you do not stand in -------------------------------------------
static var room_cost: int = 900
static var room_cost_growth: float = 1.6
static var max_rooms: int = 6
static var school_class_size: int = 6
static var furniture_step_cost: int = 240
static var furniture_steps: int = 5
static var applicant_count: int = 4
## Firing a hired teacher is instant, but not free -- otherwise a bad hire
## costs nothing to undo and "who you hire" stops being a real decision.
static var fire_cost: int = 150

# --- the paper you set ---------------------------------------------------
## A fresh count each morning, not always the same hand. See the note on
## hand_size_min in balance.json -- the hook for a later teacher LUCK skill.
static var assign_hand_size_min: int = 3
static var assign_hand_size_max: int = 7
static var assign_trade_in_count: int = 3
## Lessons taught in one subject before a lesson there can be made Prestige.
static var assign_prestige_lessons_needed: int = 5
static var assign_rarities: Array = []
static var assign_forms: Array = []

# --- the fork at the start of each term ------------------------------------
## Same "draw a small hand, pick one" shape as the paper you set above, but
## WITHOUT replacement (TermPaths.draw()) -- repeating a termly choice would
## read as broken, not lucky.
static var term_path_hand_min: int = 3
static var term_path_hand_max: int = 3
static var term_paths: Array = []

# --- the class, in a word -------------------------------------------------
## See the `mood` note in balance.json and Game.class_mood().
static var mood_noisy_weight: float = 0.15
static var mood_stuck_weight: float = 0.08
static var mood_with_you: float = 0.6
static var mood_drifting: float = 0.35
static var mood_restless: float = 0.1

# --- the roguelike subject boss ------------------------------------------
## Boss cards are folded into the term-path fork pool on every
## boss_term_interval-th term (Game.draw_term_paths), tagged kind:"boss",
## and excluded on every other term so a boss is a telegraphed choice, not
## an ambush. `bosses` is the card TABLE -- full term-path card dicts plus
## an id, strand, target bar and trophy_id. See the note on `bosses` in
## balance.json, and scripts/data/trophies.gd for the shelf they land on.
static var boss_term_interval: int = 3
static var bosses: Array = []
## The fight itself -- see the `_fight_note` on `bosses.fight` in
## balance.json and scripts/data/boss_fight.gd. Seconds, marks and the
## composure bands; the per-boss MOVE list lives on each card in `bosses`.
static var fight_round_seconds: float = 14.0
static var fight_breath_seconds: float = 3.0
static var fight_quick_seconds: float = 5.0
static var fight_rally_mark: float = 0.02
static var fight_drop_mark: float = 0.03
static var fight_max_swing: float = 0.06
static var fight_freeze_count: int = 3
static var fight_chain_spread_seconds: float = 2.5
static var fight_noise_count: int = 3
static var fight_present_radius: int = 2
static var fight_present_seconds: float = 6.0
static var fight_present_rally_seconds: float = 10.0
static var fight_restless_per_second: float = 0.04
static var fight_composure_steady: float = 0.85
static var fight_composure_wobbling: float = 0.6
static var fight_composure_cracking: float = 0.35

# --- the subject you trained in ------------------------------------------
static var spec_relief: float = 1.0
static var spec_penalty: float = 0.7
static var spec_coins: float = 1.25

# --- how hard a lesson is ------------------------------------------------
static var diff_per_step_work: float = 0.18
static var diff_per_step_stall: float = 0.22
## How much of a lesson's extra difficulty a fully furnished desk removes.
static var diff_furniture_relief: float = 0.45

# --- standing at the front and teaching ----------------------------------
static var teach_fill: float = 0.85
static var teach_decay: float = 0.25
static var teach_drift_hint_below: float = 0.35
static var uncollected_hint_after: float = 6.0
static var teach_radius: int = 6
## What fraction of normal speed an UNATTENDED class works at. Zero means
## they stop entirely, which is the point.
static var teach_floor: float = 0.0

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

# --- flare-ups (a timed warning a calm child is about to kick off) ------
## onset is per calm seated child per second, scaled by the day event's
## stall multiplier. Catch it with E before countdown_seconds runs out for
## a coin tip + defuse_xp; miss it and they just start disrupting.
static var flare_onset: float = 0.011
static var flare_countdown: float = 6.0
static var flare_reward: int = 8
static var flare_defuse_xp: int = 4
static var flare_max_per_day: int = 5

# --- mid-lesson complications (a generalized flare -- see complications.gd)
## Same onset/cap shape as flare above; WHICH complication fires is decided
## by Complication.roll(), not here. onset is further scaled by the active
## term path's own density_mult (Game.complication_density_mult()).
static var comp_onset_per_second: float = 0.006
static var comp_max_per_lesson: int = 3
static var comp_boost_seconds: float = 45.0
static var comp_boost_speed_mult: float = 1.25

# --- the end-of-session bell rush (built, but OFF until a later stage) ---
## Hand every child's marked work back before `seconds` runs out for a flat
## coin bonus + xp_per_desk each. Coins + XP only, never grade.
static var bell_rush_enabled: bool = false
static var bell_rush_seconds: float = 45.0
static var bell_rush_reward: int = 40
static var bell_rush_xp_per_desk: int = 3

# --- knowing your material ----------------------------------------------
static var concept_bonus: float = 0.012
static var concept_bonus_cap: float = 0.12

# --- buying floor space, and how it is used ----------------------------
static var room_expand_cost_per_tile: int = 26
static var room_expand_growth: float = 1.45

# --- desks that touch get talking (Game.tick_chat) ----------------------
## The counter to the desk-cramming meta, and the visible replacement for
## the old hidden cluster penalty. Two seated children within reach_tiles of
## each other (corners count) may start a conversation, start_per_second per
## pair (times each one's trait chat_mult); neither works while it lasts.
## It ends after `seconds`, or at once when the teacher comes within
## hush_tiles; grace_seconds of work follow before either can start another,
## and a chat nobody broke up has noise_chance to turn into messing about.
static var chat_reach_tiles: int = 1
static var chat_start_per_second: float = 0.06
static var chat_seconds: float = 5.0
static var chat_grace_seconds: float = 6.0
static var chat_hush_tiles: int = 2
static var chat_noise_chance: float = 0.25
static var chat_talk_scale_min: int = 1
static var chat_talk_scale_max: int = 4
static var chat_talk_max_slowdown: float = 0.5

# --- dozing off at the desk (Game.tick_sleep) ---------------------------
static var sleep_tick_seconds: float = 15.0
static var sleep_chance_per_level: float = 0.1
static var sleep_nap_seconds: float = 8.0
static var sleep_scale_max: int = 3
static var sleep_room_mult_floor: float = 0.4
static var sleep_morning_window: float = 0.4

# --- Vygotsky ZPD & collaborative roaming (Game.tick_zpd) ---------------
static var zpd_roam_interval_seconds: float = 8.0
static var zpd_interact_seconds: float = 5.0
static var zpd_gap_min: float = 0.08
static var zpd_gap_max: float = 0.45
static var zpd_boost_mult: float = 1.35
static var zpd_mismatch_mult: float = 0.8
static var zpd_bonus_xp: int = 2

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
## What a quiz does to the stall chance for the rest of the lesson.
static var quiz_focus_mult: float = 0.6

# --- "answer all questions": the mass-help skill (its own key, J) -------
## One press clears confusion and resolves flagged quizzes for the whole
## room. It pays NO grade and NO coins -- the whole cost is seconds_cost
## charged straight to the lesson clock, plus cooldown_seconds before it
## comes back. seconds_cost is deliberately steeper than the quiz's:
## this is a panic button, not a reflex.
static var answer_all_seconds_cost: float = 16.0
static var answer_all_cooldown_seconds: float = 75.0

## The call-and-response ("Class, class!" -- "Yes, yes!"), the mentor's
## third move. Attention snaps to full and holds for hold_seconds wherever
## you walk; it costs voice_cost of the voice meter settling also spends,
## and cannot be called again for cooldown_seconds. Pace only.
static var call_voice_cost: float = 0.5
static var call_hold_seconds: float = 5.0
static var call_cooldown_seconds: float = 20.0

# --- graduation & coaching ----------------------------------------------
static var grad_base_coins: int = 90
static var grad_coins_per_level: int = 45
static var grad_teacher_xp: int = 45

# --- notable moments (the per-student highlight reel) ------------------
static var moments_cap: int = 12
static var moments_grade_min_history: int = 2
## Ten-commits.md step 6: lessons running in a child's own best subject
## before it earns them a moment about it.
static var moments_favourite_streak: int = 3
static var coach_tuition_cost: int = 90
static var coach_tuition_step: float = 0.07
static var coach_parents_cost: int = 70
static var coach_parents_step: float = 0.07
static var coach_cost_growth: float = 1.7
static var coach_max_per_student: int = 4

# --- lesson crafting ------------------------------------------------------
static var craft_unlock_day: int = 5
static var craft_base_cost: int = 120
static var craft_cost_growth: float = 1.6
static var craft_days_per_attempt: int = 2
static var craft_success_chance: float = 0.65
static var craft_work_mult_per_level: float = 0.02
static var craft_stall_mult_per_level: float = 0.015
static var craft_level_cap_for_bonus: int = 5
static var craft_min_work_mult: float = 0.9

# --- perks --------------------------------------------------------------
static var perks: Dictionary = {}
static var perk_brisk_walk_speed: float = 30.0   ## doubled Aug 2026
static var perk_long_reach_radius: float = 16.0   ## doubled Aug 2026
static var perk_calm_presence_radius: float = 80.0   ## doubled Aug 2026
static var perk_calm_presence_mult: float = 0.7
static var perk_practised_marker_sheets: int = 2
static var perk_quick_sweep_presses: int = 1
static var perk_carrying_voice_tiles: float = 1.0
static var perk_quick_study_pct: float = 0.05
static var perk_lucky_break_bias: float = 0.12
static var perk_thrifty_pct: float = 0.06
static var perk_iron_will_mult: float = 0.75
static var perk_light_feet_duration: float = 0.05
static var perk_light_feet_cooldown: float = 0.25
static var perk_light_feet_smoke: int = 4
static var perk_light_feet_smoke_scale: float = 0.45

# --- teaching on your own (the multi-day skip) --------------------------
static var skip_max_days: int = 5
static var skip_item_bonus_cap: int = 5

static var not_done_forgiveness: bool = true
static var verdict_weight: float = 0.5

# --- daily room mess ------------------------------------------------------
static var mess_clean_presses: int = 5
static var mess_clean_reward: int = 5

# --- items -------------------------------------------------------------
static var items: Dictionary = {}
static var traits: Dictionary = {}
## The optional reward-video poster's tiers -- see ensure_loaded() for why
## this stays a raw Array rather than fixed static vars.
static var ad_tiers: Array = []
static var item_order: Array = []
static var item_categories: Array = []

# --- age tiers & consumables -------------------------------------------
static var age_tiers: Dictionary = {}
static var consumables: Dictionary = {}
static var distraction_default_radius: int = 2
static var distraction_min_radius: int = 1
static var distraction_max_radius: int = 3
static var distraction_wall_dampen: int = 1
static var distraction_bookcase_dampen: int = 1
static var distraction_desk_dampen: int = 1
static var distraction_dampen_range: int = 2
static var tenure_days_per_level: int = 5
static var tenure_lessons_per_level: int = 3
static var tenure_resilience_per_level: float = 0.05
static var tenure_resilience_cap: float = 0.5
static var tenure_tutor_per_level: float = 0.06
static var tenure_tutor_cap: float = 0.5
static var tier_order: Array = ["elementary", "middle", "high", "college"]
static var tier_captains_max: int = 2
static var tier_pod_reach_tiles: int = 3


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

	var gb: Dictionary = d.get("grade_bands", {})
	grade_band_a = float(gb.get("a", grade_band_a))
	grade_band_b = float(gb.get("b", grade_band_b))
	grade_band_c = float(gb.get("c", grade_band_c))
	grade_band_d = float(gb.get("d", grade_band_d))
	grade_band_e = float(gb.get("e", grade_band_e))

	var l: Dictionary = d.get("lesson", {})
	work_seconds = float(l.get("work_seconds", work_seconds))
	lesson_seconds = float(l.get("lesson_seconds", lesson_seconds))
	stall_chance_per_second = float(l.get("stall_chance_per_second", stall_chance_per_second))
	supplies_stall_mult = float(l.get("supplies_stall_mult", supplies_stall_mult))
	stall_grace_seconds = float(l.get("stall_grace_seconds", stall_grace_seconds))
	attention_per_help = float(l.get("attention_per_help", attention_per_help))
	uncollected_hint_after = float(l.get("uncollected_hint_after", uncollected_hint_after))
	entry_stagger = float(l.get("entry_stagger", entry_stagger))
	affinity_bonus = float(l.get("affinity_bonus", affinity_bonus))

	var e: Dictionary = d.get("economy", {})
	coins_per_grade_point = float(e.get("coins_per_grade_point", coins_per_grade_point))
	sell_fraction = float(e.get("sell_fraction", sell_fraction))
	start_coins = int(e.get("start_coins", start_coins))

	var c: Dictionary = d.get("class", {})
	class_start = int(c.get("start_size", class_start))
	class_cap = int(c.get("cap", class_cap))
	desk_cost = int(c.get("desk_cost", desk_cost))
	desk_cost_growth = float(c.get("desk_cost_growth", desk_cost_growth))
	class_hard_cap = int(c.get("hard_cap", class_hard_cap))
	enrol_every_days = int(c.get("enrol_every_days", enrol_every_days))
	enrol_min_average = float(c.get("enrol_min_average", enrol_min_average))

	var tm: Dictionary = d.get("term", {})
	term_days = int(tm.get("days", term_days))
	exam_pass = float(tm.get("exam_pass", exam_pass))
	exam_room_bonus = float(tm.get("exam_room_bonus", exam_room_bonus))
	term_pass_moves_up = bool(tm.get("pass_moves_them_up", term_pass_moves_up))
	term_target_base = int(tm.get("target_base", term_target_base))
	term_target_growth = int(tm.get("target_growth", term_target_growth))

	var pc: Dictionary = d.get("pacing", {})
	pace_concepts_per_day = float(pc.get("concepts_per_day", pace_concepts_per_day))
	pace_bonus_coins = int(pc.get("bonus_coins", pace_bonus_coins))
	pace_bonus_xp = int(pc.get("bonus_xp", pace_bonus_xp))
	pace_escalate_days_left = int(pc.get("escalate_days_left", pace_escalate_days_left))

	var ev: Dictionary = d.get("events", {})
	event_none_streak_cap = int(ev.get("none_streak_cap", event_none_streak_cap))

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
	teacher_dash_speed_multiplier = float(tc.get("dash_speed_multiplier", teacher_dash_speed_multiplier))
	teacher_dash_duration = float(tc.get("dash_duration", teacher_dash_duration))
	teacher_dash_cooldown = float(tc.get("dash_cooldown", teacher_dash_cooldown))
	teacher_dash_double_tap_window = float(tc.get("dash_double_tap_window", teacher_dash_double_tap_window))
	teacher_dash_cancel_grace = float(tc.get("dash_cancel_grace", teacher_dash_cancel_grace))
	teacher_dash_cancel_reach = float(tc.get("dash_cancel_reach", teacher_dash_cancel_reach))
	teacher_dash_lane_extend = float(tc.get("dash_lane_extend", teacher_dash_lane_extend))
	teacher_dash_clutter_penalty = float(tc.get("dash_clutter_penalty", teacher_dash_clutter_penalty))
	teacher_dash_smoke_count = int(tc.get("dash_smoke_count", teacher_dash_smoke_count))
	teacher_dash_smoke_spread = float(tc.get("dash_smoke_spread", teacher_dash_smoke_spread))
	teacher_dash_smoke_scale = float(tc.get("dash_smoke_scale", teacher_dash_smoke_scale))
	teacher_dash_smoke_seconds = float(tc.get("dash_smoke_seconds", teacher_dash_smoke_seconds))
	teacher_chain_dash_cooldown = float(tc.get("chain_dash_cooldown", teacher_chain_dash_cooldown))
	teacher_chain_dash_reach = float(tc.get("chain_dash_reach", teacher_chain_dash_reach))
	teacher_chain_dash_max_links = int(tc.get("chain_dash_max_links", teacher_chain_dash_max_links))
	teacher_chain_dash_window = float(tc.get("chain_dash_window", teacher_chain_dash_window))

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

	# The ad poster's tiers -- an Array of {id, seconds, wait, reward_coins}
	# dicts, read directly by scripts/interact/ad_poster.gd rather than
	# unpacked into individual static vars, since the tier COUNT itself is
	# data, not fixed at three.
	var ads: Dictionary = d.get("ads", {})
	ad_tiers = ads.get("tiers", [])

	var ai: Dictionary = d.get("aide", {})
	aide_cost = int(ai.get("hire_cost", aide_cost))
	aide_wage = int(ai.get("daily_wage", aide_wage))
	aide_collect = float(ai.get("collect_seconds", aide_collect))

	var ja: Dictionary = d.get("janitor", {})
	janitor_cost = int(ja.get("hire_cost", janitor_cost))
	janitor_wage = int(ja.get("daily_wage", janitor_wage))
	janitor_clean = float(ja.get("clean_seconds", janitor_clean))

	var sl: Dictionary = d.get("staff_levels", {})
	staff_level_max = int(sl.get("max_level", staff_level_max))
	staff_level_cost_base = int(sl.get("level_cost_base", staff_level_cost_base))
	staff_level_cost_growth = float(sl.get("level_cost_growth", staff_level_cost_growth))
	staff_speedup_per_level = float(sl.get("speedup_per_level", staff_speedup_per_level))

	var ap: Dictionary = d.get("autopilot", {})
	auto_speed = float(ap.get("speed_multiplier", auto_speed))
	auto_arrive = int(ap.get("arrive_tiles", auto_arrive))

	var rp: Dictionary = d.get("reputation", {})
	rep_start = int(rp.get("start", rep_start))
	rep_per_grade_point = float(rp.get("per_room_grade_point", rep_per_grade_point))
	rep_drift_to = float(rp.get("drift_to", rep_drift_to))
	rep_drift = float(rp.get("drift_per_day", rep_drift))
	rep_target_hit = int(rp.get("target_hit", rep_target_hit))
	rep_target_missed = int(rp.get("target_missed", rep_target_missed))
	rep_inspection = int(rp.get("inspection_pass", rep_inspection))
	rep_per_room = int(rp.get("room_per_open", rep_per_room))
	rep_closes_below = int(rp.get("closes_below", rep_closes_below))

	var sc: Dictionary = d.get("school", {})
	room_cost = int(sc.get("room_cost", room_cost))
	room_cost_growth = float(sc.get("room_cost_growth", room_cost_growth))
	max_rooms = int(sc.get("max_rooms", max_rooms))
	school_class_size = int(sc.get("class_size", school_class_size))
	furniture_step_cost = int(sc.get("furniture_step_cost", furniture_step_cost))
	furniture_steps = int(sc.get("furniture_steps", furniture_steps))
	applicant_count = int(sc.get("applicants", applicant_count))
	fire_cost = int(sc.get("fire_cost", fire_cost))

	var asg: Dictionary = d.get("assignments", {})
	assign_hand_size_min = int(asg.get("hand_size_min", assign_hand_size_min))
	assign_hand_size_max = int(asg.get("hand_size_max", assign_hand_size_max))
	assign_trade_in_count = int(asg.get("trade_in_count", assign_trade_in_count))
	assign_prestige_lessons_needed = int(asg.get("prestige_lessons_needed", assign_prestige_lessons_needed))
	assign_rarities = asg.get("rarities", assign_rarities)
	assign_forms = asg.get("forms", assign_forms)

	var tp: Dictionary = d.get("term_paths", {})
	term_path_hand_min = int(tp.get("hand_size_min", term_path_hand_min))
	term_path_hand_max = int(tp.get("hand_size_max", term_path_hand_max))
	term_paths = tp.get("paths", term_paths)

	var md: Dictionary = d.get("mood", {})
	mood_noisy_weight = float(md.get("noisy_weight", mood_noisy_weight))
	mood_stuck_weight = float(md.get("stuck_weight", mood_stuck_weight))
	mood_with_you = float(md.get("with_you", mood_with_you))
	mood_drifting = float(md.get("drifting", mood_drifting))
	mood_restless = float(md.get("restless", mood_restless))
	var bs: Dictionary = d.get("bosses", {})
	boss_term_interval = int(bs.get("term_interval", boss_term_interval))
	bosses = bs.get("table", bosses)
	var fg: Dictionary = bs.get("fight", {})
	fight_round_seconds = float(fg.get("round_seconds", fight_round_seconds))
	fight_breath_seconds = float(fg.get("breath_seconds", fight_breath_seconds))
	fight_quick_seconds = float(fg.get("quick_seconds", fight_quick_seconds))
	fight_rally_mark = float(fg.get("rally_mark", fight_rally_mark))
	fight_drop_mark = float(fg.get("drop_mark", fight_drop_mark))
	fight_max_swing = float(fg.get("max_swing", fight_max_swing))
	fight_freeze_count = int(fg.get("freeze_count", fight_freeze_count))
	fight_chain_spread_seconds = float(fg.get("chain_spread_seconds", fight_chain_spread_seconds))
	fight_noise_count = int(fg.get("noise_count", fight_noise_count))
	fight_present_radius = int(fg.get("present_radius_tiles", fight_present_radius))
	fight_present_seconds = float(fg.get("present_seconds", fight_present_seconds))
	fight_present_rally_seconds = float(fg.get("present_rally_seconds", fight_present_rally_seconds))
	fight_restless_per_second = float(fg.get("restless_per_second", fight_restless_per_second))
	fight_composure_steady = float(fg.get("composure_steady", fight_composure_steady))
	fight_composure_wobbling = float(fg.get("composure_wobbling", fight_composure_wobbling))
	fight_composure_cracking = float(fg.get("composure_cracking", fight_composure_cracking))

	var sp: Dictionary = d.get("specialism", {})
	spec_relief = float(sp.get("difficulty_relief", spec_relief))
	spec_penalty = float(sp.get("out_of_field_penalty", spec_penalty))
	spec_coins = float(sp.get("coin_bonus", spec_coins))

	var df: Dictionary = d.get("difficulty", {})
	diff_per_step_work = float(df.get("per_step_work", diff_per_step_work))
	diff_per_step_stall = float(df.get("per_step_stall", diff_per_step_stall))
	diff_furniture_relief = float(df.get("furniture_relief", diff_furniture_relief))

	var tg: Dictionary = d.get("teaching", {})
	teach_fill = float(tg.get("fill_per_second", teach_fill))
	teach_decay = float(tg.get("decay_per_second", teach_decay))
	teach_radius = int(tg.get("radius_tiles", teach_radius))
	teach_floor = float(tg.get("floor_rate", teach_floor))
	teach_drift_hint_below = float(tg.get("drift_hint_below", teach_drift_hint_below))

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

	var fl: Dictionary = d.get("flare", {})
	flare_onset = float(fl.get("onset_per_second", flare_onset))
	flare_countdown = float(fl.get("countdown_seconds", flare_countdown))
	flare_reward = int(fl.get("reward_coins", flare_reward))
	flare_defuse_xp = int(fl.get("defuse_xp", flare_defuse_xp))
	flare_max_per_day = int(fl.get("max_per_day", flare_max_per_day))

	var cp: Dictionary = d.get("complication", {})
	comp_onset_per_second = float(cp.get("onset_per_second", comp_onset_per_second))
	comp_max_per_lesson = int(cp.get("max_per_lesson", comp_max_per_lesson))
	comp_boost_seconds = float(cp.get("boost_seconds", comp_boost_seconds))
	comp_boost_speed_mult = float(cp.get("boost_speed_mult", comp_boost_speed_mult))

	var br: Dictionary = d.get("bell_rush", {})
	bell_rush_enabled = bool(br.get("enabled", bell_rush_enabled))
	bell_rush_seconds = float(br.get("seconds", bell_rush_seconds))
	bell_rush_reward = int(br.get("reward_coins", bell_rush_reward))
	bell_rush_xp_per_desk = int(br.get("xp_per_desk", bell_rush_xp_per_desk))

	var cn: Dictionary = d.get("concepts", {})
	concept_bonus = float(cn.get("bonus", concept_bonus))
	concept_bonus_cap = float(cn.get("bonus_cap", concept_bonus_cap))

	var rm: Dictionary = d.get("room", {})
	room_expand_cost_per_tile = int(rm.get("expand_cost_per_tile", room_expand_cost_per_tile))
	room_expand_growth = float(rm.get("expand_growth", room_expand_growth))

	var ch: Dictionary = d.get("chat", {})
	chat_reach_tiles = int(ch.get("reach_tiles", chat_reach_tiles))
	chat_start_per_second = float(ch.get("start_per_second", chat_start_per_second))
	chat_seconds = float(ch.get("seconds", chat_seconds))
	chat_grace_seconds = float(ch.get("grace_seconds", chat_grace_seconds))
	chat_hush_tiles = int(ch.get("hush_tiles", chat_hush_tiles))
	chat_noise_chance = float(ch.get("noise_chance", chat_noise_chance))
	chat_talk_scale_min = int(ch.get("talk_scale_min", chat_talk_scale_min))
	chat_talk_scale_max = int(ch.get("talk_scale_max", chat_talk_scale_max))
	chat_talk_max_slowdown = float(ch.get("talk_max_slowdown", chat_talk_max_slowdown))

	var slp: Dictionary = d.get("sleep", {})
	sleep_tick_seconds = float(slp.get("tick_seconds", sleep_tick_seconds))
	sleep_chance_per_level = float(slp.get("chance_per_level", sleep_chance_per_level))
	sleep_nap_seconds = float(slp.get("nap_seconds", sleep_nap_seconds))
	sleep_scale_max = int(slp.get("scale_max", sleep_scale_max))
	sleep_room_mult_floor = float(slp.get("room_mult_floor", sleep_room_mult_floor))
	sleep_morning_window = float(slp.get("morning_window", sleep_morning_window))

	var zp: Dictionary = d.get("zpd", {})
	zpd_roam_interval_seconds = float(zp.get("roam_interval_seconds", zpd_roam_interval_seconds))
	zpd_interact_seconds = float(zp.get("interact_seconds", zpd_interact_seconds))
	zpd_gap_min = float(zp.get("gap_min", zpd_gap_min))
	zpd_gap_max = float(zp.get("gap_max", zpd_gap_max))
	zpd_boost_mult = float(zp.get("boost_mult", zpd_boost_mult))
	zpd_mismatch_mult = float(zp.get("mismatch_mult", zpd_mismatch_mult))
	zpd_bonus_xp = int(zp.get("bonus_xp", zpd_bonus_xp))

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
	quiz_focus_mult = float(qz.get("focus_stall_mult", quiz_focus_mult))

	var aa: Dictionary = d.get("answer_all", {})
	answer_all_seconds_cost = float(aa.get("seconds_cost", answer_all_seconds_cost))
	answer_all_cooldown_seconds = float(aa.get("cooldown_seconds", answer_all_cooldown_seconds))

	var cr: Dictionary = d.get("call_response", {})
	call_voice_cost = float(cr.get("voice_cost", call_voice_cost))
	call_hold_seconds = float(cr.get("hold_seconds", call_hold_seconds))
	call_cooldown_seconds = float(cr.get("cooldown_seconds", call_cooldown_seconds))

	var gr: Dictionary = d.get("graduation", {})
	grad_base_coins = int(gr.get("base_coins", grad_base_coins))
	grad_coins_per_level = int(gr.get("coins_per_extra_level", grad_coins_per_level))
	grad_teacher_xp = int(gr.get("teacher_xp", grad_teacher_xp))

	var mo: Dictionary = d.get("moments", {})
	moments_cap = int(mo.get("cap", moments_cap))
	moments_grade_min_history = int(mo.get("grade_min_history", moments_grade_min_history))
	moments_favourite_streak = int(mo.get("favourite_streak", moments_favourite_streak))

	var co: Dictionary = d.get("coaching", {})
	coach_tuition_cost = int(co.get("tuition_cost", coach_tuition_cost))
	coach_tuition_step = float(co.get("tuition_step", coach_tuition_step))
	coach_parents_cost = int(co.get("parents_cost", coach_parents_cost))
	coach_parents_step = float(co.get("parents_step", coach_parents_step))
	coach_cost_growth = float(co.get("cost_growth", coach_cost_growth))
	coach_max_per_student = int(co.get("max_per_student", coach_max_per_student))

	var lc: Dictionary = d.get("lesson_crafting", {})
	craft_unlock_day = int(lc.get("unlock_day", craft_unlock_day))
	craft_base_cost = int(lc.get("base_cost", craft_base_cost))
	craft_cost_growth = float(lc.get("cost_growth", craft_cost_growth))
	craft_days_per_attempt = int(lc.get("days_per_attempt", craft_days_per_attempt))
	craft_success_chance = float(lc.get("success_chance", craft_success_chance))
	craft_work_mult_per_level = float(lc.get("work_mult_per_level", craft_work_mult_per_level))
	craft_stall_mult_per_level = float(lc.get("stall_mult_per_level", craft_stall_mult_per_level))
	craft_level_cap_for_bonus = int(lc.get("craft_level_cap_for_bonus", craft_level_cap_for_bonus))
	craft_min_work_mult = float(lc.get("min_work_mult", craft_min_work_mult))

	if d.has("perks"):
		perks = d["perks"]
	var pe: Dictionary = d.get("perk_effects", {})
	perk_brisk_walk_speed = float(pe.get("brisk_walk_speed", perk_brisk_walk_speed))
	perk_long_reach_radius = float(pe.get("long_reach_radius", perk_long_reach_radius))
	perk_calm_presence_radius = float(pe.get("calm_presence_radius", perk_calm_presence_radius))
	perk_calm_presence_mult = float(pe.get("calm_presence_mult", perk_calm_presence_mult))
	perk_practised_marker_sheets = int(pe.get("practised_marker_sheets", perk_practised_marker_sheets))
	perk_quick_sweep_presses = int(pe.get("quick_sweep_presses", perk_quick_sweep_presses))
	perk_carrying_voice_tiles = float(pe.get("carrying_voice_tiles", perk_carrying_voice_tiles))
	perk_quick_study_pct = float(pe.get("quick_study_pct", perk_quick_study_pct))
	perk_lucky_break_bias = float(pe.get("lucky_break_bias", perk_lucky_break_bias))
	perk_thrifty_pct = float(pe.get("thrifty_pct", perk_thrifty_pct))
	perk_iron_will_mult = float(pe.get("iron_will_mult", perk_iron_will_mult))
	perk_light_feet_duration = float(pe.get("light_feet_duration", perk_light_feet_duration))
	perk_light_feet_cooldown = float(pe.get("light_feet_cooldown", perk_light_feet_cooldown))
	perk_light_feet_smoke = int(pe.get("light_feet_smoke", perk_light_feet_smoke))
	perk_light_feet_smoke_scale = float(pe.get("light_feet_smoke_scale", perk_light_feet_smoke_scale))

	var sk: Dictionary = d.get("skip", {})
	skip_max_days = int(sk.get("max_days", skip_max_days))
	skip_item_bonus_cap = int(sk.get("item_bonus_cap", skip_item_bonus_cap))

	var h: Dictionary = d.get("homework", {})
	not_done_forgiveness = bool(h.get("not_done_forgiveness", not_done_forgiveness))
	verdict_weight = float(h.get("verdict_weight", verdict_weight))

	var ru: Dictionary = d.get("room_upkeep", {})
	mess_clean_presses = int(ru.get("clean_presses", mess_clean_presses))
	mess_clean_reward = int(ru.get("clean_reward_coins", mess_clean_reward))

	if d.has("items"):
		items = d["items"]
	if d.has("item_order"):
		item_order = d["item_order"]
	if d.has("item_categories"):
		item_categories = d["item_categories"]

	if d.has("age_tiers"):
		age_tiers = d["age_tiers"]
	if d.has("consumables"):
		consumables = d["consumables"]

	var dis: Dictionary = d.get("distraction", {})
	distraction_default_radius = int(dis.get("default_radius", distraction_default_radius))
	distraction_min_radius = int(dis.get("min_radius", distraction_min_radius))
	distraction_max_radius = int(dis.get("max_radius", distraction_max_radius))
	distraction_wall_dampen = int(dis.get("wall_dampen", distraction_wall_dampen))
	distraction_bookcase_dampen = int(dis.get("bookcase_dampen", distraction_bookcase_dampen))
	distraction_desk_dampen = int(dis.get("desk_dampen", distraction_desk_dampen))
	distraction_dampen_range = int(dis.get("dampen_range", distraction_dampen_range))

	var ten: Dictionary = d.get("tenure", {})
	tenure_days_per_level = int(ten.get("days_per_level", tenure_days_per_level))
	tenure_lessons_per_level = int(ten.get("lessons_per_level", tenure_lessons_per_level))
	tenure_resilience_per_level = float(ten.get("resilience_per_level", tenure_resilience_per_level))
	tenure_resilience_cap = float(ten.get("resilience_cap", tenure_resilience_cap))
	tenure_tutor_per_level = float(ten.get("tutor_per_level", tenure_tutor_per_level))
	tenure_tutor_cap = float(ten.get("tutor_cap", tenure_tutor_cap))

	var tr: Dictionary = d.get("tiers", {})
	tier_order = tr.get("order", tier_order)
	tier_captains_max = int(tr.get("captains_max", tier_captains_max))
	tier_pod_reach_tiles = int(tr.get("pod_reach_tiles", tier_pod_reach_tiles))


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
