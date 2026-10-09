extends Node2D

## A room you hold, visited (Oct 2026, the school-as-a-place tier).
##
## A staffed room's door in the corridor used to open a screen. Now it opens
## the room: its own six children at their desks, the teacher you hired at the
## front, as much furniture as you have bought it, and yesterday's lesson
## playing out again -- the same frames the WATCH screen steps through
## (RoomSim's history), shown as the children and the teacher instead of as a
## list. A stuck child puts their bubble up, a noisy one their note, one who
## finishes jumps; the teacher walks to whoever needs them whenever the sim
## had them away from the front, and back again.
##
## A VISIT, NOT A SECOND ROOM TO TEACH -- the owner's call (2026-10-05) and
## this game's model: the player puppets one room, and a delegated room stays
## a RoomSim policy. Nothing here is graded, saved or ticked; no key you
## press in here changes anything. E at the front opens the watch screen (or,
## before the bell has rung on the room, the room's overview).
##
## One node serves every room: show_room(i) builds room i's children, teacher
## and furniture into it, and is called on every visit. PLACEMENT: parked at
## y=40000 in main.tscn, below the office -- a hidden StaticBody2D still
## collides, as the hallway learned.

## The player used the door back to the corridor.
signal exit_chosen()
## The player pressed E at the front -- main.gd opens the watch screen.
signal teacher_chosen(room_index: int)

const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")
const STUDENT_SCRIPT := preload("res://scripts/actors/student.gd")
const DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const TALK_SCRIPT := preload("res://scripts/interact/visit_talk.gd")
const PROP_DESK := preload("res://art/desk.png")
const PROP_CHAIR := preload("res://art/chair.png")

const ROOM_W := 384.0
const ROOM_H := 256.0
const WALL_FOOT := 48.0
const WINDOWS := [2, 8]
## Six desks in two rows of three, an aisle between each -- the class size
## a delegated room holds (Balance.school_class_size).
const DESK_SPOTS := [
	Vector2(112, 162), Vector2(208, 162), Vector2(304, 162),
	Vector2(112, 234), Vector2(208, 234), Vector2(304, 234),
]
## As in the mentor's room: a child sits one tile behind their desk. The
## teacher helps from the aisle beside it, at the child's shoulder -- in
## front of a back-row desk would be inside the wall.
const PUPIL_OFFSET := Vector2(0.0, -34.0)
const HELP_SPOT := Vector2(-30.0, -12.0)
## Where the teacher stands to teach, and the podium beside them.
const FRONT := Vector2(176, 100)
const PODIUM_AT := Vector2(216, 104)
## What the room has, always: its board, its clock.
const FIXED := [
	["vocab_board",   Vector2(192, 4),   "wall"],
	["wall_clock",    Vector2(300, 8),   "wall"],
	["podium",        PODIUM_AT,         "floor"],
]
## What furniture you have bought it shows, one more piece per level, up to
## Balance.furniture_steps: a delegated room buys its furniture as a level, not
## as pieces it places (Game.room_value), so this is how a level LOOKS.
const FURNISHED := [
	["plant",         Vector2(364, 254), "prop"],
	["bookshelf",     Vector2(362, 120), "floor"],
	["rug",           Vector2(208, 200), "rug"],
	["globe",         Vector2(40, 96),   "prop"],
	["reading_nook",  Vector2(56, 254),  "floor"],
]
## Seconds of the replay per frame of RoomSim's history (one frame per lesson
## second), and the pause at the bell before the day plays again.
const FRAME_TIME := 0.7
const BELL_PAUSE := 3.0
## How close counts as there (the teacher walks at Actor.SPEED).
const ARRIVE := 3.0

var room_index := -1
var pupils: Array = []
var teacher: Node = null
var talk: Interactable = null
var _frames: Array = []
var _frame := -1
var _clock := 0.0
var _target := FRONT
## What changes with the room (children, teacher, furniture): torn down and
## rebuilt by show_room(). The shell -- floor, walls, the door -- is built once.
var _contents: Array = []
var _built := false
## Which of RoomBuilder.ROOM_LOOKS this room wears -- its own floor and walls,
## so the rooms you hold are not six copies of one -- and the painted shell.
var _look := ""
var _room_art: Sprite2D = null


