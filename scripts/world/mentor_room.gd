extends Node2D

## The mentor teacher's room, off the hallway.
##
## A small FIXED room the player walks into -- not one of the rooms you run
## (those are resolved by RoomSim and never entered). The desks in here are
## placed with real gaps between them, no two orthogonally adjacent, because
## the room itself is the demonstration the mentor's dialogue points at
## rather than a diagram of one. Nothing in here is graded, saved or ticked:
## it is a teaching aid you can stand in.
##
## PLACEMENT, the same lesson the hallway learned the hard way: a hidden
## StaticBody2D still collides. main.tscn parks this node far below
## everything else so its walls never overlap another scene's coordinate
## space -- hallway sits at y=10000, this at y=20000.

## The player used the door back to the hallway.
signal exit_chosen()
## The mentor has finished showing the chain dash with her own class and is
## back at the front -- hud.gd picks the dialogue up from here.
signal demo_finished()
## Her call-and-response is over -- main.gd gives the player back their feet.
signal call_demo_finished()

const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")
const DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const MENTOR_DESK_SCRIPT := preload("res://scripts/interact/mentor_desk.gd")
const PROP_DESK := preload("res://art/desk.png")
const PROP_CHAIR := preload("res://art/chair.png")
const MENTOR_TEX := preload("res://art/mentor.png")

const ROOM_W := 384.0
const ROOM_H := 288.0
## Desk anchor points, well apart -- no two share an edge OR a corner. The
## room reads as "room to breathe" before the mentor says a word about it.
const DESK_SPOTS := [
	Vector2(96, 168), Vector2(248, 138),
	Vector2(150, 244), Vector2(312, 232),
]

## The dressing. This room is the mentor's argument that a good classroom is
## DESIGNED, not packed -- a reading nook, a teacher corner and a maths
## station, each with real space around it, rather than a grid stuffed with
## the priciest furniture. A player should walk out with a picture of what
## their own room could be. Authored positions, not rng-placed, because a
## showcase is composed.
##
##   "wall"  hung flat, no floor contact, no collider, drawn behind actors
##   "rug"   flat on the floor, drawn under everything but the floor itself
##   "floor" stands on the floor: a small collider, y-sorted like a desk
##   "prop"  free-standing decoration, y-sorted, but NO collider
##   "hang"  from the ceiling, no collider, drawn over everything
const DRESSING := [
	# the display along the back wall -- spaced out, a gap left behind the
	# mentor on purpose (negative space behind the focal point)
	["alphabet_frieze", Vector2(44, 10),   "wall"],
	["whiteboard",      Vector2(128, 6),   "wall"],
	["wall_clock",      Vector2(250, 10),  "wall"],
	["class_banner",    Vector2(320, 8),   "wall"],
	# a reading nook in the near-left corner: the cosy anchor
	["rug",             Vector2(54, 244),  "rug"],
	["bookshelf",       Vector2(20, 210),  "floor"],
	["beanbag",         Vector2(46, 240),  "prop"],
	["floor_cushion",   Vector2(76, 254),  "prop"],
	["lamp",            Vector2(16, 250),  "prop"],
	["plant",           Vector2(12, 285),  "prop"],
	# a teacher corner against the right wall: worked-in, not showroom
	["teacher_desk",    Vector2(344, 104), "floor"],
	["supply_shelf",    Vector2(342, 24),  "wall"],
	["filing_cart",     Vector2(346, 168), "floor"],
	# a maths station in the far-right corner
	["number_line",     Vector2(150, 280), "wall"],
	["low_shelf",       Vector2(298, 268), "prop"],
	# odds and ends that make it lived-in
	["coat_hooks",      Vector2(32, 22),   "wall"],
	["paper_mobile",    Vector2(150, 26),  "hang"],
	["plant",           Vector2(370, 286), "prop"],
]

## Her own class: one pupil per desk, a recolour of the one character model
## like every other child in the game. Nothing about them is a StudentData.
const PUPIL_ART := ["student_b", "student_d", "student_e", "student_g"]
## Where a pupil sits relative to their desk's anchor -- on the chair behind
## it -- and where a teacher stands to answer them, in front of it.
## One tile behind the desk, the same as the classroom proper (Layout.DESK_OFFSET):
## the desk then hides a child's lap and not their face. It was -10 when the art
## was the old, shorter-headed cast and a desk 4px taller; with the LimeZu cast
## that sank the pupils right behind their desks, hair only.
const PUPIL_OFFSET := Vector2(0.0, -34.0)
const ANSWER_SPOT := Vector2(0.0, 20.0)
const MENTOR_HOME := Vector2(ROOM_W * 0.5, 80.0)

