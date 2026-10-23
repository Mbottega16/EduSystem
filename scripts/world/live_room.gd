class_name LiveRoom
extends Node2D

## One classroom in the grade wing (Oct 2026): a class of another stage of the
## school, seen from the corridor, running forever.
##
## The owner asked for "the pokemon like rooms that perpetually look like
## they're running": rooms you walk past that are busy whether you look or
## not. Each is six children at their desks and a teacher, in its stage's own
## floor, walls and furniture (STAGES), and a loop of the small things any
## classroom does. A hand goes up and the teacher walks over. Two neighbours
## whisper until the teacher looks their way. Someone finishes and jumps. A
## sleepy one nods off and is woken. The teacher turns to write on the board.
## How often each one happens is the stage's flavour, the same flavour its
## rules give your own class (age_tiers in balance.json): the little ones jump,
## middle school chats, high school dozes, college sits through a lecture.
##
## DECORATION ONLY. Nothing here is a class you hold. Nothing is graded, saved
## or read by the game, and nothing draws from Game.rng: what happens next is a
## fixed hash of the room and the beat number, so a room plays the same way
## every time and cannot move the seeded run (the window butterfly's rule).
## It is silent, too: a bubble here pops without the "stuck" sound, or four
## rooms of children would drown out the corridor.
##
## ORIGIN: the top-left of the back wall. The back wall is WALL px tall, the
## floor FLOOR px under it, the room W px wide. The walls round it are the
## corridor's (Hallway paints them).

const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")
const STUDENT_SCRIPT := preload("res://scripts/actors/student.gd")
const PROP_ANIM_SCRIPT := preload("res://scripts/world/prop_anim.gd")
const PROP_DESK := preload("res://art/desk.png")
const PROP_CHAIR := preload("res://art/chair.png")

const W := 320.0
const WALL := 64.0
const FLOOR := 128.0
## The back wall's windows, by tile column.
const WINDOW_COLS := [4, 5]

## Two rows of three, aisles between: the class a delegated room holds.
const DESK_SPOTS := [
	Vector2(148, 124), Vector2(212, 124), Vector2(276, 124),
	Vector2(148, 184), Vector2(212, 184), Vector2(276, 184),
]
## A child sits one tile behind their desk, as in every other room.
const PUPIL_OFFSET := Vector2(0.0, -34.0)
## The teacher helps from the aisle at the child's left.
const HELP_SPOT := Vector2(-32.0, -8.0)
## The front of the class is the left end: the board on the wall above it.
const FRONT := Vector2(92, 152)
const BOARD_SPOT := Vector2(56, 98)
## The aisle between the two rows, where the teacher crosses the room.
const AISLE_Y := 140.0
const ARRIVE := 3.0

## How the room's loop is paced, in seconds. Decoration, so these stay here
## with the butterfly's timetable rather than in balance.json.
const BEAT := 2.0          ## something new may start every beat
const HELP_TIME := 1.6     ## the teacher at a child's desk
const THANKS_TIME := 1.1   ## the heart after help
const CHAT_TIME := 4.4     ## a whisper nobody stops
const CHAT_TURN := 0.9     ## who is talking swaps this often
const CHAT_LOOK := 2.2     ## the teacher at the front looks over after this
const DOZE_WAIT := 2.4     ## before the teacher goes to wake a sleeper
const BOARD_TIME := 3.6    ## writing on the board

const CHAT_TINT := Color(0.84, 0.77, 1.0)
const DOZE_TINT := Color(0.75, 0.85, 1.0)
const THANKS_TINT := Color(0.55, 0.95, 0.65)