func _ready() -> void:
	add_to_group("visit_room")
	_build_shell()


func _build_shell() -> void:
	if _built:
		return
	_built = true
	_room_art = Sprite2D.new()
	_room_art.name = "RoomArt"
	_room_art.texture = _compose()
	_room_art.centered = false
	_room_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_room_art.position = Vector2(-Grid.TILE, -16.0)
	_room_art.z_index = -20
	add_child(_room_art)
	for seg: Rect2 in [
		Rect2(0.0, WALL_FOOT - 16.0, ROOM_W, 16.0),
		Rect2(0.0, ROOM_H, ROOM_W, 16.0),
		Rect2(-16.0, -16.0, 16.0, 120.0),
		Rect2(-16.0, 168.0, 16.0, ROOM_H - 168.0 + 16.0),
		Rect2(ROOM_W, -16.0, 16.0, ROOM_H + 32.0),
	]:
		add_child(_box(seg))
	var door := DOOR_SCRIPT.new()
	door.door_kind = "home"
	door.leads_out = true
	door.position = Vector2(-4.0, 136.0)
	door.set_pick_radius(28.0)
	door.chosen.connect(func(_k: String, _i: int) -> void: exit_chosen.emit())
	add_child(door)


## Fill the room with room `i` of Game.rooms: its children at their desks,
## its teacher at the front, its furniture, and its last day ready to replay.
func show_room(i: int) -> void:
	for n in _contents:
		if is_instance_valid(n):
			n.queue_free()
	_contents.clear()
	pupils.clear()
	teacher = null
	talk = null
	room_index = i
	if i < 0 or i >= Game.rooms.size():
		return
	var r: Dictionary = Game.rooms[i]
	_look = String(RoomBuilder.ROOM_LOOKS[i % RoomBuilder.ROOM_LOOKS.size()])
	_room_art.texture = _compose()
	for row: Array in FIXED:
		_add_prop(String(row[0]), row[1] as Vector2, String(row[2]))
	Balance.ensure_loaded()
	var level := clampi(int(r.get("furniture", 0)), 0, Balance.furniture_steps)
	var pieces := int(round(float(FURNISHED.size()) * float(level)
		/ float(maxi(1, Balance.furniture_steps))))
	for k in mini(pieces, FURNISHED.size()):
		var row: Array = FURNISHED[k]
		_add_prop(String(row[0]), row[1] as Vector2, String(row[2]))

	var roster: Array = r.get("roster", [])
	for k in DESK_SPOTS.size():
		var spot: Vector2 = DESK_SPOTS[k]
		_desk(spot)
		if k >= roster.size():
			continue
		var s: StudentData = roster[k]
		var pupil: Node = STUDENT_SCENE.instantiate()
		_keep(pupil)
		if pupil.has_node("Sprite2D"):
			(pupil.get_node("Sprite2D") as Sprite2D).texture = load("res://art/%s.png" % s.art)
		pupil.name = "Pupil_%d" % k
		pupil.position = spot + PUPIL_OFFSET
		pupil.idle_phase = float(k) * 0.9
		pupil.sit(Actor.DIR_DOWN)
		pupil._set_collision(false)
		pupil.z_index = int(spot.y) - 1
		pupils.append(pupil)

	var t: Dictionary = r.get("teacher", {})
	if not t.is_empty():
		teacher = STUDENT_SCENE.instantiate()
		_keep(teacher)
		if teacher.has_node("Sprite2D"):
			(teacher.get_node("Sprite2D") as Sprite2D).texture = \
				load("res://art/%s.png" % Staff.art_for(t))
		teacher.name = "Teacher"
		teacher.position = FRONT
		teacher.facing = Actor.DIR_DOWN
		teacher._set_collision(false)
		teacher.set_idle()
		talk = TALK_SCRIPT.new()
		talk.who = String(t.get("name", "the teacher"))
		talk.position = FRONT + Vector2(0, 34)
		talk.set_pick_radius(30.0)
		talk.used.connect(func(_by: Node) -> void: teacher_chosen.emit(room_index))
		_keep(talk)

	_frames = (r.get("last", {}) as Dictionary).get("history", [])
	_frame = -1
	_clock = 0.0
	_target = FRONT


