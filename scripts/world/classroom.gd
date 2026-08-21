extends Node2D

## The world root. Owns the grid, builds the room, spawns everyone, and runs
## the school day.
##
## Attached to the `World` node, which is y-sorted — so every child is drawn
## in the order its floor-anchor sits down the screen, and a teacher standing
## below a desk is drawn in front of it with no special casing.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")

## Where the teacher starts the day: front of the room, beside the podium.
const TEACHER_START := Vector2i(9, 3)

signal lesson_tick(seconds_left: float)
signal lesson_timed_out()
## The clock ran out on its own, rather than the teacher calling time. The
## results still have to reach a screen, exactly as they do from the podium.
signal lesson_auto_ended(results: Array)
signal test_auto_ended(results: Array)

signal work_finished(seat_index: int)
signal day_started(day: int)
signal item_move_requested(id: String, tile: Vector2i)
signal desk_move_requested(seat_index: int)
signal desks_changed()
signal quiz_requested()
## How many heard you, so the room can react. -1 means you had nothing left.
signal voice_raised(settled: int)
## The inspector has seen enough.
signal inspected(report: Dictionary)
signal curriculum_requested()
signal test_requested(lesson_id: String)
signal room_rebuilt()

## The bubble over a child the quiz caught out — cooler than the amber
## "stuck" one, because it is a different kind of problem.
const QUIZ_BUBBLE_TINT := Color(0.62, 0.82, 1.0)
## Messing about. Hot, because unlike the other two it gets WORSE while you
## are somewhere else.
const NOISE_BUBBLE_TINT := Color(1.0, 0.45, 0.35)

var grid := Grid.new()
var player: Actor = null
var students: Array[Actor] = []
var stations: Array = []
var podium: Interactable = null
var teacher_desk: Interactable = null
var bell: Interactable = null
var noticeboard: Interactable = null
## The way out, at the hole already in the left wall. Leads to the hallway.
var hall_door: Interactable = null
## Standing at the back on inspection days. Not in `students`, so nothing
## that walks the roster ever mistakes them for a child.
var inspector: Actor = null
var camera: Camera2D = null

var lesson_left: float = 0.0
## Ambient weather: seconds until the next mote is due. A day event whose
## id has no entry in WEATHER spawns nothing, which is deliberate — most
## days should still look like the plain room they have always been.
var _weather_due: float = 0.0
## id -> [colour, falls-rather-than-rises, seconds to cross the room,
## seconds between motes]. Purely cosmetic, so unlike a balance number
## this is allowed to live in code -- nothing here is read by the model
## a delegated room is graded against.
const WEATHER := {
	"wet_play": [Color(0.35, 0.55, 0.95, 0.9), true, 1.6, 0.3],
	"heatwave": [Color(0.95, 0.35, 0.1, 0.85), false, 1.8, 0.3],
	"sports_day": [Color(0.95, 0.5, 0.1, 0.85), false, 1.6, 0.32],
	"cold_snap": [Color(0.85, 0.93, 1.0, 0.95), true, 2.4, 0.4],
	"cleaning": [Color(1.0, 1.0, 1.0, 0.85), false, 1.1, 0.35],
}
var _purchased: Array = []
## Tiles the bought furniture is currently occupying, so they can be handed
## back when it moves or the room is cleared.
var _purchased_tiles: Array[Vector2i] = []

## Daily clutter -- trash and spills, mess.gd -- currently on the floor,
## waiting to be cleaned. Legwork with a flat coin tip (Balance.
## mess_clean_reward, see room_upkeep in balance.json) -- not a grade
## input, so the balance contract is untouched. How many spawn and which
## kinds ARE still a code const, same reasoning as WEATHER above: nothing
## about the SPAWNING is graded either, only the cleaning pays out.
const MESS_MIN := 1
const MESS_MAX := 3
const MESS_KINDS := ["trash", "trash", "spill"]   # trash twice as likely
var messes: Array[Interactable] = []


