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

const CLASS_START := 4     ## how many students enrol on day one
const CLASS_CAP := 8       ## the room has 8 desks; the roster grows into them
const SAVE_PATH := "user://pixelroom_save.json"

## A new student turns up once you've proved you can teach — every this many
## days, provided the class average is holding up.
const ENROL_EVERY_DAYS := 3
const ENROL_MIN_AVERAGE := 0.62

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
	_next_id = 1
	for i in CLASS_START:
		enrol()
	roster_changed.emit()
	room_changed.emit()


## Adds one student and seats them in the lowest free desk. Returns null when
## the room is full.
func enrol() -> StudentData:
	if roster.size() >= CLASS_CAP:
		return null
	var s := StudentData.new()
	s.id = _next_id
	_next_id += 1
	s.display_name = Names.random_name(rng)
	s.art = Names.ART[(s.id - 1) % Names.ART.size()]
	s.aptitude = rng.randf_range(0.25, 0.85)
	s.diligence = rng.randf_range(0.25, 0.85)
	s.seat_index = _lowest_free_seat()
	roster.append(s)
	roster_changed.emit()
	return s


func _lowest_free_seat() -> int:
	var taken := {}
	for s: StudentData in roster:
		taken[s.seat_index] = true
	for i in CLASS_CAP:
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


func set_phase(p: int) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(phase)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
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
	var avg := class_average()
	var earned := int(round(avg * 10.0 * roster.size()))
	add_coins(earned)

	var did := 0
	for s: StudentData in roster:
		# who actually did the homework you set
		if homework_out and s.hw_state == StudentData.HW.ASSIGNED:
			if rng.randf() < s.diligence:
				s.hw_state = StudentData.HW.DONE
				s.hw_true_accuracy = clampf(
					s.aptitude + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
				s.hw_sheet = Questions.make_sheet(s.hw_true_accuracy, rng)
				did += 1
			else:
				s.hw_state = StudentData.HW.NOT_DONE
		s.reset_lesson()

	homework_out = false
	day += 1

	# Word gets round. A new student arrives only if you're actually doing
	# the job — otherwise the class stops growing, which is feedback in
	# itself rather than a punishment screen.
	var joined := ""
	if day % ENROL_EVERY_DAYS == 1 and avg >= ENROL_MIN_AVERAGE:
		var s := enrol()
		if s != null:
			joined = s.display_name

	set_phase(Phase.MORNING)
	day_changed.emit(day)
	save_game()
	return {"day": day - 1, "average": avg, "coins": earned,
			"homework_done": did, "joined": joined}


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
## 0.32, not 0.30. With a 0.30 attention cap, a base of 0.30 puts "bare room,
## perfect attention" on 0.60 — which is a D, not the C the contract calls
## for. 0.32 lands it exactly on the C threshold, so both extremes really do
## read the same to a player.
const ROOM_BASE := 0.32            ## an empty room still teaches a bit
const ROOM_CAP := 0.65             ## the very best furniture, alone
const HW_CAP := 0.15

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
	if seat_index < 0 or seat_index >= Layout.seat_count():
		return ROOM_BASE
	var seat: Vector2i = Layout.SEATS[seat_index]
	var total := ROOM_BASE
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
	return minf(ROOM_CAP, total)


## The grade a student has earned this lesson.
func grade_for(s: StudentData) -> float:
	var hw := 0.0
	if s.hw_state == StudentData.HW.MARKED:
		hw = HW_CAP * s.hw_true_accuracy
	return clampf(room_score(s.seat_index) + s.attention_credit + hw, 0.0, 1.0)


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
	room_items.append({"id": id, "tile": tile})
	room_changed.emit()
	return true


# ------------------------------------------------------------------- save

func to_dict() -> Dictionary:
	var out: Array = []
	for s: StudentData in roster:
		out.append(s.to_dict())
	return {
		"version": 1, "day": day, "coins": coins,
		"next_id": _next_id, "roster": out,
		"homework_out": homework_out,
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


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
