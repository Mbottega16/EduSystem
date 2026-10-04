class_name RoomTemplates
extends RefCounted

## Ready-made rooms for a player to take ideas from (data/room_templates.json).
##
## Each is a layout for the OPENING 20x11 room and its eight default desks,
## built from real shop items: which things sit well together, where a reading
## corner or a lab bench goes without cutting a desk off from the door, and
## what to hang on the wall. They are inspiration, not a purchase: nothing here
## spends a coin or moves a piece of the player's own room.
##
## problems() is the author's check: it says why a layout would not work in the
## real room, using the same rules the placement cursor uses, so a template can
## never show a layout the game itself would refuse.

const PATH := "res://data/room_templates.json"

static var _list: Array = []
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_list = ((parsed as Dictionary).get("templates", []) as Array).duplicate(true)


static func all() -> Array:
	ensure_loaded()
	return _list


static func ids() -> Array:
	ensure_loaded()
	return _list.map(func(t: Dictionary) -> String: return String(t.get("id", "")))


static func get_template(id: String) -> Dictionary:
	ensure_loaded()
	for t: Dictionary in _list:
		if String(t.get("id", "")) == id:
			return t
	return {}


## The template's pieces as [{id, tile: Vector2i}].
static func entries(t: Dictionary) -> Array:
	var out: Array = []
	for e: Dictionary in t.get("items", []):
		var xy: Array = e.get("tile", [0, 0])
		out.append({"id": String(e.get("id", "")), "tile": Vector2i(int(xy[0]), int(xy[1]))})
	return out


## What the whole set costs at list price.
static func cost(t: Dictionary) -> int:
	var total := 0
	for e: Dictionary in entries(t):
		total += Items.cost(String(e["id"]))
	return total


## How many of the template's pieces the player already has, in the room or in
## the cabinet (a second bookshelf only counts if they own a second bookshelf).
static func owned_count(t: Dictionary) -> int:
	var have: Dictionary = {}
	for placed: Dictionary in Game.room_items:
		var pid := String(placed.get("id", ""))
		have[pid] = int(have.get(pid, 0)) + 1
	for cid: Variant in Game.cabinet:
		have[String(cid)] = int(have.get(String(cid), 0)) + 1
	var n := 0
	for e: Dictionary in entries(t):
		var id := String(e["id"])
		if int(have.get(id, 0)) > 0:
			have[id] = int(have[id]) - 1
			n += 1
	return n


## List price of the pieces the player does NOT already have.
static func missing_cost(t: Dictionary) -> int:
	var have: Dictionary = {}
	for placed: Dictionary in Game.room_items:
		var pid := String(placed.get("id", ""))
		have[pid] = int(have.get(pid, 0)) + 1
	for cid: Variant in Game.cabinet:
		have[String(cid)] = int(have.get(String(cid), 0)) + 1
	var total := 0
	for e: Dictionary in entries(t):
		var id := String(e["id"])
		if int(have.get(id, 0)) > 0:
			have[id] = int(have[id]) - 1
		else:
			total += Items.cost(id)
	return total


## Why this layout would not work in the opening room. Empty means it is sound.
static func problems(t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var w := Grid.BASE_W
	var h := Grid.BASE_H
	var blocked: Dictionary = {}
	for y in h:
		for x in w:
			if y < Layout.TOP_WALL or y == h - 1 or x == 0 or x == w - 1:
				blocked[Vector2i(x, y)] = "a wall"
	for d: Vector2i in Layout.DOOR_TILES:
		blocked.erase(d)
	for seat: Vector2i in Layout.DEFAULT_SEATS:
		blocked[seat + Layout.DESK_OFFSET] = "a desk"
	for fixed: Vector2i in Layout.TEACHER_DESK:
		blocked[fixed] = "the teacher's desk"
	for fixed2: Vector2i in [Layout.CABINET, Layout.PODIUM, Layout.BOARD, Layout.BELL]:
		blocked[fixed2] = "a fixture"
	var seats: Dictionary = {}
	for seat2: Vector2i in Layout.DEFAULT_SEATS:
		seats[seat2] = true

	var used: Dictionary = {}
	var hung: Dictionary = {}
	for e: Dictionary in entries(t):
		var id := String(e["id"])
		var tile: Vector2i = e["tile"]
		if Items.get_def(id).is_empty():
			out.append("%s is not a shop item" % id)
			continue
		if Items.category_of(id) == "consumable":
			out.append("%s is a consumable, not furniture" % id)
			continue
		if Items.is_wall(id):
			if tile.y != Layout.WALL_ROW:
				out.append("%s must hang on the wall row" % id)
			for ft: Vector2i in Items.footprint(id, tile):
				if ft.x < 1 or ft.x > w - 2:
					out.append("%s hangs outside the wall" % id)
				elif RoomBuilder.is_window_col(ft.x, w):
					out.append("%s hangs over a window" % id)
				elif Layout.wall_taken_cols().has(ft.x):
					out.append("%s hangs behind a fixture" % id)
				if hung.has(ft):
					out.append("%s hangs on top of %s" % [id, hung[ft]])
				hung[ft] = id
			continue
		for ft2: Vector2i in Items.footprint(id, tile):
			if blocked.has(ft2):
				out.append("%s at %s is on %s" % [id, ft2, blocked[ft2]])
			elif seats.has(ft2):
				out.append("%s at %s is on a seat" % [id, ft2])
			elif used.has(ft2):
				out.append("%s at %s is on top of %s" % [id, ft2, used[ft2]])
			used[ft2] = id
	# every seat must still be reachable from the door
	var open: Dictionary = {}
	for y2 in h:
		for x2 in w:
			var p := Vector2i(x2, y2)
			if not blocked.has(p) and not used.has(p):
				open[p] = true
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [Layout.DOOR]
	seen[Layout.DOOR] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d2: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nxt := cur + d2
			if open.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	for seat3: Vector2i in Layout.DEFAULT_SEATS:
		if not seen.has(seat3):
			out.append("the desk at %s would be cut off from the door" % seat3)
	return out
