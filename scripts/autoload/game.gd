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

signal phase_changed(phase: int)
signal day_changed(day: int)
signal coins_changed(coins: int)
signal roster_changed()
signal room_changed()

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
var exam_result: Dictionary = {}

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
	_next_id = 1
	Layout.reset_seats()      # back to the opening arrangement
	Balance.ensure_loaded()
	coins = Balance.start_coins
	for i in Balance.class_start:
		enrol()
	roster_changed.emit()
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
	lesson = Curriculum.pick(rng)
	return String(lesson.get("name", "Lesson"))


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
func sit_exam() -> Dictionary:
	Balance.ensure_loaded()
	var rows: Array = []
	var total := 0.0
	for s: StudentData in roster:
		var score := clampf(
			s.average_grade() * 0.75 + room_score(s.seat_index) * 0.35, 0.0, 1.0)
		total += score
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


## Has today's lesson already been interrupted for a quiz? One per lesson:
## the cost is lesson TIME, and without a limit the right play would be to
## run it over and over until everybody had been flagged and resolved.
var quiz_done: bool = false


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
func advance_day() -> Dictionary:
	Balance.ensure_loaded()
	var avg := class_average()
	var earned := int(round(avg * Balance.coins_per_grade_point * roster.size()
		* DayEvent.multiplier(event, "coin_mult")))
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
			"days_left": maxi(0, Balance.term_days - day + 1)}


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

	# Knowing your material. Zero on day one -- which is why the three-row
	# balance contract, measured on a fresh run, is unmoved by it.
	return clampf(room_score(s.seat_index) + lesson + hw + concept_bonus(),
		0.0, 1.0)


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
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("could not open the save file for writing")
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return int((parsed as Dictionary).get("day", 0))
	return 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