## Each stage's room, keyed by the tier id in balance.json (tiers.order).
## look: a RoomBuilder look. wall: [art, centre x, top y] on the back wall.
## floor: [art, bottom-centre x, bottom y]. rug: [art, centre]. cast: the six
## children's sheets. flavour: how often each thing starts, out of the total.
const STAGES := {
	"elementary": {
		"look": "room_e", "teacher": "staff_b",
		"cast": ["student_a", "student_m", "student_c", "student_e", "student_k", "student_q"],
		"wall": [["vocab_board", 56, 8], ["curriculum_poster", 240, 12], ["cuckoo_clock", 296, 10]],
		"floor": [["plant", 306, 190], ["terrarium", 34, 190]],
		"rug": ["rug", Vector2(56, 114)],
		"flavour": {"ask": 4, "chat": 2, "doze": 0, "finish": 4, "board": 2, "rest": 1},
	},
	"middle": {
		"look": "room_a", "teacher": "staff_a",
		"cast": ["student_d", "student_f", "student_g", "student_n", "student_p", "student_s"],
		"wall": [["vocab_board", 56, 8], ["world_map", 240, 10], ["wall_clock", 298, 12]],
		"floor": [["globe", 304, 190], ["bookshelf", 20, 190]],
		"flavour": {"ask": 3, "chat": 5, "doze": 1, "finish": 2, "board": 2, "rest": 1},
	},
	"high": {
		"look": "room_c", "teacher": "staff_c",
		"cast": ["student_h", "student_i", "student_j", "student_o", "student_r", "student_w"],
		"wall": [["vocab_board", 56, 8], ["noticeboard", 240, 14], ["wall_clock", 298, 12]],
		"floor": [["computer", 20, 190], ["desk_fan", 306, 190]],
		"flavour": {"ask": 2, "chat": 2, "doze": 5, "finish": 1, "board": 2, "rest": 2},
	},
	"college": {
		"look": "room_b", "teacher": "staff_d",
		"cast": ["student_l", "student_t", "student_u", "student_v", "student_x", "student_b"],
		"wall": [["vocab_board", 56, 8], ["certificate", 226, 12], ["certificate", 262, 12],
			["wall_clock", 300, 12]],
		"floor": [["bookshelf", 20, 190], ["state_flag", 306, 190]],
		"flavour": {"ask": 2, "chat": 1, "doze": 1, "finish": 1, "board": 5, "rest": 2},
	},
}

var stage_id := ""
var pupils: Array = []
var teacher: Node = null
## What the teacher is doing: front, board, help, wake, or walking to one of
## them ("to_board", "to_help", "to_wake", "back").
var job := "front"
## Beats so far: how many times the room has had the chance to start something.
var beats := 0

## Per child: {s: work|ask|chat|doze|thanks, until, partner, since}.
var _kid: Array = []
var _t := 0.0
var _beat_at := 0.0
var _seed := 0
var _flavour: Dictionary = {}
var _job_kid := -1
var _job_until := 0.0
var _path: Array[Vector2] = []
var _stage: Node2D = null


## Build the room for stage `id`. `seed` desynchronises rooms of the same
## layout; it is the room's own and never Game.rng.
func setup(id: String, seed: int) -> void:
	stage_id = id
	_seed = seed
	var def: Dictionary = STAGES.get(id, STAGES["elementary"])
	_flavour = def.get("flavour", {})
	var shell := Sprite2D.new()
	shell.name = "Shell"
	shell.texture = compose(String(def.get("look", "")))
	shell.centered = false
	shell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shell.z_index = -2
	add_child(shell)
	for row: Array in def.get("wall", []):
		_wall_prop(String(row[0]), Vector2(float(row[1]), float(row[2])))
	var rug: Array = def.get("rug", [])
	if not rug.is_empty():
		var tex: Texture2D = load("res://art/%s.png" % String(rug[0]))
		if tex != null:
			var r := Sprite2D.new()
			r.texture = tex
			r.position = rug[1]
			r.z_index = -1
			add_child(r)

	# Everything that stands on the floor is y-sorted against everything else,
	# anchored at its feet, so a child sits behind their desk and the teacher
	# walks between the rows rather than over them.
	_stage = Node2D.new()
	_stage.name = "Stage"
	_stage.y_sort_enabled = true
	add_child(_stage)
	for row: Array in def.get("floor", []):
		_floor_prop(String(row[0]), Vector2(float(row[1]), float(row[2])))

	var cast: Array = def.get("cast", [])
	for k in DESK_SPOTS.size():
		var spot: Vector2 = DESK_SPOTS[k]
		_standing(PROP_CHAIR, spot + PUPIL_OFFSET)
		var p: Node = STUDENT_SCENE.instantiate()
		_stage.add_child(p)
		p.name = "Pupil_%d" % k
		if k < cast.size():
			(p.get_node("Sprite2D") as Sprite2D).texture = load("res://art/%s.png" % String(cast[k]))
		p.position = spot + PUPIL_OFFSET
		p.idle_phase = float(k) * 0.9 + float(seed % 7)
		p.sit(Actor.DIR_DOWN)
		p._set_collision(false)
		pupils.append(p)
		_kid.append({"s": "work", "until": 0.0, "partner": -1, "since": 0.0})
		_standing(PROP_DESK, spot)

	teacher = STUDENT_SCENE.instantiate()
	_stage.add_child(teacher)
	teacher.name = "Teacher"
	(teacher.get_node("Sprite2D") as Sprite2D).texture = \
		load("res://art/%s.png" % String(def.get("teacher", "staff_a")))
	teacher.position = FRONT
	teacher._set_collision(false)
	teacher.facing = Actor.DIR_RIGHT
	teacher.set_idle()
	# Rooms start out of step with each other, not all on the same beat.
	_beat_at = 0.5 + float(seed % 5) * 0.4


