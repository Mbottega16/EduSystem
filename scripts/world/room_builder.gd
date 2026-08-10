class_name RoomBuilder
extends RefCounted

## Turns layout data + Game state into nodes under the world root, and marks
## the grid to match.
##
## This is built from DATA rather than hardcoded, because from the moment the
## player can buy furniture the room stops being a constant. The old version
## of this lived in main.gd as `const` arrays, which quietly made a mutable
## room impossible.

const PROP_CHAIR := preload("res://art/chair.png")
const PROP_DESK := preload("res://art/desk.png")


## Everything a prop needs: where it stands, what it looks like, what it
## blocks. `sort_bias` breaks exact y ties, which Godot otherwise resolves by
## tree order — silently order-dependent and a nightmare to debug.
static func add_prop(parent: Node2D, tex: Texture2D, tile: Vector2i,
		block: Vector2, sort_bias: float = 0.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Grid.tile_to_world(tile) + Vector2(0, sort_bias)
	body.collision_layer = 1     # world
	body.collision_mask = 0

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = Vector2(0, -tex.get_height() / 2.0)   # bottom edge on the anchor
	body.add_child(spr)

	if block != Vector2.ZERO:
		body.add_child(make_box(block, Vector2(0, -block.y / 2.0)))
	parent.add_child(body)
	return body


static func make_box(size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	return shape


## The floor image. One baked PNG rather than a TileMap: it is a single draw
## call, it comes from the same procedural pipeline as everything else, and
## nothing here needs editor tile-painting. Occupancy lives in Grid, not in
## a tilemap's cell data.
static func build_floor(parent: Node2D) -> void:
	var floor_spr := Sprite2D.new()
	floor_spr.texture = load("res://art/room.png")
	floor_spr.centered = false
	parent.add_child(floor_spr)


## Walls as a list of segments rather than four fixed boxes, so a doorway is
## expressible without special-casing.
static func build_walls(parent: Node2D, grid: Grid) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	for seg: Rect2i in Layout.WALL_SEGMENTS:
		var size := Vector2(seg.size) * Grid.TILE
		var top_left := Vector2(seg.position) * Grid.TILE
		body.add_child(make_box(size, top_left + size / 2.0))
		grid.block_rect(seg, Grid.Cell.BLOCKED)


## Eight desks and eight chairs. Present whether or not anyone sits at them —
## the roster grows into the room rather than the room growing around it.
static func build_desks(parent: Node2D, grid: Grid) -> void:
	for i in Layout.seat_count():
		var seat: Vector2i = Layout.SEATS[i]
		var desk: Vector2i = Layout.desk_tile(i)

		# The chair is nudged 1px up so it always sorts BEHIND its occupant.
		add_prop(parent, PROP_CHAIR, seat, Vector2.ZERO, -1.0)
		add_prop(parent, PROP_DESK, desk, Vector2(14, 8))

		grid.set_cell(seat, Grid.Cell.SEAT)
		grid.set_cell(desk, Grid.Cell.BLOCKED)