func _keep(n: Node) -> void:
	add_child(n)
	_contents.append(n)


func _desk(spot: Vector2) -> void:
	var chair := Sprite2D.new()
	chair.texture = PROP_CHAIR
	chair.centered = false
	chair.position = spot + PUPIL_OFFSET - Vector2(PROP_CHAIR.get_width() * 0.5,
		PROP_CHAIR.get_height())
	chair.z_index = int(spot.y) - 2
	_keep(chair)
	var desk := Sprite2D.new()
	desk.texture = PROP_DESK
	desk.centered = false
	desk.position = spot - Vector2(PROP_DESK.get_width() * 0.5, PROP_DESK.get_height())
	desk.z_index = int(spot.y)
	_keep(desk)
	_keep(_box(Rect2(spot.x - 13.0, spot.y - 14.0, 26.0, 14.0)))


## One piece of the room, anchored as in the mentor's room: bottom-centre on
## the floor, top-centre on the wall.
func _add_prop(tex_name: String, anchor: Vector2, kind: String) -> void:
	var tex: Texture2D = load("res://art/%s.png" % tex_name)
	if tex == null:
		push_error("visit room: missing texture %s" % tex_name)
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.add_to_group("visit_dressing")
	match kind:
		"wall":
			spr.position = anchor - Vector2(w * 0.5, 0.0)
			spr.z_index = -10
		"rug":
			spr.position = anchor - Vector2(w * 0.5, h * 0.5)
			spr.z_index = -15
		_:
			spr.position = anchor - Vector2(w * 0.5, h)
			spr.z_index = int(anchor.y)
	_keep(spr)
	if kind == "floor":
		var bw := minf(w - 6.0, 28.0)
		_keep(_box(Rect2(anchor.x - bw * 0.5, anchor.y - 10.0, bw, 10.0)))