## The back wall and floor in `look`, one image, origin at the wall's top-left.
static func compose(look: String) -> ImageTexture:
	var t := Grid.TILE
	var cols := int(W / t)
	var rows := int((WALL + FLOOR) / t)
	var im := Image.create(cols * t, rows * t, false, Image.FORMAT_RGBA8)
	var src := Rect2i(0, 0, t, t)
	var floors: Array[Image] = []
	for i in RoomBuilder.FLOOR_VARIANTS:
		floors.append(RoomBuilder._tile_img("tile_floor_a%d" % i, look))
		floors.append(RoomBuilder._tile_img("tile_floor_b%d" % i, look))
	var wall := [RoomBuilder._tile_img("tile_wall_top0", look), RoomBuilder._tile_img("tile_wall_top1", look)]
	var win := [[RoomBuilder._tile_img("tile_window_l0", look), RoomBuilder._tile_img("tile_window_r0", look)],
		[RoomBuilder._tile_img("tile_window_l1", look), RoomBuilder._tile_img("tile_window_r1", look)]]
	for ty in rows:
		for tx in cols:
			var img: Image
			if ty < 2:
				img = wall[ty]
				var wi := WINDOW_COLS.find(tx)
				if wi >= 0:
					img = win[ty][wi]
			else:
				# Hashed by position like every floor here: stable, not reshuffled.
				var v := absi(tx * 7919 + ty * 104729) % RoomBuilder.FLOOR_VARIANTS
				img = floors[v * 2 + (tx + ty) % 2]
			if img != null:
				im.blit_rect(img, src, Vector2i(tx, ty) * t)
	return ImageTexture.create_from_image(im)


## Hung on the back wall, top-centre at `at`. An animated piece plays its strip.
func _wall_prop(art: String, at: Vector2) -> void:
	var tex: Texture2D = load("res://art/%s.png" % art)
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, 0.0)
	spr.position = at
	spr.z_index = -1
	add_child(spr)
	_animate(spr, art)


## Stands on the floor, bottom-centre at `at`, in the y-sorted stage.
func _floor_prop(art: String, at: Vector2) -> void:
	var tex: Texture2D = load("res://art/%s.png" % art)
	if tex == null:
		return
	var spr := _standing(tex, at)
	_animate(spr, art)


