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
## Flare-ups started so far today, against Balance.flare_max_per_day. Reset
## every morning -- a bad-luck run should not be able to bury you. The
## counting and the spawning live in classroom.gd (_tick_flares), since a
## flare is a thing in the room you walk to, not a fact about the roster;
## day boundaries are Game's though, so the tally sits here.
var _flares_today: int = 0

## A pending desk interruption (phone call / parent conference) -- empty
## when nothing is waiting. Counted and ticked the same way flares are:
## classroom.gd owns the countdown (a thing in the room), Game owns the
## per-lesson tally. Neither is saved -- lesson-scoped transient state,
## same as lesson_left.
var interruption: Dictionary = {}
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

signal term_began(term: int)

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

# --- the paper you set ------------------------------------------------
## The three cards drawn at the podium, and the one you picked.
##
## Setting work used to be a formality -- tap the podium, everyone gets the
## same anonymous sheet. Drawing a hand makes the first thing you do each
## morning a decision, and it is the decision the rest of the day is spent
## living with.
var hand: Array = []
var assignment: Dictionary = {}

signal hand_drawn(cards: Array)


func draw_hand() -> Array:
	hand = Assignments.draw(rng, lesson, Progress.assignment_luck(perk_ranks))
	hand_drawn.emit(hand)
	return hand


func choose_assignment(i: int) -> Dictionary:
	if i < 0 or i >= hand.size():
		return {}
	assignment = (hand[i] as Dictionary).duplicate()
	hand.clear()
	return assignment


## What the paper on the desks is worth, as a multiplier on coins and on the
## experience finishing it gives a child. Never on the grade -- see the note
## in data/balance.json.
func assignment_pay() -> float:
	if assignment.is_empty():
		return 1.0
	return Assignments.pay(String(assignment.get("rarity", "common")))


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
func draw_term_paths() -> Array:
	Balance.ensure_loaded()
	term_path_hand = TermPaths.draw(rng, Balance.term_path_hand_min)
	return term_path_hand


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
	term_path_hand.clear()
	bell_rush_left = 0.0
	_bell_rush_done.clear()
	term_over = false
	term = 1
	term_history.clear()
	run_over = false
	milestones.clear()
	rooms.clear()
	applicants.clear()
	reputation = float(Balance.rep_start)
	exam_result = {}
	cheated = false
	unlimited_coins = false
	met_principal = false
	intro_seen = false
	_reset_consumables()
	teacher_xp = 0
	teacher_level = 1
	perk_ranks.clear()
	hat_id = ""
	background_id = ""
	auto_teach = false
	graduated.clear()
	taught.clear()
	lesson_crafts.clear()
	pending_craft.clear()
	concepts.clear()
	quiz_done = false
	# and the focus a quiz leaves behind. Without this the buff leaked
	# ACROSS runs: the term simulator quizzes in one policy and then
	# measures the balance contract in another, so a row that should
	# have had no quiz in it was quietly reading 0.69 -> 0.73.
	quiz_focus = false
	attention = 0.0
	teaching = false
	has_aide = false
	_aide_timer = 0.0
	aide_level = 1
	has_janitor = false
	_janitor_timer = 0.0
	janitor_level = 1
	test_active = false
	voice = 1.0
	last_inspection = {}
	last_split = {}
	specialism = ""
	chosen_lesson = ""
	hand.clear()
	assignment = {}
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


## The counter to the discovered meta of cramming every desk into the
## middle of the room: a child with another occupied desk orthogonally
## adjacent works Balance.room_cluster_penalty slower. Spreading the desks
## back out is the whole counter-play, and the opening layout already has
## no two seats within a tile of each other, so this costs nothing until a
## player chooses to bunch them.
##
## Layout only, read live the same way neighbours_of() is -- it never
## touches a grade formula. The contract sim (tools/sim.gd _one_lesson())
## seats every child at 0 and calls tick_work() directly rather than
## through classroom._physics_process, so it never sees this; asserted in
## test_balance()'s _one_lesson() source scan alongside tick_class().
func cluster_rate_mult(s: StudentData) -> float:
	Balance.ensure_loaded()
	if s == null or s.seat_index < 0 or Balance.room_cluster_penalty <= 0.0:
		return 1.0
	if neighbours_of(s).is_empty():
		return 1.0
	return maxf(0.0, 1.0 - Balance.room_cluster_penalty)


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
				"art": s.art,
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

