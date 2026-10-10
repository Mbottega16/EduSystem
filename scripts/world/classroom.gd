extends Node2D

## The world root. Owns the grid, builds the room, spawns everyone, and runs
## the school day.
##
## Attached to the `World` node, which is y-sorted — so every child is drawn
## in the order its floor-anchor sits down the screen, and a teacher standing
## below a desk is drawn in front of it with no special casing.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")
## For the bubble-mark constants alone (STUDENT_SCRIPT.MARK_*). student.gd has no
## class_name, and the loop below walks `Array[Actor]`, so the names have to
## come off the script resource rather than off a typed node.
const STUDENT_SCRIPT := preload("res://scripts/actors/student.gd")

## Where the teacher starts the day: front of the room, beside the podium.
const TEACHER_START := Vector2i(9, 3)

signal lesson_tick(seconds_left: float)
signal lesson_timed_out()
## The clock ran out on its own, rather than the teacher calling time. The
## results still have to reach a screen, exactly as they do from the podium.
signal lesson_auto_ended(results: Array)
## Auto-teach resolved the whole lesson instantly. `data` is
## {"history": Array, "results": Array} -- see run_auto_lesson().
signal auto_lesson_resolved(data: Dictionary)
signal test_auto_ended(results: Array)

signal work_finished(seat_index: int)
signal day_started(day: int)
signal item_move_requested(id: String, tile: Vector2i)
signal desk_move_requested(seat_index: int)
signal desks_changed()
signal quiz_requested()
signal answer_all_requested()
## How many heard you, so the room can react. -1 means you had nothing left.
signal voice_raised(settled: int)
## The inspector has seen enough.
signal inspected(report: Dictionary)
## The boss paper: one line for the banner as each question opens, and the
## report when the paper is over.
signal fight_banner(text: String)
signal fight_ended(report: Dictionary)
signal curriculum_requested()
signal marking_requested()
## The grade book on your desk was opened (interact/grade_book.gd). Relayed
## by main.gd to the HUD, like marking.
signal grade_book_requested()
## Someone is at your desk and this one wants an answer, not a nod.
## Relayed by main.gd to the HUD, exactly like quiz/marking -- the
## room does not reach into a screen itself.
signal caller_requested(row: Dictionary, student: StudentData)
signal test_requested(lesson_id: String)
signal room_rebuilt()

## The bubble over a child the quiz caught out — cooler than the amber
## "stuck" one, because it is a different kind of problem.
const QUIZ_BUBBLE_TINT := Color(0.62, 0.82, 1.0)
## The child the boss paper has put up front to present: gold, because
## the instruction is the opposite of every other bubble -- not "go and
## fix", but "go and STAY".
const PRESENT_BUBBLE_TINT := Color(1.0, 0.87, 0.42)
## Messing about. Hot, because unlike the other two it gets WORSE while you
## are somewhere else.
const NOISE_BUBBLE_TINT := Color(1.0, 0.45, 0.35)
## A flare-up brewing -- hot orange, the one on a countdown. Brighter than
## the noise red so it reads as "now" against a room that may already have
## a disruption or two showing.
const FLARE_BUBBLE_TINT := Color(1.0, 0.7, 0.2)
## Two children talking (Game.tick_chat). A soft lilac: a cost, but the
## mildest one in the room -- it ends by itself, or the moment you walk over.
const CHAT_BUBBLE_TINT := Color(0.84, 0.77, 1.0)
## How long each of a talking pair holds the floor before the bubble goes
## across to the other one. Cosmetic -- nothing reads it back.
const CHAT_TURN := 0.8

var grid := Grid.new()
var player: Actor = null
var students: Array[Actor] = []
var stations: Array = []
var podium: Interactable = null
var teacher_desk: Interactable = null
var bell: Interactable = null
var noticeboard: Interactable = null
var ad_poster: Interactable = null
var cabinet: Interactable = null
## The way out, at the hole already in the left wall. Leads to the hallway.
var hall_door: Interactable = null
## Standing at the back on inspection days. Not in `students`, so nothing
## that walks the roster ever mistakes them for a child.
var inspector: Actor = null
## The examiner, at the front for exactly as long as the boss paper runs.
var examiner: Actor = null
var camera: Camera2D = null