func _ready() -> void:
	# Explicit, because an autoload's _ready() does not fire under the custom
	# MainLoop the headless tests use. Initialising here means the game and
	# the tests take exactly the same path.
	Game.ensure_run()
	build()
	Game.room_changed.connect(_rebuild_purchased)
	Game.room_resized.connect(rebuild_room)
	# A new run builds a whole new roster. Without this the actor nodes stay
	# bound to the PREVIOUS run's StudentData -- the room carries on showing
	# and animating children who are no longer in the class, and every
	# change to the real roster is invisible. It never bit in play only
	# because the title screen reloads the scene straight afterwards, which
	# is luck rather than design.
	Game.run_started.connect(_rebind_to_new_run)


func build() -> void:
	RoomBuilder.build_floor(self)
	RoomBuilder.build_walls(self, grid)
	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()
	podium = RoomBuilder.build_podium(self, grid)
	for q in get_tree().get_nodes_in_group("quiz_caller"):
		if q is Interactable and not q.quiz_requested.is_connected(_on_quiz_requested):
			q.quiz_requested.connect(_on_quiz_requested)
	for t in get_tree().get_nodes_in_group("test_caller"):
		if t is Interactable and not t.test_requested.is_connected(_on_test_requested):
			t.test_requested.connect(_on_test_requested)
	teacher_desk = RoomBuilder.build_teacher_desk(self, grid)
	bell = RoomBuilder.build_bell(self, grid)
	noticeboard = RoomBuilder.build_noticeboard(self, grid)
	for c in get_tree().get_nodes_in_group("curriculum_board"):
		if c is Interactable and not c.curriculum_opened.is_connected(_on_curriculum_requested):
			c.curriculum_opened.connect(_on_curriculum_requested)
	hall_door = RoomBuilder.build_hall_door(self, grid)
	_purchased = RoomBuilder.build_purchased(self, grid)
	_connect_placed()
	_spawn_students()
	_spawn_player()
	_spawn_mess()
	refresh_inspector()


## New clutter for a new day. Any mess left uncleaned from before is simply
## gone -- there's no penalty system attached to this, so carrying it over
## would only be visual noise with no mechanic behind it.
func _clear_mess() -> void:
	for m in messes:
		if is_instance_valid(m):
			# Same reason mess.gd frees its own parent rather than itself:
			# `m` is the invisible Area2D, the sprite lives one level up on
			# the prop body -- freeing `m` alone would leave the art behind.
			var body := m.get_parent()
			if body != null:
				body.queue_free()
			else:
				m.queue_free()
	messes.clear()


func _spawn_mess() -> void:
	_clear_mess()
	var open := grid.free_tiles()
	if open.is_empty():
		return
	# Array.shuffle() draws from the engine's global RNG, which the
	# determinism rule bans -- everything random goes through Game.rng, so
	# this is a hand-rolled Fisher-Yates seeded from that instead.
	for i in range(open.size() - 1, 0, -1):
		var j: int = Game.rng.randi_range(0, i)
		var tmp := open[i]
		open[i] = open[j]
		open[j] = tmp
	var n: int = Game.rng.randi_range(MESS_MIN, MESS_MAX)
	for i in mini(n, open.size()):
		var kind: String = MESS_KINDS[Game.rng.randi() % MESS_KINDS.size()]
		var it := RoomBuilder.build_mess(self, open[i], kind)
		it.cleaned.connect(_on_mess_cleaned)
		messes.append(it)


func _on_mess_cleaned(mess: Interactable, _kind: String) -> void:
	messes.erase(mess)


## The inspector is IN THE ROOM on the day they visit, standing at the back
## where they can see everything and are in nobody's way.
##
## Being able to see them is most of the mechanic. The verdict arrives at the
## end of the lesson either way, but a judgement you can watch being formed
## is a different feeling from a number that turns up afterwards -- and it is
## the difference between a day that is announced and a day that is tense.
func refresh_inspector() -> void:
	var wanted: bool = Game.being_inspected()
	if wanted == (inspector != null and is_instance_valid(inspector)):
		return
	if not wanted:
		if inspector != null and is_instance_valid(inspector):
			inspector.queue_free()
		inspector = null
		return

	inspector = STUDENT_SCENE.instantiate()
	add_child(inspector)
	var tex: Texture2D = load("res://art/inspector.png")
	if tex != null and inspector.has_node("Sprite2D"):
		inspector.get_node("Sprite2D").texture = tex
	inspector.global_position = Grid.tile_to_world(_inspector_tile())
	# Standing, NOT sitting, and facing the class. They are not a pupil, and
	# seat_at() would put them in a chair pose on the floor.
	inspector.facing = Actor.DIR_UP
	inspector.set_idle()


