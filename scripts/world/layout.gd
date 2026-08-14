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
##
## The arrangement a new class starts in. Desks can be moved now, so this is
## the OPENING layout rather than the layout — see seats() below.
const DEFAULT_SEATS: Array[Vector2i] = [
	Vector2i(3, 4), Vector2i(7, 4), Vector2i(11, 4), Vector2i(15, 4),
	Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7), Vector2i(15, 7),
]

## Where the desks ACTUALLY are in this run.
##
## A static var rather than an autoload, for the same reason Balance is one:
## the headless tests and the term simulator have no SceneTree, and seating
## has to be answerable without one. Game owns loading and saving it; this
## class owns what the current arrangement is.
static var _seats: Array[Vector2i] = []


## The current arrangement, falling back to the opening one. The fallback
## matters: plenty of code asks about seating before any run has started.
static func seats() -> Array[Vector2i]:
	return _seats if not _seats.is_empty() else DEFAULT_SEATS


static func seat(seat_index: int) -> Vector2i:
	var s := seats()
	if seat_index < 0 or seat_index >= s.size():
		return Vector2i(-1, -1)
	return s[seat_index]


static func set_seats(v: Array[Vector2i]) -> void:
	_seats = v.duplicate()


## Back to the opening arrangement, for a new run.
static func reset_seats() -> void:
	_seats = []


## Move one desk (and therefore its chair, and whoever is sitting in it).
## Returns false if the tile is already somebody else's seat.
static func move_seat(seat_index: int, to: Vector2i) -> bool:
	var s := seats().duplicate()
	if seat_index < 0 or seat_index >= s.size():
		return false
	for i in s.size():
		if i != seat_index and s[i] == to:
			return false
	s[seat_index] = to
	_seats = s
	return true

const DESK_OFFSET := Vector2i(0, 1)

## Front of the room. Assigning work happens here.
const PODIUM: Vector2i = Vector2i(9, 2)

## Where you hand collected work in. Two tiles wide, so it is anchored
## between them rather than on one.
const TEACHER_DESK: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2)]

## Ends the day. Deliberately across the room from the podium so ending the
## day is a walk, not a reflex. (Not built yet — Phase 2.)
const BELL: Vector2i = Vector2i(18, 2)

## The furniture catalogue.
const BOARD: Vector2i = Vector2i(16, 2)

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

## The wall band is two tiles at the top and one everywhere else, which is
## what makes the top wall read as a wall rather than a line.
const TOP_WALL := 2


## Walls as SEGMENTS rather than four solid boxes — which is exactly what
## lets the left wall have a hole in it at DOOR without any special-casing.
##
## Derived from the CURRENT room size rather than written down, because the
## room can be bought bigger. The door stays where it is: it is a fixed point
## on the left wall, and the room grows away from it to the right and down.
static func wall_segments() -> Array[Rect2i]:
	var w := Grid.W
	var h := Grid.H
	var door_top: int = DOOR_TILES[0].y
	var door_bottom: int = DOOR_TILES[DOOR_TILES.size() - 1].y
	return [
		Rect2i(0, 0, w, TOP_WALL),            # top (2 tiles tall)
		Rect2i(0, h - 1, w, 1),               # bottom
		Rect2i(0, 0, 1, door_top),            # left, above the door
		Rect2i(0, door_bottom + 1, 1, h - door_bottom - 1),   # left, below it
		Rect2i(w - 1, 0, 1, h),               # right
	]


## Every tile inside the walls: the floor you can actually stand on.
static func floor_rect() -> Rect2i:
	return Rect2i(1, TOP_WALL, Grid.W - 2, Grid.H - TOP_WALL - 1)


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
	return seat(seat_index) + DESK_OFFSET


static func seat_count() -> int:
	return seats().size()


## Which desk is at this tile, counting the desk itself as well as the seat,
## so walking up to either half of the pair finds it. -1 for none.
static func seat_at_tile(t: Vector2i) -> int:
	var s := seats()
	for i in s.size():
		if s[i] == t or s[i] + DESK_OFFSET == t:
			return i
	return -1