func _box(r: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	sh.shape = rect
	sh.position = r.position + r.size * 0.5
	b.add_child(sh)
	return b


## The room's shell from the classroom's tiles, origin (-TILE, -16), with
## WINDOWS in the back wall and the door in the left one -- the office's
## construction at this room's size.
func _compose() -> ImageTexture:
	var t := Grid.TILE
	var cols := int(ROOM_W / t)
	var w := int(ROOM_W) + 2 * t
	var h := int(ROOM_H) + 16 + t
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var src := Rect2i(0, 0, t, t)
	var floors: Array[Image] = []
	for i in RoomBuilder.FLOOR_VARIANTS:
		floors.append(RoomBuilder._tile_img("tile_floor_a%d" % i, _look))
		floors.append(RoomBuilder._tile_img("tile_floor_b%d" % i, _look))
	var wall := [RoomBuilder._tile_img("tile_wall_top0", _look), RoomBuilder._tile_img("tile_wall_top1", _look)]
	var win := [[RoomBuilder._tile_img("tile_window_l0", _look), RoomBuilder._tile_img("tile_window_r0", _look)],
		[RoomBuilder._tile_img("tile_window_l1", _look), RoomBuilder._tile_img("tile_window_r1", _look)]]
	var side := RoomBuilder._tile_img("tile_wall_side", _look)
	var bottom := RoomBuilder._tile_img("tile_wall_bottom", _look)
	var foot := int(WALL_FOOT) + 16
	var y := foot
	var row := 0
	while y < 16 + int(ROOM_H):
		for c in cols:
			var v := absi(c * 7919 + row * 104729) % RoomBuilder.FLOOR_VARIANTS
			im.blit_rect(floors[v * 2 + (c + row) % 2], src, Vector2i(t + c * t, y))
		y += t
		row += 1
	for c in cols:
		for r in 2:
			var img: Image = wall[r]
			for first: int in WINDOWS:
				if c == first or c == first + 1:
					img = win[r][c - first]
			im.blit_rect(img, src, Vector2i(t + c * t, foot - (2 - r) * t))
		im.blit_rect(bottom, src, Vector2i(t + c * t, 16 + int(ROOM_H)))
	var yy := 0
	while yy < h:
		im.blit_rect(side, src, Vector2i(0, yy))
		im.blit_rect(side, src, Vector2i(w - t, yy))
		yy += t
	im.blit_rect(RoomBuilder._tile_img("tile_door_top", _look), src, Vector2i(0, 16 + 104))
	im.blit_rect(RoomBuilder._tile_img("tile_door_bottom", _look), src, Vector2i(0, 16 + 136))
	return ImageTexture.create_from_image(im)


## The replay, and the hand-run y-sort for the two things that move in here
## (the teacher, and the player). Only while the room is on screen.
func _physics_process(delta: float) -> void:
	if not visible:
		return
	for c in get_children():
		if c is Actor and c.is_in_group("carrier"):
			(c as Node2D).z_index = int((c as Node2D).position.y)
	if teacher == null or not is_instance_valid(teacher):
		return
	_tick_replay(delta)
	_tick_teacher(delta)
	teacher.z_index = int(teacher.position.y)


## Step yesterday's frames: one every FRAME_TIME, then a pause at the bell,
## then from the top. A room the bell has not rung on yet has no frames: its
## class just sits there working, which is the truth of it.
func _tick_replay(delta: float) -> void:
	if _frames.is_empty():
		return
	_clock += delta
	var length := float(_frames.size()) * FRAME_TIME
	if _clock >= length + BELL_PAUSE:
		_clock = 0.0
		_frame = -1
	var f := mini(int(_clock / FRAME_TIME), _frames.size() - 1)
	if f != _frame:
		_frame = f
		show_frame(f)


## Put the room in the state of history frame `f`: every child's bubble, the
## jump of one who has just finished, and where the teacher is heading.
func show_frame(f: int) -> void:
	if f < 0 or f >= _frames.size():
		return
	var frame: Dictionary = _frames[f]
	var faces: Array = frame.get("faces", [])
	var before: Array = (_frames[f - 1] as Dictionary).get("faces", []) if f > 0 else []
	var needs := -1
	for k in mini(faces.size(), pupils.size()):
		var st := String((faces[k] as Dictionary).get("state", "working"))
		var was := String((before[k] as Dictionary).get("state", "working")) if k < before.size() else "working"
		var p: Node = pupils[k]
		match st:
			"stuck":
				p.set_bubble(true, Color.WHITE, STUDENT_SCRIPT.MARK_STUCK)
			"disrupting":
				p.set_bubble(true, Color(1.0, 0.45, 0.35), STUDENT_SCRIPT.MARK_NOISE)
			_:
				p.set_bubble(false)
		if st == "done" and was != "done":
			p.play_pose(Actor.POSE_JUMP)
		if needs < 0 and (st == "stuck" or st == "disrupting"):
			needs = k
	_target = FRONT
	if not bool(frame.get("at_front", true)) and needs >= 0:
		_target = DESK_SPOTS[needs] + HELP_SPOT


## Walk the teacher to where the frame wants them -- Actor.walk(), so it is
## the same stride and step sound as anyone else -- and stand them there,
## facing the child they came to, or the class from the front.
func _tick_teacher(delta: float) -> void:
	var to: Vector2 = _target - teacher.position
	if to.length() <= ARRIVE:
		if teacher.position != _target:
			teacher.position = _target
			teacher.facing = Actor.DIR_RIGHT if _target != FRONT else Actor.DIR_DOWN
			teacher.set_idle()
		return
	teacher.walk(to, delta)


## Just inside the door, facing in.
func entry_position() -> Vector2:
	return Vector2(40.0, 140.0)


## Centre the camera on the room (limits are GLOBAL: see mentor_room.gd).
func refresh_camera_limits(camera: Camera2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var centre: Vector2 = global_position + Vector2(ROOM_W, ROOM_H) * 0.5
	camera.limit_left = int(centre.x - view.x * 0.5)
	camera.limit_right = int(centre.x + view.x * 0.5)
	camera.limit_top = int(centre.y - view.y * 0.5)
	camera.limit_bottom = int(centre.y + view.y * 0.5)