## A free tile at the back, out of the way. Falls back through the row and
## then to anywhere free, so a room the player has packed with furniture
## cannot leave the inspector standing inside a bookcase.
func _inspector_tile() -> Vector2i:
	var y: int = Grid.H - 2
	for x in range(Grid.W - 3, 1, -1):
		var t := Vector2i(x, y)
		if grid.is_free(t) and Game.item_at(t).is_empty():
			return t
	for t: Vector2i in grid.free_tiles():
		if Game.item_at(t).is_empty():
			return t
	return Vector2i(Grid.W - 3, y)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Grid.tile_to_world(TEACHER_START)
	add_child(player)
	_attach_camera()


## A camera that follows the teacher, clamped to the room.
##
## At the opening 20x11 the room is EXACTLY the viewport, so the limits pin
## the camera dead still and the game looks and feels precisely as it always
## has — the whole-room-at-a-glance reading that the "?" bubble, the audio
## design and the Practised Eye perk were all justified against. It only
## starts to move once you have bought a room bigger than one screen, which
## is the point at which those arguments genuinely change.
func _attach_camera() -> void:
	if camera == null:
		camera = Camera2D.new()
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		player.add_child(camera)
	_refresh_camera_limits()
	camera.make_current()
	camera.reset_smoothing()


func _refresh_camera_limits() -> void:
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = Grid.W * Grid.TILE
	camera.limit_bottom = Grid.H * Grid.TILE


## Ambient weather for whatever today's day event is. Purely decorative —
## it changes nothing DayEvent's own hooks do not already change, it only
## makes the handful of days that roll something different actually LOOK
## different while you are standing in the room, not just on last night's
## report.
func _tick_weather(delta: float) -> void:
	var profile: Array = WEATHER.get(String(Game.event.get("id", "none")), [])
	if profile.is_empty():
		return
	_weather_due -= delta
	if _weather_due > 0.0:
		return
	var colour: Color = profile[0]
	var fall: bool = profile[1]
	var seconds: float = profile[2]
	_weather_due = float(profile[3])
	# Kept off the very top and bottom rows on purpose: the HUD's status
	# line and hint bar sit over those in screen space, and a mote is not
	# worth drawing where it will spawn already hidden under them.
	Fx.weather_mote(self, Vector2(0.0, 20.0),
		Vector2(Grid.W * Grid.TILE, Grid.H * Grid.TILE - 40.0),
		colour, fall, seconds)


## The room got bigger. Rebuild the geometry around the people in it.
##
## Everything the room is made of is torn down and rebuilt, exactly as a
## desk move does, and for the same reason: the floor image, the collision
## boxes, the grid cells and the interactables cannot be patched into
## agreement one edge case at a time. The students and the teacher are NOT
## room parts, so they stay exactly where they were standing.
func rebuild_room() -> void:
	for n in get_tree().get_nodes_in_group("room_part"):
		if n is Node and n.get_parent() == self:
			remove_child(n)
			n.queue_free()
	_purchased.clear()
	_purchased_tiles.clear()
	# Every mess body is a room_part too, and just got torn down above --
	# forget them rather than hold references to freed nodes.
	messes.clear()

	grid.rebuild()
	RoomBuilder.build_floor(self)
	RoomBuilder.build_walls(self, grid)
	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()
	podium = RoomBuilder.build_podium(self, grid)
	for q in get_tree().get_nodes_in_group("quiz_caller"):
		if q is Interactable and not q.quiz_requested.is_connected(_on_quiz_requested):
			q.quiz_requested.connect(_on_quiz_requested)
	for t in get_tree().get_nodes_in_group("test_caller"):
		if t is Interactable and not t.test_requested.is_connected(_on_test_requested):
			t.test_requested.connect(_on_test_requested)
	teacher_desk = RoomBuilder.build_teacher_desk(self, grid)
	bell = RoomBuilder.build_bell(self, grid)
	noticeboard = RoomBuilder.build_noticeboard(self, grid)
	for c in get_tree().get_nodes_in_group("curriculum_board"):
		if c is Interactable and not c.curriculum_opened.is_connected(_on_curriculum_requested):
			c.curriculum_opened.connect(_on_curriculum_requested)
	hall_door = RoomBuilder.build_hall_door(self, grid)
	_purchased = RoomBuilder.build_purchased(self, grid)
	_connect_placed()
	# The old mess bodies were room_parts and are already gone (above), so
	# this re-rolls fresh tiles rather than actually preserving anything --
	# their old tiles may not even exist in the resized grid.
	_spawn_mess()
	_refresh_camera_limits()
	room_rebuilt.emit()


