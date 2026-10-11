# EDUSystem — Work Pack: Tiered Learning, Student Dossier & Consumables

This work pack provides the exact code, schemas, and test specs for implementing the 4-tier age system, distraction radius, student level, Minecraft-style dossier, and podium consumable stash.

---

## 1. `data/balance.json` Additions

Add these sections to `data/balance.json`:

```json
  "age_tiers": {
    "elementary": {
      "name": "Elementary School",
      "age_range": "6-10",
      "wander_interval_seconds": 18.0,
      "base_distraction_radius": 2,
      "promotion_graduates_needed": 8,
      "promotion_min_term_grade": 0.70
    },
    "middle": {
      "name": "Middle School",
      "age_range": "11-14",
      "zpd_cluster_bonus": 0.15,
      "base_distraction_radius": 2,
      "promotion_graduates_needed": 8,
      "promotion_min_term_grade": 0.75
    },
    "high": {
      "name": "High School",
      "age_range": "15-18",
      "morning_fatigue_mult": 1.4,
      "base_distraction_radius": 1,
      "promotion_graduates_needed": 8,
      "promotion_min_term_grade": 0.80
    },
    "college": {
      "name": "College / University",
      "age_range": "18-22",
      "seminar_focus_bonus": 0.20,
      "base_distraction_radius": 1,
      "promotion_graduates_needed": 8,
      "promotion_min_term_grade": 0.85
    }
  },
  "consumables": {
    "mint": {
      "name": "Peppermint",
      "description": "Wakes up a sleeping student and prevents napping for 45s.",
      "cost": 5,
      "duration": 45.0,
      "wake_immediate": true,
      "distraction_dampen": 0
    },
    "fidget_cube": {
      "name": "Fidget Cube",
      "description": "Absorbs fidgeting; cuts distraction radius by 1 for 60s.",
      "cost": 8,
      "duration": 60.0,
      "wake_immediate": false,
      "distraction_dampen": 1
    },
    "brain_snack": {
      "name": "Brain Snack",
      "description": "Clears frustration stall immediately and boosts stamina.",
      "cost": 12,
      "duration": 60.0,
      "wake_immediate": true,
      "distraction_dampen": 0
    }
  },
  "distraction": {
    "default_radius": 2,
    "min_radius": 1,
    "max_radius": 3,
    "wall_dampen": 1,
    "bookcase_dampen": 1
  },
  "tenure": {
    "days_per_level": 5,
    "lessons_per_level": 3,
    "resilience_per_level": 0.05
  }
```

---

## 2. `scripts/data/student_data.gd` Extensions

Add the following properties and methods to `StudentData`:

```gdscript
# --- new attributes: distraction, tenure, consumables ---------------
var distraction_radius: int = 2
var days_enrolled: int = 1
var active_consumable: String = ""
var consumable_left: float = 0.0

## Effective student level based on tenure and completed lessons.
func student_level() -> int:
	var lessons_done := transcript.size()
	return 1 + int(days_enrolled / 5) + int(lessons_done / 3)


## Distraction radius accounting for active consumables and trait modifiers.
func effective_distraction_radius() -> int:
	var r := distraction_radius
	if active_consumable == "fidget_cube" and consumable_left > 0.0:
		r = maxi(1, r - 1)
	return r


## Apply a consumable carried from the Supply Stash.
func give_consumable(id: String, duration: float, wake_now: bool = false) -> void:
	active_consumable = id
	consumable_left = duration
	if wake_now and sleeping():
		wake_up(true)


## Decrement consumable timer during active lesson tick.
func tick_consumable(delta: float) -> void:
	if consumable_left > 0.0:
		consumable_left = maxf(0.0, consumable_left - delta)
		if consumable_left <= 0.0:
			active_consumable = ""
```

---

## 3. `scripts/ui/hud.gd` Dossier & Book Implementation

