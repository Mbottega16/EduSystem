extends Node2D

## Builds the room, its furniture and its people, and drops the player in.
##
## The room is one pre-drawn image (art/room.png) with invisible collision
## boxes laid over its walls, rather than a TileMap. For a single fixed room
## that is the whole job.
##
## POSITION CONVENTION: every prop and character is positioned by the point
## where it MEETS THE FLOOR, not by its centre. Godot's y-sorting compares
## node positions, so having every sprite agree that "my position is my
## feet" is what makes the player correctly walk in front of a desk that is
## below them and behind one that is above them.

const TILE := 16
const ROOM_W := 20      # tiles — must match tools/make_art.py
const ROOM_H := 11
const WALL := 1         # thickness of the side/bottom walls, in tiles
const TOP_WALL := 2     # the top wall is 2 tiles tall — see tools/make_art.py

## Furniture: art name, floor position, and the footprint that blocks you.
## The blocker is only the base of the piece — you can walk "behind" a table
## so your legs are hidden by it, which is what sells the 3/4 view.
const PROPS := [
	{"art": "desk", "pos": Vector2(72, 76), "block": Vector2(14, 8)},
	{"art": "desk", "pos": Vector2(128, 76), "block": Vector2(14, 8)},
	{"art": "desk", "pos": Vector2(184, 76), "block": Vector2(14, 8)},
	{"art": "table", "pos": Vector2(236, 128), "block": Vector2(30, 10)},
	{"art": "chair", "pos": Vector2(228, 110), "block": Vector2(12, 7)},
	{"art": "chair", "pos": Vector2(244, 146), "block": Vector2(12, 7)},
	{"art": "chair", "pos": Vector2(60, 120), "block": Vector2(12, 7)},
]

## Students stand at the desks. They are scenery — they do not move.
const STUDENTS := [
	{"art": "student_boy", "pos": Vector2(72, 66)},
	{"art": "student_girl", "pos": Vector2(128, 66)},
]


func _ready() -> void:
	# Sort children by their Y position so things lower down the screen are
	# drawn in front. Without this the player walks through furniture in the
	# visual sense even though the collision stops them.
	y_sort_enabled = true

	_build_room()
	_build_walls()
	for p: Dictionary in PROPS:
		_add_prop(p["art"], p["pos"], p["block"])
	for s: Dictionary in STUDENTS:
		_add_prop(s["art"], s["pos"], Vector2(10, 6), true)
	_spawn_player()


func _build_room() -> void:
	var floor_spr := Sprite2D.new()
	floor_spr.texture = load("res://art/room.png")
	floor_spr.centered = false
	floor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(floor_spr)


## Static boxes over the wall tiles drawn into the room image. Built from the
## same constants the art uses, so collision can't drift from what's visible.
func _build_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)

	var w := ROOM_W * TILE
	var h := ROOM_H * TILE
	var t := WALL * TILE

	var boxes := [
		Rect2(0, 0, w, TOP_WALL * TILE),      # top (2 tiles tall)
		Rect2(0, h - t, w, t),                # bottom
		Rect2(0, 0, t, h),                    # left
		Rect2(w - t, 0, t, h),                # right
	]
	for r: Rect2 in boxes:
		body.add_child(_box(r.size, r.position + r.size / 2.0))


## One solid thing with a sprite: a desk, a chair, or a student.
## `is_character` picks the standing, front-facing frame out of a 4x4 sheet.
func _add_prop(art: String, floor_pos: Vector2, block: Vector2, is_character := false) -> void:
	var body := StaticBody2D.new()
	body.position = floor_pos

	var spr := Sprite2D.new()
	spr.texture = load("res://art/%s.png" % art)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_character:
		spr.hframes = 4
		spr.vframes = 4
		spr.frame_coords = Vector2i(0, 0)   # facing the camera, standing
	# Lift the art so its bottom edge sits on the node's position.
	var h: float = float(spr.texture.get_height()) / (4.0 if is_character else 1.0)
	spr.position = Vector2(0, -h / 2.0)
	body.add_child(spr)

	# The blocker sits at the base, so you bump into the legs of a table
	# rather than into the air above it.
	body.add_child(_box(block, Vector2(0, -block.y / 2.0)))
	add_child(body)


func _spawn_player() -> void:
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector2(100, 130)

	# The sprite and collision box are attached BEFORE the player enters the
	# tree. player.gd resolves `$Sprite2D` with @onready, which fires the
	# moment the node is added — attach the children afterwards and that
	# lookup silently returns null, leaving the character frozen on one frame.
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = load("res://art/player.png")
	spr.hframes = 4        # walk frames
	spr.vframes = 4        # facings
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(0, -12)      # bottom of the sprite on the node's feet
	player.add_child(spr)

	# A small box at the feet, not a body-sized one. Standing where the feet
	# are is what makes a top-down character feel like it's in the room
	# rather than floating against the walls.
	player.add_child(_box(Vector2(10, 7), Vector2(0, -3.5)))

	add_child(player)


func _box(size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	return shape