func _standing(tex: Texture2D, at: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	spr.position = at
	_stage.add_child(spr)
	return spr


## A shop item with an `anim` block plays it here as it does in your room.
func _animate(spr: Sprite2D, art: String) -> void:
	var anim: Variant = Items.get_def(art).get("anim", null)
	if not anim is Dictionary:
		return
	var strip: Texture2D = load("res://art/%s.png" % String((anim as Dictionary).get("art", "")))
	if strip == null:
		return
	var drive := Node.new()
	drive.set_script(PROP_ANIM_SCRIPT)
	drive.name = "PropAnim"
	spr.add_child(drive)
	# offset was set for the whole texture; a strip frame is narrower
	var frames := maxi(1, int((anim as Dictionary).get("frames", 1)))
	drive.setup(spr, strip, anim, 0.37 * float(_seed % 11))
	spr.offset.x = -strip.get_width() / float(frames) / 2.0


func _physics_process(delta: float) -> void:
	if is_visible_in_tree():
		tick(delta)


## Run the room `delta` seconds on. Public so a test can drive it headless.
func tick(delta: float) -> void:
	if teacher == null:
		return
	_t += delta
	_tick_kids()
	_tick_teacher(delta)
	if _t >= _beat_at:
		_beat_at = _t + BEAT
		beats += 1
		_beat()
	_dispatch()


## What the child at desk `k` is doing: work, ask, chat, doze or thanks.
func kid_state(k: int) -> String:
	return String((_kid[k] as Dictionary).get("s", "work")) if k >= 0 and k < _kid.size() else ""


# --- the beat: what starts next --------------------------------------------

## A fixed, well-mixed hash of the room, the beat and a slot. Never Game.rng.
func _hash(a: int, b: int) -> int:
	var h := (_seed + 1) * 73856093 ^ (a + 7) * 19349663 ^ (b + 3) * 83492791
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7FFFFFFF


func _beat() -> void:
	match _pick_kind():
		"ask":
			var k := _pick_kid()
			if k >= 0:
				_set_kid(k, "ask")
				(pupils[k] as Actor).play_pose(Actor.POSE_SAD)
		"chat":
			var pairs: Array = []
			for k in _kid.size() - 1:
				if k % 3 != 2 and kid_state(k) == "work" and kid_state(k + 1) == "work":
					pairs.append(k)
			if not pairs.is_empty():
				var a: int = pairs[_hash(beats, 2) % pairs.size()]
				_set_kid(a, "chat", CHAT_TIME, a + 1)
				_set_kid(a + 1, "chat", CHAT_TIME, a)
		"doze":
			var k := _pick_kid()
			if k >= 0:
				_set_kid(k, "doze", DOZE_WAIT)
		"finish":
			var k := _pick_kid()
			if k >= 0:
				(pupils[k] as Actor).play_pose(Actor.POSE_JUMP)
		"board":
			if job == "front":
				job = "to_board"
				_walk_to(BOARD_SPOT)


func _pick_kind() -> String:
	var total := 0
	for v: Variant in _flavour.values():
		total += int(v)
	if total <= 0:
		return "rest"
	var r := _hash(beats, 1) % total
	for key: String in _flavour.keys():
		r -= int(_flavour[key])
		if r < 0:
			return key
	return "rest"


## A child who is just working, picked by the hash; -1 if nobody is.
func _pick_kid() -> int:
	var free: Array = []
	for k in _kid.size():
		if kid_state(k) == "work":
			free.append(k)
	if free.is_empty():
		return -1
	return free[_hash(beats, 3) % free.size()]


func _set_kid(k: int, s: String, lasts: float = 0.0, partner: int = -1) -> void:
	_kid[k] = {"s": s, "until": _t + lasts, "partner": partner, "since": _t}
	var p: Actor = pupils[k]
	match s:
		"ask":
			_bubble(p, true, Color.WHITE, STUDENT_SCRIPT.MARK_STUCK)
		"doze":
			p.set_slumped(true)
			_bubble(p, true, DOZE_TINT, STUDENT_SCRIPT.MARK_DRIFT)
		"thanks":
			p.set_slumped(false)
			_bubble(p, true, THANKS_TINT, STUDENT_SCRIPT.MARK_HELPED)
		"chat":
			p.face_partner(pupils[partner] as Node2D)
		_:
			p.set_slumped(false)
			p.face_partner(null)
			_bubble(p, false)


## The bubble without the sound or the head-down pose student.set_bubble()
## plays for a child in YOUR room: here it is scenery.
func _bubble(p: Node, on: bool, tint: Color = Color.WHITE, mark: String = "") -> void:
	var b: Sprite2D = p.bubble
	if b == null:
		return
	if on:
		b.modulate = tint
		b.texture = STUDENT_SCRIPT.MARK_ART.get(mark, b.texture)
	if b.visible == on:
		return
	b.visible = on
	if on:
		b.scale = Vector2(0.4, 0.4)
		var tw := p.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- the children ------------------------------------------------------------

func _tick_kids() -> void:
	for k in _kid.size():
		var d: Dictionary = _kid[k]
		match String(d["s"]):
			"chat":
				var other := int(d["partner"])
				# The one talking has the bubble; it goes back and forth.
				var turn := int((_t - float(d["since"])) / CHAT_TURN) % 2
				var speaking := (turn == 0) == (k < other)
				_bubble(pupils[k], speaking, CHAT_TINT, STUDENT_SCRIPT.MARK_CHAT)
				# A teacher stood at the front looks over, and it stops.
				var looked := job == "front" and _t - float(d["since"]) >= CHAT_LOOK
				if looked and k < other:
					teacher.face_towards((pupils[k] as Node2D).global_position)
				if _t >= float(d["until"]) or (looked and _t - float(d["since"]) >= CHAT_LOOK + 0.6):
					_set_kid(k, "work")
			"thanks":
				if _t >= float(d["until"]):
					_set_kid(k, "work")


# --- the teacher -------------------------------------------------------------

## A teacher with nothing on goes to whoever needs them: a hand up first, then
## a sleeper who has been asleep long enough to be noticed.
func _dispatch() -> void:
	if job != "front" and job != "back" and job != "board":
		return
	var want := -1
	var wake := false
	for k in _kid.size():
		if kid_state(k) == "ask":
			want = k
			break
	if want < 0:
		for k in _kid.size():
			if kid_state(k) == "doze" and _t >= float((_kid[k] as Dictionary)["until"]):
				want = k
				wake = true
				break
	if want < 0:
		return
	_job_kid = want
	job = "to_wake" if wake else "to_help"
	_walk_to((DESK_SPOTS[want] as Vector2) + HELP_SPOT)


## Along the aisle between the rows, then up or down to the spot: the
## teacher never cuts across a desk.
func _walk_to(goal: Vector2) -> void:
	_path.clear()
	var at: Vector2 = teacher.position
	if absf(at.x - goal.x) > ARRIVE:
		_path.append(Vector2(at.x, AISLE_Y))
		_path.append(Vector2(goal.x, AISLE_Y))
	_path.append(goal)


func _tick_teacher(delta: float) -> void:
	if not _path.is_empty():
		var goal: Vector2 = _path[0]
		var to: Vector2 = goal - teacher.position
		if to.length() <= ARRIVE:
			teacher.position = goal
			_path.pop_front()
			if _path.is_empty():
				_arrived()
			return
		teacher.walk(to, delta)
		return
	if (job == "board" or job == "help" or job == "wake") and _t >= _job_until:
		_done()


func _arrived() -> void:
	match job:
		"to_board":
			job = "board"
			_job_until = _t + BOARD_TIME
			teacher.facing = Actor.DIR_UP
		"to_help", "to_wake":
			job = "help" if job == "to_help" else "wake"
			_job_until = _t + HELP_TIME * (0.6 if job == "wake" else 1.0)
			teacher.facing = Actor.DIR_RIGHT
		_:
			job = "front"
			teacher.facing = Actor.DIR_RIGHT
	teacher.set_idle()


func _done() -> void:
	if job == "help" or job == "wake":
		if _job_kid >= 0:
			if job == "wake":
				(pupils[_job_kid] as Actor).set_slumped(false)
				(pupils[_job_kid] as Actor).play_pose(Actor.POSE_JUMP)
			_set_kid(_job_kid, "thanks", THANKS_TIME)
		_job_kid = -1
	job = "back"
	_walk_to(FRONT)