var lesson_left: float = 0.0
## Ambient weather: seconds until the next mote is due. A day event whose
## id has no entry in WEATHER spawns nothing, which is deliberate — most
## days should still look like the plain room they have always been.
var _weather_due: float = 0.0
## The sunlight bands on the floor (RoomBuilder.build_sunlight) and when the
## next mote of dust drifts through one. Rebuilt with the room.
var _sunlight: Array = []
var _sun_due: float = 0.0
## Days with no sun to speak of: the light on the floor goes.
const OVERCAST := ["wet_play", "cold_snap"]
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
## The drawn particle a day's weather uses instead of a dust mote, where it
## has one: [strip, frames]. Ninja Adventure's (tools/free_manifest.json).
const WEATHER_ART := {
	"wet_play": [preload("res://art/fx_rain_anim.png"), 3],
	"cold_snap": [preload("res://art/fx_snow_anim.png"), 7],
	"cleaning": [preload("res://art/fx_sparkle_anim.png"), 7],
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
	Game.intro_desks_changed.connect(rebuild_desks_only)
	Game.chat_started.connect(_on_chat_started)
	Game.chat_ended.connect(_on_chat_ended)
	Game.worked_it_out.connect(_on_worked_it_out)
	# A new run builds a whole new roster. Without this the actor nodes stay
	# bound to the PREVIOUS run's StudentData -- the room carries on showing
	# and animating children who are no longer in the class, and every
	# change to the real roster is invisible. It never bit in play only
	# because the title screen reloads the scene straight afterwards, which
	# is luck rather than design.
	Game.run_started.connect(_rebind_to_new_run)


func build() -> void:
	# THE BUG THIS FIXES: `grid` is `Grid.new()` at property-init time --
	# before _ready() runs, before Game.ensure_run() has decided how big
	# the room actually is. Its AStarGrid2D region gets baked to whatever
	# Grid.W/H were at THAT moment, which can be stale (a bigger room
	# left over from the previous run in this same process) by the time
	# build() actually runs. rebuild_room() already knows to re-sync
	# after Game.expand_room() changes the size; the very first build()
	# never did, and every wall tile past the STALE width threw "Can't
	# set if point is disabled" -- caught, non-fatal, printed on every
	# single room build regardless.
	grid.rebuild()
	RoomBuilder.build_floor(self)
	_sunlight = RoomBuilder.build_sunlight(self)
	RoomBuilder.build_walls(self, grid)
	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()
	podium = RoomBuilder.build_podium(self, grid)
	for q in get_tree().get_nodes_in_group("quiz_caller"):
		if q is Interactable and not q.quiz_requested.is_connected(_on_quiz_requested):
			q.quiz_requested.connect(_on_quiz_requested)
	for aa in get_tree().get_nodes_in_group("answer_all_caller"):
		if aa is Interactable and not aa.answer_all_requested.is_connected(_on_answer_all_requested):
			aa.answer_all_requested.connect(_on_answer_all_requested)
	for t in get_tree().get_nodes_in_group("test_caller"):
		if t is Interactable and not t.test_requested.is_connected(_on_test_requested):
			t.test_requested.connect(_on_test_requested)
	teacher_desk = RoomBuilder.build_teacher_desk(self, grid)
	bell = RoomBuilder.build_bell(self, grid)
	noticeboard = RoomBuilder.build_noticeboard(self, grid)
	cabinet = RoomBuilder.build_cabinet(self, grid)
	RoomBuilder.build_decor(self, grid)
	ad_poster = RoomBuilder.build_ad_poster(self, grid)
	for c in get_tree().get_nodes_in_group("curriculum_board"):
		if c is Interactable and not c.curriculum_opened.is_connected(_on_curriculum_requested):
			c.curriculum_opened.connect(_on_curriculum_requested)
	for hw in get_tree().get_nodes_in_group("homework_desk"):
		if hw is Interactable and not hw.marking_requested.is_connected(_on_marking_requested):
			hw.marking_requested.connect(_on_marking_requested)
	_connect_grade_book()
	for rp in get_tree().get_nodes_in_group("interruption_desk"):
		if rp is Interactable and not rp.interruption_answered.is_connected(_on_interruption_answered):
			rp.interruption_answered.connect(_on_interruption_answered)
	hall_door = RoomBuilder.build_hall_door(self, grid)
	_purchased = RoomBuilder.build_purchased(self, grid)
	_connect_placed()
	_spawn_students()
	_spawn_player()
	_spawn_mess()
	refresh_inspector()
	refresh_examiner()


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


## One piece of mess, placed and wired -- shared by the day-start spawn
## below and _spawn_mid_lesson_mess() (see _tick_complications()).
func _place_mess(tile: Vector2i, kind: String) -> void:
	var it := RoomBuilder.build_mess(self, tile, kind)
	it.cleaned.connect(_on_mess_cleaned)
	messes.append(it)


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
		_place_mess(open[i], kind)


## The complication version: ONE extra piece, mid-lesson, additive rather
## than a full re-roll -- _spawn_mess() above stays the day-start "clear
## and reroll everything" version. Filters out tiles already holding a
## mess prop, since RoomBuilder.build_mess() does not itself block its
## tile the way furniture does -- an unguarded roll could otherwise stack
## two messes on one tile.
func _spawn_mid_lesson_mess() -> void:
	var occupied: Array[Vector2i] = []
	for m in messes:
		if is_instance_valid(m):
			occupied.append(Grid.world_to_tile((m as Node2D).get_parent().global_position))
	var open: Array[Vector2i] = []
	for t in grid.free_tiles():
		if not occupied.has(t):
			open.append(t)
	if open.is_empty():
		return
	var tile: Vector2i = open[Game.rng.randi_range(0, open.size() - 1)]
	var kind: String = MESS_KINDS[Game.rng.randi() % MESS_KINDS.size()]
	_place_mess(tile, kind)


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


## Where the teacher stands once they've taken their place. Every boot
## already puts the player here directly (above); the storyline cutscene
## is the one caller that wants a WALK ending at the same spot instead of
## starting there, and main.gd only ever holds `world` as a generic
## Node2D, so the constant isn't reachable from outside without this.
func teacher_start_world() -> Vector2:
	return Grid.tile_to_world(TEACHER_START)


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
	# Dragging the window edge changes how much room there is AROUND the
	# classroom, so the framing has to be recomputed then too -- not only
	# when the player buys a bigger room.
	if not get_viewport().size_changed.is_connected(_refresh_camera_limits):
		get_viewport().size_changed.connect(_refresh_camera_limits)


## Clamp the camera to the room -- or, when the room is SMALLER than the
## window, centre the room in the window instead.
##
## Both cases are live now that the stretch aspect is "expand": the room
## is 640x352 and the viewport is whatever shape the monitor is, so on
## anything but exactly 20:11 there is more viewport than room in at least
## one axis. Limits narrower than the view would otherwise pin the room
## against one edge with all the slack on the other side, which reads as
## the room having slipped rather than as it being framed. The same maths
## mentor_room.gd already uses for its own small room.
func _refresh_camera_limits() -> void:
	if camera == null:
		return
	var room := Vector2(Grid.W, Grid.H) * Grid.TILE
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	if room.x <= view.x:
		camera.limit_left = int(room.x * 0.5 - view.x * 0.5)
		camera.limit_right = int(room.x * 0.5 + view.x * 0.5)
	else:
		camera.limit_left = 0
		camera.limit_right = int(room.x)
	if room.y <= view.y:
		camera.limit_top = int(room.y * 0.5 - view.y * 0.5)
		camera.limit_bottom = int(room.y * 0.5 + view.y * 0.5)
	else:
		camera.limit_top = 0
		camera.limit_bottom = int(room.y)


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
	var drawn: Array = WEATHER_ART.get(String(Game.event.get("id", "none")), [null, 1])
	Fx.weather_mote(self, Vector2(0.0, 20.0),
		Vector2(Grid.W * Grid.TILE, Grid.H * Grid.TILE - 40.0),
		colour, fall, seconds, drawn[0], int(drawn[1]))


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
	_sunlight = RoomBuilder.build_sunlight(self)
	RoomBuilder.build_walls(self, grid)
	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()
	podium = RoomBuilder.build_podium(self, grid)
	for q in get_tree().get_nodes_in_group("quiz_caller"):
		if q is Interactable and not q.quiz_requested.is_connected(_on_quiz_requested):
			q.quiz_requested.connect(_on_quiz_requested)
	for aa in get_tree().get_nodes_in_group("answer_all_caller"):
		if aa is Interactable and not aa.answer_all_requested.is_connected(_on_answer_all_requested):
			aa.answer_all_requested.connect(_on_answer_all_requested)
	for t in get_tree().get_nodes_in_group("test_caller"):
		if t is Interactable and not t.test_requested.is_connected(_on_test_requested):
			t.test_requested.connect(_on_test_requested)
	teacher_desk = RoomBuilder.build_teacher_desk(self, grid)
	bell = RoomBuilder.build_bell(self, grid)
	noticeboard = RoomBuilder.build_noticeboard(self, grid)
	cabinet = RoomBuilder.build_cabinet(self, grid)
	RoomBuilder.build_decor(self, grid)
	ad_poster = RoomBuilder.build_ad_poster(self, grid)
	for c in get_tree().get_nodes_in_group("curriculum_board"):
		if c is Interactable and not c.curriculum_opened.is_connected(_on_curriculum_requested):
			c.curriculum_opened.connect(_on_curriculum_requested)
	for hw in get_tree().get_nodes_in_group("homework_desk"):
		if hw is Interactable and not hw.marking_requested.is_connected(_on_marking_requested):
			hw.marking_requested.connect(_on_marking_requested)
	_connect_grade_book()
	for rp in get_tree().get_nodes_in_group("interruption_desk"):
		if rp is Interactable and not rp.interruption_answered.is_connected(_on_interruption_answered):
			rp.interruption_answered.connect(_on_interruption_answered)
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
##
## Held at the door entirely while the opening scene still has desks in
## the cabinet -- there is nowhere for them to sit yet. main.gd calls
## intro_bring_students_in() once the last desk is out.
func _spawn_students(walk_in: bool = true) -> void:
	if Game.desks_in_store > 0:
		return
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


## The room's own small life, every frame and in every phase: the sun on the
## floor (gone on an overcast day), dust drifting through it on a fair day
## that has no weather of its own, and the day's own decoration -- the
## birthday balloons, or what sits on the desk on a cold snap, a book fair and
## the rest (RoomBuilder.EVENT_DESK). Pure decoration: engine randf, never
## Game.rng, and nothing reads it back.
func _process(delta: float) -> void:
	_tick_ambient(delta)


func _tick_ambient(delta: float) -> void:
	var day := String(Game.event.get("id", "none"))
	var sunny := not OVERCAST.has(day)
	for b: Dictionary in _sunlight:
		var n: Node2D = b["node"]
		if is_instance_valid(n) and n.visible != sunny:
			n.visible = sunny
	for n in get_tree().get_nodes_in_group("event_decor"):
		var today := n is Node2D and String(n.get_meta("event", "")) == day
		if n is Node2D and (n as Node2D).visible != today:
			(n as Node2D).visible = today
	if not sunny or _sunlight.is_empty() or not WEATHER.get(day, []).is_empty():
		return
	_sun_due -= delta
	if _sun_due > 0.0:
		return
	_sun_due = randf_range(0.6, 1.4)
	var pick: Dictionary = _sunlight[randi() % _sunlight.size()]
	var r: Rect2 = pick["rect"]
	Fx.sun_mote(self, r, randf_range(4.5, 7.0))


## Deliberately _physics_process, not _process. The physics tick is a fixed
## step, so "five seconds of work" is exactly 300 frames and a test can
## assert on it. On the idle tick it would be however many variable-length
## frames the machine happened to render, which is not assertable at all.
func _physics_process(delta: float) -> void:
	if Game.phase == Game.Phase.LESSON and Game.fight != null:
		# The boss paper: its own clock, its own moves, no work ticking.
		# `fight != null` rather than fight_active(): the tick is also what
		# CLOSES a paper that has just run out, and a paper driven to its
		# end by hand (a test, a screenshot) must still be closed by the
		# room rather than falling through to the ordinary lesson below.
		_tick_fight(delta)
	elif Game.phase == Game.Phase.LESSON:
		# The clock is what makes this a game rather than a chore list.
		# Without it nothing ended the lesson but the player, so you could
		# always reach every student and there was no triage to do.
		lesson_left = maxf(0.0, lesson_left - delta)
		Game.answer_all_cooldown = maxf(0.0, Game.answer_all_cooldown - delta)
		Game.tick_boost(delta)
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
			# A child you never got their materials to on a materials day
			# works slower. Off during a written test (rate is already forced
			# to 1.0 there: nobody is teaching it). It slows the work, it
			# never touches the record. (A crammed seating plan used to cost
			# a hidden slowdown here too; that is the chatter below now.)
			var s_rate: float = rate
			if not Game.test_active:
				s_rate *= Game.supply_rate_mult(s)
			if s.tick_work(delta, roll, s_rate):
				_on_work_done(s)
		# who is sitting next to whom, and who has started playing up
		Game.tick_class(delta, roll)
		# and whether a calm child is about to -- the catchable warning the
		# dash exists to answer. Silent in a written test, same as the rest.
		if roll != null:
			# Desks that touch get talking, unless you are standing by them.
			Game.tick_chat(delta, roll, teacher_tile())
			# ...and a child stuck behind a study folder looks it up.
			Game.tick_desk_tops()
			_tick_flares(delta, roll)
			_tick_complications(delta, roll)
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
		var attn_before := Game.attention
		Game.tick_attention(delta, at_front)
		# The teach beat: the mirror of Game.class_drifted()'s own downward
		# crossing, fired the other way. Attention only rises while
		# `teaching` is true, so this can only ever land while you are
		# actually stood at the front doing the thing it is praising.
		if at_front and Game.phase == Game.Phase.LESSON \
				and attn_before < Balance.teach_drift_hint_below \
				and Game.attention >= Balance.teach_drift_hint_below \
				and player != null and is_instance_valid(player):
			Sfx.play("confirm")
			Fx.puff(self, player.global_position + Vector2(0, -10),
				Color(1.0, 0.95, 0.7))
			Floater.pop(self, player.global_position + Vector2(0, -36),
				"with you", Color(1.0, 0.95, 0.7))
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
	elif Game.phase == Game.Phase.AFTERNOON:
		# The end-of-session bell rush counts down here. Dormant unless
		# Balance.bell_rush_enabled -- tick_bell_rush() returns at once when
		# no round is running.
		Game.tick_bell_rush(delta)
	_refresh_bubbles()
	# The janitor, unlike the aide above, is NOT inside the LESSON-only
	# block: mess isn't lesson-gated (see mess.gd), so cleaning it up for
	# you shouldn't be either.
	if Game.tick_janitor(delta) and not messes.is_empty():
		var swept: Interactable = messes[0]
		var at: Vector2 = swept.get_parent().global_position
		swept.auto_complete()
		Floater.pop(self, at + Vector2(0, -20), "janitor",
			Color(0.72, 0.86, 1.0))
	_layout_notices()


## One rung of the stack, and how far sideways a column may step before it
## climbs instead. RUNGS caps the search rather than the height anything
## realistically reaches: twenty-four desks all shouting at once is the
## worst case the room can physically hold, and it settles inside a few
## rungs because each column only has to clear the ones already down.
const NOTICE_STEP := 7.0
const NOTICE_SIDE := 16.0
const NOTICE_RUNGS := 24
## Breathing room between two notices. Touching is not overlapping, but two
## bars that share an edge read as one bar twice as long -- so the layout
## keeps a gap rather than merely avoiding a collision.
const NOTICE_GAP := 1.0


## Lay every notice in the room out so that NO TWO OVERLAP, however many are
## up at once — the owner's own requirement, after a room of desks pushed
## together buried half the class's bubbles behind each other.
##
## Placement, not physics. An earlier pass pushed the sprites apart with
## springs, which settles into something overlap-free only when it happens
## to, and never when a cluster is tight — exactly the case this exists for.
## This instead places each column in the first free slot: straight up from
## the head, then half a tile either side, then a rung higher, and so on.
## A slot is only taken if it touches nothing already placed, so "no
## overlap" is true by construction rather than by tuning.
##
## The finished sheet on a desk goes down first and never moves: it marks
## THAT desk, and a wandering sheet would be a lie about whose work is
## done. Everything else is placed around the sheets.
##
## Deterministic — seat order in, no randomness, no dependence on the frame
## rate. Two rooms in the same state lay out identically, which is what
## lets the suite assert on it at all.
func _layout_notices() -> void:
	var taken: Array[Rect2] = []
	for st: Interactable in stations:
		if st.paper != null and st.paper.visible and st.paper.texture != null:
			var size: Vector2 = st.paper.texture.get_size()
			taken.append(Rect2(st.paper.global_position - size / 2.0, size))

	var column: Array[Actor] = []
	for n: Actor in students:
		if n.data == null:
			continue
		if not n.has_notice():
			n.notice_offset = Vector2.ZERO
			continue
		column.append(n)
	# Seat order, so the same room always lays out the same way and a
	# column does not swap places with its neighbour because the class
	# happened to be built in a different order.
	column.sort_custom(func(a: Actor, b: Actor) -> bool:
		return a.data.seat_index < b.data.seat_index)

	for n: Actor in column:
		var box: Rect2 = n.notice_box()
		box.position += n.global_position
		var off := _free_slot(box, taken)
		n.notice_offset = off
		taken.append(Rect2(box.position + off, box.size))


## The first offset that puts `box` somewhere nothing else already sits.
## Tried in order: where it wants to be, then sideways, then a rung up —
## nearest-to-home first, so a notice only travels as far as it has to.
static func _free_slot(box: Rect2, taken: Array[Rect2]) -> Vector2:
	for rung in NOTICE_RUNGS:
		for side: float in [0.0, 1.0, -1.0, 2.0, -2.0]:
			var off := Vector2(side * NOTICE_SIDE, -float(rung) * NOTICE_STEP)
			var candidate := Rect2(box.position + off, box.size).grow(NOTICE_GAP)
			var clear := true
			for t: Rect2 in taken:
				if candidate.intersects(t.grow(NOTICE_GAP)):
					clear = false
					break
			if clear:
				return off
	return Vector2(0.0, -float(NOTICE_RUNGS) * NOTICE_STEP)


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
		var flaring: bool = n.seated and n.data.flaring()
		var noisy: bool = n.seated and n.data.disrupting
		var stuck: bool = n.seated and n.data.is_visibly_struggling()
		var flagged: bool = n.seated and n.data.quiz_flagged
		var presenting: bool = n.seated and Game.fight != null 			and Game.fight.presenting == n.data.id
		# Talking to a desk close by: the two turn to each other and the
		# bubble goes back and forth between them, one speaker at a time.
		var chatting: bool = n.seated and n.data.chatting()
		var partner: Actor = null
		if chatting:
			var other := Game.student_by_id(n.data.chat_with)
			partner = student_node(other.seat_index) if other != null else null
		if n.seated:
			n.face_partner(partner)
		# The mark says which of the three it is; the tint says how loud.
		# Both, not the tint alone -- see STUDENT_SCRIPT.MARK_ART.
		var tint := QUIZ_BUBBLE_TINT
		var mark: String = STUDENT_SCRIPT.MARK_BEHIND
		var shown: bool = flaring or noisy or stuck or presenting
		if flaring:
			tint = FLARE_BUBBLE_TINT
			mark = STUDENT_SCRIPT.MARK_FLARE
		elif noisy:
			tint = NOISE_BUBBLE_TINT
			mark = STUDENT_SCRIPT.MARK_NOISE
		elif stuck:
			tint = Color.WHITE
			mark = STUDENT_SCRIPT.MARK_STUCK
		elif presenting:
			tint = PRESENT_BUBBLE_TINT
			mark = STUDENT_SCRIPT.MARK_NERVES
		elif chatting:
			# Only the one talking right now; the listener's own bubble (a
			# quiz flag, say) waits until the conversation is over.
			shown = chat_speaking(n.data)
			tint = CHAT_BUBBLE_TINT
			mark = STUDENT_SCRIPT.MARK_CHAT
		else:
			shown = flagged
		n.set_bubble(shown, tint, mark)
		# Head down on the desk, held: a child who has stopped getting anything
		# out of this class, with no louder problem to show instead. Art only --
		# the bubble decision above is untouched and nothing here is a grade
		# input. The pose IS the read, which is why it raises no second bubble.
		var loud: bool = flaring or noisy or stuck or flagged or presenting or chatting
		n.set_slumped(n.seated and n.data.is_capped() and not loud)
	for st: Interactable in stations:
		var s := Game.student_in_seat(st.seat_index)
		st.show_paper(s != null and s.has_work_to_collect())


## Whether this half of a conversation is the one talking right now. The one
## who started it opens, and the floor changes hands every CHAT_TURN seconds.
func chat_speaking(s: StudentData) -> bool:
	if s == null or not s.chatting():
		return false
	var said: float = maxf(0.0, Balance.chat_seconds - s.chat_left)
	var lead_turn: bool = int(said / CHAT_TURN) % 2 == 0
	return lead_turn == s.chat_lead


## The tile the teacher is standing on, for Game.tick_chat(): close enough and
## nobody there gets talking. (-1, -1) when there is no teacher in THIS room --
## a test that never spawned one, or the teacher out in the corridor -- which
## the chatter reads as nobody watching.
func teacher_tile() -> Vector2i:
	if player == null or not is_instance_valid(player) or player.get_parent() != self:
		return Vector2i(-1, -1)
	return Grid.world_to_tile(player.global_position)


## Two children have got talking. One burst of babble (throttled, so a room
## that starts three conversations in a second says it once).
func _on_chat_started(_a_id: int, _b_id: int) -> void:
	Sfx.play_varied("chatter")


## A conversation stopped. Walking over says "shh" between the two desks, so
## the trip reads as having done something; a chat that ran its course and
## got loud shows the one who started it kicking off, the same flash every
## other way into messing about uses. Class, class! has its own rings and
## says nothing more here.
func _on_chat_ended(a_id: int, b_id: int, why: String) -> void:
	var a := Game.student_by_id(a_id)
	var b := Game.student_by_id(b_id)
	var na: Actor = student_node(a.seat_index) if a != null else null
	var nb: Actor = student_node(b.seat_index) if b != null else null
	match why:
		"hushed", "voice":
			if na != null:
				var at: Vector2 = na.global_position
				if nb != null:
					at = (na.global_position + nb.global_position) / 2.0
				Floater.pop(self, at + Vector2(0, -44), "shh!",
					CHAT_BUBBLE_TINT)
		"loud":
			if a != null:
				_flash_pose(a.id, Actor.POSE_CHAT)


## A stuck child looked it up in the study folder on their desk and is going
## again. Said quietly -- a word over the desk and a small puff, no sound of
## its own -- because it is the thing that happens while you are elsewhere,
## and it should read as the folder having done its job, not as an event.
func _on_worked_it_out(student_id: int) -> void:
	var s := Game.student_by_id(student_id)
	if s == null:
		return
	var at := Grid.tile_to_world(Layout.seat(s.seat_index))
	Floater.pop(self, at + Vector2(0, -40), "looked it up", Color(0.62, 0.86, 0.66))
	Fx.puff(self, at + Vector2(0, -10), Color(0.62, 0.86, 0.66))


## Somebody sat down. If the lesson has already started they have missed
## the hand-out, so they get theirs now -- which is what makes starting
## before the whole class is settled a real option rather than a mistake.
func _on_student_arrived(s: StudentData) -> void:
	if s == null:
		return
	if Game.phase == Game.Phase.LESSON and s.work_state == StudentData.Work.NONE 			and not Game.fight_active():
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
	Game.answer_all_cooldown = 0.0  # the mass-help skill comes back fresh too
	Game.call_cooldown = 0.0        # ...and so does the call-and-response
	Game.call_hold = 0.0
	lesson_left = Game.lesson_length()
	# Auto-teach fully replaces the per-student setup below: RoomSim's own
	# play_day() does its own reset_lesson()/assign_work() as part of
	# resolving the whole day, so doing it again here would just re-roll
	# a sheet nobody was ever going to see.
	if Game.auto_teach:
		auto_lesson_resolved.emit(run_auto_lesson())
		return Game.roster.size()
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n


## THE PROMISE THIS KEEPS, same as a delegated room's: run the actual
## lesson model against your OWN roster with a policy driving the
## decisions your feet would otherwise make, rather than a formula. What
## makes this different from a delegated room is the grading -- RoomSim's
## own grade_for() takes a flat room_value because a delegated room has
## no placed furniture to measure, but YOUR room does. So this throws
## RoomSim's grade away and hands off to end_lesson() instead, which
## grades through Game.grade_class() -- the exact function a lesson you
## played yourself is graded through, reading your ACTUAL room_score().
##
## Steady, not Veteran -- see Game.auto_teach's own comment for why.
func run_auto_lesson() -> Dictionary:
	var sim := RoomSim.play_day(Game.roster, Staff.archetype("steady"),
		0.0, Game.lesson, Game.rng)
	var results := end_lesson()
	return {"history": sim.get("history", []), "results": results}


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
		s.flare_left = 0.0          # the bell interrupts a brewing flare-up too
	_refresh_bubbles()
	for st: Interactable in stations:
		st.show_paper(false)
	return results


## "Right -- settle down." Reaches the desks near enough to hear it.
func raise_voice() -> int:
	if player == null:
		return -1
	# Snapshotted before the call, not asked for one -- Game.raise_voice()
	# only ever hands back HOW MANY it settled, never which desks, and its
	# int contract is not this file's to change. Diffing disrupting before
	# and after finds exactly the same set some other way: whoever it is
	# true for now who it was not true for a moment ago.
	var was_disrupting: Dictionary = {}
	for s: StudentData in Game.roster:
		was_disrupting[s.id] = s.disrupting
	var n := Game.raise_voice(Grid.world_to_tile(player.global_position))
	if n >= 0:
		Sfx.play("deny")            # a sterner noise than anything else here
		_refresh_bubbles()
		# One floater per desk that actually quieted down -- the same
		# text and colour desk_station.gd's own SETTLE already uses, so
		# settling one child by hand and settling a roomful with your
		# voice read as the same event.
		for s: StudentData in Game.roster:
			if was_disrupting.get(s.id, false) and not s.disrupting and s.seat_index >= 0:
				Floater.pop(self, Grid.tile_to_world(
					Layout.seat(s.seat_index)) + Vector2(0, -36),
					"sorry!", Color(1, 0.7, 0.5))
	else:
		Sfx.play("blip")
	voice_raised.emit(n)
	return n


## "Class, class!" -- "Yes, yes!" From anywhere in the room, mid-lesson,
## once the mentor has taught it: see Game.call_the_class() for the rule
## and its price. Everyone at their desk who is not busy playing up answers.
## A child messing about does NOT -- that is still the voice's job (C), and
## the room not answering is how you see who needs it.
signal class_called()

func call_the_class() -> bool:
	if player == null or not Game.call_the_class():
		if Game.call_response_taught and Game.phase == Game.Phase.LESSON:
			Sfx.play("blip")        # heard, but not now: no voice, or too soon
		return false
	Sfx.play("start")
	var kids: Array = []
	for n: Actor in students:
		if n.data != null and n.seated and not n.data.disrupting:
			kids.append(n)
	Fx.call_and_response(self, player, kids)
	class_called.emit()
	return true


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


## Podium, mid-lesson. The mass-help skill on its own key (J) -- see
## Game.run_answer_all(). Charges the time to the lesson clock, the same
## cost that makes the quiz a decision rather than a reflex, only steeper.
func run_answer_all() -> Dictionary:
	Balance.ensure_loaded()
	# Who the wave is about to reach: anyone stuck (a Quiet child sitting on
	# it too -- they get answered, so they get the pop) or flagged by the quiz.
	# Taken BEFORE the call, which clears all of it.
	var reached: Array[Actor] = []
	for n: Actor in students:
		if n.data != null and n.seated \
				and (n.data.is_struggling() or n.data.quiz_flagged):
			reached.append(n)
	var result := Game.run_answer_all()
	lesson_left = maxf(0.0, lesson_left - Balance.answer_all_seconds_cost)
	_refresh_bubbles()
	_answer_all_wave(reached)
	if lesson_left <= 0.0:
		lesson_timed_out.emit()
	return result


## THE BURST. Answer-all used to be a key press and some bubbles vanishing --
## nothing said "you just reached every desk at once". Now it leaves the
## teacher as a ring of light (Fx.shockwave), and each child it answered
## jumps, with a puff of chalk and a "got it", at the moment the edge of the
## wave actually passes their desk. Decoration only: the state changed in
## full above, before any of this draws.
const ANSWER_WAVE_RADIUS := 420.0
const ANSWER_WAVE_SECONDS := 0.85

func _answer_all_wave(reached: Array[Actor]) -> void:
	if player == null or not is_instance_valid(player) or not is_inside_tree():
		return
	var from := to_local(player.global_position) + Vector2(0, -16)
	Sfx.play("confirm")
	Fx.shockwave(self, from, ANSWER_WAVE_RADIUS, Color(1.0, 0.93, 0.62),
		ANSWER_WAVE_SECONDS)
	if player is Node2D:
		Fx.flash(player, Color(1.7, 1.6, 1.1), 0.3)
	Fx.shake(camera, 1.5, 0.2)
	for n: Actor in reached:
		var at := to_local(n.global_position) + Vector2(0, -30)
		var wait := Fx.wave_arrival(from.distance_to(at), ANSWER_WAVE_RADIUS,
			ANSWER_WAVE_SECONDS)
		get_tree().create_timer(wait).timeout.connect(func() -> void:
			if not is_instance_valid(n):
				return
			n.play_pose(Actor.POSE_JUMP)
			Fx.puff(self, at, Color(1.0, 0.95, 0.7, 0.95), 7)
			Floater.pop(self, at + Vector2(0, -10), "got it!", Color(1.0, 0.92, 0.55))
			Sfx.play_varied("help"))


## The boss paper, from the podium on the last morning of a boss term.
## Not a lesson: no hand, no work on the desks, nothing graded today. The
## examiner comes in, the clock is the paper's own, and the desks are the
## whole job until it is over. Returns how many sat it.
func start_boss_fight() -> int:
	Balance.ensure_loaded()
	var f := Game.start_boss_fight()
	lesson_left = f.seconds_left()
	refresh_examiner()
	_drain_fight_events()
	_refresh_bubbles()
	return Game.roster.size()


## One physics tick of the paper. Voice still recharges, the mass-help
## cooldown still drains, weather still drifts -- but no work ticks, no
## ordinary stalls or flares roll, and attention is not a thing: nobody is
## teaching, the paper is being sat.
func _tick_fight(delta: float) -> void:
	var f: BossFight = Game.fight
	Game.answer_all_cooldown = maxf(0.0, Game.answer_all_cooldown - delta)
	_tick_weather(delta)
	var where: Vector2i = Layout.PODIUM
	if player != null and is_instance_valid(player):
		where = Grid.world_to_tile(player.global_position)
	f.tick(delta, Game.rng, where)
	lesson_left = f.seconds_left()
	lesson_tick.emit(lesson_left)
	Game.tick_voice(delta)
	_drain_fight_events()
	if not f.active():
		fight_ended.emit(end_boss_fight())


## The paper is over: close the tally, calm the room, send the examiner
## home. end_lesson()'s shape, without the grading.
func end_boss_fight() -> Dictionary:
	lesson_left = 0.0
	var report := Game.end_boss_fight()
	_refresh_bubbles()
	for st: Interactable in stations:
		st.show_paper(false)
	refresh_examiner()
	return report


## Turn the fight's event list into things in the room: a banner line as a
## question opens, a word over the desk as each child's round resolves.
func _drain_fight_events() -> void:
	var f: BossFight = Game.fight
	if f == null:
		return
	for ev: String in f.events:
		var parts := ev.split(":")
		var kind := parts[0]
		var sid: int = int(parts[1]) if parts.size() > 1 else -1
		match kind:
			"breath":
				fight_banner.emit(f.question_text())
				Sfx.play_varied("paper")
			"round":
				Sfx.play("start")
			"rallied":
				_fight_pop(sid, "rose to it!", Color(0.55, 1.0, 0.6))
				_flash_pose(sid, Actor.POSE_JUMP)
			"held":
				_fight_pop(sid, "held", Color(0.9, 0.9, 0.8))
				# the neutral middle -- no pose, a pose here would be noise
			"dropped":
				_fight_pop(sid, "lost it", Color(1.0, 0.55, 0.5))
				Sfx.play("deny")
				_flash_pose(sid, Actor.POSE_SAD)
			"present":
				_fight_pop(sid, "up front", PRESENT_BUBBLE_TINT)
	f.events.clear()


func _fight_pop(sid: int, text: String, colour: Color) -> void:
	var s := Game.student_by_id(sid)
	if s == null or s.seat_index < 0:
		return
	var at := Grid.tile_to_world(Layout.seat(s.seat_index)) + Vector2(0, -36)
	Floater.pop(self, at, text, colour)
	Fx.puff(self, at + Vector2(0, 26), colour, 4)


## Cosmetic pose flash on a child's own node, found by id -- shared by the
## disrupting edge (a flare timing out, or an ignored interruption picking
## someone) and a boss-fight round's own outcome. Does nothing if the child
## has no seat right now, or no node exists for it; this is a one-shot
## flourish, never worth guarding harder than that.
func _flash_pose(sid: int, pose: int) -> void:
	var s := Game.student_by_id(sid)
	if s == null or s.seat_index < 0:
		return
	var n := student_node(s.seat_index)
	if n != null:
		n.play_pose(pose)


## The examiner stands at the front, beside the podium, facing the class,
## for exactly as long as the paper runs -- the same "you can SEE the
## judgement being formed" reasoning as the inspector, at the other end of
## the room so the two are never confused. Their own sprite when the art
## exists; the inspector's suit until it does.
func refresh_examiner() -> void:
	var wanted: bool = Game.fight_active()
	if wanted == (examiner != null and is_instance_valid(examiner)):
		return
	if not wanted:
		if examiner != null and is_instance_valid(examiner):
			examiner.queue_free()
		examiner = null
		return
	examiner = STUDENT_SCENE.instantiate()
	add_child(examiner)
	var path := "res://art/examiner.png"
	if not ResourceLoader.exists(path):
		path = "res://art/inspector.png"
	var tex: Texture2D = load(path)
	if tex != null and examiner.has_node("Sprite2D"):
		examiner.get_node("Sprite2D").texture = tex
	examiner.global_position = Grid.tile_to_world(_examiner_tile())
	examiner.facing = Actor.DIR_DOWN
	examiner.set_idle()


## Beside the podium, on whichever side is free; then anywhere free.
func _examiner_tile() -> Vector2i:
	var y: int = Layout.PODIUM.y + 1
	for dx: int in [3, -3, 4, -4, 5, -5]:
		var t := Vector2i(Layout.PODIUM.x + dx, y)
		if grid.is_free(t) and Game.item_at(t).is_empty():
			return t
	for t: Vector2i in grid.free_tiles():
		if Game.item_at(t).is_empty():
			return t
	return Vector2i(Layout.PODIUM.x + 3, y)


## Podium, during a lesson. Grades everyone on what actually happened, then
## sets tonight's homework.
func end_lesson() -> Array:
	lesson_left = 0.0
	# The bell ends the quicker-feet stretch too. A boost that outlived the
	# lesson it was won in would follow you into the next one, and nothing
	# downstream is balanced for a teacher who is permanently faster.
	Game.clear_boost()
	# Judged on the lesson they actually watched, BEFORE grading resets
	# anything -- who was still stuck or still playing up at the bell is
	# half of what they came to see.
	var report := Game.inspect() if Game.being_inspected() else {}
	var results := Game.grade_class()
	# XP has been earned here every single lesson since the game existed
	# and never once shown landing. One floater per desk, worded rather
	# than counted -- XP is the child's own growth, the same category the
	# "prose, never numbers" rule already keeps off their file page.
	for r: Dictionary in results:
		var s: StudentData = r.get("student")
		if s == null or s.seat_index < 0:
			continue
		var levelled: bool = int(r.get("levels", 0)) > 0
		Floater.pop(self, Grid.tile_to_world(Layout.seat(s.seat_index)) + Vector2(0, -36),
			"level up!" if levelled else "+xp",
			Color(1.0, 0.85, 0.3) if levelled else Color(0.65, 0.9, 1.0))
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
		s.flare_left = 0.0          # the bell interrupts a brewing flare-up too
	_refresh_bubbles()
	for st: Interactable in stations:
		st.show_paper(false)
	# The end-of-session rush, if it is switched on (it is not yet -- see
	# bell_rush in balance.json). A no-op otherwise.
	Game.start_bell_rush()
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
	refresh_examiner()
	day_started.emit(Game.day)
	return report



## Run `n` whole days without the teacher, and hand back one row per day.
##
## Built out of the calls a PLAYED day already makes, in the order it makes
## them -- start the lesson, resolve it, ring the bell -- rather than a
## second model of a day. A separate "what a skipped day is worth" formula
## is exactly the thing this project keeps refusing to write: the delegated
## rooms resolve through RoomSim, auto_teach resolves through RoomSim, and
## so does this.
##
## The caller is responsible for asking Game.skip_days_available() first;
## this clamps to it anyway, because a skip that ran through the exam would
## resolve the term on a screen nobody saw.
func run_skipped_days(n: int) -> Array:
	Balance.ensure_loaded()
	var rows: Array = []
	var want: int = mini(n, Game.skip_days_available())
	for i in want:
		var day_no: int = Game.day
		var subject: String = Curriculum.short_name(Game.lesson)
		# Exactly what start_lesson() sets up before it hands over. Not a
		# call to start_lesson() itself: that emits auto_lesson_resolved,
		# which puts the watch screen up -- right for one lesson you chose
		# to hand over, wrong five times in a row with no way past it.
		Game.set_phase(Game.Phase.LESSON)
		Game.quiz_done = false
		Game.quiz_focus = false
		Game.answer_all_cooldown = 0.0
		lesson_left = Game.lesson_length()
		run_auto_lesson()
		# No homework is set. Nobody was at the desk to set it, and that is
		# most of what a skipped day costs you -- see Balance skip._note.
		var report: Dictionary = end_day()
		# Read off advance_day()'s own report rather than re-deriving any of
		# it. The letter is the only thing not in there, and it comes from
		# the same grade_letter() every other screen prints.
		var avg := float(report.get("average", 0.0))
		rows.append({
			"day": day_no,
			"subject": subject,
			"average": avg,
			"letter": Game.grade_letter(avg),
			"coins": int(report.get("coins", 0)),
			"joined": String(report.get("joined", "")),
			"term_over": bool(report.get("term_over", false)),
		})
	return rows

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


## Take the class off the board -- the opening scene starts with an empty
## room, so main.gd clears the four that build() spawned before the
## teacher walks to the cabinet.
func clear_students() -> void:
	for n: Actor in students:
		n.queue_free()
	students.clear()


## Rebuild ONLY the desks, for the opening scene's pull-them-out beat.
## Not rebuild_room(): that re-rolls the day's mess off Game.rng and
## rebuilds every prop, and this fires once per desk. Frees every seat's
## grid cell first so build_desks() can re-block just the ones it builds.
##
## Returns the desk BODIES built this call, newest last -- so main.gd's
## cold-open desk-pull can land an Fx.land() on the one that just appeared
## rather than guessing which child of the y-sorted world is newest.
func rebuild_desks_only() -> Array:
	for n in get_tree().get_nodes_in_group("desk_part"):
		if n is Node and n.get_parent() == self:
			remove_child(n)
			n.queue_free()
	for i in Layout.seat_count():
		grid.set_cell(Layout.seat(i), Grid.Cell.FREE)
		grid.set_cell(Layout.desk_tile(i), Grid.Cell.FREE)
	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()
	_last_desks_built.clear()
	for st: Interactable in stations:
		var body: Node = st.get_parent()
		if body is StaticBody2D:
			_last_desks_built.append(body)
	return _last_desks_built


## The desk bodies from the last rebuild_desks_only(), newest last. Used by
## the cold open to animate each pulled desk in. Empty before any rebuild.
var _last_desks_built: Array = []

func newest_desk() -> StaticBody2D:
	if _last_desks_built.is_empty():
		return null
	var b: Object = _last_desks_built[_last_desks_built.size() - 1]
	return (b as StaticBody2D) if (b is StaticBody2D and is_instance_valid(b)) else null


## The last desk is out; bring the class in from the door. Called once by
## main.gd's intro cutscene.
func intro_bring_students_in() -> void:
	clear_students()
	_spawn_students(true)


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
		if Items.is_wall(String(placed["id"])):
			continue      # hung on the wall: it never marked a floor tile, so there is none to give back
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			_purchased_tiles.append(t)
	# The room's starting decor gives way to a bought wall piece (and returns
	# when that comes down), so it is rebuilt whenever the furniture changes.
	for n: Node in get_tree().get_nodes_in_group("seeded_decor"):
		n.get_parent().remove_child(n)
		n.queue_free()
	RoomBuilder.build_decor(self, grid)
	# ...and what stands on the desks (a study folder) is redrawn on them,
	# since placing or lifting one is a room change like any other.
	_dress_desks()


## Redraw what stands on every desk from Game.desk_items.
func _dress_desks() -> void:
	for st: Interactable in stations:
		if is_instance_valid(st) and st.get_parent() is Node2D:
			RoomBuilder.dress_desk(st.get_parent() as Node2D, st.seat_index)


## Flare-ups: a random, catchable warning that ONE calm child is about to
## kick off. Deliberately separate from the boredom/frustration routes into
## disruption in Game.tick_class -- those are things the player caused; this
## is the extra bit of urgency the dash exists to answer. One on the clock
## at a time, capped per day (Game._flares_today), scaled by today's event.
## Lives here rather than in Game because a flare is a thing in the room you
## walk to, not a fact about the roster -- so it never fires in the headless
## term simulator, which has no Classroom node ticking.
func _tick_flares(delta: float, rng: RandomNumberGenerator) -> void:
	var flare_active := false
	for s: StudentData in Game.roster:
		if s.flare_left <= 0.0:
			continue
		s.flare_left = maxf(0.0, s.flare_left - delta)
		if s.flare_left == 0.0:
			s.disrupting = true          # missed it -- the ordinary mechanic
			_flash_pose(s.id, Actor.POSE_CHAT)
		else:
			flare_active = true
	if flare_active or Game._flares_today >= Balance.flare_max_per_day:
		return
	var ev_mult: float = DayEvent.multiplier(Game.event, "stall_mult")
	for s: StudentData in Game.roster:
		if s.seat_index < 0 or s.disrupting or s.flaring():
			continue
		if rng.randf() < Balance.flare_onset * ev_mult * delta:
			s.flare_left = Balance.flare_countdown
			Game._flares_today += 1
			return


## Mid-lesson complications: a generalized flare-up (same catchable,
## capped-per-lesson shape), but the WHICH is decided by
## Complication.roll() rather than always being the same thing. Lives here
## for the same reason _tick_flares does -- it is a thing in the room, not
## a fact about the roster, so it never fires in the headless simulator.
func _tick_complications(delta: float, rng: RandomNumberGenerator) -> void:
	if not Game.interruption.is_empty():
		var left: float = float(Game.interruption.get("left", 0.0)) - delta
		if left <= 0.0:
			_resolve_ignored_interruption(Game.interruption)
			Game.interruption = {}
		else:
			Game.interruption["left"] = left
		return   # only one thing pending at a time
	if Game._complications_today >= Balance.comp_max_per_lesson:
		return
	var rate: float = Balance.comp_onset_per_second * Game.complication_density_mult()
	if rng.randf() >= rate * delta:
		return
	var row := Complication.roll(rng)
	Game._complications_today += 1
	match String(row.get("landmark", "")):
		"mess":
			_spawn_mid_lesson_mess()
		"desk":
			Game.interruption = row.duplicate()
			Game.interruption["left"] = float(row.get("ring_seconds", 8.0))
			# A row whose speaker is a child needs to know WHICH child before
			# the screen can show a face and a name. Picked here, off the
			# seeded rng, so replaying a seed brings the same one up.
			Game.interruption_student_id = -1
			if String(row.get("speaker", "")) == "student":
				var seated: Array[StudentData] = []
				for st: StudentData in Game.roster:
					if st.seat_index >= 0:
						seated.append(st)
				if seated.is_empty():
					Game.interruption = {}     # nobody to do the asking
					return
				Game.interruption_student_id = 					seated[rng.randi() % seated.size()].id


## Answered before it rang out -- costs real lesson seconds, pays coins.
## Instant, world-level payoff, same shape as raise_voice() -- no screen to
## open, so no main.gd relay is needed the way quiz/marking need one.
func _on_interruption_answered() -> void:
	if Game.interruption.is_empty():
		return
	var row := Game.interruption
	lesson_left = maxf(0.0, lesson_left - float(row.get("answer_cost_seconds", 5.0)))
	# A row carrying `choices` is a person, not a phone: it opens a screen and
	# pays nothing until the player has actually answered them. The clock above
	# is already spent either way -- stopping to talk costs you the seconds
	# whether or not you like what they say.
	if not (row.get("choices", []) as Array).is_empty():
		var who: StudentData = Game.student_by_id(Game.interruption_student_id)
		Game.interruption = {}
		Sfx.play("confirm")
		caller_requested.emit(row, who)
		if lesson_left <= 0.0:
			lesson_timed_out.emit()
		return
	Game.add_coins(int(row.get("answer_reward_coins", 0)))
	Game.interruption = {}
	Sfx.play("confirm")
	if teacher_desk != null:
		Floater.pop(self, teacher_desk.get_parent().global_position + Vector2(0, -36),
			"handled!", Color(0.6, 0.85, 1.0))
	if lesson_left <= 0.0:
		lesson_timed_out.emit()


## What one answer at your desk actually does. Every effect a choice can
## carry funnels through here, matched on `kind` against Complication.EFFECTS
## -- so a typo in the table is a caught test failure rather than a branch
## that silently pays nothing.
##
## NOTHING HERE TOUCHES A CHILD'S RECORD. That is the whole reason this can
## pay out freely without the balance contract moving: coins buy items, and
## items are already clamped by room_cap; the boost is teacher pace, and both
## contract rows already assume a perfect teacher or no teacher at all.
## `disrupt_one` is the exception that proves it -- it is a COST, and it uses
## the same path an ignored interruption already used.
func resolve_caller_choice(row: Dictionary, index: int, who: StudentData) -> String:
	var choices: Array = row.get("choices", [])
	if index < 0 or index >= choices.size():
		return ""
	var choice: Dictionary = choices[index]
	for eff: Dictionary in choice.get("effects", []):
		match String(eff.get("kind", "")):
			"coins":
				Game.add_coins(int(eff.get("value", 0)))
			"reputation":
				Game.nudge_reputation(float(eff.get("value", 0.0)))
			"disrupt_one":
				# The child who was standing at your desk is the one it lands
				# on, when there is one -- they are the one you just turned
				# away. Otherwise it falls back to whoever is settled, exactly
				# as an ignored interruption does.
				var picked: StudentData = who
				if picked == null or picked.seat_index < 0 or picked.disrupting:
					picked = null
					for st: StudentData in Game.roster:
						if st.seat_index >= 0 and not st.disrupting:
							picked = st
							break
				if picked != null:
					picked.disrupting = true
					_flash_pose(picked.id, Actor.POSE_CHAT)
			"item":
				var id := String(eff.get("id", ""))
				if id != "" and not Items.get_def(id).is_empty():
					Game.store_id(id)
			"boost":
				Game.start_boost()
	return String(choice.get("says", ""))


## Let it ring out instead. Matched on the row's own ignored_effect so a
## future complication can reuse either existing effect for free, or add a
## new match arm for a genuinely new one.
func _resolve_ignored_interruption(row: Dictionary) -> void:
	match String(row.get("ignored_effect", "")):
		"disrupt_one":
			for s: StudentData in Game.roster:
				if s.seat_index >= 0 and not s.disrupting:
					s.disrupting = true
					_flash_pose(s.id, Actor.POSE_CHAT)
					break
		"reputation":
			Game.nudge_reputation(-float(row.get("ignored_value", 1.0)))


## What a dash does when the teacher is standing on `tile`, decided by any
## furniture tagged "lane" or "clutter" in the items table. The effect is on
## the walkable tiles ORTHOGONALLY BESIDE the item (you cannot stand on the
## furniture itself) -- a clear rug makes a runway, a crate makes you weave.
## "clutter" always wins a tie. Read straight off Game.room_items, which is a
## handful of entries, and only while a dash is live -- no caching needed.
func dash_tile_kind(tile: Vector2i) -> String:
	var found := ""
	for placed: Dictionary in Game.room_items:
		var id := String(placed["id"])
		var d := Items.get_def(id)
		var is_lane: bool = bool(d.get("lane", false))
		var is_clutter: bool = bool(d.get("clutter", false))
		if not (is_lane or is_clutter):
			continue
		for t: Vector2i in Items.footprint(id, placed["tile"]):
			if absi(t.x - tile.x) + absi(t.y - tile.y) <= 1:
				if is_clutter:
					return "clutter"
				found = "lane"
	return found


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


func _on_answer_all_requested() -> void:
	answer_all_requested.emit()


func _on_curriculum_requested() -> void:
	curriculum_requested.emit()


func _on_marking_requested() -> void:
	marking_requested.emit()


## The desk is rebuilt with the room, so its grade book is a new object each
## time and has to be reconnected -- same as everything above it.
func _connect_grade_book() -> void:
	for gb in get_tree().get_nodes_in_group("grade_book"):
		if gb is Interactable and not gb.grade_book_opened.is_connected(_on_grade_book_requested):
			gb.grade_book_opened.connect(_on_grade_book_requested)


func _on_grade_book_requested() -> void:
	grade_book_requested.emit()


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
