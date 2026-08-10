"""One-shot: point Items and Game at Balance, and rebuild the grade model."""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def write(rel, text):
    io.open(os.path.join(ROOT, rel), "w", encoding="utf-8").write(text)
    print("wrote", rel)


def edit(rel, pairs):
    p = os.path.join(ROOT, rel)
    s = io.open(p, encoding="utf-8").read()
    for old, new in pairs:
        assert old in s, rel + " MISSING:\n" + old[:160]
        s = s.replace(old, new, 1)
    io.open(p, "w", encoding="utf-8").write(s)
    print("patched", rel)


# ------------------------------------------------------------ items.gd
write("scripts/data/items.gd", '''class_name Items
extends RefCounted

## Things you can buy and place. The table itself lives in data/balance.json
## so prices and effects can be tuned and simulated without touching code.
##
## Effects are RANGE-BASED from the item's own tile, not a room-wide
## checklist. That is what makes *where* you put a bookshelf matter.


static func catalogue() -> Dictionary:
	Balance.ensure_loaded()
	return Balance.items


static func order() -> Array:
	Balance.ensure_loaded()
	return Balance.item_order


static func get_def(id: String) -> Dictionary:
	return catalogue().get(id, {})


static func cost(id: String) -> int:
	return int(get_def(id).get("cost", 0))


static func width(id: String) -> int:
	return int(get_def(id).get("w", 1))


## Every tile a placement at `origin` would occupy.
static func footprint(id: String, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in width(id):
		out.append(origin + Vector2i(i, 0))
	return out


## Which seats an item at `origin` would actually help — the thing the
## player could never see while placing.
static func seats_in_range(id: String, origin: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var d := get_def(id)
	if d.is_empty():
		return out
	var reach := int(d.get("range", 0))
	for i in Layout.seat_count():
		var seat: Vector2i = Layout.SEATS[i]
		var best := 9999
		for t: Vector2i in footprint(id, origin):
			best = mini(best, absi(t.x - seat.x) + absi(t.y - seat.y))
		if best <= reach:
			out.append(i)
	return out
''')

# ------------------------------------------------------------- game.gd
edit("scripts/autoload/game.gd", [
    # constants now come from Balance
    ('''const CLASS_START := 4     ## how many students enrol on day one
const CLASS_CAP := 8       ## the room has 8 desks; the roster grows into them
const SAVE_PATH := "user://pixelroom_save.json"

## A new student turns up once you've proved you can teach — every this many
## days, provided the class average is holding up.
const ENROL_EVERY_DAYS := 3
const ENROL_MIN_AVERAGE := 0.62''',
     '''const SAVE_PATH := "user://pixelroom_save.json"'''),

    ('	for i in CLASS_START:\n\t\tenrol()',
     '	Balance.ensure_loaded()\n\tcoins = Balance.start_coins\n\tfor i in Balance.class_start:\n\t\tenrol()'),

    ('	if roster.size() >= CLASS_CAP:\n\t\treturn null',
     '	Balance.ensure_loaded()\n\tif roster.size() >= Balance.class_cap:\n\t\treturn null'),

    ('	for i in CLASS_CAP:\n\t\tif not taken.has(i):',
     '	for i in Balance.class_cap:\n\t\tif not taken.has(i):'),

    # payout + enrolment + homework forgiveness
    ('''	var avg := class_average()
	var earned := int(round(avg * 10.0 * roster.size()))
	add_coins(earned)''',
     '''	Balance.ensure_loaded()
	var avg := class_average()
	var earned := int(round(avg * Balance.coins_per_grade_point * roster.size()))
	add_coins(earned)'''),

    ('''			else:
				s.hw_state = StudentData.HW.NOT_DONE
		s.reset_lesson()''',
     '''			else:
				# NOT_DONE used to be terminal: assign_homework only ever
				# re-issued to NONE or MARKED, so one failed roll on day 1
				# locked a student out of homework for the entire run,
				# silently. They get asked again tomorrow.
				s.hw_state = (StudentData.HW.NONE if Balance.not_done_forgiveness
					else StudentData.HW.NOT_DONE)
		s.reset_lesson()'''),

    ('	if day % ENROL_EVERY_DAYS == 1 and avg >= ENROL_MIN_AVERAGE:',
     '	if day % Balance.enrol_every_days == 1 and avg >= Balance.enrol_min_average:'),

    # the grade model
    ('''## 0.32, not 0.30. With a 0.30 attention cap, a base of 0.30 puts "bare room,
## perfect attention" on 0.60 — which is a D, not the C the contract calls
## for. 0.32 lands it exactly on the C threshold, so both extremes really do
## read the same to a player.
const ROOM_BASE := 0.32            ## an empty room still teaches a bit
const ROOM_CAP := 0.65             ## the very best furniture, alone
const HW_CAP := 0.15''',
     '''## The numbers themselves live in data/balance.json now, and the contract
## is asserted against SIMULATED play rather than hand-set state — the old
## test wrote attention_credit directly and so validated a condition the
## game could not actually produce.'''),

    ('''func room_score(seat_index: int) -> float:
	if seat_index < 0 or seat_index >= Layout.seat_count():
		return ROOM_BASE
	var seat: Vector2i = Layout.SEATS[seat_index]
	var total := ROOM_BASE''',
     '''func room_score(seat_index: int) -> float:
	Balance.ensure_loaded()
	if seat_index < 0 or seat_index >= Layout.seat_count():
		return Balance.room_base
	var seat: Vector2i = Layout.SEATS[seat_index]
	var total := Balance.room_base'''),

    ('	return minf(ROOM_CAP, total)', '	return minf(Balance.room_cap, total)'),

    ('''## The grade a student has earned this lesson.
func grade_for(s: StudentData) -> float:
	var hw := 0.0
	if s.hw_state == StudentData.HW.MARKED:
		hw = HW_CAP * s.hw_true_accuracy
	return clampf(room_score(s.seat_index) + s.attention_credit + hw, 0.0, 1.0)''',
     '''## The grade a student has earned this lesson: the room they sat in, how
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

	return clampf(room_score(s.seat_index) + lesson + hw, 0.0, 1.0)'''),

    ('''## What you get back for selling. Half, rounded down — enough that a
## mistake is recoverable, little enough that shuffling the room for profit
## is not a strategy.
const SELL_FRACTION := 0.5


''', ''),

    ('	return int(floor(Items.cost(id) * SELL_FRACTION))',
     '	Balance.ensure_loaded()\n\treturn int(floor(Items.cost(id) * Balance.sell_fraction))'),
])

