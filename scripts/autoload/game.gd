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

const SAVE_PATH := "user://pixelroom_save.json"

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
## A brand new run has begun. The HUD listens so that no screen from the
## previous run is left hanging over the new one -- a report about a class
## that no longer exists is worse than no report.
signal run_started()

var day: int = 1
var coins: int = 0
var phase: int = Phase.MORNING
var roster: Array[StudentData] = []
var room_items: Array = []      ## [{id: String, tile: Vector2i}]
var homework_out: bool = false  ## is there homework due back tomorrow?
var subject: String = ""        ## today's lesson NAME, for display
var lesson: Dictionary = {}     ## the full curriculum entry behind it
var event: Dictionary = {}      ## what makes today different from yesterday
var term_over: bool = false
## Which term this is. A run is not one term any more -- it is as many as
## you keep teaching, and everything you built carries into the next.
var term: int = 1
## One row per finished term: [{term, letter, passed, total, moved_up}]
var term_history: Array = []
## The run ended because a term was missed. Distinct from term_over, which
## only means the exam has been sat.
var run_over: bool = false

signal term_began(term: int)
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

# --- the teacher's own progression ---------------------------------
var teacher_xp: int = 0
var teacher_level: int = 1
var perk_ranks: Dictionary = {}      ## perk id -> ranks bought
var graduated: Array = []            ## [{name, level, readiness, day}]

## Set the moment any cheat is used, and never cleared. Saved, shown on the
## end-of-term screen, and checked by the term simulator, which refuses to
## run on a cheated save -- a balance reading taken after a cheat is a lie.
var cheated: bool = false
var unlimited_coins: bool = false

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
	if not load_game():
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
	homework_out = false
	subject = pick_subject()
	event = DayEvent.by_id("none")
	term_over = false
	term = 1
	term_history.clear()
	run_over = false
	exam_result = {}
	cheated = false
	unlimited_coins = false
	teacher_xp = 0
	teacher_level = 1
	perk_ranks.clear()
	graduated.clear()
	taught.clear()
	concepts.clear()
	quiz_done = false
	# and the focus a quiz leaves behind. Without this the buff leaked
	# ACROSS runs: the term simulator quizzes in one policy and then
	# measures the balance contract in another, so a row that should
	# have had no quiz in it was quietly reading 0.69 -> 0.73.
	quiz_focus = false
	attention = 0.0
	teaching = false
	test_active = false
	voice = 1.0
	last_inspection = {}
	last_split = {}
	specialism = ""
	chosen_lesson = ""
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
func seat_capacity() -> int:
	Balance.ensure_loaded()
	return mini(Balance.class_cap, Layout.seat_count())


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
					break
				if Traits.has_flag(s.trait_id, "copy_from_neighbour") 						and rng.randf() < 0.6 * delta:
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
				chance += Balance.dis_spread       # it travels along the desks
		chance *= Traits.value(s.trait_id, "neighbour_stall_mult", 1.0)
		if chance > 0.0 and rng.randf() < chance * delta:
			s.disrupting = true


func student_in_seat(seat: int) -> StudentData:
	for s: StudentData in roster:
		if s.seat_index == seat:
			return s
	return null


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
	return DayEvent.multiplier(event, "stall_mult")