## Everyone starts at the doorway and walks to their own chair. If a seat
## somehow can't be reached they are placed directly rather than left
## standing in the doorway forever.
func _spawn_students(walk_in: bool = true) -> void:
	var n := 0
	for s: StudentData in Game.roster:
		if s.seat_index < 0 or s.seat_index >= Layout.seat_count():
			continue
		var node: Actor = STUDENT_SCENE.instantiate()
		add_child(node)                  # in the tree before bind(), so $Sprite2D resolves
		node.bind(s)
		node.position = Grid.tile_to_world(Layout.DOOR)

		var seat: Vector2i = Layout.seat(s.seat_index)
		var path := grid.path(Layout.DOOR, seat)
		if not walk_in:
			node.seat_at(Grid.tile_to_world(seat))
		elif path.is_empty():
			push_warning("seat %d unreachable from the door — seating directly" % s.seat_index)
			node.seat_at(Grid.tile_to_world(seat))
		else:
			node.walk_to_seat(path, n * Balance.entry_stagger)
		var d: StudentData = s
		if not node.arrived.is_connected(_on_student_arrived):
			node.arrived.connect(func() -> void: _on_student_arrived(d))
		students.append(node)
		n += 1


## Deliberately _physics_process, not _process. The physics tick is a fixed
## step, so "five seconds of work" is exactly 300 frames and a test can
## assert on it. On the idle tick it would be however many variable-length
## frames the machine happened to render, which is not assertable at all.
func _physics_process(delta: float) -> void:
	if Game.phase == Game.Phase.LESSON:
		# The clock is what makes this a game rather than a chore list.
		# Without it nothing ended the lesson but the player, so you could
		# always reach every student and there was no triage to do.
		lesson_left = maxf(0.0, lesson_left - delta)
		lesson_tick.emit(lesson_left)
		_tick_weather(delta)
		# Passing a null rng is what makes a test silent: tick_work() only
		# ever stalls a student when it has one to roll with. Nobody gets
		# stuck in a test, because you would not be allowed to go and
		# unstick them if they did.
		var roll: RandomNumberGenerator = null if Game.test_active else Game.rng
		# A test is sat in silence and marks itself: nobody is teaching it,
		# so it runs at full rate regardless of where the teacher stands.
		var rate: float = 1.0 if Game.test_active else Game.work_rate()
		for s: StudentData in Game.roster:
			if s.tick_work(delta, roll, rate):
				_on_work_done(s)
		# who is sitting next to whom, and who has started playing up
		Game.tick_class(delta, roll)
		Game.tick_voice(delta)
		# The aide works the room while you teach.
		var taken := Game.tick_aide(delta)
		if taken != null:
			var st := station(taken.seat_index)
			if st != null:
				st.show_paper(false)
			Floater.pop(self, Grid.tile_to_world(
				Layout.seat(taken.seat_index)) + Vector2(0, -40),   # doubled, was -20
				"aide", Color(0.72, 0.86, 1.0))
		# Attention is fed by the teacher STANDING at the front, not by a
		# button press -- holding a key to teach and holding a key to walk
		# are the same finger, and the room is what you are steering.
		var at_front := false
		if player != null and is_instance_valid(player) and not Game.test_active:
			at_front = Game.can_teach_from(
				Grid.world_to_tile(player.global_position))
		Game.tick_attention(delta, at_front)
		Game.tick_uncollected(delta)
		if lesson_left <= 0.0:
			# THE CLOCK HAS TO ACTUALLY END THE LESSON.
			#
			# This used to emit lesson_timed_out and stop, and nothing in
			# the game listened to it. The clock hit zero and the day just
			# stayed there: still in LESSON, so the bell -- which only rings
			# in the afternoon -- never came on offer, and there was no way
			# left to end the day at all. Every test called world.end_day()
			# directly, so the suite never once walked to a landmark and
			# pressed the button a player would press.
			#
			# end_lesson() and end_test() both move to AFTERNOON, so the
			# phase check above is what stops this firing twice.
			lesson_timed_out.emit()
			if Game.test_active:
				test_auto_ended.emit(end_test())
			else:
				lesson_auto_ended.emit(end_lesson())
	_refresh_bubbles()


