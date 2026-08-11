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
var subject: String = ""        ## what today's lesson is about
var event: Dictionary = {}      ## what makes today different from yesterday
var term_over: bool = false
var exam_result: Dictionary = {}

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
	_next_id = 1
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
	if roster.size() >= Balance.class_cap:
		return null
	var s := StudentData.new()
	s.id = _next_id
	_next_id += 1
	s.display_name = Names.random_name(rng)
	s.art = Names.ART[(s.id - 1) % Names.ART.size()]
	s.aptitude = rng.randf_range(0.25, 0.85)
	s.diligence = rng.randf_range(0.25, 0.85)
	s.favourite = SUBJECTS[rng.randi_range(0, SUBJECTS.size() - 1)]
	s.seat_index = _lowest_free_seat()
	roster.append(s)
	roster_changed.emit()
	return s


func _lowest_free_seat() -> int:
	var taken := {}
	for s: StudentData in roster:
		taken[s.seat_index] = true
	for i in Balance.class_cap:
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
	if not Input.is_action_just_pressed("interact"):
		return false
	var f := Engine.get_physics_frames()
	if _interact_claim == f:
		return false
	_interact_claim = f
	return true


## Today's subject. Deliberately generic for now — it names the lesson so
## the day has an identity, without pretending to a curriculum the game does
## not yet model.
const SUBJECTS := ["Maths", "Reading", "Science", "History",
	"Geography", "Art", "Music", "Spelling"]

func pick_subject() -> String:
	return SUBJECTS[rng.randi_range(0, SUBJECTS.size() - 1)]


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
	if amount > coins:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func can_afford(amount: int) -> bool:
	return amount <= coins


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
				s.hw_true_accuracy = clampf(
					s.aptitude + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
				s.hw_sheet = Questions.make_sheet(s.hw_true_accuracy, rng)
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
			"days_left": maxi(0, Balance.term_days - day + 1)}


## Set tonight's homework. Only meaningful once per day.
func assign_homework() -> int:
	if homework_out:
		return 0
	var n := 0
	for s: StudentData in roster:
		if s.hw_state == StudentData.HW.NONE or s.hw_state == StudentData.HW.MARKED:
			s.hw_state = StudentData.HW.ASSIGNED
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
	var seat: Vector2i = Layout.SEATS[seat_index]
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

	return clampf(room_score(s.seat_index) + lesson + hw, 0.0, 1.0)


## Close the lesson: everyone is graded, and it is recorded.
func grade_class() -> Array:
	var out: Array = []
	for s: StudentData in roster:
		var g := grade_for(s)
		s.last_grade = g
		s.grades.append(g)
		out.append({"student": s, "grade": g, "letter": grade_letter(g)})
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
		"term_over": term_over,
		"subject": subject,
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
	subject = String(d.get("subject", "Maths"))
	event = DayEvent.by_id(String(d.get("event_id", "none")))
	term_over = bool(d.get("term_over", false))
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
