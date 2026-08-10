class_name Layout
extends RefCounted

## The classroom's fixed furniture, in TILE coordinates.
##
## The room has eight desks permanently. The roster starts at four and grows
## into them, so class growth is an occupancy change rather than a layout
## change — seating, pathing and pacing never have to be re-solved at a new
## size.

## Where a student SITS. The desk sits one tile below (toward the camera), so
## the desk depth-sorts in front of them and occludes their lap — which is
## what makes a seated figure read as being AT a desk rather than beside one.
const SEATS: Array[Vector2i] = [
	Vector2i(3, 4), Vector2i(7, 4), Vector2i(11, 4), Vector2i(15, 4),
	Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7), Vector2i(15, 7),
]

const DESK_OFFSET := Vector2i(0, 1)

## Front of the room. Assigning work happens here.
const PODIUM: Vector2i = Vector2i(9, 2)

## Where you hand collected work in. Two tiles wide, so it is anchored
## between them rather than on one.
const TEACHER_DESK: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2)]

## Ends the day. Deliberately across the room from the podium so ending the
## day is a walk, not a reflex. (Not built yet — Phase 2.)
const BELL: Vector2i = Vector2i(18, 2)

## The gap in the left wall students come in through, and the tile they
## spawn on. Must match DOOR_TILES in tools/make_art.py, which cuts the
## matching hole in the wall art.
##
## Two tiles tall, not one. With a single-tile doorway a character standing
## in it has its feet-box bottom edge exactly on the wall segment below,
## and Godot treats that shared edge as a collision — so the door looked
## open but nobody could walk out through it.
const DOOR_TILES: Array[Vector2i] = [Vector2i(0, 7), Vector2i(0, 8)]
const DOOR: Vector2i = Vector2i(0, 8)

## Walls as SEGMENTS rather than four solid boxes — which is exactly what
## lets the left wall have a one-tile hole in it at DOOR without any
## special-casing. Tile-space rects, matching the wall band drawn into
## room.png by tools/make_art.py (2 tiles at the top, 1 elsewhere).
const WALL_SEGMENTS: Array[Rect2i] = [
	Rect2i(0, 0, 20, 2),    # top (2 tiles tall)
	Rect2i(0, 10, 20, 1),   # bottom
	Rect2i(0, 0, 1, 7),     # left, above the door
	Rect2i(0, 9, 1, 2),     # left, below the door
	Rect2i(19, 0, 1, 11),   # right
]


## World position for a prop spanning several tiles: the bottom-centre of the
## whole span, so the floor-anchor convention still holds for wide furniture.
static func span_anchor(tiles: Array[Vector2i]) -> Vector2:
	var min_x := 999
	var max_x := -999
	var max_y := -999
	for t: Vector2i in tiles:
		min_x = mini(min_x, t.x)
		max_x = maxi(max_x, t.x)
		max_y = maxi(max_y, t.y)
	return Vector2((min_x + max_x + 1) * Grid.TILE / 2.0, (max_y + 1) * Grid.TILE)


static func desk_tile(seat_index: int) -> Vector2i:
	return SEATS[seat_index] + DESK_OFFSET


static func seat_count() -> int:
	return SEATS.size()
