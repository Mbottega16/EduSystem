extends Node2D

## The corridor between the rooms you hold.
##
## Replaces the abstract School screen's door-picking with an actual one:
## walk to the door that is the room you want, press F. Your own room is
## always the first door. Every room in Game.rooms gets one after it, in
## the order you opened them. One more door appears at the end for the
## next room you could open, but only when Game.can_open_room() says you
## actually can -- a locked door with nothing behind it is exactly the
## "offers nothing" failure this project already had to fix once, at the
## podium, so it is not one to reintroduce here.
##
## PLACEMENT: main.tscn parks this node 10000px below the classroom.
## `visible = false` alone was not enough -- a hidden StaticBody2D still
## collides, so the corridor's own walls were overlapping the classroom's
## coordinate space and the player was colliding with an invisible wall in
## their OWN room. Caught by an existing test failing ("the top wall stops
## the player"), not by anything written for this feature -- worth
## remembering next time two scenes share an origin.
##
## WHAT WALKING THROUGH ONE DOES NOT DO: put the player inside that room to
## teach it. A delegated room is still resolved by RoomSim, same as it
## always was -- this is a faster way to reach the watch/hire screen for
## it than the old Tab-through-School-screen route, not a second body to
## puppet. Teaching two rooms at once is not a thing this game's model
## supports, and pretending otherwise here would be exactly the kind of
## plausible-looking feature CLAUDE.md warns against.

signal door_chosen(kind: String, room_index: int)

const DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const SPACING := 48.0
const MARGIN := 32.0
const HEIGHT := 64.0
## The classroom's own door art (tile_door_top over tile_door_bottom),
## reused rather than drawing new art -- a hallway door should look like
## the door it already is, not invent a second design.
const DOOR_TOP := preload("res://art/tile_door_top.png")
const DOOR_BOTTOM := preload("res://art/tile_door_bottom.png")

var doors: Array = []
var _door_art: Array = []
var _walls_built: bool = false


func _ready() -> void:
	_build_bounds()
	rebuild()


## Top and bottom walls plus the two ends, built once at a generous width so
## a rebuild (a room opened mid-visit) never needs to redo them. A corridor
## has no furniture to collide with, so this is the whole of its geometry.
func _build_bounds() -> void:
	if _walls_built:
		return
	_walls_built = true
	var w := MARGIN * 2.0 + SPACING * float(Balance.max_rooms + 1)

	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.16, 0.14, 0.13)
	floor_rect.position = Vector2(0.0, 0.0)
	floor_rect.size = Vector2(w, HEIGHT)
	floor_rect.z_index = -10
	add_child(floor_rect)

	for seg: Rect2 in [
		Rect2(0.0, -8.0, w, 8.0),          # top
		Rect2(0.0, HEIGHT, w, 8.0),        # bottom
		Rect2(-8.0, -8.0, 8.0, HEIGHT + 16.0),   # left end
		Rect2(w, -8.0, 8.0, HEIGHT + 16.0),      # right end
	]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = seg.size
		shape.shape = rect
		shape.position = seg.position + seg.size * 0.5
		body.add_child(shape)
		add_child(body)


## Called on entry, and again any time Game.rooms changes shape (a room
## opened, a hire made) while the hallway is still the active scene.
func rebuild() -> void:
	for d in doors:
		if is_instance_valid(d):
			d.queue_free()
	doors.clear()
	for a in _door_art:
		if is_instance_valid(a):
			a.queue_free()
	_door_art.clear()

	var n := 1 + Game.rooms.size() + (1 if Game.can_open_room() else 0)
	for i in n:
		var kind: String
		var idx := -1
		if i == 0:
			kind = "home"
		elif i <= Game.rooms.size():
			kind = "room"
			idx = i - 1
		else:
			kind = "open"
		var dx := MARGIN + float(i) * SPACING

		# The door itself: the classroom's own two-tile door art, bottom
		# edge on the floor line, same "bottom row meets the floor"
		# anchor every other prop in this game uses.
		var top_spr := Sprite2D.new()
		top_spr.texture = DOOR_TOP
		top_spr.centered = false
		top_spr.position = Vector2(dx - 8.0, HEIGHT - 32.0)
		add_child(top_spr)
		_door_art.append(top_spr)
		var bottom_spr := Sprite2D.new()
		bottom_spr.texture = DOOR_BOTTOM
		bottom_spr.centered = false
		bottom_spr.position = Vector2(dx - 8.0, HEIGHT - 16.0)
		add_child(bottom_spr)
		_door_art.append(bottom_spr)

		var d := DOOR_SCRIPT.new()
		d.door_kind = kind
		d.room_index = idx
		d.position = Vector2(dx, HEIGHT - 8.0)
		# Doors 48px apart with the player's own 20px zone would overlap a
		# neighbour's reach at the default 20px circle -- same fix as the
		# noticeboard/curriculum board sharing a tile.
		d.set_pick_radius(8.0)
		d.chosen.connect(func(k: String, ri: int) -> void: door_chosen.emit(k, ri))
		add_child(d)
		doors.append(d)


## Where a fresh arrival stands: just past the home door, facing in.
func entry_position() -> Vector2:
	return Vector2(MARGIN + 14.0, HEIGHT * 0.5 + 10.0)


func width() -> float:
	return MARGIN * 2.0 + SPACING * float(maxi(1, doors.size()))


## The corridor only needs to clamp horizontally -- it is one storey and
## far shorter than the screen, so a hard vertical limit would just pin the
## camera against empty space above the floor. Left unset, top/bottom keep
## Camera2D's own effectively-unlimited default.
func refresh_camera_limits(camera: Camera2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	camera.limit_left = -MARGIN
	camera.limit_right = int(width())
	camera.limit_top = -100000
	camera.limit_bottom = 100000