## The demonstration's pacing. Stage directions, not balance: nothing here
## is graded or saved, and the player's own chain runs off teacher.chain_*
## in balance.json, not off these.
const DEMO_LEAD := 0.9      ## hands up, a beat before she moves
const DEMO_DASH := 0.18     ## one lunge, desk to desk
const DEMO_BEAT := 0.3      ## the answer landing before the next lunge
const DEMO_GHOST := 0.03    ## seconds between trail ghosts
const PRACTICE_REST := 1.6  ## all hands down -> this long -> all back up

var mentor: Node = null
var pupils: Array = []      ## the seated Student nodes, DESK_SPOTS order
var desks: Array = []       ## their MentorDesk interactables, same order
var practising := false
var _built := false

enum Demo { OFF, LEAD, DASH, BEAT, RETURN }
var _demo: int = Demo.OFF
var _demo_t := 0.0
var _demo_queue: Array[int] = []
var _demo_at := -1
var _demo_from := Vector2.ZERO
var _ghost_t := 0.0
var _rest_t := 0.0


func _ready() -> void:
	add_to_group("mentor_room")
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.19, 0.17, 0.15)
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(ROOM_W, ROOM_H)
	floor_rect.z_index = -20
	add_child(floor_rect)

	# Walls as segments, with a gap in the left wall for the way back --
	# same construction as hallway._build_bounds().
	for seg: Rect2 in [
		Rect2(0.0, -16.0, ROOM_W, 16.0),                       # top
		Rect2(0.0, ROOM_H, ROOM_W, 16.0),                      # bottom
		Rect2(-16.0, -16.0, 16.0, 104.0),                      # left, above the door
		Rect2(-16.0, 168.0, 16.0, ROOM_H - 168.0 + 16.0),      # left, below the door
		Rect2(ROOM_W, -16.0, 16.0, ROOM_H + 32.0),             # right
	]:
		var b := StaticBody2D.new()
		b.collision_layer = 1
		b.collision_mask = 0
		var sh := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = seg.size
		sh.shape = rect
		sh.position = seg.position + seg.size * 0.5
		b.add_child(sh)
		add_child(b)

	# The spaced desks. Visual, with a small collider so you actually weave
	# between them -- the point is felt, not just seen.
	for spot: Vector2 in DESK_SPOTS:
		var chair := Sprite2D.new()
		chair.texture = PROP_CHAIR
		chair.centered = false
		# the chair stands where the pupil sits, not where the desk does
		chair.position = spot + PUPIL_OFFSET - Vector2(PROP_CHAIR.get_width() * 0.5,
			PROP_CHAIR.get_height())
		chair.z_index = int(spot.y) - 1
		add_child(chair)

		var desk := Sprite2D.new()
		desk.texture = PROP_DESK
		desk.centered = false
		desk.position = spot - Vector2(PROP_DESK.get_width() * 0.5,
			PROP_DESK.get_height())
		desk.z_index = int(spot.y)
		add_child(desk)

		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = spot
		var cs := CollisionShape2D.new()
		var cr := RectangleShape2D.new()
		cr.size = Vector2(26.0, 14.0)
		cs.shape = cr
		cs.position = Vector2(0.0, -7.0)
		body.add_child(cs)
		add_child(body)

	# Her class, one at each desk, and the desk's own hand-up/answer landmark.
	for i in DESK_SPOTS.size():
		var spot: Vector2 = DESK_SPOTS[i]
		var pupil: Node = STUDENT_SCENE.instantiate()
		add_child(pupil)
		if pupil.has_node("Sprite2D"):
			(pupil.get_node("Sprite2D") as Sprite2D).texture = \
				load("res://art/%s.png" % String(PUPIL_ART[i % PUPIL_ART.size()]))
		pupil.position = spot + PUPIL_OFFSET
		pupil.idle_phase = float(i) * 0.9     # so they don't breathe in unison
		pupil.sit(Actor.DIR_DOWN)
		pupil._set_collision(false)            # the desk is already solid
		pupil.z_index = int(spot.y) - 1        # behind their own desk
		pupil.add_to_group("mentor_pupil")
		pupils.append(pupil)

		var d: Interactable = MENTOR_DESK_SCRIPT.new()
		d.pupil = pupil
		d.position = spot + Vector2(0.0, -8.0)
		d.set_pick_radius(18.0)
		add_child(d)
		desks.append(d)

	# The dressing -- the room the mentor's dialogue actually points at.
	for i in DRESSING.size():
		var row: Array = DRESSING[i]
		_add_prop(i, String(row[0]), row[1] as Vector2, String(row[2]))

	# The mentor, up near the front. A recolour of the one character model,
	# exactly like the principal and the inspector -- not new artwork.
	mentor = STUDENT_SCENE.instantiate()
	add_child(mentor)
	if mentor.has_node("Sprite2D"):
		(mentor.get_node("Sprite2D") as Sprite2D).texture = MENTOR_TEX
	mentor.position = MENTOR_HOME
	mentor.facing = Actor.DIR_DOWN
	if mentor.has_method("set_idle"):
		mentor.set_idle()

	# The way back to the hallway. Same door script the hallway itself
	# instances, so the player's existing interact prompt works with no
	# special casing -- it just emits `chosen`, which we forward.
	var door := DOOR_SCRIPT.new()
	door.door_kind = "home"
	door.leads_out = true
	door.position = Vector2(-4.0, 130.0)
	door.set_pick_radius(28.0)
	door.chosen.connect(func(_k: String, _i: int) -> void: exit_chosen.emit())
	add_child(door)


