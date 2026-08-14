class_name Grid
extends RefCounted

## The room's tile grid: coordinate maths, occupancy, and pathfinding.
##
## One structure serves three jobs that would otherwise each grow their own:
## where things are, whether a tile is free, and how to walk between two
## tiles. Keeping them together is what makes it possible to ask "would
## placing this item trap a student?" later — you simulate it on this grid.
##
## Uses AStarGrid2D rather than NavigationRegion2D deliberately. The room is
## already conceptually a 16px grid, so nav-polygon baking would be
## re-deriving a grid the hard way; re-baking after a furniture change is one
## synchronous call here; and integer tile paths are trivially assertable in
## a headless test, which navigation-agent output is not.

const TILE := 16

## The room the game opens in, and the floor of every later size.
const BASE_W := 20           ## tiles across, matching tools/make_art.py
const BASE_H := 11           ## tiles down
## Nothing sensible happens beyond this, and it bounds the floor image the
## renderer composes.
const MAX_W := 34
const MAX_H := 20

## The CURRENT room size. Static vars rather than consts, because the room
## can be bought bigger now -- and static rather than an autoload for the
## same reason Balance and Layout are: the headless tests and the term
## simulator have no SceneTree, and "how big is the room" has to be
## answerable without one.
static var W: int = BASE_W
static var H: int = BASE_H


## Grow (or reset) the room. Everything that reads W/H reads it live, so the
## only thing that has to be rebuilt afterwards is the room itself.
static func set_size(w: int, h: int) -> void:
	W = clampi(w, BASE_W, MAX_W)
	H = clampi(h, BASE_H, MAX_H)


static func reset_size() -> void:
	W = BASE_W
	H = BASE_H

enum Cell { FREE, BLOCKED, SEAT }

var cells := PackedByteArray()
var astar := AStarGrid2D.new()


func _init() -> void:
	rebuild()


## Re-cut the grid to the current room size. Everything on it is forgotten,
## because the caller is about to re-mark every wall, desk and item anyway.
func rebuild() -> void:
	cells.resize(W * H)
	cells.fill(Cell.FREE)
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(TILE, TILE)
	# Without this, a diagonal step between two desk corners visually clips
	# straight through the furniture.
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()


# ------------------------------------------------------------ coordinates

## A tile's ANCHOR is its bottom-centre — the point where something standing
## on it meets the floor. Every actor and prop in the game is positioned by
## that point, which is what makes y-sorting work with no special cases.
static func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE)


## The -1 matters: a point sitting exactly on a tile's bottom edge belongs to
## THAT tile, not the one below it.
static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / float(TILE))), int(floor((p.y - 1.0) / float(TILE))))


static func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H


# -------------------------------------------------------------- occupancy

func get_cell(t: Vector2i) -> int:
	if not in_bounds(t):
		return Cell.BLOCKED
	return cells[t.y * W + t.x]


func set_cell(t: Vector2i, kind: int) -> void:
	if not in_bounds(t):
		return
	cells[t.y * W + t.x] = kind
	# A seat is walkable for the student claiming it but never a through-route,
	# so it is solid to the pathfinder and handled as a goal exception instead.
	astar.set_point_solid(t, kind != Cell.FREE)


func block_rect(r: Rect2i, kind: int = Cell.BLOCKED) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			set_cell(Vector2i(x, y), kind)


func is_free(t: Vector2i) -> bool:
	return get_cell(t) == Cell.FREE


func free_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in H:
		for x in W:
			var t := Vector2i(x, y)
			if is_free(t):
				out.append(t)
	return out


# ------------------------------------------------------------ pathfinding

## Tile path from `from` to `to`, inclusive of both ends. Empty if there is
## no route.
##
## The GOAL is temporarily un-solidified: a chair is by definition occupied
## furniture, so without this you could never path onto one. Only the goal —
## every intermediate tile still has to be genuinely walkable.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not in_bounds(from) or not in_bounds(to):
		return []
	var goal_was_solid := astar.is_point_solid(to)
	if goal_was_solid:
		astar.set_point_solid(to, false)
	var p := astar.get_id_path(from, to)
	if goal_was_solid:
		astar.set_point_solid(to, true)
	var out: Array[Vector2i] = []
	out.assign(p)
	return out


func reachable(from: Vector2i, to: Vector2i) -> bool:
	return not path(from, to).is_empty()


## The four orthogonal neighbours of `t` that are currently free — the tiles
## you could stand on to interact with whatever occupies `t`.
func approach_tiles(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = t + d
		if in_bounds(n) and is_free(n):
			out.append(n)
	return out
