class_name RoomBuilder
extends RefCounted

## Turns layout data + Game state into nodes under the world root, and marks
## the grid to match.
##
## Built from DATA rather than hardcoded, because from the moment the player
## can buy furniture the room stops being a constant. The old version of this
## lived in main.gd as `const` arrays, which quietly made a mutable room
## impossible.

const PROP_CHAIR := preload("res://art/chair.png")
const PROP_DESK := preload("res://art/desk.png")
const PROP_PODIUM := preload("res://art/podium.png")
const PROP_TEACHER_DESK := preload("res://art/teacher_desk.png")
const PROP_PAPER := preload("res://art/paper.png")
const PROP_BELL := preload("res://art/bell.png")
const PROP_BOARD := preload("res://art/noticeboard.png")

const DESK_STATION_SCRIPT := preload("res://scripts/interact/desk_station.gd")
const PODIUM_SCRIPT := preload("res://scripts/interact/podium.gd")
const MARKING_DESK_SCRIPT := preload("res://scripts/interact/marking_desk.gd")
const BELL_SCRIPT := preload("res://scripts/interact/bell.gd")
const BOARD_SCRIPT := preload("res://scripts/interact/noticeboard.gd")
const PLACED_SCRIPT := preload("res://scripts/interact/placed_item.gd")


static func make_box(size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	return shape


## A prop standing on the floor. `sort_bias` breaks exact y ties, which Godot
## otherwise resolves by tree order — silently order-dependent and miserable
## to debug.
static func add_prop(parent: Node2D, tex: Texture2D, at: Vector2,
		block: Vector2, sort_bias: float = 0.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at + Vector2(0, sort_bias)
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


## The floor image. One baked PNG rather than a TileMap: a single draw call,
## from the same procedural pipeline as everything else, and nothing here
## needs editor tile-painting. Occupancy lives in Grid, not in cell data.
static func build_floor(parent: Node2D) -> void:
	var floor_spr := Sprite2D.new()
	floor_spr.texture = load("res://art/room.png")
	floor_spr.centered = false
	parent.add_child(floor_spr)


## Walls as a list of segments rather than four fixed boxes — which is
## exactly what lets the left wall have a doorway in it.
static func build_walls(parent: Node2D, grid: Grid) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	grid.block_rect(Rect2i(0, 0, Grid.W, Grid.H), Grid.Cell.BLOCKED)
	grid.block_rect(Rect2i(1, 2, Grid.W - 2, Grid.H - 3), Grid.Cell.FREE)

	for seg: Rect2i in Layout.WALL_SEGMENTS:
		var size := Vector2(seg.size) * Grid.TILE
		var top_left := Vector2(seg.position) * Grid.TILE
		body.add_child(make_box(size, top_left + size / 2.0))
		grid.block_rect(seg, Grid.Cell.BLOCKED)

	# The doorway is a hole in the wall, so its tiles have to be walkable
	# even though they sit on the wall ring.
	for t: Vector2i in Layout.DOOR_TILES:
		grid.set_cell(t, Grid.Cell.FREE)


## Eight desks and eight chairs, present whether or not anyone sits at them —
## the roster grows into the room rather than the room growing around it.
## Each desk carries its own Interactable so work can be collected from it.
static func build_desks(parent: Node2D, grid: Grid) -> Array:
	var stations: Array = []
	for i in Layout.seat_count():
		var seat: Vector2i = Layout.SEATS[i]
		var desk: Vector2i = Layout.desk_tile(i)

		# The chair is nudged 1px up so it always sorts BEHIND its occupant.
		add_prop(parent, PROP_CHAIR, Grid.tile_to_world(seat), Vector2.ZERO, -1.0)
		var body := add_prop(parent, PROP_DESK, Grid.tile_to_world(desk), Vector2(14, 8))

		# The finished sheet, hidden until they're done with it.
		var paper := Sprite2D.new()
		paper.texture = PROP_PAPER
		paper.position = Vector2(0, -18)
		paper.visible = false
		body.add_child(paper)

		var station := Interactable.new()
		station.set_script(DESK_STATION_SCRIPT)
		station.seat_index = i
		station.paper = paper
		body.add_child(station)
		stations.append(station)

		grid.set_cell(seat, Grid.Cell.SEAT)
		grid.set_cell(desk, Grid.Cell.BLOCKED)
	return stations


static func build_podium(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_PODIUM, Grid.tile_to_world(Layout.PODIUM), Vector2(12, 8))
	var it := Interactable.new()
	it.set_script(PODIUM_SCRIPT)
	body.add_child(it)
	grid.set_cell(Layout.PODIUM, Grid.Cell.BLOCKED)
	return it


static func build_teacher_desk(parent: Node2D, grid: Grid) -> Interactable:
	var anchor := Layout.span_anchor(Layout.TEACHER_DESK)
	var body := add_prop(parent, PROP_TEACHER_DESK, anchor, Vector2(30, 10))
	var it := Interactable.new()
	it.set_script(MARKING_DESK_SCRIPT)
	body.add_child(it)
	for t: Vector2i in Layout.TEACHER_DESK:
		grid.set_cell(t, Grid.Cell.BLOCKED)
	return it


static func build_bell(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_BELL, Grid.tile_to_world(Layout.BELL), Vector2(12, 8))
	var it := Interactable.new()
	it.set_script(BELL_SCRIPT)
	body.add_child(it)
	grid.set_cell(Layout.BELL, Grid.Cell.BLOCKED)
	return it


static func build_noticeboard(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_BOARD, Grid.tile_to_world(Layout.BOARD), Vector2(12, 8))
	var it := Interactable.new()
	it.set_script(BOARD_SCRIPT)
	body.add_child(it)
	grid.set_cell(Layout.BOARD, Grid.Cell.BLOCKED)
	return it


## Everything the player has bought. Rebuilt from Game.room_items whenever
## the room changes, so a save reload reconstructs it exactly.
static func build_purchased(parent: Node2D, grid: Grid) -> Array:
	var nodes: Array = []
	for placed: Dictionary in Game.room_items:
		var id := String(placed["id"])
		var def := Items.get_def(id)
		if def.is_empty():
			continue
		var tiles := Items.footprint(id, placed["tile"])
		var anchor := Layout.span_anchor(tiles)
		var tex: Texture2D = load("res://art/%s.png" % String(def["art"]))
		var body := add_prop(parent, tex, anchor,
			Vector2(Items.width(id) * 16 - 2, 8))
		body.add_to_group("purchased")

		# every bought item can be picked up again
		var it := Interactable.new()
		it.set_script(PLACED_SCRIPT)
		it.item_id = id
		it.origin = placed["tile"]
		body.add_child(it)
		nodes.append(body)
		for t: Vector2i in tiles:
			grid.set_cell(t, Grid.Cell.BLOCKED)
	return nodes
