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

const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")
const DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
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

var mentor: Node = null
var _built := false


func _ready() -> void:
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
		chair.position = spot - Vector2(PROP_CHAIR.get_width() * 0.5,
			PROP_CHAIR.get_height() + 6.0)
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

	# The mentor, up near the front. A recolour of the one character model,
	# exactly like the principal and the inspector -- not new artwork.
	mentor = STUDENT_SCENE.instantiate()
	add_child(mentor)
	if mentor.has_node("Sprite2D"):
		(mentor.get_node("Sprite2D") as Sprite2D).texture = MENTOR_TEX
	mentor.position = Vector2(ROOM_W * 0.5, 80.0)
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


## Where a fresh arrival stands: just inside the door, facing in. Local
## coordinates -- main.gd sets the reparented player's `position` to this.
func entry_position() -> Vector2:
	return Vector2(40.0, 138.0)


## The corridor-style camera clamp. The room is one screen, so this mostly
## pins the camera; it exists so a bigger viewport still cannot see past
## the walls.
func refresh_camera_limits(camera: Camera2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	camera.limit_left = -16
	camera.limit_top = -16
	camera.limit_right = int(ROOM_W + 16.0)
	camera.limit_bottom = int(ROOM_H + 16.0)