## Today's lesson length, after the day's event has had its say.
func lesson_length() -> float:
	Balance.ensure_loaded()
	return Balance.lesson_seconds * DayEvent.multiplier(event, "lesson_mult")


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
func exam_score_for(s: StudentData) -> float:
	Balance.ensure_loaded()
	var span: float = maxf(0.01, Balance.room_cap - Balance.room_base)
	var built: float = clampf(
		(room_score(s.seat_index) - Balance.room_base) / span, 0.0, 1.0)
	return clampf(s.average_grade() + built * Balance.exam_room_bonus, 0.0, 1.0)


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

	# Missing the target ends the RUN. Everything below still happens, so
	# the final screen can say what the term was, but no next term opens.
	var target := term_target()
	var hit := met_target(int(result.get("passed", 0)))
	if not hit:
		run_over = true

	var moved_up: Array[String] = []
	var stayed: Array[StudentData] = []
	for row: Dictionary in result.get("rows", []):
		var s: StudentData = row["student"]
		if bool(row.get("passed", false)) and Balance.term_pass_moves_up:
			moved_up.append(s.display_name)
			graduated.append({
				"name": s.display_name, "level": s.level,
				"readiness": s.readiness(), "day": day, "term": term,
			})
		else:
			stayed.append(s)

	term_history.append({
		"term": term, "letter": String(result.get("letter", "F")),
		"passed": int(result.get("passed", 0)),
		"total": int(result.get("total", 0)),
		"moved_up": moved_up.size(),
		"target": target, "met": hit,
	})

	if run_over:
		save_game()
		return {
			"term": term, "moved_up": moved_up, "joined": [],
			"stayed": stayed.size(), "run_over": true,
			"target": target,
			"previous": term_history[term_history.size() - 1],
		}

	# whoever is left starts the new term with a clean slate but their own
	# history -- the transcript is theirs and it travels
	roster.clear()
	for s: StudentData in stayed:
		s.grades.clear()
		s.last_grade = -1.0
		s.reset_lesson()
		s.hw_state = StudentData.HW.NONE
		s.misjudged = false
		roster.append(s)

	term += 1
	day = 1
	term_over = false
	exam_result = {}
	homework_out = false
	quiz_done = false
	test_active = false
	voice = 1.0
	last_inspection = {}
	event = DayEvent.by_id("none")
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
	save_game()
	return {
		"term": term, "moved_up": moved_up, "joined": joined,
		"stayed": stayed.size(), "run_over": false,
		"target": term_target(),
		"previous": term_history[term_history.size() - 1],
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
	var record := {
		"name": s.display_name, "level": s.level,
		"readiness": s.readiness(), "day": day,
	}
	graduated.append(record)
	add_coins(coins_won)
	add_teacher_xp(Balance.grad_teacher_xp)
	roster.erase(s)
	roster_changed.emit()
	# their desk frees up, so someone new can have it
	var joined := enrol()
	record["coins"] = coins_won
	record["replaced_by"] = joined.display_name if joined != null else ""
	return record


# --- what you have taught, and what it taught YOU -------------------
## lesson id -> how many times you have taught it.
var taught: Dictionary = {}
## Concept ids you have unlocked, in the order you got them.
var concepts: Array = []

signal concepts_learned(ids: Array)


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


## May this unit be tested yet? You have to have actually taught it -- a
## test on something the class has never covered is not a difficulty
## setting, it is just a worse lesson.
func can_test(lesson_id: String) -> bool:
	Balance.ensure_loaded()
	return times_taught(lesson_id) >= Balance.test_requires_taught


## Any unit ready to be tested, for the podium's prompt.
func testable_lesson() -> Dictionary:
	Curriculum.ensure_loaded()
	for l: Dictionary in Curriculum.lessons:
		if can_test(String(l.get("id", ""))):
			return l
	return {}


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
		+ concept_bonus(), 0.0, 1.0)


## Mark the papers. Worth a row in every child's record, flagged as a test
## so their transcript can tell the two apart.
func grade_test() -> Array:
	Balance.ensure_loaded()
	var out: Array = []
	for s: StudentData in roster:
		var g := test_grade_for(s)
		s.last_grade = g
		s.grades.append(g)
		s.record_result(lesson, g, day, true)
		s.add_xp(Balance.stu_xp_per_lesson + Balance.stu_xp_per_work_done)
		out.append({"student": s, "grade": g, "letter": grade_letter(g)})
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
	for s: StudentData in roster:
		if s.seat_index < 0 or not s.disrupting:
			continue
		var seat: Vector2i = Layout.seat(s.seat_index)
		if absi(seat.x - from.x) + absi(seat.y - from.y) > Balance.voice_range:
			continue
		if s.settle():
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

# --- the class's attention -------------------------------------------
## 0..1. Filled by standing at the front and teaching, and it drains when
## you stop. Work advances in proportion to it.
##
## THE POINT: a lesson used to run itself. Students worked whether or not
## the teacher existed, so the entire job was reacting to bubbles and the
## time between them was dead. Now the room needs you at the front, and
## every second spent at one child's desk is a second the other seven are
## not being taught -- which is the trade the whole game is about.
var attention: float = 0.0
## Whether the teacher is teaching RIGHT NOW, for the animation and the HUD.
var teaching: bool = false