```gdscript
# Minecraft-style inventory dossier constants
const DOSSIER_PAGE_BIO := 0
const DOSSIER_PAGE_BOOK := 1

var _dossier_tab: int = DOSSIER_PAGE_BIO
var _book_page: int = 0
const ASSIGNMENTS_PER_BOOK_PAGE := 4

func show_student_dossier(s: StudentData) -> void:
	if s == null:
		return
	_bio = s
	_open(Mode.STUDENT)
	
	if _dossier_tab == DOSSIER_PAGE_BIO:
		_render_dossier_bio(s)
	else:
		_render_dossier_book(s)


func _render_dossier_bio(s: StudentData) -> void:
	title.text = "%s — Lv.%d Student" % [s.display_name, s.student_level()]
	portrait.texture = load("res://art/portrait_%s.png" % s.art)
	portrait.visible = true
	
	var lines: Array[String] = []
	lines.append("Seat %d · Days Enrolled: %d · Grade Book Pages: %d" % [
		s.seat_index + 1, s.days_enrolled, int(ceil(float(s.transcript.size()) / ASSIGNMENTS_PER_BOOK_PAGE))
	])
	lines.append("Intel: %s · Talk: %s · Sleep: %s" % [
		_pip_bar(s.intelligence_tier(), 4),
		_pip_bar(s.talkativeness, 4),
		_pip_bar(s.sleepiness, 3)
	])
	lines.append("Distraction Radius: %d tiles" % s.effective_distraction_radius())
	if s.active_consumable != "":
		lines.append("Buff: %s (%.0fs left)" % [s.active_consumable.capitalize(), s.consumable_left])
	else:
		lines.append("Buff: None")
	lines.append("")
	lines.append_array(_bio_actions(s))
	body.text = "\n".join(lines)
	hint.text = "Tab: Open Grade Book   E: Action   Esc: Close"


func _render_dossier_book(s: StudentData) -> void:
	var total_pages := maxi(1, int(ceil(float(s.transcript.size()) / ASSIGNMENTS_PER_BOOK_PAGE)))
	_book_page = clampi(_book_page, 0, total_pages - 1)
	
	title.text = "%s's Assignment Book (Page %d/%d)" % [s.first_name(), _book_page + 1, total_pages]
	portrait.visible = false
	
	var lines: Array[String] = []
	var start_idx := _book_page * ASSIGNMENTS_PER_BOOK_PAGE
	var end_idx := mini(start_idx + ASSIGNMENTS_PER_BOOK_PAGE, s.transcript.size())
	
	if s.transcript.is_empty():
		lines.append("No assignments graded yet.")
	else:
		for i in range(start_idx, end_idx):
			var entry: Dictionary = s.transcript[i]
			var l_name: String = entry.get("name", "Lesson")
			var grade_val: float = float(entry.get("grade", 0.0))
			var letter: String = _book_letter(grade_val)
			var day_num: int = int(entry.get("day", 1))
			lines.append("Day %2d: %-18s [%s]" % [day_num, l_name, letter])
	
	body.text = "\n".join(lines)
	hint.text = "Left/Right: Flip Pages   Tab: Back to Bio   Esc: Close"
```

---

## 4. Test Verification Suite Skeleton (`tests/run.gd`)

Add a dedicated test block in `tests/run.gd`:

```gdscript
func test_tiered_learning() -> void:
	section("TIERED LEARNING & STUDENT DOSSIER")
	
	var s := StudentData.new()
	s.days_enrolled = 12
	s.transcript = [
		{"name": "Math 1", "grade": 0.85, "day": 1},
		{"name": "Math 2", "grade": 0.90, "day": 2},
		{"name": "Math 3", "grade": 0.88, "day": 3},
		{"name": "Math 4", "grade": 0.92, "day": 4},
		{"name": "Math 5", "grade": 0.95, "day": 5},
		{"name": "Math 6", "grade": 0.91, "day": 6},
	]
	
	# Level = 1 + int(12/5) + int(6/3) = 1 + 2 + 2 = 5
	assert_eq(s.student_level(), 5, "student level scales with days and assignments")
	
	s.distraction_radius = 2
	assert_eq(s.effective_distraction_radius(), 2, "base distraction radius is 2")
	
	s.give_consumable("fidget_cube", 30.0)
	assert_eq(s.effective_distraction_radius(), 1, "fidget cube reduces distraction radius by 1")
	
	s.tick_consumable(35.0)
	assert_eq(s.effective_distraction_radius(), 2, "consumable expires after duration")
```
