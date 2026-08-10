extends Node2D

## Builds the room and drops the player in it.
##
## The room is one pre-drawn image (art/room.png) with four invisible
## collision walls laid over its border, rather than a TileMap. For a single
## fixed room that is the whole job, and it keeps the project to two images
## and two scripts.

const TILE := 16
const ROOM_W := 20      # tiles — must match tools/make_art.py
const ROOM_H := 11
const WALL := 1         # thickness of the side/bottom walls, in tiles
const TOP_WALL := 2     # the top wall is 2 tiles tall — see tools/make_art.py


func _ready() -> void:
	_build_room()
	_build_walls()
	_spawn_player()


func _build_room() -> void:
	var floor_spr := Sprite2D.new()
	floor_spr.texture = load("res://art/room.png")
	floor_spr.centered = false
	floor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(floor_spr)


## Four static boxes around the inside edge, matching the wall tiles drawn
## into the image. Built from the same constants the art uses, so the
## collision can't drift away from what the player can see.
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
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.position + r.size / 2.0
		body.add_child(shape)


func _spawn_player() -> void:
	var player := CharacterBody2D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector2(ROOM_W * TILE / 2.0, ROOM_H * TILE / 2.0)

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
	# Lift the art so the character's FEET sit on its position, which is what
	# the collision box is aligned to.
	spr.position = Vector2(0, -4)
	player.add_child(spr)

	# A small box at the feet, not a body-sized one. Standing where the feet
	# are is what makes a top-down character feel like it's in the room
	# rather than floating against the walls.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 7)
	shape.shape = rect
	shape.position = Vector2(0, 4)
	player.add_child(shape)

	add_child(player)