## The "?" over a stuck student and the finished sheet on their desk, both
## driven from STATE every frame rather than from a one-off event.
##
## The paper used to be shown only by _on_work_done(), which meant the
## display was correct only if this node happened to be the thing that
## advanced the work. Reading state instead makes the room always agree with
## the data, whoever moved it.
func _refresh_bubbles() -> void:
	for n: Actor in students:
		if n.data == null:
			continue
		# Three problems, three colours, in order of how fast they get worse
		# while you are somewhere else:
		#   red    messing about  -- SPREADS to the desks either side
		#   amber  stuck          -- frozen, but going nowhere
		#   blue   quiz-flagged   -- behind, but working
		#
		# is_VISIBLY_struggling, not is_struggling: a Quiet child sits on it
		# for a few seconds, which is what stops scanning for bubbles from
		# being the whole of the job.
		var noisy: bool = n.seated and n.data.disrupting
		var stuck: bool = n.seated and n.data.is_visibly_struggling()
		var flagged: bool = n.seated and n.data.quiz_flagged
		var tint := QUIZ_BUBBLE_TINT
		if noisy:
			tint = NOISE_BUBBLE_TINT
		elif stuck:
			tint = Color.WHITE
		n.set_bubble(noisy or stuck or flagged, tint)
	for st: Interactable in stations:
		var s := Game.student_in_seat(st.seat_index)
		st.show_paper(s != null and s.has_work_to_collect())


## Somebody sat down. If the lesson has already started they have missed
## the hand-out, so they get theirs now -- which is what makes starting
## before the whole class is settled a real option rather than a mistake.
func _on_student_arrived(s: StudentData) -> void:
	if s == null:
		return
	if Game.phase == Game.Phase.LESSON and s.work_state == StudentData.Work.NONE:
		s.assign_work()


func _on_work_done(s: StudentData) -> void:
	var st := station(s.seat_index)
	if st != null:
		st.show_paper(true)
	work_finished.emit(s.seat_index)


func station(seat_index: int) -> Interactable:
	for st: Interactable in stations:
		if st.seat_index == seat_index:
			return st
	return null


func student_node(seat_index: int) -> Actor:
	for n: Actor in students:
		if n.data != null and n.data.seat_index == seat_index:
			return n
	return null


func everyone_seated() -> bool:
	if students.is_empty():
		return false
	for n: Actor in students:
		if not n.seated:
			return false
	return true


# ------------------------------------------------------------- the day

## Podium, in the morning. Sets the whole class working.
func start_lesson() -> int:
	Balance.ensure_loaded()
	Game.set_phase(Game.Phase.LESSON)
	Game.quiz_done = false        # one quiz per lesson, so a new one re-arms it
	Game.quiz_focus = false       # and the focus it bought goes with it
	lesson_left = Game.lesson_length()
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n


## Podium, in the morning, on a unit you have taught enough times. Sits the
## whole class down for the unit test.
##
## Mechanically it IS a lesson — the clock runs, the work ticks — but every
## verb you have is switched off for the duration. That is the instrument:
## the one time the game asks what you built rather than what you are doing.
func start_test(lesson_id: String) -> int:
	Balance.ensure_loaded()
	if not Game.can_test(lesson_id):
		return -1
	Game.lesson = Curriculum.by_id(lesson_id)
	Game.subject = String(Game.lesson.get("name", "Test"))
	Game.test_active = true
	Game.quiz_done = true          # no quizzing your way through a test
	# Any flag left over from an earlier lesson goes with it. The blue
	# bubble means "go to that desk", and during a test the desk offers
	# nothing at all -- a signal you cannot act on is worse than none.
	for s: StudentData in Game.roster:
		s.quiz_flagged = false
		s.quiz_score = -1.0
	Game.set_phase(Game.Phase.LESSON)
	lesson_left = Balance.test_seconds
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n