signal attention_changed(level: float)


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
	var steps: float = float(Curriculum.difficulty(lesson) - 3)
	# your own subject is a step easier; anything else is a step harder
	if specialism != "":
		steps += (-Balance.spec_relief if lesson_strand() == specialism
			else Balance.spec_penalty)
	if steps > 0.0:
		# only the EXTRA difficulty is relieved; an easy lesson is not made
		# easier still by a room full of furniture
		var span: float = maxf(0.01, Balance.room_cap - Balance.room_base)
		var built: float = clampf(
			(room_score(seat_index) - Balance.room_base) / span, 0.0, 1.0)
		steps *= 1.0 - built * Balance.diff_furniture_relief
	return [
		maxf(0.25, 1.0 + steps * Balance.diff_per_step_work),
		maxf(0.25, 1.0 + steps * Balance.diff_per_step_stall),
	]


## How fast the class works, as a fraction of normal.
func work_rate() -> float:
	Balance.ensure_loaded()
	return maxf(Balance.teach_floor, attention)


## Feed or drain the class's attention. `at_front` is whether the teacher is
## close enough to the front of the room to be teaching them.
func tick_attention(delta: float, at_front: bool) -> void:
	Balance.ensure_loaded()
	teaching = at_front and phase == Phase.LESSON and not test_active
	var before := attention
	if teaching:
		attention = minf(1.0, attention + Balance.teach_fill * delta)
	else:
		attention = maxf(0.0, attention - Balance.teach_decay * delta)
	if not is_equal_approx(before, attention):
		attention_changed.emit(attention)


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
	phase_changed.emit(phase)


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
		* DayEvent.multiplier(event, "coin_mult") * lesson_pay_multiplier()))
	add_coins(earned)
	# Furniture wears out. Without an ongoing cost, coins simply piled up
	# with nothing to spend them on once the room was capped.
	var upkeep := room_items.size() * Balance.upkeep_per_item
	coins = maxi(0, coins - upkeep)
	coins_changed.emit(coins)

	var did := 0
	for s: StudentData in roster:
		# who actually did the homework you set
		if homework_out and s.hw_state == StudentData.HW.ASSIGNED:
			if bool(event.get("homework_sure", false)) or rng.randf() < s.diligence:
				s.hw_state = StudentData.HW.DONE
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

	homework_out = false
	day += 1

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
	event = DayEvent.roll(rng)
	if event.has("bonus_coins"):
		add_coins(int(event["bonus_coins"]))
	if day > Balance.term_days:
		term_over = true
	set_phase(Phase.MORNING)
	day_changed.emit(day)
	save_game()
	return {"day": day - 1, "average": avg, "coins": earned,
			"upkeep": upkeep, "homework_done": did, "joined": joined,
			"event": event.get("name", ""), "event_blurb": event.get("blurb", ""),
			"term_over": term_over,
		"teacher_xp": teacher_xp, "perk_ranks": perk_ranks,
		"cheated": cheated,
		"graduated": graduated,
			"days_left": maxi(0, Balance.term_days - day + 1),
			"split": split, "split_before": before}


## Set tonight's homework. Only meaningful once per day.
func assign_homework() -> int:
	if homework_out:
		return 0
	var n := 0
	for s: StudentData in roster:
		if s.hw_state == StudentData.HW.NONE or s.hw_state == StudentData.HW.MARKED:
			s.hw_state = StudentData.HW.ASSIGNED
			s.hw_set_total += 1
			n += 1
	homework_out = n > 0
	return n


# ---------------------------------------------------------------- grading

## THE BALANCE CONTRACT. This table IS the design pillar — "the room sets the
## floor, the teacher sets the ceiling" — and tests/run.gd asserts all three
## rows of it so tuning can't silently break the game's whole point.
##
##   perfect room, no attention     -> ~0.65   a C
##   bare room, perfect attention   -> ~0.60   a C
##   both                           ->  0.95   an A
##
## Neither input alone can reach the top band. That is the whole idea.
## The numbers themselves live in data/balance.json now, and the contract
## is asserted against SIMULATED play rather than hand-set state — the old
## test wrote attention_credit directly and so validated a condition the
## game could not actually produce.