# --------------------------------------------------------- classroom.gd
edit("scripts/world/classroom.gd", [
    ('''## Students file in rather than surging through the door as one block.
const ENTRY_STAGGER := 0.35

## How likely a student is to get stuck partway through a piece of work.
## This is the dial that decides whether a lesson is a stroll or a scramble.
const STALL_CHANCE := 0.7''',
     '''signal lesson_tick(seconds_left: float)
signal lesson_timed_out()'''),

    ('	var grid := Grid.new()', '	var grid := Grid.new()'),

    ('''			node.walk_to_seat(path, n * ENTRY_STAGGER)''',
     '''			node.walk_to_seat(path, n * Balance.entry_stagger)'''),

    ('''func _physics_process(delta: float) -> void:
	for s: StudentData in Game.roster:
		if s.tick_work(delta):
			_on_work_done(s)
	_refresh_bubbles()''',
     '''func _physics_process(delta: float) -> void:
	if Game.phase == Game.Phase.LESSON:
		# The clock is what makes this a game rather than a chore list.
		# Without it nothing ends the lesson but the player, so they can
		# always reach every student and there is no triage to do.
		lesson_left = maxf(0.0, lesson_left - delta)
		lesson_tick.emit(lesson_left)
		for s: StudentData in Game.roster:
			if s.tick_work(delta, Game.rng):
				_on_work_done(s)
		if lesson_left <= 0.0:
			lesson_timed_out.emit()
	_refresh_bubbles()'''),

    ('''## Podium, in the morning. Sets the whole class working.
func start_lesson() -> int:
	Game.set_phase(Game.Phase.LESSON)
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work(Game.rng, STALL_CHANCE):
			n += 1
	return n''',
     '''## Podium, in the morning. Sets the whole class working and starts the clock.
func start_lesson() -> int:
	Balance.ensure_loaded()
	Game.set_phase(Game.Phase.LESSON)
	lesson_left = Balance.lesson_seconds
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n'''),

    ('''func end_lesson() -> Array:
	var results := Game.grade_class()''',
     '''func end_lesson() -> Array:
	lesson_left = 0.0
	var results := Game.grade_class()'''),

    ('''	for s: StudentData in Game.roster:
		s.set_confused(false)
	_refresh_bubbles()''',
     '''	for s: StudentData in Game.roster:
		s.confusion = 0.0
	_refresh_bubbles()'''),

    ('''func assign_work_to_class() -> int:
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work(Game.rng, 0.0):
			n += 1
	return n''',
     '''func assign_work_to_class() -> int:
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n'''),

    ('var _purchased: Array = []',
     'var lesson_left: float = 0.0\nvar _purchased: Array = []'),
])

# ------------------------------------------------------------ student.gd
edit("scripts/actors/student.gd", [
    ('		1.0 - data.work_timer / StudentData.WORK_SECONDS, 0.0, 1.0)',
     '		data.work_fraction(), 0.0, 1.0)'),
])
print("done")