# --- lesson crafting --------------------------------------------------
## lesson id -> {craft_level: int, invested_coins: int, invested_days: int}
var lesson_crafts: Dictionary = {}
## {} when nothing in flight, else {lesson_id: String, days_left: int}.
## Single pending craft at a time -- no queue in this first slice.
var pending_craft: Dictionary = {}


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
	var entry: Dictionary = lesson_crafts.get(lesson_id, {"craft_level": 0, "invested_coins": 0, "invested_days": 0}).duplicate()
	entry["invested_coins"] = int(entry.get("invested_coins", 0)) + cost
	lesson_crafts[lesson_id] = entry
	return true


## Called once per real advance_day() while a craft is in flight. Resolves
## through Game.rng at 0 days left -- the same seeded stream every other
## daily roll uses, so a fixed seed reproduces the same outcome.
func _tick_pending_craft() -> void:
	if pending_craft.is_empty():
		return
	var lesson_id: String = String(pending_craft["lesson_id"])
	var entry: Dictionary = lesson_crafts.get(lesson_id, {"craft_level": 0, "invested_coins": 0, "invested_days": 0}).duplicate()
	entry["invested_days"] = int(entry.get("invested_days", 0)) + 1
	lesson_crafts[lesson_id] = entry

	pending_craft["days_left"] = int(pending_craft["days_left"]) - 1
	if int(pending_craft["days_left"]) > 0:
		return

	if rng.randf() < Balance.craft_success_chance:
		entry = lesson_crafts[lesson_id].duplicate()
		entry["craft_level"] = int(entry.get("craft_level", 0)) + 1
		lesson_crafts[lesson_id] = entry
	pending_craft = {}


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
		var range_tiles: float = Balance.voice_range + Progress.voice_range_bonus(perk_ranks)
		if absi(seat.x - from.x) + absi(seat.y - from.y) > range_tiles:
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
	if teaching:
		attention = minf(1.0, attention + Balance.teach_fill * delta)
	else:
		attention = maxf(0.0, attention - Balance.teach_decay * delta)
	if not is_equal_approx(before, attention):
		attention_changed.emit(attention)
	# Downward crossing only, so it cannot fire repeatedly while the player
	# stands at a desk, and cannot fire at all on the way back up.
	if phase == Phase.LESSON and not teaching 			and before >= Balance.teach_drift_hint_below 			and attention < Balance.teach_drift_hint_below:
		class_drifted.emit()


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
		* DayEvent.multiplier(event, "coin_mult") * consumable_multiplier("coin_mult")
		* term_path_multiplier("coin_mult")
		* lesson_pay_multiplier())) + consumable_bonus_coins
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
		# who actually did the homework you set
		if homework_out and s.hw_state == StudentData.HW.ASSIGNED:
			if bool(event.get("homework_sure", false)) or _consumable_homework_sure \
					or rng.randf() < s.diligence:
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
	_tick_pending_craft()

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
	event = DayEvent.roll(rng)
	_flares_today = 0
	interruption = {}
	_complications_today = 0
	bell_rush_left = 0.0
	_bell_rush_done.clear()
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
			"consumables": used_today,
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
		"term_path": term_path,
		"graduated": graduated,
		"cheated": cheated,
		"met_principal": met_principal,
		"intro_seen": intro_seen,
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
		"term_history": term_history,
		"run_over": run_over,
		"milestones": milestones,
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
	met_principal = bool(d.get("met_principal", false))
	intro_seen = bool(d.get("intro_seen", false))
	teacher_level = Progress.level_for_xp(teacher_xp)
	perk_ranks = d.get("perk_ranks", {}).duplicate()
	term_path = (d.get("term_path", {}) as Dictionary).duplicate()
	graduated = d.get("graduated", []).duplicate()
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
	run_over = bool(d.get("run_over", false))
	milestones = d.get("milestones", []).duplicate()
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
