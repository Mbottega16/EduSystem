class_name StudentData
extends RefCounted

## One student's record.
##
## Deliberately a RefCounted and NOT a Node. Keeping the record off the scene
## tree is what lets grading and homework be tested headlessly with no scene
## at all — the student node reads from this, it never becomes the place a
## fact lives.

## Homework lifecycle. NONE until a lesson assigns it.
enum HW { NONE, ASSIGNED, DONE, NOT_DONE, COLLECTED, MARKED }

# --- identity ---------------------------------------------------------
var id: int = 0
var display_name: String = ""
var art: String = "student_a"      ## which generated sheet in art/
var seat_index: int = -1           ## -1 = not enrolled in a seat

# --- ability. Two numbers on purpose; resist growing this to four. ----
var aptitude: float = 0.5          ## 0..1 — how fast understanding accrues
var diligence: float = 0.5         ## 0..1 — will they actually do the homework

# --- per-lesson, reset by reset_lesson() ------------------------------
var understanding: float = 0.0     ## 0..1, accrues while a lesson runs
var confusion: float = 0.0         ## 0..1, rises on a snag and gates the above
var attention_credit: float = 0.0  ## 0..ATTENTION_CAP, earned only by being helped

# --- homework, persists across days -----------------------------------
var hw_state: int = HW.NONE
var hw_true_accuracy: float = 0.0  ## hidden from the player
var hw_player_verdict: int = -1    ## -1 unset, 0 "not yet", 1 "got it"

# --- history ----------------------------------------------------------
var grades: Array[float] = []
var last_grade: float = -1.0


## Derived, never stored — a stored copy would drift the moment confusion moves.
func is_struggling() -> bool:
	return confusion > 0.5


func average_grade() -> float:
	if grades.is_empty():
		return 0.0
	var total := 0.0
	for g: float in grades:
		total += g
	return total / float(grades.size())


func reset_lesson() -> void:
	understanding = 0.0
	confusion = 0.0
	attention_credit = 0.0


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "art": art,
		"seat_index": seat_index, "aptitude": aptitude, "diligence": diligence,
		"hw_state": hw_state, "hw_true_accuracy": hw_true_accuracy,
		"hw_player_verdict": hw_player_verdict,
		"grades": grades, "last_grade": last_grade,
	}


static func from_dict(d: Dictionary) -> StudentData:
	var s := StudentData.new()
	s.id = int(d.get("id", 0))
	s.display_name = String(d.get("display_name", ""))
	s.art = String(d.get("art", "student_a"))
	s.seat_index = int(d.get("seat_index", -1))
	s.aptitude = float(d.get("aptitude", 0.5))
	s.diligence = float(d.get("diligence", 0.5))
	s.hw_state = int(d.get("hw_state", HW.NONE))
	s.hw_true_accuracy = float(d.get("hw_true_accuracy", 0.0))
	s.hw_player_verdict = int(d.get("hw_player_verdict", -1))
	s.last_grade = float(d.get("last_grade", -1.0))
	s.grades.assign(d.get("grades", []))
	return s