## Papers in. Unlike end_lesson() this sets no homework — the unit is over.
func end_test() -> Array:
	lesson_left = 0.0
	var results := Game.grade_test()
	Game.set_phase(Game.Phase.AFTERNOON)
	# The bell settles them. Confusion was already cleared here; disruption
	# was not, so a child who had been playing up stayed "playing up" for the
	# whole afternoon -- red bubble over their head, "Have a word with Quinn"
	# offered at their desk -- with no lesson left to disrupt.
	#
	# Note the ORDER: the inspection above has already been taken, so the
	# inspector still sees exactly who was still going at the bell.
	for s: StudentData in Game.roster:
		s.confusion = 0.0
		s.disrupting = false
	_refresh_bubbles()
	for st: Interactable in stations:
		st.show_paper(false)
	return results


## "Right -- settle down." Reaches the desks near enough to hear it.
func raise_voice() -> int:
	if player == null:
		return -1
	var n := Game.raise_voice(Grid.world_to_tile(player.global_position))
	if n >= 0:
		Sfx.play("deny")            # a sterner noise than anything else here
		_refresh_bubbles()
	else:
		Sfx.play("blip")
	voice_raised.emit(n)
	return n


## Podium, mid-lesson. Stops the class, asks everyone a few questions, and
## charges the time to the lesson clock — which is the cost that makes it a
## decision rather than something you always do.
##
## The clock is never taken below zero: a quiz called with eight seconds
## left should end the lesson, not owe time to the next one.
func run_quiz() -> Dictionary:
	Balance.ensure_loaded()
	var result := Game.run_quiz()
	lesson_left = maxf(0.0, lesson_left - Balance.quiz_seconds_cost)
	_refresh_bubbles()
	if lesson_left <= 0.0:
		lesson_timed_out.emit()
	return result


## Podium, during a lesson. Grades everyone on what actually happened, then
## sets tonight's homework.
func end_lesson() -> Array:
	lesson_left = 0.0
	# Judged on the lesson they actually watched, BEFORE grading resets
	# anything -- who was still stuck or still playing up at the bell is
	# half of what they came to see.
	var report := Game.inspect() if Game.being_inspected() else {}
	var results := Game.grade_class()
	Game.assign_homework()
	Game.set_phase(Game.Phase.AFTERNOON)
	# The bell settles them. Confusion was already cleared here; disruption
	# was not, so a child who had been playing up stayed "playing up" all
	# afternoon -- red bubble up, "Have a word with Quinn" offered at their
	# desk -- with no lesson left to disrupt.
	#
	# Note the ORDER: the inspection above has already been taken, so the
	# inspector still sees exactly who was still going at the bell.
	for s: StudentData in Game.roster:
		s.confusion = 0.0
		s.disrupting = false
	_refresh_bubbles()
	for st: Interactable in stations:
		st.show_paper(false)
	if not report.is_empty():
		inspected.emit(report)
	return results


## The bell. Pays out, rolls overnight homework, and starts tomorrow with the
## class filing back in.
## The bell. Pays out, rolls overnight homework, and starts tomorrow.
##
## Milestones are checked HERE because the end of the day is the one moment
## the player is already reading a screen. Firing one mid-lesson would be an
## interruption; firing it here is a line on a report they wanted anyway.
func end_day() -> Dictionary:
	var report := Game.advance_day()
	report["rooms"] = Game.resolve_rooms()
	Game.tick_reputation(report["rooms"])
	report["reputation"] = Game.reputation
	report["milestones"] = Game.check_milestones()
	if player != null:
		player.drop_all_work()
		player.drop_all_homework()
	for st: Interactable in stations:
		st.show_paper(false)
	_respawn_students()
	_spawn_mess()
	refresh_inspector()
	day_started.emit(Game.day)
	return report


