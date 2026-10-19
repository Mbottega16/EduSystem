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
	for t: Dictionary in _generated:
		if String(t.get("id", "")) == id:
			return t
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


## What the opening room never lets a piece stand on: walls, the eight desks,
## the teacher's desk and the fixtures. Tile -> why.
static func _opening_blocked() -> Dictionary:
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
	return blocked


## Why this layout would not work in the opening room. Empty means it is sound.
static func problems(t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var w := Grid.BASE_W
	var h := Grid.BASE_H
	var blocked := _opening_blocked()
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


# ------------------------------------------------------ rooms from YOUR pieces

## Layouts built from the pieces the player owns (in the room or the cabinet),
## shown first on the Ideas tab. Three ways of arranging the same things:
##   focus  each piece where it reaches the most desks, best pieces first
##   edge   pieces round the edge, the middle left clear for walking
##   zones  like with like: seating, books, science each in their own corner
## Each is checked by problems(): every desk stays reachable from the door.
const STYLES := [
	{"id": "mine_focus", "name": "Yours: most help",
		"blurb": "Your own pieces, each where it reaches the most desks."},
	{"id": "mine_edge", "name": "Yours: open floor",
		"blurb": "Your own pieces round the edge, with clear aisles to every desk."},
	{"id": "mine_zones", "name": "Yours: zones",
		"blurb": "Your own pieces grouped by use, one corner for each kind."},
]
## Where each kind of piece gathers in the zones layout, in the order kinds
## are met.
const ZONE_ANCHORS: Array[Vector2i] = [
	Vector2i(18, 9), Vector2i(1, 9), Vector2i(18, 3), Vector2i(1, 3),
]
## The most pieces one suggestion carries: past that the picture is a crowd.
const MAX_PIECES := 26

static var _generated: Array = []
static var _signature := ""


## The Ideas list for this player: rooms built from their own pieces first,
## then the ready-made ones, the ones they are closest to owning leading.
static func player_ids() -> Array:
	ensure_loaded()
	_refresh_generated()
	var out: Array = []
	for t: Dictionary in _generated:
		out.append(String(t.get("id", "")))
	# nearest-to-owned first; equal ones keep the order they are written in
	var rank: Array = []
	for i in _list.size():
		rank.append([owned_count(_list[i]), i])
	rank.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[1]) < int(b[1]) if int(a[0]) == int(b[0]) else int(a[0]) > int(b[0]))
	for pair: Array in rank:
		out.append(String((_list[int(pair[1])] as Dictionary).get("id", "")))
	return out


## Every piece of furniture the player owns, one entry per copy: placed or in
## the cabinet. Consumables and desk-top pieces are not room furniture.
static func owned_furniture() -> Array[String]:
	var out: Array[String] = []
	var all: Array = []
	for placed: Dictionary in Game.room_items:
		all.append(String(placed.get("id", "")))
	for cid: Variant in Game.cabinet:
		all.append(String(cid))
	for id: String in all:
		if Items.get_def(id).is_empty() or Items.category_of(id) == "consumable" \
				or Items.is_desk_top(id):
			continue
		out.append(id)
	# a stable order, so the same pieces always give the same picture
	out.sort_custom(func(a: String, b: String) -> bool:
		var ba: float = float(Items.get_def(a).get("bonus", 0.0))
		var bb: float = float(Items.get_def(b).get("bonus", 0.0))
		return ba > bb if ba != bb else a < b)
	return out


static func _refresh_generated() -> void:
	var pieces := owned_furniture()
	var sig := ",".join(PackedStringArray(pieces))
	if sig == _signature:
		return
	_signature = sig
	_generated.clear()
	if pieces.is_empty():
		return
	var seen: Dictionary = {}
	for style: Dictionary in STYLES:
		var items := _arrange(String(style["id"]), pieces)
		if items.is_empty():
			continue
		var key := str(items)
		if seen.has(key):
			continue
		seen[key] = true
		var rows: Array = []
		for e: Dictionary in items:
			var at: Vector2i = e["tile"]
			rows.append({"id": String(e["id"]), "tile": [at.x, at.y]})
		_generated.append({
			"id": String(style["id"]), "name": String(style["name"]),
			"blurb": String(style["blurb"]), "items": rows, "mine": true})


