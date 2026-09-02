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
const SPACING := 96.0   # doubled Aug 2026, was 48.0
const MARGIN := 64.0   # doubled Aug 2026, was 32.0
const HEIGHT := 128.0   # doubled Aug 2026, was 64.0
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
		Rect2(0.0, -16.0, w, 16.0),          # top
		Rect2(0.0, HEIGHT, w, 16.0),        # bottom
		Rect2(-16.0, -16.0, 16.0, HEIGHT + 32.0),   # left end
		Rect2(w, -16.0, 16.0, HEIGHT + 32.0),      # right end
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

	# Slots 0-2 are always home, the office, and the mentor teacher's room --
	# none of the three counts against Game.rooms or the max_rooms cap, all
	# three being about YOU rather than a room you are running. Rooms you
	# hold follow from slot 3.
	var n := 3 + Game.rooms.size() + (1 if Game.can_open_room() else 0)
	for i in n:
		var kind: String
		var idx := -1
		if i == 0:
			kind = "home"
		elif i == 1:
			kind = "office"
		elif i == 2:
			kind = "mentor"
		elif i <= 2 + Game.rooms.size():
			kind = "room"
			idx = i - 3
		else:
			kind = "open"
		var dx := MARGIN + float(i) * SPACING

		# The door itself: the classroom's own two-tile door art, bottom
		# edge on the floor line, same "bottom row meets the floor"
		# anchor every other prop in this game uses.
		#
		# TINTED BY KIND -- every door used the same untinted art, so
		# telling "home" from "the office" from "a room you hold" meant
		# walking up and reading the prompt, confirmed by screenshot as a
		# real "which one is which" problem rather than assumed. A colour
		# is not full signage, but it is the smallest change that turns
		# four identical doors into four doors you can tell apart from
		# across the corridor.
		var tint := _door_tint(kind, idx)
		var top_spr := Sprite2D.new()
		top_spr.texture = DOOR_TOP
		top_spr.centered = false
		top_spr.modulate = tint
		top_spr.position = Vector2(dx - 16.0, HEIGHT - 64.0)   # doubled, door art is 32x32/tile now
		add_child(top_spr)
		_door_art.append(top_spr)
		var bottom_spr := Sprite2D.new()
		bottom_spr.texture = DOOR_BOTTOM
		bottom_spr.centered = false
		bottom_spr.modulate = tint
		bottom_spr.position = Vector2(dx - 16.0, HEIGHT - 32.0)
		add_child(bottom_spr)
		_door_art.append(bottom_spr)

		var d := DOOR_SCRIPT.new()
		d.door_kind = kind
		d.room_index = idx
		d.position = Vector2(dx, HEIGHT - 16.0)
		# Doors 48px apart with the player's own 20px zone would overlap a
		# neighbour's reach at the default 20px circle -- same fix as the
		# noticeboard/curriculum board sharing a tile.
		d.set_pick_radius(32.0)   # doubled Aug 2026, was 8.0 -> 16.0 -> 32.0
		d.chosen.connect(func(k: String, ri: int) -> void: door_chosen.emit(k, ri))
		add_child(d)
		doors.append(d)


## The colour each door kind gets tinted, so the row reads at a glance
## rather than only on approach. Muted rather than saturated -- these are
## still the same door art, not a different prop, and a loud tint would
## fight the room's own palette rather than sit inside it.
func _door_tint(kind: String, idx: int) -> Color:
	match kind:
		"office":
			return Color(1.15, 1.0, 0.7)      # warm gold -- matches the
			                                    # principal's own colour
			                                    # everywhere else it appears
		"mentor":
			return Color(1.15, 0.85, 0.7)      # warm rust -- the mentor's own
			                                    # cardigan colour, and clearly
			                                    # not the office's gold
		"room":
			if idx >= 0 and idx < Game.rooms.size():
				var r: Dictionary = Game.rooms[idx]
				if (r.get("teacher", {}) as Dictionary).is_empty():
					# THE FIX: a flat 0.85 grey just darkens the same teal
					# the plain "home" door already is -- confirmed by a
					# zoomed screenshot to be nearly indistinguishable at
					# a glance, which defeats the entire point of tinting
					# by kind. A warm red-orange reads as "needs you"
					# clearly, and shares no hue with office (gold) or a
					# staffed room (blue).
					return Color(1.3, 0.55, 0.4)
				# A STAFFED room used to read identically whether its
				# teacher was thriving or had been failing for the whole
				# term -- found via /deep_critique running Simulate the
				# School.bat, which showed exactly that: a room stuck on a
				# failing grade for twenty straight days with nothing
				# anywhere hinting you should go deal with it short of
				# opening the school board and checking every room by
				# hand. A muted amber, distinct from unstaffed's stronger
				# red-orange (this room HAS a teacher, just a bad one), so
				# the hallway itself becomes the place you notice fire()
				# is worth using, not just the screen it lives on.
				var letter := String((r.get("last", {}) as Dictionary).get("letter", ""))
				if letter in ["D", "E"]:
					return Color(1.15, 0.75, 0.45)
			return Color(0.75, 0.9, 1.15)       # staffed and fine -- cool blue
		"open":
			return Color(0.55, 0.55, 0.6)       # dim -- not really a room yet
		_:
			return Color.WHITE                   # home: the door as drawn


## Where a fresh arrival stands: just past the home door, facing in.
func entry_position() -> Vector2:
	return Vector2(MARGIN + 28.0, HEIGHT * 0.5 + 20.0)   # doubled, was 14.0/10.0


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