## A brand new run: throw away the actors bound to the previous roster and
## make new ones, ALREADY SEATED.
##
## Not the walk-in: that belongs to the start of a school day. This is the
## world catching up with a run that was replaced underneath it, and the
## class should simply be there.
func _rebind_to_new_run() -> void:
	for n: Actor in students:
		n.queue_free()
	students.clear()
	_spawn_students(false)
	if player != null:
		player.global_position = Grid.tile_to_world(TEACHER_START)


func _respawn_students() -> void:
	for n: Actor in students:
		n.queue_free()
	students.clear()
	_spawn_students()
	if player != null:
		player.global_position = Grid.tile_to_world(TEACHER_START)


## Rebuild just the bought furniture. Cheaper and far less error-prone than
## rebuilding the whole room, and it keeps the students where they are.
##
## Releasing the OLD tiles first is not optional: without it, removing or
## replacing an item left its cells blocked forever, so the floor slowly
## filled up with invisible obstacles that pathfinding still respected.
func _rebuild_purchased() -> void:
	for n: Node in _purchased:
		if not is_instance_valid(n):
			continue
		# Detach BEFORE freeing. queue_free() leaves a node in its groups and
		# in the physics world until the end of the frame, so a just-sold
		# bookshelf could still be found by the player's interact zone and by
		# get_nodes_in_group() — you could walk up to furniture that no
		# longer exists. remove_child takes it out immediately.
		n.get_parent().remove_child(n)
		n.queue_free()
	for t: Vector2i in _purchased_tiles:
		grid.set_cell(t, Grid.Cell.FREE)
	_purchased_tiles.clear()
	_purchased = RoomBuilder.build_purchased(self, grid)
	_connect_placed()
	for placed: Dictionary in Game.room_items:
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			_purchased_tiles.append(t)


## The desks are rebuilt whenever one of them moves, so their movers are new
## objects each time -- same reason _connect_placed() exists.
func _connect_desk_movers() -> void:
	for n in get_tree().get_nodes_in_group("desk_part"):
		if not (n is Node) or n.get_parent() != self:
			continue
		for c in n.get_children():
			if c is Interactable and c.has_signal("desk_move_requested"):
				if not c.desk_move_requested.is_connected(_on_desk_move_requested):
					c.desk_move_requested.connect(_on_desk_move_requested)


func _on_desk_move_requested(seat_index: int) -> void:
	desk_move_requested.emit(seat_index)


func _on_quiz_requested() -> void:
	quiz_requested.emit()


func _on_curriculum_requested() -> void:
	curriculum_requested.emit()


func _on_test_requested(lesson_id: String) -> void:
	test_requested.emit(lesson_id)


## Bought furniture is rebuilt from data, so its interactables are new
## objects each time and have to be reconnected.
func _connect_placed() -> void:
	for body: Node in _purchased:
		for c in body.get_children():
			if c is Interactable and c.has_signal("move_requested"):
				if not c.move_requested.is_connected(_on_move_requested):
					c.move_requested.connect(_on_move_requested)


func _on_move_requested(id: String, tile: Vector2i) -> void:
	item_move_requested.emit(id, tile)


## Put one desk somewhere else, and take its chair and its occupant with it.
##
## The seating is torn down and rebuilt wholesale rather than nudged in
## place. There are eight desks: rebuilding is cheap, and it means the grid
## cells, the collision boxes and the interactables can never drift out of
## step with where the desks actually are — which they would, one edge case
## at a time, if this tried to patch the difference.
func move_desk(seat_index: int, to: Vector2i) -> bool:
	var old_seats := Layout.seats().duplicate()
	if not Layout.move_seat(seat_index, to):
		return false

	# free the tiles the old arrangement was holding
	for t: Vector2i in old_seats:
		grid.set_cell(t, Grid.Cell.FREE)
		grid.set_cell(t + Layout.DESK_OFFSET, Grid.Cell.FREE)

	for n in get_tree().get_nodes_in_group("desk_part"):
		if n is Node2D and (n as Node2D).get_parent() == self:
			remove_child(n)
			n.queue_free()

	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()

	# whoever was sitting there is now sitting somewhere else
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null:
			node.seat_at(Grid.tile_to_world(Layout.seat(s.seat_index)))
	desks_changed.emit()
	return true


## Assign work to every seated student. Exposed so tests and future systems
## can drive it without faking an interaction.
func assign_work_to_class() -> int:
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n