## Letter thresholds carried over from EduSystems, which are already tuned —
## and note E is a real letter there, between D and F.
static func grade_letter(v: float) -> String:
	if v >= 0.88: return "A"
	if v >= 0.75: return "B"
	if v >= 0.62: return "C"
	if v >= 0.50: return "D"
	if v >= 0.38: return "E"
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
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			best = mini(best, absi(t.x - seat.x) + absi(t.y - seat.y))
		if best <= int(def.get("range", 0)):
			total += float(def.get("bonus", 0.0))
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


## Close the lesson: everyone is graded, and it is recorded.
func grade_class() -> Array:
	var out: Array = []
	Balance.ensure_loaded()
	# Teaching it once more is what unlocks the next concept, so this has to
	# happen before the grades that concept knowledge feeds into? No -- AFTER.
	# Today's lesson is graded on what you knew while you were teaching it;
	# the concept it just unlocked pays from tomorrow.
	for s: StudentData in roster:
		var g := grade_for(s)
		s.last_grade = g
		s.grades.append(g)
		s.record_result(lesson, g, day)
		# they get better simply by being taught -- attending is worth
		# something, finishing the work is worth more
		var earned := Balance.stu_xp_per_lesson
		if s.work_state == StudentData.Work.COLLECTED:
			earned += Balance.stu_xp_per_work_done
		if s.hw_state == StudentData.HW.MARKED:
			earned += Balance.stu_xp_per_homework
		var levels := s.add_xp(earned)
		out.append({"student": s, "grade": g, "letter": grade_letter(g),
			"levels": levels})
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
## The caller still has to check the grid for walls and furniture.
func item_fits(id: String, tile: Vector2i) -> bool:
	var want := Items.footprint(id, tile)
	for placed: Dictionary in room_items:
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			if t in want:
				return false
	return true


func place_item(id: String, tile: Vector2i) -> bool:
	if not spend(Items.cost(id)):
		return false
	add_item(id, tile)
	return true


## Put an item down without charging — used when MOVING one that is already
## owned, and when a cancelled move puts it back.
func add_item(id: String, tile: Vector2i) -> void:
	room_items.append({"id": id, "tile": tile})
	room_changed.emit()


## The placed item covering `tile`, or an empty dictionary.
func item_at(tile: Vector2i) -> Dictionary:
	for placed: Dictionary in room_items:
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			if t == tile:
				return placed
	return {}


## Lift an item off the floor. Returns its id, or "" if there was none.
func remove_item(tile: Vector2i) -> String:
	var placed := item_at(tile)
	if placed.is_empty():
		return ""
	room_items.erase(placed)
	room_changed.emit()
	return String(placed["id"])


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
		"graduated": graduated,
		"cheated": cheated,
		"room_w": Grid.W, "room_h": Grid.H, "expansions": expansions,
		"term": term,
		"specialism": specialism,
		"chosen_lesson": chosen_lesson,
		"term_history": term_history,
		"run_over": run_over,
		"taught": taught,
		"concepts": concepts,
		"seats": Layout.seats().map(func(t: Vector2i) -> Dictionary:
			return {"tx": t.x, "ty": t.y}),
		"room_items": room_items.map(func(p: Dictionary) -> Dictionary:
			return {"id": p["id"], "tx": p["tile"].x, "ty": p["tile"].y}),
	}


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
	teacher_level = Progress.level_for_xp(teacher_xp)
	perk_ranks = d.get("perk_ranks", {}).duplicate()
	graduated = d.get("graduated", []).duplicate()
	# An older save has no size, so it simply reopens at the base room.
	Grid.set_size(int(d.get("room_w", Grid.BASE_W)), int(d.get("room_h", Grid.BASE_H)))
	expansions = int(d.get("expansions", 0))
	term = int(d.get("term", 1))
	specialism = String(d.get("specialism", ""))
	chosen_lesson = String(d.get("chosen_lesson", ""))
	run_over = bool(d.get("run_over", false))
	term_history = d.get("term_history", []).duplicate()
	taught = d.get("taught", {}).duplicate()
	concepts = d.get("concepts", []).duplicate()
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
	phase = Phase.MORNING
	roster.clear()
	for sd: Dictionary in d.get("roster", []):
		roster.append(StudentData.from_dict(sd))
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
