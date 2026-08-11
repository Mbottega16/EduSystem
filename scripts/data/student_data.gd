class_name StudentData
extends RefCounted

## One student's record.
##
## Deliberately a RefCounted and NOT a Node. Keeping the record off the scene
## tree is what lets grading, homework and a whole simulated term be tested
## headlessly with no scene at all.

## Homework lifecycle. NONE until a lesson assigns it.
enum HW { NONE, ASSIGNED, DONE, NOT_DONE, COLLECTED, MARKED }

## In-lesson classwork: assigned at the podium, worked on, collected from the
## desk, handed in at yours.
enum Work { NONE, WORKING, DONE, COLLECTED }

# --- identity ---------------------------------------------------------
var id: int = 0
var display_name: String = ""
var art: String = "student_a"
var seat_index: int = -1

# --- ability. Two numbers on purpose; resist growing this to four. ----
var aptitude: float = 0.5          ## 0..1 — resistance to getting stuck
var diligence: float = 0.5         ## 0..1 — will they do the homework
## The one subject this student is good at. Gives the day's subject a
## reason to exist beyond being a label.
var favourite: String = ""

# --- per-lesson, reset by reset_lesson() ------------------------------
var work_state: int = Work.NONE
var work_timer: float = 0.0        ## seconds of UNSTUCK work still needed
var confusion: float = 0.0
var helps_received: int = 0        ## for the report; not a grade input

# --- homework, persists across days -----------------------------------
var hw_state: int = HW.NONE
var hw_true_accuracy: float = 0.0  ## hidden from the player
var hw_player_verdict: int = -1    ## -1 unset, 0 "not yet", 1 "got it"
var hw_sheet: Dictionary = {}
## Set when you passed a sheet that did not deserve it. That student is
## secretly behind, so they stall more next lesson — which is exactly what
## the marking screen has always claimed happens.
var misjudged: bool = false

# --- history ----------------------------------------------------------
var grades: Array[float] = []
var last_grade: float = -1.0

var _since_stall: float = 0.0


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
	work_state = Work.NONE
	work_timer = 0.0
	confusion = 0.0
	helps_received = 0
	_since_stall = 0.0


# ---------------------------------------------------------------- work

## Hand them a piece of work. Only a seated student can be given any.
func assign_work() -> bool:
	Balance.ensure_loaded()
	if work_state != Work.NONE:
		return false
	work_state = Work.WORKING
	work_timer = Balance.work_seconds
	_since_stall = 0.0
	confusion = 0.0
	return true


## How much of it they have actually done, 0..1. This is the number the
## grade is built on, which is why helping matters: a stuck student's timer
## is frozen, so their fraction stops rising until you reach them.
func work_fraction() -> float:
	Balance.ensure_loaded()
	if work_state == Work.NONE:
		return 0.0
	if work_state != Work.WORKING:
		return 1.0
	return clampf(1.0 - work_timer / Balance.work_seconds, 0.0, 1.0)


## Advance their work by `delta`. Returns true on the single frame they
## finish, so the caller can react once.
##
## The stall is rolled CONTINUOUSLY rather than scheduled once up front.
## The old version rolled a single stall moment in assign_work and cleared
## it when it fired, so a student could get stuck at most once per lesson —
## which quietly made the teacher's whole contribution a one-shot.
func tick_work(delta: float, rng: RandomNumberGenerator = null) -> bool:
	Balance.ensure_loaded()
	if work_state != Work.WORKING:
		return false
	if is_struggling():
		return false                      # frozen until someone helps

	work_timer -= delta
	if work_timer <= 0.0:
		work_timer = 0.0
		work_state = Work.DONE
		return true

	# a short grace after starting or being helped, so they never stall
	# again the instant you walk away — that reads as the game cheating
	_since_stall += delta
	if rng != null and _since_stall >= Balance.stall_grace_seconds:
		if rng.randf() < stall_chance() * delta:
			confusion = 1.0
			_since_stall = 0.0
	return false


## Per-second chance of getting stuck. Brighter students stall less, and a
## student whose homework you waved through is secretly behind.
func stall_chance() -> float:
	Balance.ensure_loaded()
	var c := Balance.stall_chance_per_second * (1.4 - 0.8 * aptitude)
	if misjudged:
		c *= 1.6
	if favourite != "" and favourite == Game.subject:
		c *= (1.0 - Balance.affinity_bonus)      # on a good day for them
	c *= Game.event_stall_multiplier()
	return c


func has_work_to_collect() -> bool:
	return work_state == Work.DONE


func collect_work() -> bool:
	if work_state != Work.DONE:
		return false
	work_state = Work.COLLECTED
	return true


## Unstick them. Returns false if they were fine, so mashing E at a happy
## student does nothing.
func help() -> bool:
	if not is_struggling():
		return false
	confusion = 0.0
	_since_stall = 0.0
	helps_received += 1
	return true


# ------------------------------------------------------------ homework

func homework_ready_to_mark() -> bool:
	return hw_state == HW.COLLECTED


## Did the player judge this sheet the way it deserved?
func verdict_was_right() -> bool:
	if hw_player_verdict < 0 or hw_sheet.is_empty():
		return false
	return (hw_player_verdict == 1) == Questions.sheet_is_good(hw_sheet)


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "art": art,
		"seat_index": seat_index, "aptitude": aptitude, "diligence": diligence,
		"hw_state": hw_state, "hw_true_accuracy": hw_true_accuracy,
		"hw_player_verdict": hw_player_verdict, "misjudged": misjudged,
		"favourite": favourite,
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
	s.misjudged = bool(d.get("misjudged", false))
	s.favourite = String(d.get("favourite", ""))
	s.last_grade = float(d.get("last_grade", -1.0))
	s.grades.assign(d.get("grades", []))
	return s
