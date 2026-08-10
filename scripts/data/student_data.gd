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

## In-lesson classwork: you assign it at the podium, they work on it, it
## lands on their desk, you walk round and collect it, you carry it to your
## own desk. Separate from HW, which is the overnight cycle.
enum Work { NONE, WORKING, DONE, COLLECTED }

## How long a student takes to finish a piece of assigned work.
const WORK_SECONDS := 5.0

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

# --- assigned classwork ----------------------------------------------
var work_state: int = Work.NONE
var work_timer: float = 0.0        ## seconds left until they finish


## Assign a fresh piece of work. Only a seated student can be given any —
## you can't hand a sheet to someone still walking to their chair.
##
## `stall_chance` is how likely they are to get stuck partway through and
## need you. Rolled once, up front, so the whole lesson is deterministic
## from the seed.
func assign_work(rng: RandomNumberGenerator = null, stall_chance: float = 0.0) -> bool:
	if work_state != Work.NONE:
		return false
	work_state = Work.WORKING
	work_timer = WORK_SECONDS
	_elapsed = 0.0
	_confuse_at = -1.0
	set_confused(false)
	if rng != null and rng.randf() < stall_chance:
		# never on the very first or last moment — both read as a glitch
		_confuse_at = rng.randf_range(WORK_SECONDS * 0.2, WORK_SECONDS * 0.8)
	return true


## Returns true on the frame the work is finished, so the caller can react
## once rather than every frame afterwards.
##
## A confused student's timer is FROZEN — that is the entire pressure of the
## lesson. Reach them and they finish; don't and they never do.
func tick_work(delta: float) -> bool:
	if work_state != Work.WORKING:
		return false
	if is_struggling():
		return false
	_elapsed += delta
	if _confuse_at >= 0.0 and _elapsed >= _confuse_at:
		_confuse_at = -1.0
		set_confused(true)
		return false
	work_timer -= delta
	if work_timer <= 0.0:
		work_timer = 0.0
		work_state = Work.DONE
		return true
	return false


func has_work_to_collect() -> bool:
	return work_state == Work.DONE


func collect_work() -> bool:
	if work_state != Work.DONE:
		return false
	work_state = Work.COLLECTED
	return true


# --- getting stuck, and being helped ----------------------------------
# Confusion FREEZES the work timer. That is the whole pressure of a lesson:
# an unhelped student never finishes, so there is nothing on their desk to
# collect, so they contribute nothing. The thing you can see (a sheet
# appearing) and the thing you're managing (attention) are the same thing.

const ATTENTION_PER_HELP := 0.10
const ATTENTION_CAP := 0.30

var _elapsed: float = 0.0
var _confuse_at: float = -1.0


func set_confused(v: bool) -> void:
	confusion = 1.0 if v else 0.0


## Returns true if this actually helped — so a player mashing E at a student
## who is fine can't farm attention credit.
func help() -> bool:
	if not is_struggling():
		return false
	set_confused(false)
	attention_credit = minf(ATTENTION_CAP, attention_credit + ATTENTION_PER_HELP)
	return true


# --- homework ---------------------------------------------------------
var hw_sheet: Dictionary = {}


func homework_pending() -> bool:
	return hw_state == HW.DONE or hw_state == HW.NOT_DONE


func homework_ready_to_mark() -> bool:
	return hw_state == HW.COLLECTED

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
	work_state = Work.NONE
	work_timer = 0.0


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
