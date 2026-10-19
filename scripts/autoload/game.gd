extends Node

## The mutable run: day, coins, phase, roster. Registered as the `Game`
## autoload.
##
## EVERY random decision in the game goes through `rng`, which is seeded.
## Retrofitting determinism later is miserable, and without it none of the
## interesting tests — grading balance, homework distribution — can exist at
## all. Never call the global randi()/randf() anywhere in this project.

## The school day is a small state machine, and every verb in the game is
## gated on it. That single rule is what keeps the day coherent.
enum Phase {
	MORNING,    ## students filing in; no lesson yet
	LESSON,     ## class is working; the teacher circulates
	AFTERNOON,  ## lesson over, day not yet ended
}

const SAVE_PATH := "user://edusystem_save.json"

## Written once, next to the save, after a pre-rename save has been carried
## across. Its presence is what stops the migration below running every boot.
const MIGRATION_SENTINEL := "user://.migrated_from_pixelroom"

## Where this process saves.
##
## A var, not the const, because advance_day() autosaves -- so the test
## suite and the term simulator, both of which advance hundreds of days,
## were quietly overwriting the player's real save every time they ran. A
## dev tool must never be able to destroy the thing it is meant to be
## testing. Both point this somewhere else.
var save_path: String = SAVE_PATH

signal phase_changed(phase: int)
signal day_changed(day: int)
signal coins_changed(coins: int)
signal roster_changed()
signal room_changed()
signal lesson_unlocked(lesson_id: String)
## A brand new run has begun. The HUD listens so that no screen from the
## previous run is left hanging over the new one -- a report about a class
## that no longer exists is worse than no report.
signal run_started()

var day: int = 1
var coins: int = 0
var phase: int = Phase.MORNING
var roster: Array[StudentData] = []
var owned_lessons: Array = []
var room_items: Array = []      ## [{id: String, tile: Vector2i}]
var homework_out: bool = false  ## is there homework due back tomorrow?
var subject: String = ""        ## today's lesson NAME, for display
var lesson: Dictionary = {}     ## the full curriculum entry behind it
var event: Dictionary = {}      ## what makes today different from yesterday
## Flare-ups started so far today, against Balance.flare_max_per_day. Reset
## every morning -- a bad-luck run should not be able to bury you. The
## counting and the spawning live in classroom.gd (_tick_flares), since a
## flare is a thing in the room you walk to, not a fact about the roster;
## day boundaries are Game's though, so the tally sits here.
var _flares_today: int = 0

## Consecutive "none" days rolled so far, for DayEvent.roll()'s spread
## guarantee (ten-commits.md step 5). Not saved, same as the other
## day-scoped tallies here -- a reload losing count of a running streak
## is not worth persisting a field for.
var _none_streak: int = 0

## A pending desk interruption (phone call / parent conference) -- empty
## when nothing is waiting. Counted and ticked the same way flares are:
## classroom.gd owns the countdown (a thing in the room), Game owns the
## per-lesson tally. Neither is saved -- lesson-scoped transient state,
## same as lesson_left.
var interruption: Dictionary = {}
## Which seated child is the one standing at your desk, for a complication
## whose `speaker` is "student". Picked through `rng` when the row spawns,
## so a seed replays the same child asking the same thing.
var interruption_student_id: int = -1

## A stretch of quicker feet, won by answering someone at your desk well.
## Transient like `interruption` and `fight`: it is never saved, and the
## bell ends it. Deliberately a TEACHER-PACE boost and nothing else -- a
## reward that moved a child's grade would move the balance contract, and
## the contract is the one thing in this game that must not drift.
var boost_left: float = 0.0
signal boost_changed(seconds_left: float)
var _complications_today: int = 0

## The end-of-session bell rush -- OFF unless Balance.bell_rush_enabled (it
## belongs to a later stage of the game). Seconds left on the round, 0 when
## not running; and which seats have had their marked work handed back.
var bell_rush_left: float = 0.0
var _bell_rush_done: Dictionary = {}
@warning_ignore("unused_signal")
signal bell_rush_changed(seconds_left: float)
@warning_ignore("unused_signal")
signal bell_rush_finished(completed: bool)
var term_over: bool = false
## Which term this is. A run is not one term any more -- it is as many as
## you keep teaching, and everything you built carries into the next.
var term: int = 1
## One row per finished term: [{term, letter, passed, total, moved_up}]
var term_history: Array = []
## The run ended because a term was missed. Distinct from term_over, which
## only means the exam has been sat.
var run_over: bool = false

## Milestones already announced. Named things to aim at in a game that never
## ends -- see scripts/data/milestones.gd for why an endless game needs them.
## They gate nothing and pay nothing: the moment is the reward.
var milestones: Array = []

signal milestone_earned(ids: Array)


## Check for anything newly earned, announce it, and remember it was told.
## Called at the end of a day, which is the only moment the player is
## reading a screen anyway.
func check_milestones() -> Array:
	var fresh := Milestones.newly_earned(milestones)
	if fresh.is_empty():
		return []
	for id: String in fresh:
		milestones.append(id)
	milestone_earned.emit(fresh)
	return fresh


## Trophies won by beating a roguelike endgame boss -- one per subject
## boss plus the gauntlet, see scripts/data/trophies.gd. Unlike milestones
## these are never derived from ordinary play: next_term()'s boss branch
## calls award_trophy() when the class clears a boss card's target bar.
var trophies: Array = []

signal trophy_earned(id: String)


## Record a boss win. Returns true if this is the first time -- false for
## a repeat or an id with no trophy behind it.
func award_trophy(id: String) -> bool:
	if Trophies.by_id(id).is_empty() or trophies.has(id):
		return false
	trophies.append(id)
	trophy_earned.emit(id)
	return true

signal term_began(term: int)

# --- the boss paper --------------------------------------------------
## The assessment in progress (scripts/data/boss_fight.gd), or null.
## Lesson-scoped and transient, like `interruption`: never saved. The room
## ticks it, the podium starts it, end_boss_fight() closes it.
var fight: BossFight = null
## The last paper's report, for the screen that shows it. Transient.
var fight_report: Dictionary = {}
## Has today's paper been sat? Reset every morning, so quitting between
## the paper and the bell re-offers the paper rather than losing the day.
var fight_done: bool = false

signal fight_started(card: Dictionary)
signal fight_ended(report: Dictionary)


func fight_active() -> bool:
	return fight != null and fight.active()


## Is the paper on offer at the podium this morning? The last day of a
## boss term, before it has been sat.
func boss_fight_today() -> bool:
	Balance.ensure_loaded()
	return String(term_path.get("kind", "")) == "boss" 		and day >= Balance.term_days and phase == Phase.MORNING 		and not fight_done and not term_over


## The podium, on the last morning of a boss term. Replaces the lesson:
## no hand, no work set, no grade for the day. The class sits the paper,
## and the afternoon's exam reads how they held up (StudentData.boss_delta,
## through exam_score_for()).
func start_boss_fight() -> BossFight:
	Balance.ensure_loaded()
	fight = BossFight.new()
	for s: StudentData in roster:
		s.boss_delta = 0.0
		s.reset_lesson()
	fight.start(term_path, roster, rng)
	quiz_done = true            # no quizzing the paper
	quiz_focus = false
	answer_all_cooldown = 0.0   # the panic button comes in fresh
	call_hold = 0.0             # nobody is being taught; there is nothing to hold
	test_active = false
	set_phase(Phase.LESSON)
	fight_started.emit(term_path)
	return fight


## The paper is over. Closes the tally into each child's boss_delta, moves
## the day to the afternoon and hands back the report for the screen.
func end_boss_fight() -> Dictionary:
	if fight == null:
		return {}
	fight_report = fight.finish()
	fight = null
	fight_done = true
	for s: StudentData in roster:
		s.confusion = 0.0
		s.disrupting = false
		s.flare_left = 0.0
	set_phase(Phase.AFTERNOON)
	fight_ended.emit(fight_report)
	return fight_report

# --- the school ------------------------------------------------------
## Rooms you do not stand in. Each has its own children, its own teacher and
## its own furniture, and is resolved every day by RUNNING THE LESSON with
## that teacher's policy -- see scripts/data/room_sim.gd for why it is not a
## formula.
##
## The player's own room is NOT in here. It is the room they are standing
## in, and it is played rather than resolved.
var rooms: Array = []
## Teachers currently looking for work. Redrawn each term.
var applicants: Array = []

## What the school is thought of, 0..100.
##
## The only thing a badly run room actually costs you. Rooms earn more than
## they pay in wages -- the simulator says so -- so without this, opening one
## is free money and staffing it properly is optional. Reputation makes a
## room you cannot run into a liability.
##
## It GATES rather than pays: how many rooms you may open, and how good the
## applicants are. A bonus would just be more money in a game that already
## has enough of it.
var reputation: float = 50.0

signal reputation_changed(value: float)


## A day's worth of reputation, from what every room did today.
##
## Drifts toward the middle on its own, so one glorious term does not carry
## a school forever and one bad week does not sink it. What moves it is the
## gap between what your rooms scored and a pass.
func tick_reputation(room_results: Array) -> void:
	Balance.ensure_loaded()
	var before := reputation
	# your own class counts too -- you are one of the teachers
	var scores: Array[float] = [class_average()]
	for r: Dictionary in room_results:
		scores.append(float(r.get("average", 0.0)))
	var total := 0.0
	for v: float in scores:
		total += v - Balance.exam_pass
	reputation += total * Balance.rep_per_grade_point / float(maxi(1, scores.size()))
	# and back toward the middle, slowly
	reputation += signf(Balance.rep_drift_to - reputation) * Balance.rep_drift
	reputation = clampf(reputation, 0.0, 100.0)
	if not is_equal_approx(before, reputation):
		reputation_changed.emit(reputation)


func nudge_reputation(by: float) -> void:
	Balance.ensure_loaded()
	reputation = clampf(reputation + by, 0.0, 100.0)
	reputation_changed.emit(reputation)


## In words. The player is never shown a decimal.
func reputation_words() -> String:
	if reputation >= 85.0:
		return "outstanding"
	if reputation >= 68.0:
		return "well thought of"
	if reputation >= 45.0:
		return "steady"
	if reputation >= 25.0:
		return "under a cloud"
	if reputation >= Balance.rep_closes_below:
		return "in special measures"
	return "finished"


## How many rooms your standing allows. This is the gate.
func rooms_allowed() -> int:
	Balance.ensure_loaded()
	return 1 + int(floor(reputation / float(maxi(1, Balance.rep_per_room))))


## The school shuts when nobody will send their children to it.
func school_is_finished() -> bool:
	Balance.ensure_loaded()
	return reputation < float(Balance.rep_closes_below)

signal school_changed()


func room_cost() -> int:
	Balance.ensure_loaded()
	return int(round(float(Balance.room_cost)
		* pow(Balance.room_cost_growth, float(rooms.size()))))


func can_open_room() -> bool:
	Balance.ensure_loaded()
	if rooms.size() >= Balance.max_rooms - 1:       # the player holds one
		return false
	# and your standing has to allow it. A school nobody thinks well of is
	# not given another room to run badly.
	return rooms.size() + 1 < rooms_allowed()


## Open a room. It arrives empty and unstaffed -- an unstaffed room teaches
## nobody, which is the cost of opening one you cannot afford to run.
func open_room() -> String:
	Balance.ensure_loaded()
	if not can_open_room():
		if rooms.size() >= Balance.max_rooms - 1:
			return "There is no space for another room."
		return "Your standing will not stretch to another room."
	var cost := room_cost()
	if not spend(cost):
		return "You cannot afford another room."
	var r := {
		"name": "Room %d" % (rooms.size() + 2),
		"teacher": {}, "furniture": 0, "roster": [], "last": {},
	}
	for i in Balance.school_class_size:
		var s := StudentData.new()
		s.id = _next_id
		_next_id += 1
		s.display_name = Names.unique_name(rng, _taken_names())
		s.joined_day = day
		s.art = Names.ART[(s.id - 1) % Names.ART.size()]
		s.aptitude = rng.randf_range(0.25, 0.85)
		s.diligence = rng.randf_range(0.25, 0.85)
		var strands := Curriculum.strands()
		s.favourite = strands[rng.randi_range(0, strands.size() - 1)] 			if not strands.is_empty() else "math"
		s.trait_id = Traits.roll(rng)
		s.seat_index = i
		var bio_rng := RandomNumberGenerator.new()
		bio_rng.seed = int(rng.seed) * 1103515245 + s.id * 12345 + day * 97
		s.roll_bio_scales(bio_rng)
		(r["roster"] as Array).append(s)
	rooms.append(r)
	school_changed.emit()
	return ""


## What a delegated room's furniture is worth to a desk in it.
##
## Bought as a LEVEL rather than placed. Placing furniture is a spatial
## puzzle about range, and that puzzle is only interesting in a room you can
## actually see -- so a room you never enter buys the outcome instead, and
## is honest about doing so.
func room_value(r: Dictionary) -> float:
	Balance.ensure_loaded()
	var step: float = (Balance.room_cap - Balance.room_base) 		/ float(maxi(1, Balance.furniture_steps))
	return Balance.room_base + step * float(int(r.get("furniture", 0)))


func furnish_cost(r: Dictionary) -> int:
	Balance.ensure_loaded()
	return Balance.furniture_step_cost * (int(r.get("furniture", 0)) + 1)


func furnish_room(i: int) -> String:
	Balance.ensure_loaded()
	if i < 0 or i >= rooms.size():
		return "No such room."
	var r: Dictionary = rooms[i]
	if int(r.get("furniture", 0)) >= Balance.furniture_steps:
		return "That room is fully furnished."
	if not spend(furnish_cost(r)):
		return "You cannot afford that."
	r["furniture"] = int(r.get("furniture", 0)) + 1
	school_changed.emit()
	return ""


## Who applies. A well thought-of school attracts better people, which is
## the second thing reputation buys and the reason it is worth defending.
func draw_applicants() -> Array:
	Balance.ensure_loaded()
	applicants = Staff.applicants(rng, Balance.applicant_count,
		reputation / 100.0)
	return applicants


func hire(room_index: int, applicant_index: int) -> String:
	if room_index < 0 or room_index >= rooms.size():
		return "No such room."
	if applicant_index < 0 or applicant_index >= applicants.size():
		return "Nobody by that name."
	var room: Dictionary = rooms[room_index]
	# Used to silently overwrite whoever was already there, for free, with
	# no warning that a room even HAD a teacher -- found while adding
	# fire(): a player could already "fix" a bad hire, just by accident,
	# for nothing, which made a deliberate fire cost meaningless the moment
	# it existed alongside a free back door to the same result.
	if not (room.get("teacher", {}) as Dictionary).is_empty():
		return "Already staffed — let them go first."
	var t: Dictionary = applicants[applicant_index]
	room["teacher"] = t.duplicate()
	applicants.remove_at(applicant_index)
	school_changed.emit()
	return ""


## Undoing a bad hire. Instant, but never free -- Balance.fire_cost is the
## whole reason this is a real decision rather than a reset button: a
## delegated room that stalled out (see room_sim.gd's own honest simulation)
## used to have no recovery at all short of never touching it again for the
## rest of the run. Clears the room back to the same empty-teacher state
## open_room() leaves a brand new one in, so hire() can staff it again the
## normal way.
func fire(room_index: int) -> String:
	Balance.ensure_loaded()
	if room_index < 0 or room_index >= rooms.size():
		return "No such room."
	var r: Dictionary = rooms[room_index]
	if (r.get("teacher", {}) as Dictionary).is_empty():
		return "Nobody there to let go."
	if not spend(Balance.fire_cost):
		return "Can't afford the severance."
	r["teacher"] = {}
	school_changed.emit()
	return ""


## Every delegated room's day, resolved. Called at the bell.
##
## A room with no teacher is not taught: the children sit there and the
## grade is the room alone. That is the cost of opening a room you cannot
## staff, and it is why an empty room is worse than no room.
func resolve_rooms() -> Array:
	Balance.ensure_loaded()
	var out: Array = []
	for r: Dictionary in rooms:
		var teacher: Dictionary = r.get("teacher", {})
		var result: Dictionary = RoomSim.play_day(
			r.get("roster", []), teacher, room_value(r), lesson, rng)
		result["room"] = String(r.get("name", "Room"))
		result["teacher"] = String(teacher.get("name", "")) 			if not teacher.is_empty() else ""
		r["last"] = result
		out.append(result)
	return out


## What the staff cost you, per day.
func wage_bill() -> int:
	var total := 0
	for r: Dictionary in rooms:
		total += int((r.get("teacher", {}) as Dictionary).get("wage", 0))
	return total
var exam_result: Dictionary = {}
## Yesterday's grade split, so the day report can show which way each part
## moved. A number with no yesterday beside it cannot tell you whether what
## you changed helped.
var last_split: Dictionary = {}

## The subject you trained in, as a strand id. Empty until you have chosen.
##
## A lean rather than a cage: your own subject is a step easier and pays
## better, everything else is a step harder, and you can still teach all of
## it. A class that only ever sees one subject learns one subject.
var specialism: String = ""
## Which lesson you have chosen to teach next. Empty means the game picks,
## which is what it always used to do.
var chosen_lesson: String = ""

# --- the paper you set & tier trade-up ---------------------------------
## The three cards drawn at the podium, and the one you picked.
##
## Setting work used to be a formality -- tap the podium, everyone gets the
## same anonymous sheet. Drawing a hand makes the first thing you do each
## morning a decision, and it is the decision the rest of the day is spent
## living with.
var hand: Array = []
var assignment: Dictionary = {}
## The day the paper was set. A paper only pays on its own day.
var assignment_day: int = -1
## Completed/graded assignments banked at the teacher's desk by rarity id
## ("common" -> int, "rare" -> int, ...). Three of a lower tier trade up for
## one of the next tier up.
var graded_bank: Dictionary = {}
## Rarity id queued from the trade-up desk to upgrade the current or next
## assignment set for the class.
var queued_assignment_tier: String = ""

## Prestige: after enough lessons in a subject, one lesson there can be made
## Prestige. A Prestige lesson always offers a Legendary card in its hand.
## `prestige_lessons` is lesson id -> true. `prestige_used` is strand -> how
## many taught lessons of that subject earlier upgrades already spent.
var prestige_lessons: Dictionary = {}
var prestige_used: Dictionary = {}

signal hand_drawn(cards: Array)


## How many times lessons of this subject have been taught this run.
func strand_taught(strand: String) -> int:
	var n := 0
	for l: Dictionary in Curriculum.lessons:
		if String(l.get("strand", "")) == strand:
			n += int(taught.get(String(l.get("id", "")), 0))
	return n


## Taught lessons in this subject that no upgrade has spent yet.
func prestige_progress(strand: String) -> int:
	return maxi(0, strand_taught(strand) - int(prestige_used.get(strand, 0)))


func is_prestige(lesson_id: String) -> bool:
	return bool(prestige_lessons.get(lesson_id, false))


func can_prestige(lesson_id: String) -> bool:
	Balance.ensure_loaded()
	var l := Curriculum.by_id(lesson_id)
	if l.is_empty() or String(l.get("id", "")) != lesson_id:
		return false
	if is_prestige(lesson_id) or int(taught.get(lesson_id, 0)) < 1:
		return false
	return prestige_progress(String(l.get("strand", ""))) >= Balance.assign_prestige_lessons_needed


## Spend the subject's progress to make this lesson Prestige.
func make_prestige(lesson_id: String) -> bool:
	if not can_prestige(lesson_id):
		return false
	var strand := String(Curriculum.by_id(lesson_id).get("strand", ""))
	prestige_used[strand] = int(prestige_used.get(strand, 0)) + Balance.assign_prestige_lessons_needed
	prestige_lessons[lesson_id] = true
	return true


func draw_hand() -> Array:
	hand = Assignments.draw(rng, lesson, Progress.assignment_luck(perk_ranks))
	# A Prestige lesson always has a Legendary on offer. The LAST card, so a
	# queued trade-up (which rewrites the first) cannot overwrite it.
	if is_prestige(String(lesson.get("id", ""))) and not hand.is_empty():
		var top: Dictionary = Assignments.card_for_rarity(
			"legendary", lesson, hand[hand.size() - 1])
		top["prestige"] = true
		hand[hand.size() - 1] = top
	if queued_assignment_tier != "" and not hand.is_empty():
		hand[0] = Assignments.card_for_rarity(queued_assignment_tier, lesson, hand[0])
	hand_drawn.emit(hand)
	return hand


func choose_assignment(i: int) -> Dictionary:
	if i < 0 or i >= hand.size():
		return {}
	assignment = (hand[i] as Dictionary).duplicate()
	assignment_day = day
	if queued_assignment_tier != "" and Assignments.rarity_index(queued_assignment_tier) \
			> Assignments.rarity_index(String(assignment.get("rarity", "common"))):
		assignment = Assignments.card_for_rarity(queued_assignment_tier, lesson, assignment)
	queued_assignment_tier = ""
	hand.clear()
	return assignment


func graded_count(rarity_id: String) -> int:
	return maxi(0, int(graded_bank.get(rarity_id, 0)))


func total_graded_bank() -> int:
	var n := 0
	for r: Dictionary in Assignments.rarities():
		n += graded_count(String(r.get("id", "")))
	return n