## One piece of dressing. Sprites are un-centred, like the desks above, so
## `anchor` is the point the piece sits ON: bottom-centre for anything on
## the floor, top-centre for anything on the wall.
func _add_prop(idx: int, tex_name: String, anchor: Vector2, kind: String) -> void:
	var tex: Texture2D = load("res://art/%s.png" % tex_name)
	if tex == null:
		push_error("mentor room: missing dressing texture %s" % tex_name)
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.name = "prop_%d_%s" % [idx, tex_name]
	spr.add_to_group("mentor_dressing")
	match kind:
		"wall":
			spr.position = anchor - Vector2(w * 0.5, 0.0)
			spr.z_index = -10
		"hang":
			spr.position = anchor - Vector2(w * 0.5, 0.0)
			spr.z_index = 900
		"rug":
			spr.position = anchor - Vector2(w * 0.5, h * 0.5)
			spr.z_index = -15
		_:  # "floor" / "prop" -- bottom-centre on the anchor, y-sorted
			spr.position = anchor - Vector2(w * 0.5, h)
			spr.z_index = int(anchor.y)
	add_child(spr)

	if kind != "floor":
		return
	# A small collider hugging the wall it stands against, so the room feels
	# solid without turning the walkable space into a maze.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = anchor
	body.add_to_group("mentor_solid")
	var cs := CollisionShape2D.new()
	var cr := RectangleShape2D.new()
	cr.size = Vector2(minf(w - 6.0, 28.0), 10.0)
	cs.shape = cr
	cs.position = Vector2(0.0, -5.0)
	body.add_child(cs)
	add_child(body)


## Y-sort by hand for the two things that move in here -- the room is not a
## y-sorted node, and the desks carry their own z by their feet. Then the
## demonstration or the practice, whichever is running.
func _physics_process(delta: float) -> void:
	if mentor != null:
		mentor.z_index = int(mentor.position.y)
	for c in get_children():
		if c is Actor and c.is_in_group("carrier"):
			(c as Node2D).z_index = int((c as Node2D).position.y)
	if _demo != Demo.OFF:
		_tick_demo(delta)
	elif practising:
		_tick_practice(delta)


## How many of her class have a hand up right now.
func hands_up() -> int:
	var n := 0
	for d: Interactable in desks:
		if d.asking:
			n += 1
	return n


func demo_running() -> bool:
	return _demo != Demo.OFF


## The mentor shows the chain dash with her own class: every hand goes up,
## and she runs at them one after another -- lunge, answer, lunge, answer --
## never walking, never stopping to press anything. Then she walks back to
## the front and hud.gd says what the player just watched.
##
## Driven off physics frames rather than a Tween, so the suite can step it
## exactly the way it steps everything else.
func play_chain_demo() -> void:
	stop_practice()
	for d: Interactable in desks:
		d.raise_hand()
	_demo_queue = _demo_order()
	_demo = Demo.LEAD
	_demo_t = 0.0
	if mentor != null:
		mentor._set_collision(false)          # she runs the aisles, not into them
		mentor.facing = Actor.DIR_DOWN


## Nearest desk first, then the nearest to that -- the route a teacher
## would actually run. Fixed layout, so this never changes.
func _demo_order() -> Array[int]:
	var out: Array[int] = []
	var left: Array[int] = []
	for i in DESK_SPOTS.size():
		left.append(i)
	var at := MENTOR_HOME
	while not left.is_empty():
		var best: int = left[0]
		for i in left:
			if at.distance_to(_answer_spot(i)) < at.distance_to(_answer_spot(best)):
				best = i
		out.append(best)
		left.erase(best)
		at = _answer_spot(best)
	return out


func _answer_spot(i: int) -> Vector2:
	return (DESK_SPOTS[i] as Vector2) + ANSWER_SPOT


