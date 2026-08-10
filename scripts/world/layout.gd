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

## Front of the room. The teacher starts a lesson here.
const PODIUM: Vector2i = Vector2i(9, 2)

## Ends the day. Deliberately across the room from the podium so ending the
## day is a walk, not a reflex.
const BELL: Vector2i = Vector2i(18, 2)

## Where students enter from. Phase 1 opens a gap in the wall art here.
const DOOR: Vector2i = Vector2i(1, 9)

## Walls as SEGMENTS rather than four solid boxes, so a doorway is
## expressible. Tile-space rects, matching the wall band drawn into room.png
## by tools/make_art.py (2 tiles at the top, 1 elsewhere).
const WALL_SEGMENTS: Array[Rect2i] = [
	Rect2i(0, 0, 20, 2),    # top (2 tiles tall)
	Rect2i(0, 10, 20, 1),   # bottom
	Rect2i(0, 0, 1, 11),    # left
	Rect2i(19, 0, 1, 11),   # right
]


static func desk_tile(seat_index: int) -> Vector2i:
	return SEATS[seat_index] + DESK_OFFSET


static func seat_count() -> int:
	return SEATS.size()