## Lay `pieces` out in the opening room in one style. Returns [{id, tile}].
static func _arrange(style: String, pieces: Array[String]) -> Array:
	var w := Grid.BASE_W
	var h := Grid.BASE_H
	var blocked := _opening_blocked()
	var used: Dictionary = {}
	var out: Array = []
	var zone_of: Dictionary = {}

	var floor_ids: Array[String] = []
	var wall_ids: Array[String] = []
	for id: String in pieces:
		if Items.is_wall(id):
			wall_ids.append(id)
		elif floor_ids.size() < MAX_PIECES:
			floor_ids.append(id)
	if style == "mine_zones":
		floor_ids.sort_custom(func(a: String, b: String) -> bool:
			var ca := Items.category_of(a)
			var cb := Items.category_of(b)
			return ca < cb if ca != cb else a < b)

	var tiles: Array[Vector2i] = []
	for y in range(Layout.TOP_WALL, h - 1):
		for x in range(1, w - 1):
			var p := Vector2i(x, y)
			if not blocked.has(p):
				tiles.append(p)

	for id: String in floor_ids:
		var cat := Items.category_of(id)
		if not zone_of.has(cat):
			zone_of[cat] = zone_of.size() % ZONE_ANCHORS.size()
		var scored: Array = []
		for p: Vector2i in tiles:
			if not _fits(id, p, blocked, used, w, h):
				continue
			scored.append([_score(style, id, p, ZONE_ANCHORS[int(zone_of[cat])], w, h), p])
		# best first; ties go to the tile nearest the top-left so the result is stable
		scored.sort_custom(func(a: Array, b: Array) -> bool:
			if not is_equal_approx(float(a[0]), float(b[0])):
				return float(a[0]) > float(b[0])
			var pa: Vector2i = a[1]
			var pb: Vector2i = b[1]
			return pa.y * 100 + pa.x < pb.y * 100 + pb.x)
		for pair: Array in scored:
			var at: Vector2i = pair[1]
			for f: Vector2i in Items.footprint(id, at):
				used[f] = id
			if _seats_reachable(blocked, used, w, h):
				out.append({"id": id, "tile": at})
				break
			for f2: Vector2i in Items.footprint(id, at):
				used.erase(f2)

	# hung pieces: along the wall, from the left (right for the open floor)
	var hung: Dictionary = {}
	var cols: Array[int] = []
	for x2 in range(1, w - 1):
		cols.append(x2)
	if style == "mine_edge":
		cols.reverse()
	for id2: String in wall_ids:
		for x3: int in cols:
			var origin := Vector2i(x3, Layout.WALL_ROW)
			if style == "mine_edge":
				# the origin is the LEFT end, so step back by the width
				origin = Vector2i(x3 - Items.width(id2) + 1, Layout.WALL_ROW)
			if _wall_ok(id2, origin, hung, w):
				for f3: Vector2i in Items.footprint(id2, origin):
					hung[f3] = id2
				out.append({"id": id2, "tile": origin})
				break
	return out


static func _fits(id: String, at: Vector2i, blocked: Dictionary,
		used: Dictionary, w: int, h: int) -> bool:
	for f: Vector2i in Items.footprint(id, at):
		if f.x < 1 or f.x > w - 2 or f.y < Layout.TOP_WALL or f.y > h - 2:
			return false
		if blocked.has(f) or used.has(f) or Layout.DEFAULT_SEATS.has(f):
			return false
	return true


static func _wall_ok(id: String, at: Vector2i, hung: Dictionary, w: int) -> bool:
	for f: Vector2i in Items.footprint(id, at):
		if f.x < 1 or f.x > w - 2 or RoomBuilder.is_window_col(f.x, w) \
				or Layout.wall_taken_cols().has(f.x) or hung.has(f):
			return false
	return true


## How many of the eight desks this piece reaches from `at`, weighted by what it
## is worth. Same distance rule as Items.seats_in_range, on the opening desks.
static func _reach_value(id: String, at: Vector2i) -> float:
	var d := Items.get_def(id)
	var reach := int(d.get("range", 0))
	var covered := 0
	for seat: Vector2i in Layout.DEFAULT_SEATS:
		var best := 9999
		for f: Vector2i in Items.footprint(id, at):
			best = mini(best, absi(f.x - seat.x) + absi(f.y - seat.y))
		if best <= reach:
			covered += 1
	return float(covered) * maxf(0.01, float(d.get("bonus", 0.0)))


static func _score(style: String, id: String, at: Vector2i, anchor: Vector2i,
		w: int, h: int) -> float:
	match style:
		"mine_edge":
			var edge := mini(mini(at.x - 1, w - 2 - at.x),
				mini(at.y - Layout.TOP_WALL, h - 2 - at.y))
			return -float(edge) + _reach_value(id, at)
		"mine_zones":
			return -float(absi(at.x - anchor.x) + absi(at.y - anchor.y))
	return _reach_value(id, at)


## Can every desk still be walked to from the door with `used` in the way?
static func _seats_reachable(blocked: Dictionary, used: Dictionary, w: int, h: int) -> bool:
	var seen: Dictionary = {Layout.DOOR: true}
	var queue: Array[Vector2i] = [Layout.DOOR]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nxt := cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= w or nxt.y >= h:
				continue
			if blocked.has(nxt) or used.has(nxt) or seen.has(nxt):
				continue
			seen[nxt] = true
			queue.append(nxt)
	for seat: Vector2i in Layout.DEFAULT_SEATS:
		if not seen.has(seat):
			return false
	return true