func _tick_demo(delta: float) -> void:
	_demo_t += delta
	match _demo:
		Demo.LEAD:
			if _demo_t >= DEMO_LEAD:
				_next_lunge()
		Demo.DASH:
			var f := clampf(_demo_t / DEMO_DASH, 0.0, 1.0)
			mentor.position = _demo_from.lerp(_answer_spot(_demo_at), f)
			_ghost_t += delta
			if _ghost_t >= DEMO_GHOST:
				_ghost_t = 0.0
				Fx.afterimage(mentor.get_node("Sprite2D") as Sprite2D, self)
			if f >= 1.0:
				mentor.facing = Actor.DIR_UP          # face the child she answers
				mentor.play_pose(Actor.POSE_HANDOFF)
				(desks[_demo_at] as Interactable).answer(mentor)
				_demo = Demo.BEAT
				_demo_t = 0.0
		Demo.BEAT:
			if _demo_t >= DEMO_BEAT:
				_next_lunge()
		Demo.RETURN:
			var to: Vector2 = MENTOR_HOME - mentor.position
			if to.length() <= 2.0:
				mentor.position = MENTOR_HOME
				mentor.velocity = Vector2.ZERO
				mentor.facing = Actor.DIR_DOWN
				mentor.set_idle()
				mentor._set_collision(true)
				_demo = Demo.OFF
				demo_finished.emit()
			else:
				mentor.walk(to, delta)


func _next_lunge() -> void:
	_demo_t = 0.0
	if _demo_queue.is_empty():
		_demo = Demo.RETURN
		return
	_demo_at = _demo_queue.pop_front()
	_demo_from = mentor.position
	var heading: Vector2 = _answer_spot(_demo_at) - _demo_from
	mentor.face_towards(to_global(_answer_spot(_demo_at)))
	Fx.smoke(self, _demo_from + Vector2(0.0, 2.0), heading, 6, 12.0, 2.0, 0.4)
	Sfx.play("blip")
	_ghost_t = 0.0
	_demo = Demo.DASH


## After the lesson, her class keeps putting hands up while the player is in
## the room, so there is always something to try the chain on. All four go
## up together once every hand is down and the room has rested a moment.
## "Class, class!" -- "Yes, yes!" Shown with her own four, the same drawing
## the player's call gets in the classroom (Fx.call_and_response()). Pure
## show: nothing about her pupils changes, and the hands stay where they were.
const CALL_DEMO_SECONDS := 2.6

func play_call_demo() -> void:
	if mentor == null or not is_instance_valid(mentor):
		call_demo_finished.emit()
		return
	Sfx.play("start")
	Fx.call_and_response(self, mentor, pupils, 300.0)
	get_tree().create_timer(CALL_DEMO_SECONDS).timeout.connect(func() -> void:
		call_demo_finished.emit())


func start_practice() -> void:
	practising = true
	_rest_t = PRACTICE_REST


func stop_practice() -> void:
	practising = false
	for d: Interactable in desks:
		if d.asking:
			d.asking = false
			d.pupil.set_bubble(false)


func _tick_practice(delta: float) -> void:
	if hands_up() > 0:
		_rest_t = 0.0
		return
	_rest_t += delta
	if _rest_t >= PRACTICE_REST:
		_rest_t = 0.0
		for d: Interactable in desks:
			d.raise_hand()


## Where a fresh arrival stands: just inside the door, facing in. Local
## coordinates -- main.gd sets the reparented player's `position` to this.
func entry_position() -> Vector2:
	return Vector2(40.0, 138.0)


## Pin the camera on the room. The room is smaller than one screen, so this
## centres the view on it rather than clamping to a box the view cannot fit
## inside.
##
## Camera2D limits are GLOBAL, and main.tscn parks this room at (0, 20000)
## so it cannot overlap the classroom. The original numbers here were
## room-LOCAL (-16 .. ROOM_H + 16), which pinned the camera 20,000px above
## the room and rendered an empty screen -- in the real game's own
## _enter_mentor() as much as in `Take a Screenshot.bat mentor`, since both
## call this same function. It was read as a screenshot-harness quirk for
## two sessions because test_mentor() asserts the room is DRESSED, which it
## always was; nothing asserted what the camera could see.
func refresh_camera_limits(camera: Camera2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var centre: Vector2 = global_position + Vector2(ROOM_W, ROOM_H) * 0.5
	camera.limit_left = int(centre.x - view.x * 0.5)
	camera.limit_right = int(centre.x + view.x * 0.5)
	camera.limit_top = int(centre.y - view.y * 0.5)
	camera.limit_bottom = int(centre.y + view.y * 0.5)