func bank_graded_assignment(rarity_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	var rid := rarity_id if rarity_id != "" else "common"
	graded_bank[rid] = graded_count(rid) + count


## Bank any collected homework sheets sitting on the teacher's desk into
## graded_bank and mark them on the students' records so their homework
## grade term and XP still pay out cleanly.
func bank_collected_homework() -> int:
	var banked := 0
	var rid := String(assignment.get("rarity", "common")) if not assignment.is_empty() else "common"
	for s: StudentData in roster:
		if s.homework_ready_to_mark():
			s.hw_player_verdict = 1 if Questions.sheet_is_good(s.hw_sheet) else 0
			s.misjudged = false
			s.hw_state = StudentData.HW.MARKED
			bank_graded_assignment(rid, 1)
			banked += 1
	return banked


## The player's own call on one sheet: a check (`pass_it`) or an X. A check
## banks the sheet at the rarity of the paper that was set. Waving through a
## sheet that did not deserve it marks the child `misjudged`, which is what
## lets a quiz catch a bad marking call before it becomes a bad grade. Returns
## true when the call matched what the sheet deserved.
func mark_sheet(s: StudentData, pass_it: bool) -> bool:
	var good := Questions.sheet_is_good(s.hw_sheet)
	s.hw_player_verdict = 1 if pass_it else 0
	s.misjudged = pass_it and not good
	s.hw_state = StudentData.HW.MARKED
	if pass_it:
		var rid := String(assignment.get("rarity", "common")) if not assignment.is_empty() else "common"
		bank_graded_assignment(rid, 1)
	return pass_it == good


func can_trade_up(rarity_id: String) -> bool:
	Balance.ensure_loaded()
	var next_id := Assignments.next_rarity_id(rarity_id)
	if next_id == "":
		return false
	return graded_count(rarity_id) >= Balance.assign_trade_in_count


## Trade `Balance.assign_trade_in_count` (3) graded assignments of `rarity_id`
## for 1 of the next rarity tier up. Returns the new tier's id, or "".
func trade_up_assignment(rarity_id: String) -> String:
	Balance.ensure_loaded()
	if not can_trade_up(rarity_id):
		return ""
	var next_id := Assignments.next_rarity_id(rarity_id)
	graded_bank[rarity_id] = graded_count(rarity_id) - Balance.assign_trade_in_count
	bank_graded_assignment(next_id, 1)
	return next_id


## Spend 1 banked assignment of `rarity_id` to upgrade the active/next class
## assignment to that tier.
func apply_graded_tier(rarity_id: String) -> bool:
	if graded_count(rarity_id) <= 0:
		return false
	graded_bank[rarity_id] = graded_count(rarity_id) - 1
	queued_assignment_tier = rarity_id
	if not assignment.is_empty():
		assignment = Assignments.card_for_rarity(rarity_id, lesson, assignment)
	if not hand.is_empty():
		hand[0] = Assignments.card_for_rarity(rarity_id, lesson, hand[0])
	return true


## What the paper on the desks is worth, as a multiplier on coins and on the
## experience finishing it gives a child. Never on the grade -- see the note
## in data/balance.json.
func assignment_pay() -> float:
	if assignment.is_empty():
		return 1.0
	return Assignments.pay(String(assignment.get("rarity", "common")))


## The pay that counts today: the paper set on THIS day, else 1.0.
## A paper from an earlier day must not keep paying.
func paper_pay_today() -> float:
	if assignment_day != day:
		return 1.0
	return assignment_pay()


## How long the paper is, 1..5. The LESSON's difficulty says how confusing
## the subject is; the PAPER's says how much of it there is. Keeping them
## apart is what lets an easy subject carry a long project.
func assignment_difficulty() -> int:
	if assignment.is_empty():
		return 3
	return clampi(int(assignment.get("difficulty", 3)), 1, 5)


# --- the teacher's own progression ---------------------------------
var teacher_xp: int = 0
var teacher_level: int = 1
var perk_ranks: Dictionary = {}      ## perk id -> ranks bought
var graduated: Array = []            ## [{name, level, readiness, day}]

## Career-wide memory that OUTLIVES a single run. new_run() rebuilds a run
## from nothing but never touches this; only wipe_everything() clears it.
## The alumni wall and the run-count ratchet both read from here. Every key
## is topped up by _ensure_meta_keys() -- the same forward-compat shape
## from_dict() uses, so a save written before "meta" existed still loads.
var meta: Dictionary = {}

## The default for each meta key. Read-only -- _ensure_meta_keys() copies
## the containers so a caller never mutates this template.
const META_DEFAULTS := {
	"alumni": [],                ## graduate snapshots, appended every graduation, kept across runs
	"best_term": 0,              ## highest term reached in any run
	"runs_finished": 0,          ## runs that ended in run_over -- the ratchet key
	"lifetime_graduated": 0,     ## every child ever sent up, across every run
	"lifetime_milestones": [],   ## milestone ids ever earned, so cross-run beats fire once
	"career_boon": {},           ## small persistent leg-up per finished run (filled in a later slice)
}

# --- the fork at the start of each term ------------------------------
## The drawn-but-not-yet-chosen hand, and the path actually active for
## the CURRENT term (empty dict = every multiplier below reads as 1.0,
## i.e. today's ordinary numbers -- see TermPaths.draw()).
var term_path_hand: Array = []
var term_path: Dictionary = {}

## One factor in Game.lesson_length()'s chain, or complication onset's
## own scaling -- never touches Balance.lesson_seconds itself.
func term_path_multiplier(key: String) -> float:
	return float(term_path.get(key, 1.0))


func complication_density_mult() -> float:
	return term_path_multiplier("density_mult")


## Rolled once, at the moment a new term opens -- see next_term(). Not
## rolled on demand, so the report screen that just closed can hand
## straight off to a hand that's already waiting.
##
## Boss cards (kind:"boss") are folded into the fork pool ONLY on an
## eligible term -- every boss_term_interval-th one -- and excluded on
## every other term, so a boss is a real telegraphed card alongside the
## ordinary Quiet/Ordinary/Busy/Chaotic ones, never a random ambush.
func draw_term_paths() -> Array:
	Balance.ensure_loaded()
	var pool: Array = TermPaths.paths().duplicate()
	if boss_term_eligible():
		pool.append_array(Balance.bosses)
	term_path_hand = TermPaths.draw(rng, Balance.term_path_hand_min, pool)
	return term_path_hand


## Is the CURRENT term one a subject boss can be offered on?
func boss_term_eligible() -> bool:
	Balance.ensure_loaded()
	return Balance.boss_term_interval > 0 \
		and term % Balance.boss_term_interval == 0


func choose_term_path(i: int) -> Dictionary:
	if i < 0 or i >= term_path_hand.size():
		return {}
	term_path = (term_path_hand[i] as Dictionary).duplicate()
	term_path_hand.clear()
	return term_path

## Cosmetics. Purely decorative -- see cosmetics.gd's own note on why
## these are not tunables. "" means none chosen, same convention as
## `specialism` and `chosen_lesson` already use.
var hat_id: String = ""
var background_id: String = ""

## Toggle, on the player's own request (Aug 2026): resolve the lesson you
## are ABOUT to teach -- or the one you are currently standing in -- the
## same honest way a delegated room is, by running RoomSim against your
## OWN roster and OWN room, rather than a formula. It never grades on
## RoomSim's own flat room_value: classroom.gd's run_auto_lesson() lets
## RoomSim decide what happens to the children, then hands off to the
## SAME end_lesson()/grade_class() a manually-played day already uses,
## so a room resolved this way is graded on your actual furniture, not
## a delegated room's abstraction of it.
##
## Deliberately Steady's policy, not Veteran's -- Veteran is the one
## archetype in the game meant to have no hole in it, and a free stand-in
## for the best hired teacher in the game would make playing the lesson
## yourself the WORSE option rather than an equal one. Steady still
## leaves real room for a player who actually walks the floor to beat it.
var auto_teach: bool = false

## Set the moment any cheat is used, and never cleared. Saved, shown on the
## end-of-term screen, and checked by the term simulator, which refuses to
## run on a cheated save -- a balance reading taken after a cheat is a lie.
var cheated: bool = false
var unlimited_coins: bool = false
## Set the first time the office door is used. Its only job is proving
## the "met_principal" milestone from real state, same as every other
## milestone -- see scripts/data/milestones.gd.
var met_principal: bool = false

## Set once the day-one story intro has played. Persisted, unlike the
## smaller narrative beats (first lesson, first room, first hire), which
## reuse hud.gd's own once-per-session `_shown_hints` the same way every
## existing hint already does -- a single throwaway line reappearing after
## a reload is a shrug, the whole opening scene doing it is not.
var intro_seen: bool = false

## Two verbs the mentor teacher unlocks -- the dash and the mass-help
## "answer all". Locked mechanically until then: player.gd's tap-dash and
## answer_all_caller.can_interact() both gate on the matching flag.
##
## GRANDFATHER, the same pattern intro_seen uses: a brand-new career sets
## both false in new_run(); a save written before this feature has no key,
## so from_dict() defaults both to TRUE -- an existing run keeps the verbs
## it has always had rather than losing them to a mentor it never met.
## dash_taught doubles as "has visited the mentor": the first visit always
## teaches the dash, so `not dash_taught` is the same as "not been down the
## hall yet" -- what the day-end nudge and the first-visit dialogue check.
var dash_taught: bool = false
var answer_all_taught: bool = false
## The chain dash -- a dash that reaches a raised hand answers it and leaves
## the next dash ready at once (player.gd's _tick_chain()). Taught by the
## mentor SHOWING it, with her own class, then saying what you saw. NOT
## grandfathered, unlike the two above: a save from before this has the
## dash but has never seen the demonstration, and the demonstration is the
## lesson. from_dict() defaults it false, so the next walk down the hall
## plays it -- the day-end nudge in main.gd points there.
var chain_dash_taught: bool = false
## "Class, class!" -- "Yes, yes!" The call-and-response, the mentor's third
## move (Oct 2026). Taught on the visit AFTER the chain dash, with her own
## class answering her. NOT grandfathered, for the same reason as the chain:
## the demonstration is the lesson, so an older save gets it on its next walk
## down the hall.
var call_response_taught: bool = false

## TUTORIAL CUTSCENES (data/tutorials.json, scripts/ui/tutorial.gd). `tutorials_seen`
## is id -> true, saved with the run and cleared by new_run(). `tutorials_enabled`
## is false everywhere but the real game: main.gd turns it on only when the
## process is a player's (not the suite, a simulator, the walkthrough or a
## screenshot), so a tutorial never holds up a headless run. A test that wants
## one turns it on itself.
var tutorials_enabled: bool = false
var tutorials_seen: Dictionary = {}
## A first-time moment a tutorial may hang on. The HUD listens.
signal tutorial_event(event: String)


func tutorial_seen(id: String) -> bool:
	return bool(tutorials_seen.get(id, false))


func mark_tutorial_seen(id: String) -> void:
	tutorials_seen[id] = true


## Say that `event` has just happened. A no-op unless tutorials are on, and
## the HUD drops it when its tutorial is already seen.
func fire_tutorial(event: String) -> void:
	if tutorials_enabled:
		tutorial_event.emit(event)


## An older save has no `tutorials_seen`. A tutorial counts as seen when the
## save clearly used the feature already, so nobody is taught what they know.
func _tutorials_from_use() -> Dictionary:
	var out := {}
	var kinds := {}
	for e: Dictionary in grade_log:
		kinds[String(e.get("kind", ""))] = true
	if not taught.is_empty():
		out["quiz"] = true
		out["lesson_plans"] = true
	if not graded_bank.is_empty() or term > 1:
		out["homework"] = true
	if kinds.has("test"):
		out["unit_test"] = true
	if not prestige_lessons.is_empty():
		out["prestige"] = true
	if not cabinet.is_empty() or not room_items.is_empty() or expansions > 0:
		out["cabinet"] = true
		out["room_ideas"] = true
	if not exam_picks.is_empty() or not term_history.is_empty():
		out["exam_picks"] = true
	if not desk_items.is_empty():
		out["study_folder"] = true
	if not grade_log.is_empty():
		out["grade_book"] = true
	return out


signal teacher_levelled(level: int)

var rng := RandomNumberGenerator.new()
var _next_id: int = 1


## Starts a run only if one isn't already going. Called explicitly by
## classroom.gd rather than from _ready(): an autoload's _ready() does NOT
## fire under a custom MainLoop (which is how the headless tests run), so
## relying on it would mean the game and the tests initialise differently —
## exactly the divergence that makes a suite stop being trustworthy.
func ensure_run() -> void:
	if not roster.is_empty():
		return
	migrate_legacy_user_files()
	if not load_game():
		new_run()


## Carry a pre-rename save and settings file across the user:// directory
## move that renaming the project (PixelRoom -> EDUSystem) caused. Godot
## builds user:// from config/name, so the old files sit in a sibling
## "PixelRoom" folder the running game can no longer see. Runs once, and
## only for the real game -- a dev tool or the suite redirects save_path,
## and must never reach into the player's real user directory.
func migrate_legacy_user_files() -> void:
	if save_path != SAVE_PATH:
		return
	if FileAccess.file_exists(MIGRATION_SENTINEL):
		return
	var old_dir := OS.get_user_data_dir().get_base_dir().path_join("PixelRoom")
	_migrate_one(old_dir.path_join("pixelroom_save.json"), SAVE_PATH)
	_migrate_one(old_dir.path_join("pixelroom_settings.json"), Settings.PATH)
	var f := FileAccess.open(MIGRATION_SENTINEL, FileAccess.WRITE)
	if f != null:
		f.store_string("carried across from the PixelRoom user directory\n")
		f.close()


## Copy one file from an absolute source path into a user:// destination,
## but only if the destination does not exist yet. Every failure is quiet:
## a missing old file is the normal case, not an error.
func _migrate_one(old_abs: String, new_path: String) -> void:
	if new_path.is_empty() or FileAccess.file_exists(new_path):
		return
	if not FileAccess.file_exists(old_abs):
		return
	var src := FileAccess.open(old_abs, FileAccess.READ)
	if src == null:
		return
	var text := src.get_as_text()
	src.close()
	var dst := FileAccess.open(new_path, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(text)
	dst.close()


## Fill any missing meta key with a fresh copy of its default, in place.
## Never overwrites a value already present -- so it is safe on load, in
## new_run(), and at boot. This is meta's equivalent of from_dict()'s
## per-key .get(default).
func _ensure_meta_keys() -> void:
	for k: String in META_DEFAULTS:
		if not meta.has(k):
			var d: Variant = META_DEFAULTS[k]
			meta[k] = d.duplicate() if (d is Array or d is Dictionary) else d


## A true reset: everything new_run() clears, PLUS the career-wide meta
## block. This is "start over completely" -- the title-screen wipe, a
## deleted save. new_run() on its own is a fresh RUN inside the same
## career and deliberately leaves meta standing.
func wipe_everything() -> void:
	meta.clear()
	_ensure_meta_keys()
	new_run()


func new_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	day = 1
	coins = 0
	phase = Phase.MORNING
	roster.clear()
	room_items.clear()
	cabinet.clear()
	desk_items.clear()
	grade_log.clear()
	desks_in_store = 0
	homework_out = false
	subject = pick_subject()
	event = DayEvent.by_id("none")
	_none_streak = 0
	_flares_today = 0
	interruption = {}
	_complications_today = 0
	# Term 1 has no "new term" report to hand off from (that only exists
	# from next_term() onward), so it never gets a path SCREEN -- but the
	# multipliers themselves must not leak in from whatever the last run
	# ended on. Same leak class the quiz_focus reset below already guards
	# against, just for this var: term 1 of a brand new run reads as
	# ordinary numbers, silently, rather than inheriting a finished run's
	# chaotic_term.
	term_path = {}
	exam_picks.clear()
	term_path_hand.clear()
	bell_rush_left = 0.0
	_bell_rush_done.clear()
	term_over = false
	term = 1
	term_history.clear()
	fight = null
	fight_done = false
	fight_report = {}
	run_over = false
	milestones.clear()
	trophies.clear()
	rooms.clear()
	applicants.clear()
	reputation = float(Balance.rep_start)
	exam_result = {}
	cheated = false
	unlimited_coins = false
	met_principal = false
	intro_seen = false
	dash_taught = false
	answer_all_taught = false
	chain_dash_taught = false
	call_response_taught = false
	tutorials_seen.clear()
	_reset_consumables()
	teacher_xp = 0
	teacher_level = 1
	perk_ranks.clear()
	hat_id = ""
	background_id = ""
	auto_teach = false
	graduated.clear()
	age_tier = 0
	tier_graduates = 0
	captains.clear()
	lesson_progress = 1.0
	set_carried("")
	# meta is NOT cleared here -- it outlives the run. This only tops up a
	# key a mid-upgrade save might be missing, so the block is always whole.
	_ensure_meta_keys()
	taught.clear()
	lesson_crafts.clear()
	pending_craft.clear()
	concepts.clear()
	term_start_concepts = 0
	quiz_done = false
	# and the focus a quiz leaves behind. Without this the buff leaked
	# ACROSS runs: the term simulator quizzes in one policy and then
	# measures the balance contract in another, so a row that should
	# have had no quiz in it was quietly reading 0.69 -> 0.73.
	quiz_focus = false
	answer_all_cooldown = 0.0
	call_cooldown = 0.0
	call_hold = 0.0
	owned_lessons.clear()
	# One owned lesson per strand to start -- gives assignments.gd's
	# draw() something to hand out from turn one instead of an empty
	# owned-lessons list.
	var strands = Curriculum.strands()
	for s in strands:
		var l = Curriculum.pick(rng)
		while String(l.get("strand", "")) != s:
			l = Curriculum.pick(rng)
		var id = String(l.get("id", ""))
		owned_lessons.append(id)
		lesson_unlocked.emit(id)
	attention = 0.0
	teaching = false
	has_aide = false
	_aide_timer = 0.0
	aide_level = 1
	has_janitor = false
	_janitor_timer = 0.0
	janitor_level = 1
	test_active = false
	tested.clear()
	voice = 1.0
	last_inspection = {}
	last_split = {}
	specialism = ""
	chosen_lesson = ""
	hand.clear()
	assignment = {}
	assignment_day = -1
	graded_bank.clear()
	prestige_lessons.clear()
	prestige_used.clear()
	queued_assignment_tier = ""
	_sleep_tick_accum = 0.0
	_zpd_tick_accum = 0.0
	expansions = 0
	Grid.reset_size()
	_next_id = 1
	Layout.reset_seats()      # back to the opening arrangement
	Balance.ensure_loaded()
	coins = Balance.start_coins
	for i in Balance.class_start:
		enrol()
	run_started.emit()
	roster_changed.emit()
	# The room may have been left bigger by the previous run. Grid.reset_size()
	# above puts the NUMBERS back, but the world is still holding the old
	# room's walls and floor until something tells it to rebuild -- and a grid
	# that disagrees with the nodes on screen is the worst of both.
	room_resized.emit()
	room_changed.emit()


## Adds one student and seats them in the lowest free desk. Returns null when
## the room is full.
func enrol() -> StudentData:
	Balance.ensure_loaded()
	if roster.size() >= seat_capacity():
		return null
	var s := StudentData.new()
	s.id = _next_id
	_next_id += 1
	s.display_name = Names.unique_name(rng, _taken_names())
	s.joined_day = day
	s.art = Names.ART[(s.id - 1) % Names.ART.size()]
	s.aptitude = rng.randf_range(0.25, 0.85)
	s.diligence = rng.randf_range(0.25, 0.85)
	var strands := Curriculum.strands()
	s.favourite = strands[rng.randi_range(0, strands.size() - 1)] \
		if not strands.is_empty() else "math"
	s.trait_id = Traits.roll(rng)
	s.seat_index = _lowest_free_seat()
	s.distraction_radius = tier_base_radius()
	var bio_rng := RandomNumberGenerator.new()
	bio_rng.seed = int(rng.seed) * 1103515245 + s.id * 12345 + day * 97
	s.roll_bio_scales(bio_rng)
	roster.append(s)
	roster_changed.emit()
	return s


## Names already in the class, so a new student cannot be handed a first
## name someone is already using. Read from the LIVE roster, so a
## departed student's name frees itself again with no bookkeeping.
func _taken_names() -> Array:
	var out: Array = []
	for s: StudentData in roster:
		out.append(s.display_name)
	return out


## How many children the room can hold: the desks that exist, but never more
## than the class cap. Desks can be moved (and later bought), so the cap is a
## ceiling on enrolment rather than a fact about the room.
## What the next desk costs. Rises with every one you own, so a big class
## is a long-term project rather than a purchase.
func desk_cost() -> int:
	Balance.ensure_loaded()
	var bought: int = maxi(0, Layout.seat_count() - Balance.class_cap)
	return int(round(float(Balance.desk_cost)
		* pow(Balance.desk_cost_growth, float(bought))))


func can_buy_desk() -> bool:
	Balance.ensure_loaded()
	return Layout.seat_count() < Balance.class_hard_cap


## Buy a desk. Returns "" or why not.
##
## The FLOOR is the real cost. A desk needs two free tiles with an aisle
## back to the door, so past a certain point the answer is to buy a bigger
## room -- which is what ties the class size to the room rather than to a
## number in a table.
func buy_desk() -> String:
	Balance.ensure_loaded()
	if not can_buy_desk():
		return "There is no room for another desk."
	var spot := _free_desk_spot()
	if spot.x < 0:
		return "Nowhere to put it. Try a bigger room."
	var cost := desk_cost()
	if not spend(cost):
		return "You cannot afford a desk."
	if Layout.add_seat(spot) < 0:
		add_coins(cost)          # refund; something took the tile
		return "Nowhere to put it."
	room_resized.emit()          # the room rebuilds its desks
	roster_changed.emit()
	return ""


## Somewhere a desk and its chair both fit, leaving the aisles walkable.
func _free_desk_spot() -> Vector2i:
	var taken := {}
	for s: Vector2i in Layout.seats():
		taken[s] = true
		taken[s + Layout.DESK_OFFSET] = true
	for p: Dictionary in room_items:
		for t: Vector2i in Items.footprint(String(p["id"]), p["tile"]):
			taken[t] = true
	for t: Vector2i in [Layout.PODIUM, Layout.BELL, Layout.BOARD]:
		taken[t] = true
	for t: Vector2i in Layout.TEACHER_DESK:
		taken[t] = true
	var floor_rect := Layout.floor_rect()
	# leave the row nearest the door clear so the class can still file in
	for y in range(floor_rect.position.y + 1, floor_rect.end.y - 1):
		for x in range(floor_rect.position.x + 1, floor_rect.end.x):
			var seat := Vector2i(x, y)
			var desk := seat + Layout.DESK_OFFSET
			if taken.has(seat) or taken.has(desk):
				continue
			if not Grid.in_bounds(desk):
				continue
			# AISLES. A desk pair is two tiles tall, so packing them
			# directly under one another fills the room with furniture and
			# no way to walk between it -- 24 desks in the starting room,
			# none of them reachable from the front. Requiring the tile
			# below the desk to be clear forces a walking row between rows,
			# which is what makes FLOOR the real limit on a class rather
			# than a number in a table.
			var below := desk + Layout.DESK_OFFSET
			if taken.has(below):
				continue
			# and a side aisle: no desk immediately to the left, so they go
			# in alternate columns the way a real classroom does. Without
			# this the starting room swallows the entire hard cap and the
			# floor never binds -- the room stops being what limits a class.
			if taken.has(seat + Vector2i(-1, 0)):
				continue
			# AND IT MUST NOT TRAP ANYBODY. Aisle rules are local; whether
			# the room is still walkable is not. Placement has always run
			# this check for bought furniture, and a desk is furniture that
			# a child has to be able to reach -- without it you can buy a
			# desk that walls another one off and the child assigned to it
			# can never sit down.
			if _desk_would_trap(seat):
				continue
			return seat
	return Vector2i(-1, -1)


## Simulate a desk at `seat` on the real grid and check every seat is still
## reachable from the door, then put the grid back.
func _desk_would_trap(seat: Vector2i) -> bool:
	var room := get_tree().get_first_node_in_group("classroom") if is_inside_tree() else null
	if room == null or not room.has_method("student_node"):
		return false          # no world to check against; nothing to trap
	var grid = room.grid
	var desk := seat + Layout.DESK_OFFSET
	var was_seat: int = grid.get_cell(seat)
	var was_desk: int = grid.get_cell(desk)
	grid.set_cell(seat, Grid.Cell.SEAT)
	grid.set_cell(desk, Grid.Cell.BLOCKED)

	var trapped := false
	for i in Layout.seat_count():
		if not grid.reachable(Layout.DOOR, Layout.seat(i)):
			trapped = true
			break
	if not trapped and not grid.reachable(Layout.DOOR, seat):
		trapped = true

	grid.set_cell(seat, was_seat)
	grid.set_cell(desk, was_desk)
	return trapped


func seat_capacity() -> int:
	Balance.ensure_loaded()
	# The DESKS decide, not the table. class_cap is the number you start
	# with; buying more raises it, up to the hard cap.
	return mini(Balance.class_hard_cap, Layout.seat_count())


func _lowest_free_seat() -> int:
	var taken := {}
	for s: StudentData in roster:
		taken[s.seat_index] = true
	for i in seat_capacity():
		if not taken.has(i):
			return i
	return -1


func student_by_id(sid: int) -> StudentData:
	for s: StudentData in roster:
		if s.id == sid:
			return s
	return null


## Whoever is sitting at an ADJACENT desk, read from the live seating.
##
## Orthogonal neighbours only, and it asks the LAYOUT rather than assuming a
## grid of rows -- desks can be moved anywhere now, so "the next one along"
## is no longer a fact about seat_index. Two desks pushed together are
## neighbours; the same two moved apart are not.
func neighbours_of(s: StudentData) -> Array[StudentData]:
	var out: Array[StudentData] = []
	if s == null or s.seat_index < 0:
		return out
	var here: Vector2i = Layout.seat(s.seat_index)
	for other: StudentData in roster:
		if other == s or other.seat_index < 0:
			continue
		var there: Vector2i = Layout.seat(other.seat_index)
		if absi(there.x - here.x) + absi(there.y - here.y) <= 1:
			out.append(other)
	return out


# --- desks that touch get talking ------------------------------------------
#
# The counter to the discovered meta of cramming every desk into the middle
# of the room. It used to be a hidden 12% slowdown for any child with a desk
# beside theirs (cluster_rate_mult(), room.cluster_penalty): real, but
# invisible, and nothing you could do about it once the lesson started. The
# owner asked for the visible version (Oct 2026): sit two children too close
# and they start talking to one another. While they talk neither works; walk
# over and it stops. The cost of crowding is now something on screen.
#
# Pace only. A chat stops a child's work timer exactly the way messing about
# does, and never touches a grade formula. It is ticked by the room
# (classroom._physics_process) and never by tools/sim.gd, so the contract rows
# cannot see it -- asserted in test_balance()'s source scan.

## A conversation began between these two (a_id started it).
signal chat_started(a_id: int, b_id: int)
## It ended. `why`: "over" (ran its course), "loud" (ran its course and the
## one who started it is messing about now), "hushed" (the teacher came over),
## "called" (Class, class!), "voice" (raised voice, within earshot).
signal chat_ended(a_id: int, b_id: int, why: String)


## Who this child could talk to: everyone seated within reach of them, corners
## counting. Read live from the seating, like neighbours_of(), so moving a desk
## changes it at once. Corners count because a staggered block of desks is
## every bit as crammed as a straight row, and the old penalty, which only
## looked along the row, let it through. The reach is Balance.chat_reach_tiles
## at the default distraction radius and moves a tile for each step of either
## child's radius above or below it -- see pair_reach().
func chat_partners(s: StudentData) -> Array[StudentData]:
	Balance.ensure_loaded()
	var out: Array[StudentData] = []
	if s == null or s.seat_index < 0:
		return out
	var here: Vector2i = Layout.seat(s.seat_index)
	var damp := _dampeners()
	var mine := _radius_with(s, damp)
	var ceiling := Balance.chat_reach_tiles \
		+ maxi(0, Balance.distraction_max_radius - Balance.distraction_default_radius)
	for other: StudentData in roster:
		if other == s or other.seat_index < 0:
			continue
		var there: Vector2i = Layout.seat(other.seat_index)
		var dist := maxi(absi(there.x - here.x), absi(there.y - here.y))
		if dist > ceiling:
			continue
		if dist <= pair_reach(mine, _radius_with(other, damp)):
			out.append(other)
	return out


# --- distraction radius -----------------------------------------------------
#
# How far a child's whispering carries (learning-system-plan.md). The radius
# is a per-child number between Balance.distraction_min_radius and
# _max_radius whose DEFAULT is today's behaviour exactly: desks that touch get
# talking. Each step above or below the default moves the reach by one tile.
# What shrinks it: a fidget cube in their pocket (StudentData), a pencil caddy
# on their desk, and a bookcase or divider standing near their seat. What sets
# it to begin with: their school's age tier (tier_base_radius()).
#
# Room-only, like the chat it feeds: never read by tools/sim.gd.

## The reach, in tiles, between two children whose radii are `ra` and `rb`.
## A narrowed child screens the pair (the narrowest wins, the way a study
## folder does); when neither is narrowed the wider of the two decides, so one
## loud child can reach across an aisle.
func pair_reach(ra: int, rb: int) -> int:
	var base := Balance.distraction_default_radius
	var da := ra - base
	var db := rb - base
	var d := mini(da, db)
	if d >= 0:
		d = maxi(da, db)
	return maxi(0, Balance.chat_reach_tiles + d)


## The placed items that muffle whispering, with their footprints worked out
## once so a loop over the whole class does not redo it per child.
func _dampeners() -> Array:
	var out: Array = []
	for placed: Dictionary in room_items:
		var def := Items.get_def(String(placed.get("id", "")))
		var amount := dampener_amount(def)
		if amount > 0:
			out.append({"amount": amount,
				"tiles": Items.reach_footprint(String(placed["id"]), placed["tile"])})
	return out


## How many steps of radius an item takes off, by its `dampener` kind.
func dampener_amount(def: Dictionary) -> int:
	match String(def.get("dampener", "")):
		"bookcase": return Balance.distraction_bookcase_dampen
		"wall": return Balance.distraction_wall_dampen
		"desk": return Balance.distraction_desk_dampen
	return 0


## What the room and their desk take off this child's radius.
func distraction_dampen_at(s: StudentData) -> int:
	return _dampen_with(s, _dampeners())


func _dampen_with(s: StudentData, damp: Array) -> int:
	if s == null or s.seat_index < 0:
		return 0
	var total := dampener_amount(desk_item_def(s))
	var seat: Vector2i = Layout.seat(s.seat_index)
	for d: Dictionary in damp:
		for t: Vector2i in d["tiles"]:
			if absi(t.x - seat.x) + absi(t.y - seat.y) <= Balance.distraction_dampen_range:
				total += int(d["amount"])
				break
	return total


func _radius_with(s: StudentData, damp: Array) -> int:
	return clampi(s.effective_distraction_radius() - _dampen_with(s, damp),
		Balance.distraction_min_radius, Balance.distraction_max_radius)


## How far this child's whispering carries right now, in steps of radius.
func distraction_radius_of(s: StudentData) -> int:
	Balance.ensure_loaded()
	if s == null:
		return Balance.distraction_default_radius
	return _radius_with(s, _dampeners())


## Sitting close enough to someone to get talking: the warm outline in build
## mode, "too close" on the strip, and a line on the child's file.
func too_close(s: StudentData) -> bool:
	return not chat_partners(s).is_empty()


## How much a child's learning speed is slowed by sitting too close to
## others: reads the highest talkativeness (1..4) among `s` and any
## unscreened chat_partners(s), scaling up to cutting work speed in half
## (1.0 - Balance.chat_talk_max_slowdown = 0.50x) at talk_scale_max (4).
## Returns 1.0 when desks are spaced apart or screened by a study folder.
func talk_proximity_rate_mult(s: StudentData) -> float:
	Balance.ensure_loaded()
	if s == null or s.seat_index < 0 or screened(s):
		return 1.0
	var max_talk := 0
	for other: StudentData in chat_partners(s):
		if screened(other):
			continue
		max_talk = maxi(max_talk, maxi(s.talkativeness, other.talkativeness))
	if max_talk <= 0:
		return 1.0
	var scale_max := float(maxi(1, Balance.chat_talk_scale_max))
	var frac := clampf(float(max_talk) / scale_max, 0.0, 1.0)
	return clampf(1.0 - Balance.chat_talk_max_slowdown * frac, 0.1, 1.0)


## Free to start a conversation right now: seated, a sheet in front of them
## and working at it -- not stuck (they want YOU), not messing about, not
## about to, not already talking, not inside the quiet a broken-up chat
## buys, and not behind a study folder (nobody chats over one).
func can_chat(s: StudentData) -> bool:
	return s != null and s.seat_index >= 0 \
		and s.work_state == StudentData.Work.WORKING \
		and not s.is_struggling() and not s.disrupting and not s.flaring() \
		and not s.chatting() and not s.sleeping() and s.chat_cool <= 0.0 and not screened(s)


## This pair's chance per second of getting talking. A Chatty child doubles
## it; a Shy one halves it.
func chat_chance(a: StudentData, b: StudentData) -> float:
	Balance.ensure_loaded()
	return Balance.chat_start_per_second \
		* Traits.value(a.trait_id, "chat_mult", 1.0) \
		* Traits.value(b.trait_id, "chat_mult", 1.0)


## Is the teacher (standing on `teacher_tile`) close enough to this desk that
## nobody there will chat? A negative tile means nobody is in the room.
func teacher_near(s: StudentData, teacher_tile: Vector2i) -> bool:
	if s == null or s.seat_index < 0 or teacher_tile.x < 0:
		return false
	var seat: Vector2i = Layout.seat(s.seat_index)
	return absi(seat.x - teacher_tile.x) + absi(seat.y - teacher_tile.y) \
		<= Balance.chat_hush_tiles


## One frame of the room's chatter, called by the room during a lesson (never
## a written test, never the boss paper) with the tile the teacher stands on.
## A null rng is a test, which is silent: nobody talks in one.
func tick_chat(delta: float, rng: RandomNumberGenerator, teacher_tile: Vector2i) -> void:
	Balance.ensure_loaded()
	if rng == null:
		return
	for s: StudentData in roster:
		if s.chat_cool > 0.0:
			s.chat_cool = maxf(0.0, s.chat_cool - delta)

	# --- the conversations already going, each pair once (from its lead) ---
	for s: StudentData in roster.duplicate():
		if not s.chatting() or not s.chat_lead:
			continue
		var m := student_by_id(s.chat_with)
		if m == null or m.chat_with != s.id:
			end_chat(s, "over")
		elif s.disrupting or m.disrupting or s.is_struggling() or m.is_struggling() \
				or s.flaring() or m.flaring():
			end_chat(s, "over")             # something louder took over
		elif teacher_near(s, teacher_tile) or teacher_near(m, teacher_tile):
			end_chat(s, "hushed")
		else:
			s.chat_left = maxf(0.0, s.chat_left - delta)
			m.chat_left = s.chat_left
			if s.chat_left <= 0.0:
				# Nobody came. Sometimes that is the end of it, and sometimes
				# it gets loud -- and then it is ordinary messing about, which
				# spreads and wants settling. A veteran is less likely to be
				# the one who kicks off (StudentData.resilience()).
				if rng.randf() < Balance.chat_noise_chance * (1.0 - s.resilience()):
					s.disrupting = true
					end_chat(s, "loud")
				else:
					end_chat(s, "over")

	# --- new ones. Each pair is rolled once a frame, from its lower id. ---
	for s: StudentData in roster:
		if not can_chat(s) or teacher_near(s, teacher_tile):
			continue
		for m: StudentData in chat_partners(s):
			if m.id <= s.id or not can_chat(m) or teacher_near(m, teacher_tile):
				continue
			if rng.randf() < chat_chance(s, m) * delta:
				# The chattier of the two started it.
				var lead := s
				if Traits.value(m.trait_id, "chat_mult", 1.0) \
						> Traits.value(s.trait_id, "chat_mult", 1.0):
					lead = m
				start_chat(lead, m if lead == s else s)
				break


## Get these two talking: `a` started it.
func start_chat(a: StudentData, b: StudentData) -> void:
	Balance.ensure_loaded()
	if a == null or b == null or a == b:
		return
	a.chat_with = b.id
	b.chat_with = a.id
	a.chat_left = Balance.chat_seconds
	b.chat_left = Balance.chat_seconds
	a.chat_lead = true
	b.chat_lead = false
	for c: StudentData in [a, b]:
		if not c.has_moment("got_chatting"):
			c.note_moment("got_chatting", day)
	chat_started.emit(a.id, b.id)


## Stop the conversation `s` is in, both halves of it, and start both on the
## quiet that follows. Returns false if they were not talking.
func end_chat(s: StudentData, why: String) -> bool:
	Balance.ensure_loaded()
	if s == null or not s.chatting():
		return false
	var m := student_by_id(s.chat_with)
	var lead := s if s.chat_lead or m == null else m
	var other := m if lead == s else s
	for c: StudentData in [s, m]:
		if c == null:
			continue
		c.chat_with = -1
		c.chat_left = 0.0
		c.chat_lead = false
		c.chat_cool = Balance.chat_grace_seconds
	chat_ended.emit(lead.id, other.id if other != null else -1, why)
	return true


## Every conversation in the room, stopped at once -- Class, class! Returns
## how many pairs it broke up.
func end_all_chats(why: String) -> int:
	var n := 0
	for s: StudentData in roster.duplicate():
		if s.chatting() and s.chat_lead and end_chat(s, why):
			n += 1
	return n


# --- dozing off at the desk (15-second sleep tick) -------------------------
var _sleep_tick_accum: float = 0.0
signal student_fell_asleep(student_id: int)
signal student_woke_up(student_id: int, why: String)


## Wake every sleeping child in the room (Class, class! or Answer all).
func wake_all_sleeping(why: String = "called") -> int:
	var n := 0
	for s: StudentData in roster:
		if s.sleeping() and s.wake_up(false):
			student_woke_up.emit(s.id, why)
			n += 1
	return n


## Advance active naps and roll once every Balance.sleep_tick_seconds (15s)
## against each working child's sleepiness (1->10%, 2->20%, 3->30%).
func tick_sleep(delta: float, r: RandomNumberGenerator) -> void:
	Balance.ensure_loaded()
	for s: StudentData in roster:
		if not s.sleeping():
			continue
		if s.disrupting or s.flaring():
			s.wake_up(false)
			student_woke_up.emit(s.id, "startled")
			continue
		s.sleeping_left = maxf(0.0, s.sleeping_left - delta)
		if s.sleeping_left <= 0.0:
			student_woke_up.emit(s.id, "rested")
	if r == null:
		return
	_sleep_tick_accum += delta
	var interval := maxf(0.5, Balance.sleep_tick_seconds)
	while _sleep_tick_accum >= interval:
		_sleep_tick_accum -= interval
		for s: StudentData in roster:
			if s.seat_index < 0 or s.work_state != StudentData.Work.WORKING:
				continue
			if s.sleeping() or s.disrupting or s.flaring() or s.chatting() or s.is_struggling():
				continue
			if r.randf() < sleep_chance_for(s):
				if s.fall_asleep():
					student_fell_asleep.emit(s.id)


## The chance this child dozes off on a sleep tick, with everything that eases
## or sharpens it: their own sleepiness (StudentData.sleep_chance()), how long
## they have been here (a veteran sleeps less), the room (a water cooler or a
## standing fan within reach of the desk), a peppermint in the pocket, and a
## high school's early-morning fatigue (tier_sleep_mult()).
func sleep_chance_for(s: StudentData) -> float:
	Balance.ensure_loaded()
	if s == null or s.sleep_proof():
		return 0.0
	return clampf(s.sleep_chance() * (1.0 - s.resilience()) * sleep_room_mult(s)
		* tier_sleep_mult(), 0.0, 1.0)


## The share of their sleep chance that is left once the room has had its say:
## 1.0 in a bare room, never below Balance.sleep_room_mult_floor however many
## items stand about. Each item with a `sleep_dampen` cuts by that share when
## the seat is within the item's own `range`, measured exactly the way
## room_score() measures it.
func sleep_room_mult(s: StudentData) -> float:
	Balance.ensure_loaded()
	if s == null or s.seat_index < 0:
		return 1.0
	var seat: Vector2i = Layout.seat(s.seat_index)
	var mult := 1.0
	for placed: Dictionary in room_items:
		var def := Items.get_def(String(placed.get("id", "")))
		var cut := float(def.get("sleep_dampen", 0.0))
		if cut <= 0.0:
			continue
		var best := 9999
		for t: Vector2i in Items.reach_footprint(String(placed["id"]), placed["tile"]):
			best = mini(best, absi(t.x - seat.x) + absi(t.y - seat.y))
		if best <= int(def.get("range", 0)):
			mult *= (1.0 - cut)
	return maxf(Balance.sleep_room_mult_floor, mult)


## What each child has in their pocket ticks down once a frame during a lesson
## the room is running (not the boss paper, which has its own clock).
func tick_buffs(delta: float) -> void:
	for s: StudentData in roster:
		s.tick_consumable(delta)


# --- Vygotsky ZPD & collaborative roaming ----------------------------------
var _zpd_tick_accum: float = 0.0
signal zpd_paired(roamer_id: int, host_id: int, boosted: bool)
signal zpd_ended(roamer_id: int, host_id: int)


## True when today's assignment or crafted lesson style has students get up,
## walk around, and work together.
func is_collaborative_lesson() -> bool:
	if Assignments.is_collaborative(assignment):
		return true
	var style := craft_style(String(lesson.get("id", "")))
	return style in ["Hands-On", "Discussion", "Game-Based"]


func zpd_competence(s: StudentData) -> float:
	if s == null:
		return 0.0
	return s.aptitude * 0.65 + s.work_fraction() * 0.35


## Vygotsky's Zone of Proximal Development multiplier when `learner` works
## with `peer`. If the competence gap between them sits inside the ZPD
## scaffolding zone [zpd_gap_min, zpd_gap_max], learning speeds up by
## zpd_boost_mult; outside that zone (no scaffold or too far apart), learning
## slows by zpd_mismatch_mult.
func zpd_multiplier_between(learner: StudentData, peer: StudentData) -> float:
	Balance.ensure_loaded()
	if learner == null or peer == null or learner == peer:
		return 1.0
	var gap := absf(zpd_competence(peer) - zpd_competence(learner))
	var mult := Balance.zpd_mismatch_mult
	if gap >= Balance.zpd_gap_min and gap <= Balance.zpd_gap_max:
		mult = Balance.zpd_boost_mult + tier_zpd_bonus(learner, peer)
	return mult + peer_tutoring_bonus(learner, peer)


## Peer tutoring: a classmate who has been here longer shows `learner` the
## ropes. The bonus grows with every level of tenure the peer leads by
## (Balance.tenure_tutor_per_level), up to Balance.tenure_tutor_cap, and is
## nothing when the peer is no further along. It sits on top of the
## scaffolding, so a veteran can turn even a mismatched pair into a useful one.
func peer_tutoring_bonus(learner: StudentData, peer: StudentData) -> float:
	Balance.ensure_loaded()
	if learner == null or peer == null:
		return 0.0
	var lead := peer.student_level() - learner.student_level()
	if lead <= 0:
		return 0.0
	return minf(Balance.tenure_tutor_cap, float(lead) * Balance.tenure_tutor_per_level)


func zpd_multiplier(s: StudentData) -> float:
	if s == null or not s.zpd_active():
		return 1.0
	var peer := student_by_id(s.zpd_partner_id)
	if peer == null:
		return 1.0
	return zpd_multiplier_between(s, peer)


func start_zpd_pair(roamer: StudentData, host: StudentData) -> bool:
	Balance.ensure_loaded()
	if roamer == null or host == null or roamer == host:
		return false
	roamer.zpd_partner_id = host.id
	roamer.zpd_left = Balance.zpd_interact_seconds
	roamer.zpd_roaming = true
	host.zpd_partner_id = roamer.id
	host.zpd_left = Balance.zpd_interact_seconds
	host.zpd_roaming = false
	var boosted := zpd_multiplier_between(roamer, host) > 1.0
	if boosted:
		roamer.add_xp(Balance.zpd_bonus_xp)
		host.add_xp(Balance.zpd_bonus_xp)
	zpd_paired.emit(roamer.id, host.id, boosted)
	return true


func end_zpd_pair(s: StudentData) -> bool:
	if s == null or s.zpd_partner_id < 0:
		return false
	var m := student_by_id(s.zpd_partner_id)
	var roamer_id := s.id if s.zpd_roaming else (m.id if m != null else s.id)
	var host_id := m.id if (m != null and s.zpd_roaming) else s.id
	for c: StudentData in [s, m]:
		if c == null:
			continue
		c.zpd_partner_id = -1
		c.zpd_left = 0.0
		c.zpd_roaming = false
	zpd_ended.emit(roamer_id, host_id)
	return true


func end_all_zpd() -> void:
	for s: StudentData in roster.duplicate():
		if s.zpd_partner_id >= 0:
			end_zpd_pair(s)


func tick_zpd(delta: float, r: RandomNumberGenerator) -> void:
	Balance.ensure_loaded()
	for s: StudentData in roster.duplicate():
		if not s.zpd_active() or not s.zpd_roaming:
			continue
		var m := student_by_id(s.zpd_partner_id)
		if m == null or m.zpd_partner_id != s.id \
				or s.work_state != StudentData.Work.WORKING \
				or m.work_state != StudentData.Work.WORKING \
				or s.disrupting or m.disrupting or s.sleeping() or m.sleeping():
			end_zpd_pair(s)
		else:
			s.zpd_left = maxf(0.0, s.zpd_left - delta)
			m.zpd_left = s.zpd_left
			if s.zpd_left <= 0.0:
				end_zpd_pair(s)
	if not is_collaborative_lesson() or r == null:
		return
	_zpd_tick_accum += delta
	var interval := maxf(0.5, Balance.zpd_roam_interval_seconds)
	while _zpd_tick_accum >= interval:
		_zpd_tick_accum -= interval
		var pool: Array[StudentData] = []
		for s: StudentData in roster:
			if s.seat_index >= 0 and s.work_state == StudentData.Work.WORKING \
					and not s.zpd_active() and not s.sleeping() and not s.disrupting \
					and not s.flaring() and not s.chatting() and not s.is_struggling():
				pool.append(s)
		if pool.size() >= 2:
			var r_idx := r.randi_range(0, pool.size() - 1)
			var roamer := pool[r_idx]
			pool.remove_at(r_idx)
			var h_idx := r.randi_range(0, pool.size() - 1)
			var host := pool[h_idx]
			start_zpd_pair(roamer, host)



## Everything that depends on WHO IS SITTING NEXT TO WHOM, once per frame.
##
## This lives here rather than in tick_work() because it needs the whole
## roster and the seating, and a student's own record deliberately knows
## nothing about the class around it.
##
## Both routes into messing about are things the PLAYER caused. Boredom is
## finished work you never came to collect; frustration is a child left
## stuck too long. Neither is bad luck, so neither feels like one.
func tick_class(delta: float, rng: RandomNumberGenerator) -> void:
	Balance.ensure_loaded()
	if rng == null:
		return                      # a test is silent; nobody plays up
	for s: StudentData in roster:
		if s.seat_index < 0:
			continue
		var mates := neighbours_of(s)

		# --- the good half of a seating plan ---
		# Somebody who has finished helps the desk beside them.
		if s.is_struggling() and not s.disrupting:
			for m: StudentData in mates:
				if m.disrupting:
					continue
				var lift := Traits.value(m.trait_id, "helps_neighbour", 0.0)
				if lift > 0.0 and m.work_fraction() >= 0.999 						and rng.randf() < lift * delta:
					s.help()
					# ten-commits.md step 6: the helper's own moment, not
					# the one who got unstuck -- once, the first time.
					if not m.has_moment("helped_neighbour"):
						m.note_moment("helped_neighbour", day)
					break
				# Nobody copies past a study folder -- theirs or the desk they
				# would be copying from (Game.screened()). They look it up instead.
				if Traits.has_flag(s.trait_id, "copy_from_neighbour") \
						and not screened(s) and not screened(m) \
						and rng.randf() < 0.6 * delta:
					if s.copy_from(m):
						break

		# --- messing about ---
		if s.disrupting:
			continue
		var chance := 0.0
		if s.work_state == StudentData.Work.DONE:
			chance += Balance.dis_boredom          # finished, and ignored
		if s.is_struggling() and s.stuck_seconds() >= Balance.dis_frustration_after:
			chance += Balance.dis_frustration      # left stuck too long
		for m: StudentData in mates:
			if m.disrupting:
				# Iron Will only shrinks how far it TRAVELS -- boredom and
				# frustration above are untouched, so trouble still starts
				# exactly as often as it always did.
				chance += Balance.dis_spread * Progress.disruption_spread_mult(perk_ranks)
		chance *= Traits.value(s.trait_id, "neighbour_stall_mult", 1.0)
		if chance > 0.0 and rng.randf() < chance * delta:
			s.disrupting = true


func student_in_seat(seat: int) -> StudentData:
	for s: StudentData in roster:
		if s.seat_index == seat:
			return s
	return null


# --- the end-of-session bell rush --------------------------------------
# Built and tested, but dormant: start_bell_rush() returns immediately
# unless Balance.bell_rush_enabled. See the bell_rush note in balance.json.
# Coins + XP only -- it never touches grade.

func bell_rush_active() -> bool:
	return bell_rush_left > 0.0


## Seats still owed their marked work back this round.
func bell_rush_pending() -> Array[int]:
	var out: Array[int] = []
	for s: StudentData in roster:
		if s.seat_index >= 0 and not bool(_bell_rush_done.get(s.seat_index, false)):
			out.append(s.seat_index)
	return out


## Kick off the rush, if it is switched on. Called from Classroom.end_lesson().
func start_bell_rush() -> void:
	Balance.ensure_loaded()
	bell_rush_left = 0.0
	_bell_rush_done.clear()
	if not Balance.bell_rush_enabled or phase != Phase.AFTERNOON:
		return
	if bell_rush_pending().is_empty():
		return
	bell_rush_left = Balance.bell_rush_seconds
	bell_rush_changed.emit(bell_rush_left)


## Counts the round down. Driven from Classroom._physics_process in AFTERNOON.
func tick_bell_rush(delta: float) -> void:
	if bell_rush_left <= 0.0:
		return
	bell_rush_left = maxf(0.0, bell_rush_left - delta)
	bell_rush_changed.emit(bell_rush_left)
	if bell_rush_left == 0.0:
		bell_rush_finished.emit(false)          # time ran out -- no bonus


## Hand one desk's work back. XP per desk as you go; the flat coin bonus
## lands only on the desk that completes the set. Returns true on that desk.
func bell_rush_hand_back(seat_index: int) -> bool:
	if bell_rush_left <= 0.0 or bool(_bell_rush_done.get(seat_index, false)):
		return false
	_bell_rush_done[seat_index] = true
	var s := student_in_seat(seat_index)
	if s != null:
		s.add_xp(Balance.bell_rush_xp_per_desk)
	if bell_rush_pending().is_empty():
		add_coins(Balance.bell_rush_reward)
		bell_rush_left = 0.0
		bell_rush_finished.emit(true)
		return true
	return false


## ONE press, ONE consumer.
##
## Several systems poll "interact": the player, the overlays, and placement
## mode. Input.is_action_just_pressed() reports true in BOTH the idle frame
## and the physics tick, so without arbitration a single tap could close a
## menu AND immediately re-trigger whatever the teacher was standing next
## to. Everything now handles input on the physics tick and claims the press
## here; the first claimant in a given tick wins.
var _interact_claim: int = -1

func claim_interact() -> bool:
	return claim_action("interact")


## Keyed by ACTION as well as frame, because there are two buttons now: a
## press of "manage" must not be swallowed because something already claimed
## "interact" on the same tick.
var _claims := {}

func claim_action(action: String) -> bool:
	if not Input.is_action_just_pressed(action):
		return false
	var f := Engine.get_physics_frames()
	if int(_claims.get(action, -1)) == f:
		return false
	_claims[action] = f
	return true


## Today's lesson, drawn from the REAL Maryland standards in
## data/curriculum.json rather than from a list of subject words.
## `subject` stays as the display name because a lot of UI reads it.
func pick_subject() -> String:
	# A CHOICE now, not a dice roll. Today's lesson was rolled at random
	# every morning, which is exactly why the curriculum screen read as
	# inert: it was a list you could not act on.
	if chosen_lesson != "":
		lesson = Curriculum.by_id(chosen_lesson)
		chosen_lesson = ""
	else:
		lesson = Curriculum.pick(rng)
	return String(lesson.get("name", "Lesson"))


## Teaching your own subject pays better.
func lesson_pay_multiplier() -> float:
	Balance.ensure_loaded()
	if specialism == "" or lesson_strand() != specialism:
		return 1.0
	return Balance.spec_coins


## Which strand today's lesson belongs to (math / ela / science /
## social). This also decides which bank tonight's homework comes from,
## so the subject on the board genuinely changes what the sheets ask.
func lesson_strand() -> String:
	return String(lesson.get("strand", "math"))


## How much more (or less) likely a stall is today.
func event_stall_multiplier() -> float:
	return DayEvent.multiplier(event, "stall_mult") * consumable_multiplier("stall_mult")


## Today's lesson length, after the day's event -- and anything bought
## for today -- have had their say.
func lesson_length() -> float:
	Balance.ensure_loaded()
	return Balance.lesson_seconds * DayEvent.multiplier(event, "lesson_mult") \
		* consumable_multiplier("lesson_mult") * term_path_multiplier("lesson_mult") \
		* Progress.lesson_length_mult(perk_ranks)


## THE END OF TERM. Everything you built up gets scored in one sitting: each
## student's own record across the term, plus the room you sat them in. This
## is what a run is FOR — without it the days just keep coming and nothing
## ever resolves.
## What one child scores in the exam: THEIR OWN RECORD, plus a little for
## the room you sat them in.
##
## It used to be average*0.75 + room*0.35, and that counted the room twice --
## room_score is already a term inside every single daily grade. The two
## weights summed to 1.10, corresponded to nothing, and marked down everyone
## whose average was better than 0.39. A child who averaged an A for twenty
## days sat the exam in a bare room and came out with a B, which is not a
## result anybody could explain to themselves.
##
## The room's contribution is normalised to what YOU ADDED (room_score above
## room_base, over the range you can actually buy), so a bare room changes
## nothing at all and a finished one is worth about half a letter.
## The final assessment's lessons: subject (strand) id -> lesson id, one of
## each. Empty until the player has chosen. Cleared when a term closes.
var exam_picks: Dictionary = {}


func exam_picks_complete() -> bool:
	var strands := Curriculum.strands()
	if strands.is_empty():
		return true
	for st: String in strands:
		if String(exam_picks.get(st, "")) == "":
			return false
	return true


## Choose the lesson that stands for one subject on the exam.
func pick_exam_lesson(strand: String, lesson_id: String) -> bool:
	var l := Curriculum.by_id(lesson_id)
	if l.is_empty() or String(l.get("id", "")) != lesson_id \
			or String(l.get("strand", "")) != strand:
		return false
	exam_picks[strand] = lesson_id
	return true


## The lesson in this subject you have taught most (first in the book on a
## tie): where the pick screen starts the cursor.
func best_taught_lesson(strand: String) -> String:
	var best := ""
	var most := -1
	for l: Dictionary in Curriculum.lessons:
		if String(l.get("strand", "")) != strand:
			continue
		var n := int(taught.get(String(l.get("id", "")), 0))
		if n > most:
			most = n
			best = String(l.get("id", ""))
	return best


## How the chosen lessons move one child's paper: a little up for lessons you
## taught well, down for ones you never did, up again in a subject they love.
## Zero until all the picks are in, and never more than exam_pick_swing.
func exam_pick_delta(s: StudentData) -> float:
	if exam_picks.is_empty() or not exam_picks_complete():
		return 0.0
	Balance.ensure_loaded()
	var tot := 0.0
	for st: String in exam_picks:
		var prep := clampf(float(taught.get(String(exam_picks[st]), 0))
			/ float(Balance.exam_pick_taught_full), 0.0, 1.0)
		if s.favourite != "" and s.favourite == st:
			prep += Balance.exam_pick_favourite
		tot += prep
	var mean := tot / float(exam_picks.size())
	return clampf((mean - 0.5) * Balance.exam_pick_swing,
		-Balance.exam_pick_swing, Balance.exam_pick_swing)


func exam_score_for(s: StudentData) -> float:
	Balance.ensure_loaded()
	var span: float = maxf(0.01, Balance.room_cap - Balance.room_base)
	var built: float = clampf(
		(room_score(s.seat_index) - Balance.room_base) / span, 0.0, 1.0)
	# ...plus how they held up on the morning of a boss paper: zero on any
	# ordinary term, and never more than fight.max_swing either way. See
	# BossFight.finish().
	return clampf(s.average_grade() + built * Balance.exam_room_bonus
		+ s.boss_delta + exam_pick_delta(s), 0.0, 1.0)


## How many children have to pass THIS term for you to keep the job.
##
## It rises every term, and it is the only thing in this game you can lose
## to. Without it the room gets better every term against a difficulty that
## never moves, so by the third term nothing you do matters much -- the
## target is what makes a better room necessary rather than merely pleasant.
##
## Capped by the size of the class, because a target nobody could reach is
## not a target, it is an ending with extra steps.
func term_target() -> int:
	Balance.ensure_loaded()
	var want: int = Balance.term_target_base \
		+ Balance.term_target_growth * (term - 1)
	return mini(want, maxi(1, seat_capacity()))


func met_target(passed: int) -> bool:
	return passed >= term_target()


## Close the term and open the next one.
##
## THE POINT OF THIS is that a term is a chapter rather than the whole book.
## Everything you SPENT THE TERM BUILDING carries over -- the room, the
## curriculum you learned to teach, your own level and perks, your coins.
## Taking those away at the bell would make twenty days of building into a
## sandbox you get bored of.
##
## The CLASS does not carry over, and that is the cost. Children who passed
## move up and out; children who did not stay for another go, keeping the
## record they already have. So a term you taught well empties your class of
## exactly the children you got good at teaching.
func next_term() -> Dictionary:
	Balance.ensure_loaded()
	var result := exam_result if not exam_result.is_empty() else sit_exam()
	# The exam goes in the grade book here, where the term is closed -- once,
	# whichever way it was reached -- and before the class moves on.
	log_grades("exam", "Term exam", "", result.get("rows", []))

	# Missing the target ends the RUN. Everything below still happens, so
	# the final screen can say what the term was, but no next term opens.
	var target := term_target()
	# A BOSS TERM is judged differently -- and ONLY differently. It reuses
	# the class AVERAGE the exam above already produced (no new formula --
	# see the source-scan guard in test_boss()), measured against this
	# boss's own `target` bar rather than the seat-count target. Clearing it
	# awards the trophy and unlocks the cosmetic gated on it; missing it is
	# run_over, exactly like missing an ordinary term. The non-boss path
	# below is untouched.
	var hit: bool
	if String(term_path.get("kind", "")) == "boss":
		var bar := float(term_path.get("target", 1.0))
		hit = float(result.get("average", 0.0)) >= bar
		if hit:
			award_trophy(String(term_path.get("trophy_id", "")))
	else:
		hit = met_target(int(result.get("passed", 0)))
	if not hit:
		run_over = true

	# The school moves up a stage when enough children have left it at the
	# bar. promotion_preview() reads the same rule for the Graduation Hall,
	# which is where `captains` were picked.
	var qualified := 0
	for row: Dictionary in result.get("rows", []):
		if _row_qualifies(row):
			qualified += 1
	var promoting := not run_over and not is_top_tier() and qualified > 0 \
		and tier_graduates + qualified >= tier_graduates_needed()
	var captain_names: Array[String] = []

	var moved_up: Array[String] = []
	var stayed: Array[StudentData] = []
	for row: Dictionary in result.get("rows", []):
		var s: StudentData = row["student"]
		# ten-commits.md step 6: reached the bell having never once been
		# stuck. Lifetime, not "just this term" -- moments carry no term
		# marker of their own, and has_moment() already keeps this from
		# firing again once it is true, so a kept-back child who got
		# stuck in an EARLIER term correctly never claims it here either.
		if not s.has_moment("got_stuck") and not s.has_moment("never_stuck"):
			s.note_moment("never_stuck", day)
		if bool(row.get("passed", false)) and Balance.term_pass_moves_up:
			if promoting and captains.has(s.id) and _row_qualifies(row) \
					and captain_names.size() < Balance.tier_captains_max:
				# A cohort captain: stays on into the next stage with their
				# whole record -- bio, level, traits, transcript -- and is
				# not archived to the alumni yet.
				s.note_moment("captain", day)
				captain_names.append(s.display_name)
				stayed.append(s)
			else:
				s.note_moment("graduated", day)
				moved_up.append(s.display_name)
				_add_graduation(s)
		else:
			s.note_moment("kept_back", day)
			stayed.append(s)

	term_history.append({
		"term": term, "letter": String(result.get("letter", "F")),
		"passed": int(result.get("passed", 0)),
		"total": int(result.get("total", 0)),
		"moved_up": moved_up.size(),
		"target": target, "met": hit,
		"boss": String(term_path.get("name", ""))
			if String(term_path.get("kind", "")) == "boss" else "",
	})

	if run_over:
		save_game()
		return {
			"term": term, "moved_up": moved_up, "joined": [],
			"stayed": stayed.size(), "run_over": true,
			"target": target,
			"previous": term_history[term_history.size() - 1],
		}

	# The school moves up a stage, or counts the children who got it closer.
	# Everyone staying on -- the captains and whoever was kept back -- begins
	# the new stage in the new stage's own way of whispering.
	if promoting:
		age_tier += 1
		tier_graduates = 0
		for s: StudentData in stayed:
			s.distraction_radius = tier_base_radius()
	else:
		tier_graduates += qualified
	captains.clear()

	# whoever is left starts the new term with a clean slate but their own
	# history -- the transcript is theirs and it travels
	roster.clear()
	for s: StudentData in stayed:
		s.grades.clear()
		s.last_grade = -1.0
		s.boss_delta = 0.0
		s.reset_lesson()
		s.hw_state = StudentData.HW.NONE
		s.misjudged = false
		roster.append(s)

	term_start_concepts = concepts.size()
	term += 1
	day = 1
	term_over = false
	fight = null
	fight_done = false
	fight_report = {}
	exam_result = {}
	homework_out = false
	quiz_done = false
	answer_all_cooldown = 0.0
	call_cooldown = 0.0
	call_hold = 0.0
	test_active = false
	tested.clear()
	voice = 1.0
	last_inspection = {}
	event = DayEvent.by_id("none")
	_none_streak = 0
	_flares_today = 0
	interruption = {}
	_complications_today = 0
	bell_rush_left = 0.0
	_bell_rush_done.clear()
	subject = pick_subject()

	# fill the empty desks
	var joined: Array[String] = []
	while roster.size() < seat_capacity():
		var s := enrol()
		if s == null:
			break
		joined.append(s.display_name)

	set_phase(Phase.MORNING)
	roster_changed.emit()
	term_began.emit(term)
	# The PokeRogue-style fork: this term's hand, drawn now so it's already
	# waiting the moment the report screen that announces the new term
	# closes -- see hud.gd's show_new_term()/show_term_paths().
	draw_term_paths()
	save_game()
	if promoting:
		tier_promoted.emit(age_tier)
	return {
		"term": term, "moved_up": moved_up, "joined": joined,
		"stayed": stayed.size(), "run_over": false,
		"target": term_target(),
		"previous": term_history[term_history.size() - 1],
		"promoted": promoting, "school": tier_name(), "captains": captain_names,
	}


func sit_exam() -> Dictionary:
	Balance.ensure_loaded()
	var rows: Array = []
	var total := 0.0
	for s: StudentData in roster:
		total += exam_score_for(s)
		var score := exam_score_for(s)
		rows.append({
			"student": s, "score": score, "letter": grade_letter(score),
			"passed": score >= Balance.exam_pass,
		})
	var avg := total / maxf(1.0, float(roster.size()))
	var passed := 0
	for r: Dictionary in rows:
		if bool(r["passed"]):
			passed += 1
	exam_result = {
		"rows": rows, "average": avg, "letter": grade_letter(avg),
		"passed": passed, "total": roster.size(),
	}
	return exam_result


## Award the teacher experience. Returns levels gained, so the caller can
## say something about it.
func add_teacher_xp(amount: int) -> int:
	Balance.ensure_loaded()
	if amount <= 0:
		return 0
	teacher_xp += amount
	var was := teacher_level
	teacher_level = Progress.level_for_xp(teacher_xp)
	if teacher_level > was:
		teacher_levelled.emit(teacher_level)
	return teacher_level - was


func perk_points_spent() -> int:
	var n := 0
	for id: String in perk_ranks:
		n += int(perk_ranks[id])
	return n


func perk_points_free() -> int:
	return Progress.points_for_level(teacher_level) - perk_points_spent()


func perk_rank(id: String) -> int:
	return int(perk_ranks.get(id, 0))


## Spend a point. Returns "" on success or why it was refused.
func buy_perk(id: String) -> String:
	if Progress.perk_def(id).is_empty():
		return "No such thing."
	if perk_rank(id) >= Progress.max_rank(id):
		return "Already at the top of that."
	if perk_points_free() <= 0:
		return "No points to spend. Keep teaching."
	perk_ranks[id] = perk_rank(id) + 1
	return ""


# --- graduation ------------------------------------------------------

## A consistent snapshot of a child who is leaving -- the SAME shape from
## both exit paths (an exam pass in next_term(), or you sending them up
## early in graduate()). Carries their whole record, not just a name and a
## final grade, so the alumni wall can tell their story later. Pure: it
## builds a dict, it appends nowhere.
func graduate_record(s: StudentData) -> Dictionary:
	return {
		"name": s.display_name, "level": s.level,
		"readiness": s.readiness(), "day": day, "term": term, "art": s.art,
		"trait_id": s.trait_id, "aptitude": s.aptitude,
		"favourite": s.favourite, "joined_day": s.joined_day,
		"helps_total": s.helps_total, "best_subject": s.best_subject(),
		"transcript": s.transcript.duplicate(true),
		"moments": s.moments.duplicate(true),
	}


## Record a graduation into BOTH lists: `graduated` (this run -- what the
## end-of-run yearbook reads) and `meta.alumni` (the career -- what the
## alumni wall reads, and it survives new_run()). Returns the `graduated`
## entry, so a caller can tack its own fields on (graduate() adds coins
## and replaced_by).
func _add_graduation(s: StudentData) -> Dictionary:
	var rec := graduate_record(s)
	graduated.append(rec)
	meta.alumni.append(rec.duplicate(true))
	return rec


## Send a child up. YOUR decision -- is_ready_to_graduate() only says they
## could be, and readiness() says how well prepared they would leave.
##
## It pays immediately, in coins and teacher XP, so sending a strong student
## on trades against a thinner class at exam time rather than being a pure
## loss. Without that trade the optimal play would be to never graduate
## anyone, which is not a decision at all.
func graduate(s: StudentData) -> Dictionary:
	Balance.ensure_loaded()
	if s == null or not s.is_ready_to_graduate():
		return {}
	var extra := maxi(0, s.level - Balance.stu_ready_level)
	var coins_won := Balance.grad_base_coins + Balance.grad_coins_per_level * extra
	s.note_moment("graduated", day)
	var record := _add_graduation(s)
	add_coins(coins_won)
	add_teacher_xp(Balance.grad_teacher_xp)
	roster.erase(s)
	roster_changed.emit()
	# their desk frees up, so someone new can have it
	var joined := enrol()
	record["coins"] = coins_won
	record["replaced_by"] = joined.display_name if joined != null else ""
	return record


# --- the school's age tier --------------------------------------------------
#
# learning-system-plan.md: Elementary -> Middle -> High -> College. A run
# begins in the first stage; when enough children have left the class at or
# above the stage's bar, the school moves up (next_term() does it, the
# Graduation & Transfer Hall lets you pick cohort captains first). What a
# stage changes is pace only and read by the room -- the starting radius of a
# new child's whispering, and one flavour each (tier_zpd_bonus(),
# tier_sleep_mult()) -- so the balance contract, measured in the first stage,
# cannot see it.

## Index into Balance.tier_order. Saved; new_run() sends it back to the first.
var age_tier: int = 0
## Children who left this stage's class at or above its term-evaluation bar and
## have not yet been counted into a promotion. Saved.
var tier_graduates: int = 0
## Student ids picked in the Graduation Hall to stay on into the next stage.
## Read and cleared by next_term().
var captains: Array = []
## The lesson clock, 0 at the bell and 1 at the end, kept by the room each
## frame. Only the morning fatigue of a high school reads it.
var lesson_progress: float = 1.0

signal tier_promoted(tier: int)


func tier_count() -> int:
	Balance.ensure_loaded()
	return Balance.tier_order.size()


func is_top_tier() -> bool:
	return age_tier >= tier_count() - 1


## The id of tier `i` (this run's own when -1), clamped into range.
func tier_id(i: int = -1) -> String:
	var n := tier_count()
	if n == 0:
		return ""
	return String(Balance.tier_order[clampi(age_tier if i < 0 else i, 0, n - 1)])


func tier_def(i: int = -1) -> Dictionary:
	return Balance.age_tiers.get(tier_id(i), {})


func tier_name(i: int = -1) -> String:
	return String(tier_def(i).get("name", "School"))


## The distraction radius a child starts with in this stage.
func tier_base_radius() -> int:
	return int(tier_def().get("base_distraction_radius", Balance.distraction_default_radius))


## The term evaluation (0..1) a child must reach to count towards promotion.
func tier_min_grade() -> float:
	return float(tier_def().get("promotion_min_term_grade", 0.0))


func tier_graduates_needed() -> int:
	return maxi(1, int(tier_def().get("promotion_graduates_needed", 8)))


## Would this exam row count towards promotion: passed, would move up, and at
## or above the stage's bar.
func _row_qualifies(row: Dictionary) -> bool:
	return bool(row.get("passed", false)) and Balance.term_pass_moves_up \
		and float(row.get("score", 0.0)) >= tier_min_grade()


## Did the class clear the term? The same rule next_term() applies, read
## without any of its side effects so the Hall can ask first.
func _term_hit(result: Dictionary) -> bool:
	if String(term_path.get("kind", "")) == "boss":
		return float(result.get("average", 0.0)) >= float(term_path.get("target", 1.0))
	return met_target(int(result.get("passed", 0)))


## What closing the exam is about to do to the school, read BEFORE next_term()
## commits to it: {due, candidates, from, to}. `candidates` are the exam rows
## of the children who qualify, the ones that may stay on as captains. Nothing
## here changes anything.
func promotion_preview() -> Dictionary:
	Balance.ensure_loaded()
	var out := {"due": false, "candidates": [], "from": tier_name(), "to": ""}
	if exam_result.is_empty() or is_top_tier() or not _term_hit(exam_result):
		return out
	var rows: Array = []
	for row: Dictionary in exam_result.get("rows", []):
		if _row_qualifies(row):
			rows.append(row)
	if rows.is_empty() or tier_graduates + rows.size() < tier_graduates_needed():
		return out
	out["due"] = true
	out["candidates"] = rows
	out["to"] = tier_name(age_tier + 1)
	return out


## The pace bonus a stage adds to a ZPD pair that is already being scaffolded:
## middle school's pods (desks within Balance.tier_pod_reach_tiles of each
## other) and college's research pairs. Zero in elementary and high school.
func tier_zpd_bonus(learner: StudentData, peer: StudentData) -> float:
	var def := tier_def()
	var bonus := float(def.get("seminar_focus_bonus", 0.0))
	var cluster := float(def.get("zpd_cluster_bonus", 0.0))
	if cluster > 0.0 and learner != null and peer != null \
			and learner.seat_index >= 0 and peer.seat_index >= 0:
		var a: Vector2i = Layout.seat(learner.seat_index)
		var b: Vector2i = Layout.seat(peer.seat_index)
		if maxi(absi(a.x - b.x), absi(a.y - b.y)) <= Balance.tier_pod_reach_tiles:
			bonus += cluster
	return bonus


## A high school is sleepier early in the lesson: the stage's
## morning_fatigue_mult for the first Balance.sleep_morning_window of the
## clock, 1.0 otherwise and in every other stage.
func tier_sleep_mult() -> float:
	var mult := float(tier_def().get("morning_fatigue_mult", 1.0))
	if mult == 1.0 or lesson_progress > Balance.sleep_morning_window:
		return 1.0
	return mult


# --- what you have taught, and what it taught YOU -------------------
## lesson id -> how many times you have taught it.
var taught: Dictionary = {}
## Concept ids you have unlocked, in the order you got them.
var concepts: Array = []
## concepts.size() the moment THIS term began -- knowledge carries across
## terms (see next_term()'s own comment), so "how many did this term add"
## has to be measured from a snapshot, not from zero.
var term_start_concepts: int = 0

signal concepts_learned(ids: Array)


## Is the term on schedule to actually finish its curriculum, or told about
## it if not (ten-commits.md step 3). Measured against concepts unlocked
## SINCE THIS TERM BEGAN -- concepts carry over term to term, so the whole
## curriculum's own total would never once say "on pace" for a single term.
##
## `day_ended` is the day that just finished, BEFORE the caller's own
## `day += 1` -- advance_day() calls this early for exactly that reason.
## record_taught() already ran earlier today, inside grade_class(), so
## `concepts` is fresh rather than one day stale by the time this runs.
func pacing_report(day_ended: int) -> Dictionary:
	Balance.ensure_loaded()
	var earned := concepts.size() - term_start_concepts
	var expected := int(ceil(float(day_ended) * Balance.pace_concepts_per_day))
	return {
		"on_pace": earned >= expected, "earned": earned, "expected": expected,
		"days_left": maxi(0, Balance.term_days - day_ended),
	}


# --- lesson crafting --------------------------------------------------
## lesson id -> {craft_level: int, invested_coins: int, invested_days: int,
## style: String}
var lesson_crafts: Dictionary = {}
## {} when nothing in flight, else {lesson_id: String, days_left: int}.
## Single pending craft at a time -- no queue in this first slice.
var pending_craft: Dictionary = {}

## Cosmetic-only, still: a name the FIRST craft on a lesson gets
## assigned (through Game.rng, so it is as deterministic as everything
## else), so a crafted lesson reads as "Algebra II -- Visual" rather than
## a bare level number -- the naming from the 2026-08-24 vision interview
## ("Algebra II, Visual Lesson, v15"). Every style still runs through the
## SAME craft_work_mult() below; giving each one an actually different
## mechanical hook, and letting the player pick rather than roll one, are
## both real design questions this doc deliberately does not decide (see
## docs/relay/turns/0011-claude.md's NEED FROM YOU, still open).
## Five named styles, each with its own colour, UI treatment and
## asset-naming convention -- see docs/CRAFT_STYLES.md. The colour table
## lives in hud.gd (CRAFT_STYLE_COLOUR), next to STRAND_COLOUR, since it
## is a display concern, not game state.
const CRAFT_STYLES: Array[String] = [
	"Visual", "Hands-On", "Discussion", "Story-Based", "Game-Based",
]


## A flat day-count gate for now (see docs/AUTONOMOUS_TASKLIST.md /
## the vision interview this was built from) -- swappable later without
## touching any UI/save code, since every caller goes through here.
func lesson_crafting_unlocked() -> bool:
	return day >= Balance.craft_unlock_day


## Cost to attempt the NEXT craft level for this lesson (coaching-style
## growing cost: base_cost * cost_growth ^ current_level).
func craft_next_cost(lesson_id: String) -> int:
	var level: int = int(lesson_crafts.get(lesson_id, {}).get("craft_level", 0))
	return int(round(Balance.craft_base_cost * pow(Balance.craft_cost_growth, level)))


## Spend + start a pending craft. False (no state change) if a craft is
## already pending, the lesson id is unknown, or it is unaffordable --
## mirrors buy_desk()'s look-up-cost -> spend -> mutate shape.
func commit_lesson_craft(lesson_id: String) -> bool:
	if not pending_craft.is_empty():
		return false
	if String(Curriculum.by_id(lesson_id).get("id", "")) != lesson_id:
		return false
	var cost := craft_next_cost(lesson_id)
	if not spend(cost):
		return false
	pending_craft = {"lesson_id": lesson_id, "days_left": Balance.craft_days_per_attempt}
	var entry: Dictionary = lesson_crafts.get(lesson_id,
		{"craft_level": 0, "invested_coins": 0, "invested_days": 0, "style": ""}).duplicate()
	entry["invested_coins"] = int(entry.get("invested_coins", 0)) + cost
	if String(entry.get("style", "")) == "":
		entry["style"] = CRAFT_STYLES[rng.randi_range(0, CRAFT_STYLES.size() - 1)]
	lesson_crafts[lesson_id] = entry
	return true


## The style label for a lesson's craft, or "" if it has never been
## crafted. See CRAFT_STYLES above.
func craft_style(lesson_id: String) -> String:
	return String(lesson_crafts.get(lesson_id, {}).get("style", ""))


## Called once per real advance_day() while a craft is in flight. Resolves
## through Game.rng at 0 days left -- the same seeded stream every other
## daily roll uses, so a fixed seed reproduces the same outcome.
##
## Returns {} on an ordinary day. On the day a craft resolves, returns
## {"lesson_id": .., "success": bool} so the caller can put the result on
## that day's own report -- a failed attempt already spent real coins and
## days (Balance.craft_success_chance), and it used to just vanish with no
## announcement either way. Surfacing the feature without saying so when
## it fails would read as a silent loss rather than a fair roll.
func _tick_pending_craft() -> Dictionary:
	if pending_craft.is_empty():
		return {}
	var lesson_id: String = String(pending_craft["lesson_id"])
	var entry: Dictionary = lesson_crafts.get(lesson_id,
		{"craft_level": 0, "invested_coins": 0, "invested_days": 0, "style": ""}).duplicate()
	entry["invested_days"] = int(entry.get("invested_days", 0)) + 1
	lesson_crafts[lesson_id] = entry

	pending_craft["days_left"] = int(pending_craft["days_left"]) - 1
	if int(pending_craft["days_left"]) > 0:
		return {}

	var success := rng.randf() < Balance.craft_success_chance
	if success:
		entry = lesson_crafts[lesson_id].duplicate()
		entry["craft_level"] = int(entry.get("craft_level", 0)) + 1
		lesson_crafts[lesson_id] = entry
	pending_craft = {}
	return {"lesson_id": lesson_id, "success": success}


## [work_length_mult, stall_mult] adjustment from this lesson's craft
## level, clamped so a fully-crafted lesson still cannot push a room past
## what perfect vanilla play could already reach -- see the balance
## contract note in data/balance.json's lesson_crafting section.
func craft_work_mult(lesson_id: String) -> float:
	var level: int = min(int(lesson_crafts.get(lesson_id, {}).get("craft_level", 0)), Balance.craft_level_cap_for_bonus)
	return max(1.0 - level * Balance.craft_work_mult_per_level, Balance.craft_min_work_mult)


func craft_stall_mult(lesson_id: String) -> float:
	var level: int = min(int(lesson_crafts.get(lesson_id, {}).get("craft_level", 0)), Balance.craft_level_cap_for_bonus)
	return max(1.0 - level * Balance.craft_stall_mult_per_level, Balance.craft_min_work_mult)


## Record a lesson as taught and hand back whatever that just unlocked.
##
## THE LESSON FROM EDUSYSTEMS, recorded in its own notes: concepts there
## unlocked a name on a list and changed nothing, which was "the single
## clearest reason the learning system doesn't make sense". So a concept
## here is worth something the moment you have it -- see concept_bonus().
func record_taught(lesson_id: String) -> Array:
	if lesson_id == "":
		return []
	taught[lesson_id] = int(taught.get(lesson_id, 0)) + 1
	var fresh: Array = []
	for cid: String in Curriculum.concepts_unlocked_at(
			lesson_id, int(taught[lesson_id])):
		if not concepts.has(cid):
			concepts.append(cid)
			fresh.append(cid)
	# some furniture teaches a concept just by being in the room
	for extra: String in _item_taught_concepts():
		if not concepts.has(extra):
			concepts.append(extra)
			fresh.append(extra)
	if not fresh.is_empty():
		concepts_learned.emit(fresh)
	return fresh


## Concepts the room itself confers. This is what finally ties the furniture
## you buy to the curriculum: a microscope is not just a grade bonus, it
## puts Earth & Life Science within reach.
func _item_taught_concepts() -> Array[String]:
	var out: Array[String] = []
	for placed: Dictionary in room_items:
		var cid := String(Items.get_def(String(placed.get("id", ""))).get("teaches", ""))
		if cid != "" and not out.has(cid):
			out.append(cid)
	return out



# --- teaching on your own -------------------------------------------
## Hand the room over and let several days run without you.
##
## THE TENSION THIS SITS IN, stated plainly because CLAUDE.md's "legwork,
## not judgement" rule asks for exactly that rather than an assumption:
## `auto_teach` was the one named exception, and it hands ONE lesson to
## RoomSim's Steady policy. This hands several DAYS to the same policy. It
## is the same kind of step -- stepping outside the lesson entirely and
## letting an honest simulation resolve it -- rather than the thing the
## rule still forbids, which is automation pressing buttons while you are
## stood in a lesson you are nominally playing. Built Sept 2026 on explicit
## request, with that distinction named here rather than left implied.
##
## What keeps it a decision rather than a fast-forward button:
##   - RoomSim Steady is a competent stand-in, not you at your best.
##   - No homework is set on a day you were not there to set it, so the
##     marking that lifts a class never happens on a skipped day.
##   - It cannot reach the exam. See skip_days_available().

## The most days you may hand over at once, before the calendar clamps it.
## Balance.skip_max_days plus whatever furniture adds, itself capped so a
## room full of future upgrades can never skip a whole term.
func skip_days_max() -> int:
	Balance.ensure_loaded()
	return Balance.skip_max_days + mini(_item_skip_days(),
		Balance.skip_item_bonus_cap)


## Days added by what is in the room. An item def carrying a "skip_days"
## key contributes it -- the same shape as "teaches", which is how an item
## already grants a concept. Nothing in the table carries one yet: the hook
## exists so raising the cap later is a data edit rather than a code change.
func _item_skip_days() -> int:
	var n := 0
	for placed: Dictionary in room_items:
		n += int(Items.get_def(String(placed.get("id", ""))).get("skip_days", 0))
	return n


## How many days you may actually hand over right now.
##
## Clamped so the run never skips the end of a term. `advance_day()` treats
## `day > Balance.term_days` as the term being over, and the exam and a boss
## day both live at that edge -- letting a skip walk through them would hand
## the one day the game is actually asking about to a policy, and resolve
## the term on a screen nobody saw. Zero means "not now", and the verb is
## not offered.
func skip_days_available() -> int:
	Balance.ensure_loaded()
	if term_over:
		return 0
	return clampi(Balance.term_days - day, 0, skip_days_max())

func knows_concept(cid: String) -> bool:
	return concepts.has(cid)


func times_taught(lesson_id: String) -> int:
	return int(taught.get(lesson_id, 0))


## What everything you have learned to teach is worth, as a grade bonus.
##
## Capped, and small per concept: this is the difference between a teacher in
## their first term and one in their fifth, not a replacement for the room or
## for turning up.
func concept_bonus() -> float:
	Balance.ensure_loaded()
	return minf(Balance.concept_bonus * float(concepts.size()),
		Balance.concept_bonus_cap)


# --- the room itself -------------------------------------------------
## How many times floor space has been bought. Priced off this, so each
## expansion costs more than the last.
var expansions: int = 0

signal room_resized()


## Which way the room can still grow. It only ever grows RIGHT and DOWN:
## the door is a fixed point on the left wall, and everything already placed
## has to keep the coordinates it was placed at.
func can_expand(axis: String) -> bool:
	if axis == "wide":
		return Grid.W < Grid.MAX_W
	return Grid.H < Grid.MAX_H


## What the next column or row costs. Per tile of NEW floor, so a wide room
## charges more for another row than a narrow one -- and rising each time,
## which is what keeps a bigger room an investment rather than a formality.
func expand_cost(axis: String) -> int:
	Balance.ensure_loaded()
	var tiles: int = Grid.H if axis == "wide" else Grid.W
	var base := float(Balance.room_expand_cost_per_tile * tiles)
	return int(round(base * pow(Balance.room_expand_growth, float(expansions))))


## Buy one more column or row. Returns "" on success, or why not.
func expand_room(axis: String) -> String:
	Balance.ensure_loaded()
	if not can_expand(axis):
		return "The room cannot get any bigger than this."
	var cost := expand_cost(axis)
	if not spend(cost):
		return "You cannot afford that."
	if axis == "wide":
		Grid.set_size(Grid.W + 1, Grid.H)
	else:
		Grid.set_size(Grid.W, Grid.H + 1)
	expansions += 1
	room_resized.emit()
	return ""


# --- the end-of-unit test -------------------------------------------
## Is the class sitting a test right now? The single flag that makes the
## room go quiet: no helping, no collecting, no stalls, no quiz.
var test_active: bool = false
## Unit tests given: lesson id -> the day it was sat. Saved. Cleared by
## new_run() and by next_term() (days restart each term). It is what stops
## one lesson being tested every morning, and a retake paying out again.
var tested: Dictionary = {}



## May this unit be tested yet? You have to have actually taught it -- a
## test on something the class has never covered is not a difficulty
## setting, it is just a worse lesson.
func can_test(lesson_id: String) -> bool:
	Balance.ensure_loaded()
	return times_taught(lesson_id) >= Balance.test_requires_taught


## Any unit ready to be tested, for the podium's prompt.
##
## One test a day. Of the units that qualify, a unit never tested comes first;
## once all were tested, the one tested longest ago comes round again.
func testable_lesson() -> Dictionary:
	Curriculum.ensure_loaded()
	for tid: Variant in tested:
		if int(tested[tid]) == day:
			return {}
	var best: Dictionary = {}
	var best_day := 1 << 30
	for l: Dictionary in Curriculum.lessons:
		var lid := String(l.get("id", ""))
		if not can_test(lid):
			continue
		var when: int = int(tested[lid]) if tested.has(lid) else -1
		if when < best_day:
			best_day = when
			best = l
	return best


## What a child scores on the test.
##
## Deliberately NOT the same formula as a lesson. There is no homework term
## -- it is a test -- and no credit for you having collected anything,
## because you are not allowed to. What is left is the room you built, the
## work they can do unaided, and what you know well enough to have taught
## them. That is the whole argument for the instrument existing.
func test_grade_for(s: StudentData) -> float:
	Balance.ensure_loaded()
	return clampf(room_score(s.seat_index)
		+ s.work_fraction() * Balance.test_cap
		+ concept_bonus() * s.work_fraction(), 0.0, 1.0)


## Mark the papers. Worth a row in every child's record, flagged as a test
## so their transcript can tell the two apart.
func grade_test() -> Array:
	Balance.ensure_loaded()
	var out: Array = []
	var drill := String(event.get("id", "")) == "fire_drill"
	for s: StudentData in roster:
		var g := test_grade_for(s)
		s.last_grade = g
		s.grades.append(g)
		s.record_result(lesson, g, day, true)
		if drill and not s.has_moment("fire_drill"):
			s.note_moment("fire_drill", day)
		s.misjudged = false         # their next lesson has ended
		var levels := s.add_xp(Balance.stu_xp_per_lesson + Balance.stu_xp_per_work_done)
		out.append({"student": s, "grade": g, "letter": grade_letter(g),
			"levels": levels})
	if String(lesson.get("id", "")) != "":
		tested[String(lesson.get("id", ""))] = day
	log_grades("test", String(lesson.get("name", "Lesson")), lesson_strand(), out,
		String(lesson.get("id", "")))
	test_active = false
	return out


# --- being inspected --------------------------------------------------
## The last inspection, kept so the class list and the term can refer back
## to it. Empty until one has happened.
var last_inspection: Dictionary = {}


func being_inspected() -> bool:
	return bool(event.get("inspection", false))


## What the inspector made of it.
##
## Three judgements, all computed from things the game ALREADY tracks -- no
## hidden inspection stat, and nothing that was not visible to the player
## while it was happening:
##
##   the room      what the furniture is worth to the desks, against its cap
##   the lesson    how much of the work got done, less what was still going
##                 wrong at the bell
##   the material  whether you know what you are teaching today
##
## It is announced the evening before, so all three are things you can go
## and do something about. An unannounced judgement is weather.
func inspect() -> Dictionary:
	Balance.ensure_loaded()
	var seated := 0
	var room_total := 0.0
	var work_total := 0.0
	var trouble := 0
	for s: StudentData in roster:
		if s.seat_index < 0:
			continue
		seated += 1
		room_total += room_score(s.seat_index)
		work_total += s.work_fraction()
		if s.disrupting or s.is_struggling():
			trouble += 1

	var n := maxf(1.0, float(seated))
	# room_base is what an empty room is worth, so the judgement is what YOU
	# added rather than what the building came with.
	var room := clampf(
		(room_total / n - Balance.room_base)
		/ maxf(0.01, Balance.room_cap - Balance.room_base), 0.0, 1.0)
	var lesson := clampf(work_total / n - float(trouble) / n * 0.5, 0.0, 1.0)

	var lid := String(self.lesson.get("id", ""))
	var concepts_here := Curriculum.concepts_of(lid)
	var known := 0
	for c: Dictionary in concepts_here:
		if knows_concept(String(c.get("id", ""))):
			known += 1
	var knowledge := 0.0 if concepts_here.is_empty() \
		else float(known) / float(concepts_here.size())

	var overall := room * Balance.insp_w_room \
		+ lesson * Balance.insp_w_lesson \
		+ knowledge * Balance.insp_w_knowledge
	var passed := overall >= Balance.insp_pass
	var grant := int(round(float(Balance.insp_grant) * overall)) if passed else 0
	if grant > 0:
		add_coins(grant)

	last_inspection = {
		"day": day, "room": room, "lesson": lesson, "knowledge": knowledge,
		"overall": overall, "letter": grade_letter(overall),
		"passed": passed, "grant": grant,
		"subject": String(self.lesson.get("name", "")),
		"standard": String(self.lesson.get("standard", "")),
	}
	return last_inspection


# --- your voice ------------------------------------------------------
## 0..1. Spent settling the room, and it comes back slowly on its own.
##
## The second resource inside a lesson. Lesson TIME is the first, and the
## interesting decision is between them: crossing the room to have a word
## costs seconds, raising your voice costs this instead and reaches several
## desks at once -- but only the ones near enough to hear you.
var voice: float = 1.0

signal voice_changed(level: float)


func tick_voice(delta: float) -> void:
	Balance.ensure_loaded()
	if voice >= 1.0:
		return
	voice = minf(1.0, voice + Balance.voice_recharge * delta)
	voice_changed.emit(voice)


func can_raise_voice() -> bool:
	Balance.ensure_loaded()
	return phase == Phase.LESSON and not test_active and voice >= Balance.voice_cost


## "Right — settle down." Settles every disruptive child WITHIN EARSHOT of
## `from`, and does nothing whatever for anybody who is merely stuck.
##
## That restriction is the whole design. Settling is crowd control and can
## be done from across a few desks; teaching cannot, so a stuck child still
## needs you to walk over. Returns how many heard you, or -1 if you had no
## voice left.
func raise_voice(from: Vector2i) -> int:
	Balance.ensure_loaded()
	if not can_raise_voice():
		return -1
	voice = maxf(0.0, voice - Balance.voice_cost)
	voice_changed.emit(voice)
	var settled := 0
	var range_tiles: float = Balance.voice_range + Progress.voice_range_bonus(perk_ranks)
	for s: StudentData in roster:
		if s.seat_index < 0:
			continue
		var seat: Vector2i = Layout.seat(s.seat_index)
		if absi(seat.x - from.x) + absi(seat.y - from.y) > range_tiles:
			continue
		# "Right -- settle down" stops a chat within earshot as well. It is not
		# counted: the count is who was messing about, and a chat was not.
		if s.chatting():
			end_chat(s, "voice")
		if s.sleeping() and s.wake_up(false):
			student_woke_up.emit(s.id, "voice")
		if s.disrupting and s.settle():
			settled += 1
	return settled


## Calm Presence, finally wired up: a child sitting near the teacher gets
## stuck less often.
##
## The perk has been on sale since perks existed and did absolutely nothing
## -- Progress.calm_multiplier() had no caller in the whole of scripts/. A
## perk you can spend on that does not work is worse than one that does not
## exist, because you paid for it.
func calm_multiplier_at(seat_index: int) -> float:
	Balance.ensure_loaded()
	if seat_index < 0 or perk_ranks.get("calm_presence", 0) == 0:
		return 1.0
	var room := get_tree().get_first_node_in_group("classroom") if is_inside_tree() else null
	if room == null or room.player == null or not is_instance_valid(room.player):
		return 1.0
	var seat := Grid.tile_to_world(Layout.seat(seat_index))
	if seat.distance_to(room.player.global_position) > Progress.calm_radius(perk_ranks):
		return 1.0
	return Progress.calm_multiplier(perk_ranks)


## Has today's lesson already been interrupted for a quiz? One per lesson:
## the cost is lesson TIME, and without a limit the right play would be to
## run it over and over until everybody had been flagged and resolved.
var quiz_done: bool = false
## The class has been made to think, and is harder to distract for the rest
## of the lesson. Cleared with the lesson, like everything else about it.
var quiz_focus: bool = false

## Seconds until "answer all questions" (the mass-help skill, its own key J)
## can be used again. It pays no grade and no coins -- the cost is a big
## slice of lesson time up front plus this long wait -- so it is a panic
## button, not a substitute for walking the floor. Ticked down by the
## lesson clock in classroom._physics_process; re-armed by start_lesson().
var answer_all_cooldown: float = 0.0

## THE CALL-AND-RESPONSE (key Y, taught by the mentor). "Class, class!" from
## wherever you are standing, and the room answers "Yes, yes!" and turns back
## to you: attention snaps to full and HOLDS -- no decay -- for call_hold
## seconds, wherever you then walk. It is the one verb aimed at the game's
## central squeeze: work only moves while the class is with you, and the
## class is only with you while you are at the front, so every trip to a
## desk costs the room. This buys one trip.
##
## Paid for in VOICE, the same meter settling the room spends ("Right --
## settle down"), so the two compete: call them back, or quiet the noisy
## ones. A cooldown on top stops a full meter buying two holds back to back.
## Pace only: it touches attention, which only ever scales how fast work
## moves -- never a grade term, never a coin -- and tools/sim.gd never calls
## it (a guard in tests/run.gd), so the contract rows cannot see it.
var call_cooldown: float = 0.0
var call_hold: float = 0.0


func can_call_class() -> bool:
	Balance.ensure_loaded()
	return call_response_taught and phase == Phase.LESSON and not test_active \
		and fight == null and call_cooldown <= 0.0 \
		and voice >= Balance.call_voice_cost and not roster.is_empty()


## "Class, class!" Returns true if the room heard it.
func call_the_class() -> bool:
	if not can_call_class():
		return false
	voice = maxf(0.0, voice - Balance.call_voice_cost)
	voice_changed.emit(voice)
	call_cooldown = Balance.call_cooldown_seconds
	call_hold = Balance.call_hold_seconds
	if not is_equal_approx(attention, 1.0):
		attention = 1.0
		attention_changed.emit(attention)
	# Every head turns to you, so every conversation stops mid-sentence.
	end_all_chats("called")
	wake_all_sleeping("called")
	return true

# --- the class's attention -------------------------------------------
## 0..1. Filled by standing at the front and teaching, and it drains when
## you stop. Work advances in proportion to it.
##
## THE POINT: a lesson used to run itself. Students worked whether or not
## the teacher existed, so the entire job was reacting to bubbles and the
## time between them was dead. Now the room needs you at the front, and
## every second spent at one child's desk is a second the other seven are
## not being taught -- which is the trade the whole game is about.
## Have you hired an aide? They collect finished work so you can stay at
## the front. They never help, settle or mark -- collecting is legwork and
## helping is a judgement, and hiring out the judgement would be hiring
## somebody to play the game for you.
var has_aide: bool = false
## Seconds until the aide reaches the next finished desk.
var _aide_timer: float = 0.0
## 1..Balance.staff_level_max. Each level shortens aide_interval() by
## Balance.staff_speedup_per_level, compounding -- see aide_interval().
var aide_level: int = 1

## Have you hired a janitor? Same shape as the aide, one door over: they
## clean the room's own daily mess (mess.gd) for you, one piece per
## interval, any time of day rather than only during a lesson -- mess
## itself isn't lesson-gated, so neither is this.
var has_janitor: bool = false
var _janitor_timer: float = 0.0
var janitor_level: int = 1

# --- consumables -------------------------------------------------------
## A treat for TODAY, bought at the noticeboard rather than placed in the
## room. Furniture is an investment; a consumable is spent the moment you
## buy it, same day, and gone tomorrow -- which is what keeps it cheap and
## keeps buying one a real, repeatable choice rather than a one-off.
##
## Reuses the exact hook vocabulary DayEvent already uses (stall_mult,
## lesson_mult, coin_mult, bonus_coins, homework_sure) rather than
## inventing a second effect system: a consumable and a day event are the
## same kind of thing mechanically, one rolled by the game and one bought
## by the player, and they stack the same way multipliers already do.
var _consumable_mults: Dictionary = {}
var consumable_bonus_coins: int = 0
var _consumable_homework_sure: bool = false
## What you actually bought today, for the evening report to name.
var consumables_used_today: Array = []


func consumable_multiplier(key: String) -> float:
	return float(_consumable_mults.get(key, 1.0))


## Buy and use, in the same motion -- there is no inventory to manage,
## which is the whole point: it is a decision about today, not a stockpile.
func use_consumable(id: String) -> String:
	Balance.ensure_loaded()
	var d := Items.get_def(id)
	if d.is_empty() or String(d.get("cat", "")) != "consumable":
		return "That is not something you can use today."
	if not spend(shop_price(id)):
		return "You cannot afford that."
	var effect: Dictionary = d.get("effect", {})
	for key: String in effect:
		var v = effect[key]
		if key == "bonus_coins":
			consumable_bonus_coins += int(v)
		elif key == "homework_sure":
			_consumable_homework_sure = _consumable_homework_sure or bool(v)
		else:
			_consumable_mults[key] = float(_consumable_mults.get(key, 1.0)) * float(v)
	consumables_used_today.append(String(d.get("name", id)))
	return ""


func _reset_consumables() -> void:
	_consumable_mults.clear()
	consumable_bonus_coins = 0
	_consumable_homework_sure = false
	consumables_used_today.clear()


# --- the supply stash: treats carried from the shelf to a desk -----------
#
# learning-system-plan.md: "no magical hotbars" -- you walk to the supply
# cupboard (the back-wall cabinet), take a treat, walk to a child's desk and
# hand it over. The treats are
# Balance.consumables (a peppermint, a fidget cube, a brain snack); what each
# does lives in balance.json and in StudentData (wake, sleep-proof, a smaller
# radius, a stall cleared). Taking one is free and can be put back; it is
# paid for when it is handed over. Pace only -- never graded, never ticked by
# tools/sim.gd, and never offered mid-test or mid-paper.

## The id of the treat in your hands, or "". Not saved: a lesson is the only
## place it means anything, and it goes when the lesson does.
var carried: String = ""

signal carried_changed(id: String)
signal treat_given(student_id: int, id: String)


## The treats on the stash, in the order the cupboard offers them.
func stash_ids() -> Array:
	Balance.ensure_loaded()
	return Balance.consumables.keys()


func treat_name(id: String) -> String:
	Balance.ensure_loaded()
	return String(Balance.consumables.get(id, {}).get("name", id)).to_lower()


func treat_cost(id: String) -> int:
	Balance.ensure_loaded()
	return int(Balance.consumables.get(id, {}).get("cost", 0))


## The stash and the desks answer only in a lesson you are teaching.
func treats_available() -> bool:
	return phase == Phase.LESSON and not test_active and not fight_active() \
		and not stash_ids().is_empty()


func set_carried(id: String) -> void:
	if id == carried:
		return
	carried = id
	carried_changed.emit(id)


## One press at the cupboard: empty hands take the first treat, a held one is
## swapped for the next, and after the last you put it back. Returns what you
## are holding now.
func cycle_carried() -> String:
	var ids := stash_ids()
	if ids.is_empty():
		return ""
	var i := ids.find(carried)
	set_carried("" if i >= ids.size() - 1 and i >= 0 else String(ids[i + 1]))
	return carried


## Hand the treat in your hands to this child. Returns "" on success, or why
## not. It is paid for here; a child who is asleep wakes at once (a peppermint
## or a brain snack), a brain snack frees a stuck child without a help being
## counted, and a fidget cube narrows how far their whispering carries.
func give_treat(s: StudentData) -> String:
	Balance.ensure_loaded()
	if carried == "":
		return "You are not carrying anything."
	if s == null or s.seat_index < 0:
		return "Nobody is sitting there."
	if not treats_available():
		return "Not now."
	var def: Dictionary = Balance.consumables.get(carried, {})
	if def.is_empty():
		return "That is not on the stash."
	if not spend(int(def.get("cost", 0))):
		return "Not enough coins."
	var id := carried
	var was_asleep := s.sleeping()
	s.give_consumable(id, float(def.get("duration", 0.0)), bool(def.get("wake_immediate", false)))
	if was_asleep and not s.sleeping():
		student_woke_up.emit(s.id, "desk")
	if bool(def.get("clears_stall", false)):
		s.clear_stall()
	consumables_used_today.append(String(def.get("name", id)))
	set_carried("")
	treat_given.emit(s.id, id)
	return ""


signal aide_hired(on: bool)
signal janitor_hired(on: bool)
## `which` is "aide" or "janitor".
signal staff_leveled(which: String, level: int)

var attention: float = 0.0
## Whether the teacher is teaching RIGHT NOW, for the animation and the HUD.
var teaching: bool = false

signal attention_changed(level: float)

## The class has drifted far enough that the absence has cost something.
##
## ONBOARDING, and the smallest version of it that works. Nothing told a
## new player that the work only advances while they are at the front, so
## the first lesson read as broken rather than as the central mechanic.
##
## It fires on the DOWNWARD crossing only, and not the moment you step
## away: walking to a stuck child is the game, and a nudge fired then
## would read as "do not do that". By the time attention has fallen this
## far the player has already watched the work slow, so the sentence
## explains something they have just seen rather than pre-empting it.
signal class_drifted()

## A finished sheet has been sitting on a desk long enough to matter.
##
## ONBOARDING, slice two. Work left uncollected at the bell HALVES that
## child's lesson grade (grade.uncollected_penalty), and nothing said so
## -- a new player could lose half a term's marks without ever being told
## the collecting was part of the job rather than tidying up after it.
##
## Dwelled, not instant: a child finishing is not a mistake, and a nudge
## fired the moment they put their pen down would be noise while the
## player is already walking over.
signal work_going_cold()

var _uncollected_for: float = 0.0


## How hard today's lesson is for the child in `seat_index`, as a pair of
## multipliers: how much longer the work takes, and how much more often they
## get stuck on it.
##
## Difficulty 3 is neutral. Furniture takes the edge off -- a well-equipped
## desk makes the work EASIER, which is what a player expects it to do and
## what room_score conspicuously did not do before: it fed the grade and
## nothing else, so a bookshelf was worth points and changed nothing you
## could watch happen.
func difficulty_mults(seat_index: int) -> Array:
	Balance.ensure_loaded()
	# TWO different questions, and they deserve two different answers.
	#
	#   the PAPER   how much work there is       -> how long it takes
	#   the SUBJECT how confusing the material is -> how often they stall
	#
	# Keeping them apart is what lets an easy subject carry a long project,
	# and a hard subject carry a short worksheet. Before a paper is chosen
	# both fall back to the lesson, which is how it behaved before cards.
	var subject_steps: float = float(Curriculum.difficulty(lesson) - 3)
	var paper_steps: float = subject_steps if assignment.is_empty() 		else float(assignment_difficulty() - 3)

	if specialism != "":
		var lean: float = (-Balance.spec_relief if lesson_strand() == specialism
			else Balance.spec_penalty)
		subject_steps += lean
		paper_steps += lean

	# Furniture takes the edge off the EXTRA difficulty only -- an easy
	# lesson is not made easier still by a room full of shelves.
	var span: float = maxf(0.01, Balance.room_cap - Balance.room_base)
	var built: float = clampf(
		(room_score(seat_index) - Balance.room_base) / span, 0.0, 1.0)
	var relief: float = 1.0 - built * Balance.diff_furniture_relief
	if subject_steps > 0.0:
		subject_steps *= relief
	if paper_steps > 0.0:
		paper_steps *= relief

	# A crafted lesson makes the SAME material go down easier -- shorter
	# effective work, fewer stalls -- rather than adding a new grade term.
	# See data/balance.json's lesson_crafting section for why this plugs in
	# here instead of grade_for() directly.
	var lesson_id: String = String(lesson.get("id", ""))
	var craft_work: float = craft_work_mult(lesson_id) if lesson_id != "" else 1.0
	var craft_stall: float = craft_stall_mult(lesson_id) if lesson_id != "" else 1.0

	return [
		maxf(0.25, 1.0 + paper_steps * Balance.diff_per_step_work) * craft_work,
		maxf(0.25, 1.0 + subject_steps * Balance.diff_per_step_stall) * craft_stall,
	]


## How fast the class works, as a fraction of normal.
func work_rate() -> float:
	Balance.ensure_loaded()
	return maxf(Balance.teach_floor, attention)


## Hire, or let go. Returns "" on success or why not.
func set_aide(on: bool) -> String:
	Balance.ensure_loaded()
	if on == has_aide:
		return "Nothing to change."
	if on:
		if not spend(Balance.aide_cost):
			return "You cannot afford an aide."
	has_aide = on
	_aide_timer = 0.0
	if not on:
		aide_level = 1   # letting them go loses the training you paid for
	aide_hired.emit(has_aide)
	return ""


## The aide works the room while you teach.
##
## They take one finished sheet at a time, on a timer, and they do it whether
## or not you are watching -- which is the whole point. It frees the ONE
## thing that was pure legwork without touching anything that was a decision.
func tick_aide(delta: float) -> StudentData:
	Balance.ensure_loaded()
	if not has_aide or phase != Phase.LESSON or test_active:
		return null
	_aide_timer -= delta
	if _aide_timer > 0.0:
		return null
	_aide_timer = aide_interval()
	for s: StudentData in roster:
		if s.has_work_to_collect():
			s.collect_work()
			return s
	return null


## How long between the aide's collections, right now. Level 1 is
## Balance.aide_collect unchanged; each level above that compounds a
## Balance.staff_speedup_per_level reduction, so a levelled aide gets
## faster without ever hitting zero.
func aide_interval() -> float:
	Balance.ensure_loaded()
	return Balance.aide_collect \
		* pow(1.0 - Balance.staff_speedup_per_level, aide_level - 1)


func janitor_interval() -> float:
	Balance.ensure_loaded()
	return Balance.janitor_clean \
		* pow(1.0 - Balance.staff_speedup_per_level, janitor_level - 1)


## Coins to raise EITHER staff member from `level` to `level + 1`. Same
## rising-cost shape Grid expansion already uses, just base/growth read
## from balance.json's staff_levels instead of school.room_cost*.
func staff_level_cost(level: int) -> int:
	Balance.ensure_loaded()
	return int(round(Balance.staff_level_cost_base
		* pow(Balance.staff_level_cost_growth, level - 1)))


## `which` is "aide" or "janitor". Returns "" on success or why not.
func level_up_staff(which: String) -> String:
	Balance.ensure_loaded()
	var hired: bool = has_aide if which == "aide" else has_janitor
	if not hired:
		return "Hire one first."
	var level: int = aide_level if which == "aide" else janitor_level
	if level >= Balance.staff_level_max:
		return "Already fully trained."
	if not spend(staff_level_cost(level)):
		return "You cannot afford that."
	level += 1
	if which == "aide":
		aide_level = level
	else:
		janitor_level = level
	staff_leveled.emit(which, level)
	return ""


## Hire, or let go. Returns "" on success or why not.
func set_janitor(on: bool) -> String:
	Balance.ensure_loaded()
	if on == has_janitor:
		return "Nothing to change."
	if on:
		if not spend(Balance.janitor_cost):
			return "You cannot afford a janitor."
	has_janitor = on
	_janitor_timer = 0.0
	if not on:
		janitor_level = 1
	janitor_hired.emit(has_janitor)
	return ""


## The janitor works the room at any time of day -- mess isn't
## lesson-gated, so neither is this, unlike tick_aide().
##
## Unlike the aide, Game does not own the room's mess list (that is
## classroom.gd's), so this only answers the timing question: true means
## "clean whatever is closest to hand right now", and the caller (which
## does own the list) decides what that means.
func tick_janitor(delta: float) -> bool:
	Balance.ensure_loaded()
	if not has_janitor:
		return false
	_janitor_timer -= delta
	if _janitor_timer > 0.0:
		return false
	_janitor_timer = janitor_interval()
	return true


## Feed or drain the class's attention. `at_front` is whether the teacher is
## close enough to the front of the room to be teaching them.
## Watch for finished work nobody has come for. Called beside
## tick_attention, once a frame, for the same reason: it is a fact about
## the room right now rather than an event anything emits.
func tick_uncollected(delta: float) -> void:
	Balance.ensure_loaded()
	if phase != Phase.LESSON or test_active:
		_uncollected_for = 0.0
		return
	var waiting := false
	for s: StudentData in roster:
		if s.has_work_to_collect():
			waiting = true
			break
	if not waiting:
		_uncollected_for = 0.0
		return
	var before := _uncollected_for
	_uncollected_for += delta
	if before < Balance.uncollected_hint_after 			and _uncollected_for >= Balance.uncollected_hint_after:
		work_going_cold.emit()


func tick_attention(delta: float, at_front: bool) -> void:
	Balance.ensure_loaded()
	teaching = at_front and phase == Phase.LESSON and not test_active
	var before := attention
	# The call-and-response's hold runs down whether or not you go back to
	# the front -- it is time bought, not a state you have to walk out of.
	call_hold = maxf(0.0, call_hold - delta)
	call_cooldown = maxf(0.0, call_cooldown - delta)
	if teaching:
		attention = minf(1.0, attention + Balance.teach_fill * delta)
	elif call_hold > 0.0:
		pass                    # they are still with you: no decay
	else:
		attention = maxf(0.0, attention - Balance.teach_decay * delta)
	if not is_equal_approx(before, attention):
		attention_changed.emit(attention)
	# Downward crossing only, so it cannot fire repeatedly while the player
	# stands at a desk, and cannot fire at all on the way back up.
	if phase == Phase.LESSON and not teaching 			and before >= Balance.teach_drift_hint_below 			and attention < Balance.teach_drift_hint_below:
		class_drifted.emit()


## The class, in a word, for the status strip. Attention, less a slice
## per child messing about and per child visibly stuck -- the three things
## the strip used to make the player add up from pips. Thresholds and
## weights in balance.json's `mood`. A word, never a number: "the room is
## with you" is a thing you can act on.
func class_mood() -> String:
	Balance.ensure_loaded()
	var noisy := 0
	var stuck := 0
	for s: StudentData in roster:
		if s.seat_index < 0:
			continue
		if s.disrupting:
			noisy += 1
		elif s.is_visibly_struggling():
			stuck += 1
	var m: float = attention - Balance.mood_noisy_weight * float(noisy) \
		- Balance.mood_stuck_weight * float(stuck)
	if m >= Balance.mood_with_you:
		return "with you"
	if m >= Balance.mood_drifting:
		return "drifting"
	if m >= Balance.mood_restless:
		return "restless"
	return "lost them"


## Is this tile close enough to the front to teach from?
##
## Measured against the PODIUM, which makes the front of the room somewhere
## you stand rather than somewhere you tap once at the start of the day.
func can_teach_from(tile: Vector2i) -> bool:
	Balance.ensure_loaded()
	return absi(tile.x - Layout.PODIUM.x) + absi(tile.y - Layout.PODIUM.y) \
		<= Balance.teach_radius


## Sit the whole class down for a quick quiz. Returns a row per student,
## worst first — the order matters, because the entire point is to tell you
## who to walk to next.
func run_quiz() -> Dictionary:
	Balance.ensure_loaded()
	var rows: Array = []
	var total := 0.0
	var flagged := 0
	for s: StudentData in roster:
		if s.seat_index < 0:
			continue
		var right := s.take_quiz(rng, lesson_strand())
		total += s.quiz_score
		if s.quiz_flagged:
			flagged += 1
		rows.append({
			"student": s, "right": right,
			"of": Balance.quiz_questions,
			"score": s.quiz_score, "flagged": s.quiz_flagged,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"]))
	quiz_done = true
	quiz_focus = true
	return {
		"rows": rows, "flagged": flagged,
		"average": total / maxf(1.0, float(rows.size())),
		"subject": subject,
	}


func answer_all_ready() -> bool:
	return answer_all_cooldown <= 0.0


## The mass-help skill, on its own key (J). Go round the whole room at
## once: clear confusion for every stuck child and resolve every flagged
## quiz -- the SAME per-desk effects the player's own E press has, just
## compressed. The cost is lesson seconds up front (charged in
## classroom.run_answer_all()) and a long cooldown. It pays NO grade and
## NO coins, exactly like the quiz, so it cannot move the balance
## contract -- see the guard in tests/run.gd test_balance().
func run_answer_all() -> Dictionary:
	Balance.ensure_loaded()
	# During the paper, talking the room through it counts as HELD for
	# everyone frozen right now -- never rallied. Flagged before the
	# confusion clears, so the fight's own tick sees why they came round.
	if fight != null:
		fight.mass_steady()
	var helped := 0
	var flagged_cleared := 0
	for s: StudentData in roster:
		if s.seat_index < 0:
			continue
		if s.help():
			helped += 1
		if s.sleeping() and s.wake_up(true):
			student_woke_up.emit(s.id, "answer_all")
			helped += 1
		if s.resolve_quiz():
			flagged_cleared += 1
	answer_all_cooldown = Balance.answer_all_cooldown_seconds
	return {"helped": helped, "flagged_cleared": flagged_cleared}


## Pay for extra help for one child. `kind` is "tuition" or "parents".
func coach(s: StudentData, kind: String) -> String:
	Balance.ensure_loaded()
	if s == null:
		return "Nobody selected."
	if not s.can_be_coached():
		return "There is only so much extra you can give one child."
	var base: int = Balance.coach_tuition_cost if kind == "tuition" \
		else Balance.coach_parents_cost
	var cost := s.coaching_cost(base)
	if not spend(cost):
		return "You cannot afford that."
	if kind == "tuition":
		s.aptitude = clampf(s.aptitude + Balance.coach_tuition_step, 0.0, 1.0)
	else:
		s.diligence = clampf(s.diligence + Balance.coach_parents_step, 0.0, 1.0)
	s.coached += 1
	return ""


func set_phase(p: int) -> void:
	if p == phase:
		return
	phase = p
	# A treat is carried within a lesson; it does not follow you out of one.
	if p != Phase.LESSON:
		set_carried("")
	phase_changed.emit(phase)


## Start (or top up) the quicker-feet boost. Never stacks past one stretch:
## a second win refreshes it rather than doubling it, so no run of good luck
## can compound into something the room was never balanced for.
func start_boost(seconds: float = -1.0) -> void:
	Balance.ensure_loaded()
	var secs := seconds if seconds > 0.0 else Balance.comp_boost_seconds
	boost_left = maxf(boost_left, secs)
	boost_changed.emit(boost_left)


## Tick it down. Called by the room, the same way it ticks the lesson.
func tick_boost(delta: float) -> void:
	if boost_left <= 0.0:
		return
	boost_left = maxf(0.0, boost_left - delta)
	boost_changed.emit(boost_left)


## The bell ends it, win or lose.
func clear_boost() -> void:
	if boost_left <= 0.0:
		return
	boost_left = 0.0
	boost_changed.emit(0.0)


## What the teacher's pace is multiplied by right now. 1.0 when nothing is
## running, which is the overwhelming majority of the time.
func boost_speed_mult() -> float:
	if boost_left <= 0.0:
		return 1.0
	Balance.ensure_loaded()
	return Balance.comp_boost_speed_mult


## Is today a materials day?
func supplies_day() -> bool:
	return bool(event.get("supplies", false))


## Empty every child's hands on a materials day, and fill them on any other.
## Called once when the day rolls over, never mid-lesson.
func _set_up_supplies() -> void:
	var needed := supplies_day()
	for s: StudentData in roster:
		s.has_supply = not needed


## How much slower a child works for having nothing in front of them. 1.0
## on every ordinary day, and on a materials day for every child you got to
## in time. This is a PACE penalty on the child's own stall rate -- it does
## not touch their record, and it cannot fire at all unless the day rolled
## a materials event, which tools/sim.gd never does.
func supply_rate_mult(s: StudentData) -> float:
	Balance.ensure_loaded()
	if s == null or s.has_supply:
		return 1.0
	return Balance.supplies_stall_mult


## Hand one child their materials. Returns false if they already had them,
## so the desk can offer the job only while it is still a job.
func give_supply(s: StudentData) -> bool:
	if s == null or s.has_supply:
		return false
	s.has_supply = true
	return true


## How many are still waiting, for the one line the room shows you.
func awaiting_supplies() -> int:
	var n := 0
	for s: StudentData in roster:
		if s.seat_index >= 0 and not s.has_supply:
			n += 1
	return n


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	if amount > 0 and is_inside_tree():
		Sfx.play("coins")
	coins_changed.emit(coins)


## Returns false and changes nothing if you can't afford it, so callers can
## use it as the affordability check as well as the deduction.
func spend(amount: int) -> bool:
	if unlimited_coins:
		return true
	if amount > coins:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func can_afford(amount: int) -> bool:
	return unlimited_coins or amount <= coins


## Pay out, roll overnight homework, and move to tomorrow.
## Returns a small report for the end-of-day screen.
## Where the class's grade came from today, part by part.
##
## The same four terms grade_for() adds up, averaged over the class, so the
## day report can show the working rather than only the total. Kept here
## rather than in the HUD because it is the grade model's own arithmetic and
## it must not be able to drift from it.
func grade_split() -> Dictionary:
	Balance.ensure_loaded()
	var n := maxf(1.0, float(roster.size()))
	var room := 0.0
	var lesson := 0.0
	var hw := 0.0
	for s: StudentData in roster:
		room += room_score(s.seat_index)
		var l: float = s.work_fraction() * Balance.lesson_cap
		if s.work_state != StudentData.Work.COLLECTED:
			l *= Balance.uncollected_penalty
		lesson += l
		if s.hw_state == StudentData.HW.MARKED:
			var h: float = Balance.homework_cap * s.hw_true_accuracy
			if not s.verdict_was_right():
				h *= Balance.verdict_weight
			hw += h
	return {
		"room": room / n, "lesson": lesson / n, "homework": hw / n,
		"known": concept_bonus(),
	}


func advance_day() -> Dictionary:
	Balance.ensure_loaded()
	var before: Dictionary = last_split.duplicate()
	var split := grade_split()
	last_split = split
	var avg := class_average()
	var earned := int(round(avg * Balance.coins_per_grade_point * roster.size()
		* DayEvent.multiplier(event, "coin_mult") * consumable_multiplier("coin_mult")
		* term_path_multiplier("coin_mult")
		* lesson_pay_multiplier() * paper_pay_today())) + consumable_bonus_coins
	add_coins(earned)
	# Furniture wears out. Without an ongoing cost, coins simply piled up
	# with nothing to spend them on once the room was capped.
	var upkeep := room_items.size() * Balance.upkeep_per_item
	# An aide is paid every day, so keeping one is a standing decision
	# rather than a purchase you make once and forget about.
	if has_aide:
		upkeep += Balance.aide_wage
	if has_janitor:
		upkeep += Balance.janitor_wage
	# every teacher you employ, every day, taught or not
	upkeep += wage_bill()
	coins = maxi(0, coins - upkeep)
	coins_changed.emit(coins)

	var did := 0
	for s: StudentData in roster:
		# A sheet nobody collected or marked in two days is stale. It goes
		# back to NONE with no credit, so the child can be set new work.
		if s.hw_state == StudentData.HW.DONE or s.hw_state == StudentData.HW.COLLECTED:
			s.hw_stale += 1
			if s.hw_stale >= 2:
				s.hw_state = StudentData.HW.NONE
				s.hw_sheet = {}
				s.hw_stale = 0
		# who actually did the homework you set
		if homework_out and s.hw_state == StudentData.HW.ASSIGNED:
			if bool(event.get("homework_sure", false)) or _consumable_homework_sure \
					or rng.randf() < s.diligence:
				s.hw_state = StudentData.HW.DONE
				s.hw_stale = 0
				s.hw_done_total += 1
				s.hw_true_accuracy = clampf(
					s.aptitude + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
				s.hw_sheet = Questions.make_sheet(
					s.hw_true_accuracy, rng, lesson_strand())
				did += 1
			else:
				# NOT_DONE used to be terminal: assign_homework only ever
				# re-issued to NONE or MARKED, so one failed roll on day 1
				# locked a student out of homework for the entire run,
				# silently. They get asked again tomorrow.
				s.hw_state = (StudentData.HW.NONE if Balance.not_done_forgiveness
					else StudentData.HW.NOT_DONE)
		s.reset_lesson()
		s.days_enrolled += 1

	# Read BEFORE day advances -- pacing_report() judges the day that just
	# ended, and `day` is about to become tomorrow's number.
	var pacing := pacing_report(day)
	if bool(pacing["on_pace"]):
		add_coins(Balance.pace_bonus_coins)
		for s: StudentData in roster:
			s.add_xp(Balance.pace_bonus_xp)

	homework_out = false
	day += 1
	var craft_result := _tick_pending_craft()

	# Word gets round. A new student arrives only if you're actually doing
	# the job — otherwise the class stops growing, which is feedback in
	# itself rather than a punishment screen.
	# the teacher learns from the day too
	add_teacher_xp(Balance.teacher_xp_per_day
		+ int(round(avg * Balance.teacher_xp_per_grade_point)))

	var joined := ""
	if day % Balance.enrol_every_days == 1 and avg >= Balance.enrol_min_average:
		var s := enrol()
		if s != null:
			joined = s.display_name

	subject = pick_subject()
	# Captured before the reset below clears it -- these were bought FOR
	# the day that just ended, so they belong on that day's own report,
	# not on tomorrow's (which is what "event" a few lines down already is).
	var used_today := consumables_used_today.duplicate()
	_reset_consumables()
	# The streak counts TODAY'S event, which is about to become yesterday's --
	# read before the roll, or the guarantee is one day stale (same trap
	# pacing_report() avoids for the same reason).
	if String(event.get("id", "none")) == "none":
		_none_streak += 1
	else:
		_none_streak = 0
	event = DayEvent.roll(rng, _none_streak)
	_flares_today = 0
	fight_done = false
	interruption = {}
	_complications_today = 0
	bell_rush_left = 0.0
	_bell_rush_done.clear()
	_apply_announced_event(event)
	# A materials day starts with every seated child empty-handed. The
	# end-of-day report that announces tomorrow's event is what warns you --
	# it already prints the blurb, so no new announcement was needed.
	_set_up_supplies()
	if day > Balance.term_days:
		term_over = true
	set_phase(Phase.MORNING)
	day_changed.emit(day)
	save_game()
	return {"day": day - 1, "average": avg, "coins": earned,
			"upkeep": upkeep, "homework_done": did, "joined": joined,
			"event": event.get("name", ""), "event_blurb": event.get("blurb", ""),
			"consumables": used_today,
			"term_over": term_over,
		"teacher_xp": teacher_xp, "perk_ranks": perk_ranks,
		"cheated": cheated,
		"graduated": graduated,
			"days_left": maxi(0, Balance.term_days - day + 1),
			"split": split, "split_before": before,
			"pacing": pacing, "craft_result": craft_result}


## Whatever a freshly rolled event pays out the moment it is ANNOUNCED --
## today's report already says "Tomorrow: The book fair", so this runs
## against tomorrow's event, not the day it actually plays out. Split out
## of advance_day() so it can be tested against a chosen event directly,
## without needing DayEvent.roll() to land on it by chance.
func _apply_announced_event(ev: Dictionary) -> void:
	if ev.has("bonus_coins"):
		add_coins(int(ev["bonus_coins"]))
	# Ten-commits.md step 5: the book fair.
	if ev.has("grant_item"):
		store_id(String(ev["grant_item"]))


## Set tonight's homework. Only meaningful once per day.
func assign_homework() -> int:
	if homework_out:
		return 0
	var n := 0
	for s: StudentData in roster:
		if s.hw_state == StudentData.HW.NONE or s.hw_state == StudentData.HW.MARKED:
			s.hw_state = StudentData.HW.ASSIGNED
			s.hw_stale = 0
			s.hw_set_total += 1
			n += 1
	homework_out = n > 0
	return n


# ---------------------------------------------------------------- grading

## THE BALANCE CONTRACT. This table IS the design pillar — "the room sets the
## floor, the teacher sets the ceiling" — and tests/run.gd asserts all three
## rows of it so tuning can't silently break the game's whole point.
##
##   bare room, perfect teaching   -> ~0.63   a C
##   full room, never helped       -> ~0.71   a C
##   both                          -> ~0.97   an A
##
## Neither input alone can reach the top band. That is the whole idea.
## The numbers themselves live in data/balance.json now, and the contract
## is asserted against SIMULATED play rather than hand-set state — the old
## test wrote attention_credit directly and so validated a condition the
## game could not actually produce.
##
## Trust a fresh run of tools/sim.gd's CONTRACT CHECK over this comment —
## it has drifted before, twice, and stopped saying what the code did.

## Letter thresholds, read from data/balance.json's grade_bands so tuning
## them does not mean editing a .gd file.
##
## Softened from the EduSystems originals (A .88 / B .75 / C .62 / D .50 /
## E .38): the contract's own bare-room-perfect-teaching row sat at 0.63,
## a single point above the old C floor of 0.62 -- meaning realistic,
## trying-but-imperfect play (not perfect, just decent) landed BELOW it,
## in D. The three contract rows above still land C / C / A under the new
## bands, with real margin instead of a hair's width; tests/run.gd asserts
## this explicitly so a future retune can't silently break it again.
static func grade_letter(v: float) -> String:
	Balance.ensure_loaded()
	if v >= Balance.grade_band_a: return "A"
	if v >= Balance.grade_band_b: return "B"
	if v >= Balance.grade_band_c: return "C"
	if v >= Balance.grade_band_d: return "D"
	if v >= Balance.grade_band_e: return "E"
	return "F"


## What the room alone is worth to whoever sits in `seat_index`.
## Range-based from each item's tile, so where you put things matters.
func room_score(seat_index: int) -> float:
	Balance.ensure_loaded()
	if seat_index < 0 or seat_index >= Layout.seat_count():
		return Balance.room_base
	var seat: Vector2i = Layout.seat(seat_index)
	var total := Balance.room_base
	for placed: Dictionary in room_items:
		var def := Items.get_def(String(placed.get("id", "")))
		if def.is_empty():
			continue
		# distance to the NEAREST tile of the item, so a wide item helps from
		# either end rather than only from its anchor
		var best := 9999
		for t: Vector2i in Items.reach_footprint(String(placed["id"]), placed["tile"]):
			best = mini(best, absi(t.x - seat.x) + absi(t.y - seat.y))
		if best <= int(def.get("range", 0)):
			total += float(def.get("bonus", 0.0))
			# A subject item pays a bit more on a day its strand is being
			# taught. Additive and small -- the room_cap clamp below is
			# what keeps this out of the balance contract.
			var st := String(def.get("strand", ""))
			if st != "" and st == lesson_strand():
				total += float(def.get("strand_bonus", 0.0))
	return minf(Balance.room_cap, total)


## The grade a student has earned this lesson: the room they sat in, how
## much of their work they actually got through, and their homework.
##
## There is no separate "attention" term any more. Your attention shows up
## as work_fraction — a stuck student's timer is frozen, so reaching them is
## literally the only way that number rises. One mechanism, visible on the
## bar above their head, instead of an invisible counter that could never
## reach its own cap.
func grade_for(s: StudentData) -> float:
	Balance.ensure_loaded()

	var lesson := s.work_fraction() * Balance.lesson_cap
	if s.work_state != StudentData.Work.COLLECTED:
		# work you never picked up counts for less, which is what makes the
		# walk round the desks worth doing at all
		lesson *= Balance.uncollected_penalty

	var hw := 0.0
	if s.hw_state == StudentData.HW.MARKED:
		hw = Balance.homework_cap * s.hw_true_accuracy
		if not s.verdict_was_right():
			hw *= Balance.verdict_weight

	# Knowing your material, SCALED BY how much of the lesson they actually
	# got through.
	#
	# As a flat bonus it lifted the floor as much as the ceiling: the term
	# simulator showed a player who never helped anybody climbing from an E
	# to a D purely for having stood at the podium. Expertise should pay for
	# teaching, not for attendance -- so a child who did none of the work
	# gains nothing from yours. Zero on day one either way, which is what
	# keeps the three-row contract unmoved.
	var expertise := concept_bonus() * s.work_fraction()
	return clampf(room_score(s.seat_index) + lesson + hw + expertise, 0.0, 1.0)


# --- the grade book ---------------------------------------------------------
#
# The owner's ask (Oct 2026): "keep a log book of all the grades on the table
# where you submit the papers". Every grade this run has given, in the order
# it was given: one entry per lesson, unit test and term exam, each row a
# child's id, first name and grade. It is the TEACHER's record, kept apart
# from each child's transcript on purpose -- a transcript leaves with its
# child when they move up, and the book keeps them. Read at the register
# lying open on your desk (interact/grade_book.gd, hud.show_grade_book()).
# Saved, and cleared by new_run(); it only ever records grades the game
# already gave, so it cannot move anything.

## [{term, day, kind ("lesson" | "test" | "exam"), name, strand, rows:
## [{id, name, grade}]}], oldest first.
var grade_log: Array = []


## Write one page of the book: `results` as grade_class()/grade_test() return
## them ({student, grade}) or as the exam's rows ({student, score}).
## `lesson_id` names the lesson an entry is for (Oct 2026), so the grade book's
## subjects page can find it again; older entries only have its name.
func log_grades(kind: String, title: String, strand: String, results: Array,
		lesson_id: String = "") -> void:
	var rows: Array = []
	for r: Dictionary in results:
		var s: StudentData = r.get("student", null)
		if s == null:
			continue
		rows.append({"id": s.id, "name": s.first_name(),
			"grade": float(r.get("grade", r.get("score", 0.0)))})
	if rows.is_empty():
		return
	var entry := {"term": term, "day": day, "kind": kind, "name": title,
		"strand": strand, "rows": rows}
	if lesson_id != "":
		entry["lesson"] = lesson_id
	grade_log.append(entry)


## A save from before the book existed: write this term back into it from the
## class's own records, so the book does not open empty on a term already
## under way. A child's last N transcript rows are this term's, N being how
## many grades they hold (next_term() clears `grades` and keeps the
## transcript). Earlier terms are not recovered -- the children who sat them
## have moved on, and the book says it starts here.
func _grade_log_from_transcripts() -> Array:
	var pages := {}
	var order: Array = []
	for s: StudentData in roster:
		var n := mini(s.grades.size(), s.transcript.size())
		for row: Dictionary in s.transcript.slice(s.transcript.size() - n):
			var test := bool(row.get("test", false))
			var key := "%d|%s|%s" % [int(row.get("day", 0)), String(row.get("lesson", "")), str(test)]
			if not pages.has(key):
				var l := Curriculum.by_id(String(row.get("lesson", "")))
				pages[key] = {"term": term, "day": int(row.get("day", 0)),
					"kind": "test" if test else "lesson",
					"name": String(row.get("name", "Lesson")),
					"strand": String(l.get("strand", "")), "rows": []}
				if not l.is_empty():
					pages[key]["lesson"] = String(l.get("id", ""))
				order.append(key)
			(pages[key]["rows"] as Array).append({"id": s.id, "name": s.first_name(),
				"grade": float(row.get("grade", 0.0))})
	var out: Array = []
	for key: String in order:
		out.append(pages[key])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["day"]) < int(b["day"]))
	return out


## Close the lesson: everyone is graded, and it is recorded.
func grade_class() -> Array:
	var out: Array = []
	Balance.ensure_loaded()
	# Teaching it once more is what unlocks the next concept, so this has to
	# happen before the grades that concept knowledge feeds into? No -- AFTER.
	# Today's lesson is graded on what you knew while you were teaching it;
	# the concept it just unlocked pays from tomorrow.
	var strand := lesson_strand()
	# ten-commits.md step 6: a fire drill touches the whole roster once,
	# the first time -- not per-student streak state, so it lives outside
	# the loop below rather than inside it.
	var drill := String(event.get("id", "")) == "fire_drill"
	for s: StudentData in roster:
		var g := grade_for(s)
		s.last_grade = g
		s.grades.append(g)
		s.record_result(lesson, g, day)
		s.misjudged = false         # their next lesson has ended
		# ten-commits.md step 6: lessons running in their own best subject.
		# Reset the moment a DIFFERENT strand is taught, so it is a streak,
		# not a lifetime tally.
		if s.favourite != "" and s.favourite == strand:
			s._favourite_streak += 1
			if s._favourite_streak >= Balance.moments_favourite_streak:
				s.note_moment("favourite_streak", day)
				s._favourite_streak = 0
		else:
			s._favourite_streak = 0
		if drill and not s.has_moment("fire_drill"):
			s.note_moment("fire_drill", day)
		# they get better simply by being taught -- attending is worth
		# something, finishing the work is worth more
		var earned := Balance.stu_xp_per_lesson
		if s.work_state == StudentData.Work.COLLECTED:
			earned += Balance.stu_xp_per_work_done
			bank_graded_assignment(String(assignment.get("rarity", "common")), 1)
		if s.hw_state == StudentData.HW.MARKED:
			earned += Balance.stu_xp_per_homework
		earned = maxi(earned, int(round(float(earned) * paper_pay_today())))
		var levels := s.add_xp(earned)
		out.append({"student": s, "grade": g, "letter": grade_letter(g),
			"levels": levels})
	_sleep_tick_accum = 0.0
	_zpd_tick_accum = 0.0
	end_all_zpd()
	log_grades("lesson", String(lesson.get("name", "Lesson")), strand, out,
		String(lesson.get("id", "")))
	record_taught(String(lesson.get("id", "")))
	return out


func class_average() -> float:
	if roster.is_empty():
		return 0.0
	var t := 0.0
	for s: StudentData in roster:
		t += s.last_grade if s.last_grade >= 0.0 else 0.0
	return t / float(roster.size())


# ------------------------------------------------------------------ items

## Can `id` be placed with its origin at `tile`, given what's already down?
## The caller still has to check the grid for walls and furniture. A
## desk-top piece fits on a desk with nothing on it, and nowhere else.
func item_fits(id: String, tile: Vector2i) -> bool:
	if Items.is_desk_top(id):
		return desk_top_free(tile)
	var want := Items.footprint(id, tile)
	for placed: Dictionary in room_items:
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			if t in want:
				return false
	return true


## The first place on the back wall this hanging piece fits, scanning left to
## right; (-1, -1) once the wall is full.
func free_wall_slot(id: String) -> Vector2i:
	for tx in range(1, Grid.W - 1):
		var t := Vector2i(tx, Layout.WALL_ROW)
		if Layout.wall_slot_ok(id, t) and item_fits(id, t):
			return t
	return Vector2i(-1, -1)


## A save from before wall pieces hung had its clock and banner standing on the
## floor. Put each one up on the wall; if the wall has no room it goes back in
## the cabinet rather than vanishing. The same for a piece hung where the wall
## is no longer free: the Oct 2026 back wall gave the curriculum poster, the
## treat shelf and the intercom columns of their own, and a clock a save hung
## there moves along to the next free spot.
func rehang_wall_items() -> void:
	for placed: Dictionary in room_items.duplicate():
		var id := String(placed["id"])
		if not Items.is_wall(id):
			continue
		var at := placed["tile"] as Vector2i
		if at.y == Layout.WALL_ROW and Layout.wall_slot_ok(id, at):
			continue
		room_items.erase(placed)
		var slot := free_wall_slot(id)
		if slot.x >= 0:
			room_items.append({"id": id, "tile": slot})
		else:
			cabinet.append(id)


## Quick Sweep, wired up: how many presses a piece of mess takes to clean.
func mess_presses_needed() -> int:
	return Progress.mess_presses(perk_ranks)


## What buying `id` actually costs right now -- Thrifty's discount applied.
## The one function every BUY-side price display/check reads, so the shop
## list, the afford colour, and the actual spend can never drift apart.
## Deliberately not used for the SELL side (sell_value() below) -- a
## discount you paid for should not also deflate what you get back.
func shop_price(id: String) -> int:
	return int(round(Items.cost(id) * (1.0 - Progress.shop_discount(perk_ranks))))


func place_item(id: String, tile: Vector2i) -> bool:
	if not spend(shop_price(id)):
		return false
	add_item(id, tile)
	return true


## Put an item down without charging — used when MOVING one that is already
## owned, and when a cancelled move puts it back. A desk-top piece goes on
## the desk at `tile` (its seat or the desk itself).
func add_item(id: String, tile: Vector2i) -> void:
	if Items.is_desk_top(id):
		var seat := Layout.seat_at_tile(tile)
		if seat >= 0:
			desk_items[seat] = id
			room_changed.emit()
			fire_tutorial("study_folder_placed")
		return
	room_items.append({"id": id, "tile": tile})
	room_changed.emit()


## The placed item covering `tile`, or an empty dictionary.
func item_at(tile: Vector2i) -> Dictionary:
	for placed: Dictionary in room_items:
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			if t == tile:
				return placed
	return {}


## Lift an item off the floor -- or off the desk at `tile`, where a desk-top
## piece stands. Returns its id, or "" if there was none.
func remove_item(tile: Vector2i) -> String:
	var placed := item_at(tile)
	if placed.is_empty():
		var on_desk := desk_item_at(tile)
		if on_desk.is_empty():
			return ""
		desk_items.erase(int(on_desk["seat"]))
		room_changed.emit()
		return String(on_desk["id"])
	room_items.erase(placed)
	room_changed.emit()
	return String(placed["id"])


# --------------------------------------------------- what stands on the desks
#
# The owner's ask (Oct 2026): "an item you can put on the child's desk to make
# them solve their lessons". A desk-top item (Items.is_desk_top) is placed ON a
# child's desk with the same ghost cursor as everything else, and kept here
# rather than in room_items: it takes no floor, reaches nobody else, and moves
# with its desk, because a desk keeps its seat index when it moves. Whoever
# sits at that desk -- this child, or the next one after they move up -- is
# the one it works for.
#
# The study folder is the first: a child stuck at a desk with one looks it up
# and gets going again after its works_out_after seconds (tick_desk_tops()),
# and it screens them from the desks beside them -- nobody chats with them or
# copies over it. Pace only, like the chatter: it is never a room_score term
# (range 0, bonus 0), and the room ticks it, never tools/sim.gd.

## seat index -> item id. Saved; cleared by new_run().
var desk_items: Dictionary = {}

## A stuck child looked it up in the folder on their desk and got going again.
signal worked_it_out(student_id: int)


## The id of what stands on desk `seat_index`, or "".
func desk_item(seat_index: int) -> String:
	return String(desk_items.get(seat_index, ""))


## The def of what stands on this child's desk, or {} for a bare desk.
func desk_item_def(s: StudentData) -> Dictionary:
	if s == null or s.seat_index < 0:
		return {}
	var id := desk_item(s.seat_index)
	return Items.get_def(id) if id != "" else {}


## Behind something that screens them from the desks beside them (the study
## folder): nobody gets talking to them over it, and they cannot copy past it.
func screened(s: StudentData) -> bool:
	return bool(desk_item_def(s).get("screens_neighbours", false))


## Seconds a child at this desk sits stuck before they look it up themselves,
## or 0 when nothing on their desk lets them.
func works_out_after(s: StudentData) -> float:
	return float(desk_item_def(s).get("works_out_after", 0.0))


## Work-rate multiplier granted by the item standing on this child's desk
## (e.g. Pencil Caddy 1.15x, Desk Primer 1.22x, Desk Atlas 1.30x, Study Folder 1.10x).
func desk_work_mult(s: StudentData) -> float:
	return float(desk_item_def(s).get("desk_work_mult", 1.0))


## Can a desk-top piece go on the desk at `tile` (its seat or the desk) right
## now: a desk that is out of the cabinet, with nothing already on it.
func desk_top_free(tile: Vector2i) -> bool:
	var seat := Layout.seat_at_tile(tile)
	return seat >= 0 and seat < Layout.seat_count() - desks_in_store \
		and desk_item(seat) == ""


## {id, tile, seat} for what stands on the desk at `tile`, or {} -- `tile` is
## the DESK's tile, so a piece picked up goes back exactly where it came from.
func desk_item_at(tile: Vector2i) -> Dictionary:
	var seat := Layout.seat_at_tile(tile)
	if seat < 0 or desk_item(seat) == "":
		return {}
	return {"id": desk_item(seat), "tile": Layout.desk_tile(seat), "seat": seat}


## How many of `id` you own: in the cabinet, on the floor and on desks.
func owned_count(id: String) -> int:
	var n := cabinet_count(id)
	for placed: Dictionary in room_items:
		if String(placed.get("id", "")) == id:
			n += 1
	for seat: Variant in desk_items:
		if String(desk_items[seat]) == id:
			n += 1
	return n


## The study folder at work, once a frame during a lesson the room is running
## (never a written test, never the boss paper -- an exam has no folder --
## never tools/sim.gd). A child stuck at a desk with one looks it up after its
## works_out_after seconds: slower than you walking over, no XP, nobody's help
## counted -- but they stop sitting there stewing until frustration tips them
## into messing about, which in practice is most of what it buys.
func tick_desk_tops() -> void:
	for s: StudentData in roster:
		var after := works_out_after(s)
		if after <= 0.0 or not s.is_struggling() or s.disrupting:
			continue
		if s.stuck_seconds() >= after and s.work_it_out():
			worked_it_out.emit(s.id)


func sell_value(id: String) -> int:
	Balance.ensure_loaded()
	return int(floor(Items.cost(id) * Balance.sell_fraction))


func sell_item(tile: Vector2i) -> int:
	var id := remove_item(tile)
	if id == "":
		return 0
	var refund := sell_value(id)
	add_coins(refund)
	return refund


# ---------------------------------------------------------------- the cabinet
#
# Everything you own but have not placed. Buying puts an item HERE; you
# place it from here into the room; packing one up puts it back here;
# selling is done from here. room_items is only ever what is on the floor
# right now. Persisted, and cleared by new_run().
signal cabinet_changed()

var cabinet: Array = []   ## item ids, one entry per owned copy

## Desks the opening scene is still holding back in the cabinet. 0 in
## every ordinary run -- build_desks() builds seat_count() desks then.
## The cold open stashes all of them, rebuilds the room empty, and the
## teacher pulls them out one at a time. Saved so a mid-cutscene reload
## does not strand the class; an older save has no key and loads at 0.
var desks_in_store: int = 0


## Rebuild just the desks -- NOT the whole room. A full rebuild re-rolls
## the day's mess off Game.rng, and the opening scene fires this eight
## times; routing it through its own signal keeps the rng stream and
## every other prop untouched.
signal intro_desks_changed()


## The opening scene: stash every desk in the cabinet and rebuild the
## room with none. classroom._spawn_students() holds the class at the
## door while this is non-zero.
func intro_begin_desks() -> void:
	desks_in_store = Layout.seat_count()
	intro_desks_changed.emit()


## Pull one desk out of the cabinet. Returns how many are still in it --
## 0 means the room is furnished and the class can come in.
func intro_pull_desk() -> int:
	if desks_in_store <= 0:
		return 0
	desks_in_store -= 1
	intro_desks_changed.emit()
	return desks_in_store


## Buy `id` into the cabinet. Returns "" on success or why it was refused.
## The shop stays open afterwards -- there is no placement to start yet.
func buy_to_cabinet(id: String) -> String:
	var price := shop_price(id)
	# A piece with a limit (the study folder: Items.max_owned) is about WHICH
	# children get one, so the shop stops selling it once you have them all.
	var cap := Items.max_owned(id)
	if cap > 0 and owned_count(id) >= cap:
		return "you have all you can use"
	if not can_afford(price):
		return "not enough coins"
	spend(price)
	cabinet.append(id)
	cabinet_changed.emit()
	return ""


## How many copies of `id` are sitting in the cabinet.
func cabinet_count(id: String) -> int:
	var n := 0
	for c: String in cabinet:
		if c == id:
			n += 1
	return n


## The distinct ids in the cabinet, in the catalogue's own order so the
## list reads the same way the shop does.
func cabinet_ids() -> Array:
	var seen: Array = []
	for id: String in Items.order():
		if cabinet.has(id) and not seen.has(id):
			seen.append(id)
	return seen


## Take one copy of `id` out of the cabinet and put it in the room. No
## charge -- it was paid for when it was bought. False if there is none to
## take or it does not fit.
func place_from_cabinet(id: String, tile: Vector2i) -> bool:
	if not cabinet.has(id) or not item_fits(id, tile):
		return false
	cabinet.erase(id)
	add_item(id, tile)
	cabinet_changed.emit()
	return true


## Pack a placed item away. Returns its id, or "" if the tile was bare.
func store_item(tile: Vector2i) -> String:
	var id := remove_item(tile)
	if id == "":
		return ""
	cabinet.append(id)
	cabinet_changed.emit()
	return id


## Put one copy of `id` straight into the cabinet without a tile -- used
## when a carried item is packed away rather than set down.
func store_id(id: String) -> void:
	cabinet.append(id)
	cabinet_changed.emit()


## Sell one copy of `id` out of the cabinet for half its price.
func sell_from_cabinet(id: String) -> int:
	if not cabinet.has(id):
		return 0
	cabinet.erase(id)
	var refund := sell_value(id)
	add_coins(refund)
	cabinet_changed.emit()
	return refund


# ------------------------------------------------------------------- save

func to_dict() -> Dictionary:
	var out: Array = []
	for s: StudentData in roster:
		out.append(s.to_dict())
	return {
		"version": 1, "day": day, "coins": coins,
		"next_id": _next_id, "roster": out,
		"homework_out": homework_out,
		"event_id": event.get("id", "none"),
		"lesson_id": lesson.get("id", ""),
		"term_over": term_over,
		"subject": subject,
		# from_dict() has always READ these four. Nothing wrote them, so your
		# own level, your perks, everyone you ever sent up, and the cheat mark
		# were quietly thrown away by every save.
		"teacher_xp": teacher_xp,
		"perk_ranks": perk_ranks,
		"term_path": term_path,
		"exam_picks": exam_picks.duplicate(),
		"graduated": graduated,
		"meta": meta,
		"cheated": cheated,
		"met_principal": met_principal,
		"intro_seen": intro_seen,
		"dash_taught": dash_taught,
		"answer_all_taught": answer_all_taught,
		"chain_dash_taught": chain_dash_taught,
		"call_response_taught": call_response_taught,
		"tutorials_seen": tutorials_seen.duplicate(),
		"room_w": Grid.W, "room_h": Grid.H, "expansions": expansions,
		"term": term,
		"specialism": specialism,
		"has_aide": has_aide,
		"aide_level": aide_level,
		"has_janitor": has_janitor,
		"janitor_level": janitor_level,
		"chosen_lesson": chosen_lesson,
		"hat_id": hat_id,
		"background_id": background_id,
		"auto_teach": auto_teach,
		"assignment": assignment,
		"assignment_day": assignment_day,
		"graded_bank": graded_bank.duplicate(),
		"prestige_lessons": prestige_lessons.duplicate(),
		"prestige_used": prestige_used.duplicate(),
		"queued_assignment_tier": queued_assignment_tier,
		"term_history": term_history,
		"run_over": run_over,
		"milestones": milestones,
		"trophies": trophies,
		"lesson_crafts": lesson_crafts,
		"pending_craft": pending_craft,
		"rooms": rooms.map(func(r: Dictionary) -> Dictionary:
			return {
				"name": r.get("name", ""), "teacher": r.get("teacher", {}),
				"furniture": r.get("furniture", 0), "last": r.get("last", {}),
				"roster": (r.get("roster", []) as Array).map(
					func(s: StudentData) -> Dictionary: return s.to_dict()),
			}),
		"applicants": applicants,
		"reputation": reputation,
		"taught": taught,
		"concepts": concepts,
		"term_start_concepts": term_start_concepts,
		"seats": Layout.seats().map(func(t: Vector2i) -> Dictionary:
			return {"tx": t.x, "ty": t.y}),
		"room_items": room_items.map(func(p: Dictionary) -> Dictionary:
			return {"id": p["id"], "tx": p["tile"].x, "ty": p["tile"].y}),
		"cabinet": cabinet.duplicate(),
		# seat -> id, with the seat as a string: JSON object keys are strings,
		# and from_dict() turns them back into seat numbers.
		"desk_items": _desk_items_for_save(),
		"grade_log": grade_log.duplicate(true),
		"tested": tested.duplicate(),
		"desks_in_store": desks_in_store,
		"age_tier": age_tier,
		"tier_graduates": tier_graduates,
	}


func _desk_items_for_save() -> Dictionary:
	var out := {}
	for seat: Variant in desk_items:
		out[str(seat)] = String(desk_items[seat])
	return out


func from_dict(d: Dictionary) -> void:
	# Every field defaults, so a save written by an older build still loads
	# rather than crashing on a key that did not exist yet.
	day = int(d.get("day", 1))
	coins = int(d.get("coins", 0))
	_next_id = int(d.get("next_id", 1))
	homework_out = bool(d.get("homework_out", false))
	lesson = Curriculum.by_id(String(d.get("lesson_id", "")))
	subject = String(d.get("subject", lesson.get("name", "Lesson")))
	event = DayEvent.by_id(String(d.get("event_id", "none")))
	term_over = bool(d.get("term_over", false))
	teacher_xp = int(d.get("teacher_xp", 0))
	cheated = bool(d.get("cheated", false))
	met_principal = bool(d.get("met_principal", false))
	intro_seen = bool(d.get("intro_seen", false))
	# No key -> an older save from before the mentor. Grandfather both verbs
	# as already taught, so a run in progress does not lose the dash and the
	# mass-help it has always had. A new career sets them false in new_run().
	dash_taught = bool(d.get("dash_taught", true))
	answer_all_taught = bool(d.get("answer_all_taught", true))
	# NOT grandfathered -- see the var's own note. No key means the mentor
	# has not shown it yet, whatever else this save already knows.
	chain_dash_taught = bool(d.get("chain_dash_taught", false))
	# Not grandfathered either -- see the var's own note.
	call_response_taught = bool(d.get("call_response_taught", false))
	teacher_level = Progress.level_for_xp(teacher_xp)
	perk_ranks = d.get("perk_ranks", {}).duplicate()
	term_path = (d.get("term_path", {}) as Dictionary).duplicate()
	exam_picks = (d.get("exam_picks", {}) as Dictionary).duplicate()
	graduated = d.get("graduated", []).duplicate()
	# The career block that survives new_run(). An older save has no "meta"
	# key -- _ensure_meta_keys() then fills a fresh one, exactly like every
	# other forward-compat default in this function.
	meta = (d.get("meta", {}) as Dictionary).duplicate(true)
	_ensure_meta_keys()
	# An older save has no size, so it simply reopens at the base room.
	Grid.set_size(int(d.get("room_w", Grid.BASE_W)), int(d.get("room_h", Grid.BASE_H)))
	expansions = int(d.get("expansions", 0))
	term = int(d.get("term", 1))
	specialism = String(d.get("specialism", ""))
	has_aide = bool(d.get("has_aide", false))
	aide_level = int(d.get("aide_level", 1))
	has_janitor = bool(d.get("has_janitor", false))
	janitor_level = int(d.get("janitor_level", 1))
	chosen_lesson = String(d.get("chosen_lesson", ""))
	hat_id = String(d.get("hat_id", ""))
	background_id = String(d.get("background_id", ""))
	auto_teach = bool(d.get("auto_teach", false))
	assignment = d.get("assignment", {}).duplicate()
	assignment_day = int(d.get("assignment_day", -1))
	graded_bank = (d.get("graded_bank", {}) as Dictionary).duplicate()
	prestige_lessons = (d.get("prestige_lessons", {}) as Dictionary).duplicate()
	prestige_used = (d.get("prestige_used", {}) as Dictionary).duplicate()
	queued_assignment_tier = String(d.get("queued_assignment_tier", ""))
	run_over = bool(d.get("run_over", false))
	milestones = d.get("milestones", []).duplicate()
	# An older save has no trophies key -- it loads with none, same as a
	# fresh run.
	trophies = (d.get("trophies", []) as Array).duplicate()
	rooms.clear()
	for rd: Dictionary in d.get("rooms", []):
		var roster_in: Array = []
		for sd: Dictionary in rd.get("roster", []):
			roster_in.append(StudentData.from_dict(sd))
		rooms.append({
			"name": String(rd.get("name", "Room")),
			"teacher": rd.get("teacher", {}).duplicate(),
			"furniture": int(rd.get("furniture", 0)),
			"last": rd.get("last", {}).duplicate(),
			"roster": roster_in,
		})
	applicants = d.get("applicants", []).duplicate()
	reputation = float(d.get("reputation", Balance.rep_start))
	term_history = d.get("term_history", []).duplicate()
	taught = d.get("taught", {}).duplicate()
	lesson_crafts = d.get("lesson_crafts", {}).duplicate()
	pending_craft = d.get("pending_craft", {}).duplicate()
	concepts = d.get("concepts", []).duplicate()
	term_start_concepts = int(d.get("term_start_concepts", 0))
	# where the desks were left. An older save has no "seats" key, so it
	# simply keeps the opening arrangement.
	var saved_seats: Array[Vector2i] = []
	for st: Dictionary in d.get("seats", []):
		saved_seats.append(Vector2i(int(st.get("tx", 0)), int(st.get("ty", 0))))
	if saved_seats.is_empty():
		Layout.reset_seats()
	else:
		Layout.set_seats(saved_seats)
	room_items.clear()
	for p: Dictionary in d.get("room_items", []):
		room_items.append({"id": String(p.get("id", "")),
			"tile": Vector2i(int(p.get("tx", 0)), int(p.get("ty", 0)))})
	# An older save has no cabinet key -- it simply loads with an empty one.
	cabinet = (d.get("cabinet", []) as Array).duplicate()
	# ...nor anything on the desks. A piece whose id no longer exists, or that
	# sits on a desk the room no longer has, goes back in the cabinet rather
	# than vanishing (the same courtesy rehang_wall_items() pays a clock).
	desk_items.clear()
	var saved_tops: Dictionary = d.get("desk_items", {})
	for key: Variant in saved_tops:
		var top_id := String(saved_tops[key])
		var seat := int(str(key))
		if not Items.is_desk_top(top_id):
			continue
		if seat >= 0 and seat < Layout.seat_count() and not desk_items.has(seat):
			desk_items[seat] = top_id
		else:
			cabinet.append(top_id)
	rehang_wall_items()      # an older save kept its clock standing on the floor
	desks_in_store = int(d.get("desks_in_store", 0))
	# An older save has no stage: it is the first, and nobody is counted yet.
	age_tier = clampi(int(d.get("age_tier", 0)), 0, maxi(0, tier_count() - 1))
	tier_graduates = maxi(0, int(d.get("tier_graduates", 0)))
	captains.clear()
	phase = Phase.MORNING
	test_active = false         # a save never resumes mid-test; the phase is MORNING
	tested.clear()
	var tested_in: Dictionary = d.get("tested", {})
	for tid: Variant in tested_in:
		tested[String(tid)] = int(tested_in[tid])
	roster.clear()
	for sd: Dictionary in d.get("roster", []):
		roster.append(StudentData.from_dict(sd))
	# The grade book. A save from before it existed has no key: this term is
	# written back into it from the class's own records (needs the roster,
	# hence here, last).
	if d.has("grade_log"):
		grade_log = (d.get("grade_log", []) as Array).duplicate(true)
	else:
		grade_log = _grade_log_from_transcripts()
	# Tutorials already seen. An older save has none recorded: count whatever
	# it clearly used (needs the grade log, the cabinet and the rest, hence here).
	if d.has("tutorials_seen"):
		tutorials_seen = (d.get("tutorials_seen", {}) as Dictionary).duplicate()
	else:
		tutorials_seen = _tutorials_from_use()
	roster_changed.emit()


# ------------------------------------------------------------- save file

func save_game() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("could not open the save file for writing")
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("the save file is corrupt — starting fresh")
		return false
	from_dict(parsed as Dictionary)
	return true


## What day the save file is on, without loading it — so the title screen
## can say "Continue (day 7)" without disturbing the current run.
func saved_day() -> int:
	if not has_save():
		return 0
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return 0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return int((parsed as Dictionary).get("day", 0))
	return 0


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ------------------------------------------------------- multi-slot saves
#
# The single save above (save_path) is the autosave/"Continue" file the
# title screen already reads. These slots are a separate, additional way
# to keep more than one run around -- same to_dict()/from_dict() state,
# stored through SaveManager's 8 user://saves/slot_N.json files instead
# of the one fixed path. Nothing calls these yet; no menu offers a slot
# picker. That is a real, separate UI decision (where it lives, how many
# slots a player actually sees) -- this is the tested, working bridge a
# future menu can call once that's scoped.

func save_to_slot(index: int) -> bool:
	return SaveManager.save(index, to_dict())


func load_from_slot(index: int) -> bool:
	var d := SaveManager.load(index)
	if d.is_empty():
		return false
	from_dict(d)
	return true


func has_slot(index: int) -> bool:
	return FileAccess.file_exists(SaveManager.get_slot_path(index))


## What day a slot is on, without loading it -- has_slot()'s day-number
## sibling, same purpose saved_day() serves for the single save file.
func slot_day(index: int) -> int:
	if not has_slot(index):
		return 0
	var f := FileAccess.open(SaveManager.get_slot_path(index), FileAccess.READ)
	if f == null:
		return 0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return int((parsed as Dictionary).get("day", 0))
	return 0


## Key run facts for a slot without loading it into live state.
func slot_info(index: int) -> Dictionary:
	if not has_slot(index):
		return {}
	var f := FileAccess.open(SaveManager.get_slot_path(index), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed as Dictionary
		return {
			"day": int(d.get("day", 1)),
			"coins": int(d.get("coins", 0)),
			"term": int(d.get("term", 1)),
			"subject": String(d.get("subject", "general")),
		}
	return {}


func delete_slot(index: int) -> bool:
	return SaveManager.delete_slot(index)
