class_name Placement
extends Node2D

## Ghost-cursor mode for putting a bought item down.
##
## The cursor is KEYBOARD-first and free-floating — not anchored to the tile
## the teacher happens to face, which is charming for about a minute and then
## makes the far corners of the room miserable to reach.

## Build mode: pick something up from anywhere, put it down anywhere.
##
## Editing the room used to mean walking to each item in turn, pressing E to
## lift it, moving a ghost, and walking to the next one. That is fine for one
## bookshelf and miserable for a room, which is what "confusing to edit and
## move things around" meant.
##
## The cursor already roams freely and the placement rules -- the footprint
## check, the aisle-safety check that refuses to cut a seat off from the door
## -- are the same ones. All build mode adds is being able to PICK UP from
## under the cursor rather than from under your feet.
signal picked_up(id: String, tile: Vector2i)
## Pack the item under the cursor away into the cabinet. Was `sold` -- the
## room's own contents are packed here now and disposed of from the
## cabinet screen, so build mode's F puts things AWAY rather than
## destroying them for half their value.
signal stored(tile: Vector2i)

signal placed(id: String, tile: Vector2i)
signal desk_placed(seat_index: int, tile: Vector2i)
signal cancelled()

const OK_TINT := Color(0.55, 1.0, 0.6, 0.75)
const BAD_TINT := Color(1.0, 0.45, 0.4, 0.7)

var active: bool = false
var item_id: String = ""
var tile: Vector2i = Vector2i(9, 5)

## Which desk is being carried, or -1 when this is an ordinary item. A desk
## is not a catalogue entry: it occupies a PAIR of tiles (the seat and the
## desk below it) and it has an identity, because a child is sitting in it.
var desk_index: int = -1

## Roaming the room with nothing in hand, looking for something to move.
var browsing: bool = false

## Colours for the range overlay.
const REACH_FILL := Color(0.45, 0.95, 0.55, 0.55)
const REACH_EDGE := Color(0.70, 1.0, 0.75, 1.0)
const EMPTY_SEAT := Color(0.85, 0.85, 0.9, 0.35)
## A desk close enough to another to get talking (ten-commits.md step 4;
## since Oct 2026 the warning is talking, Game.too_close(), rather than the
## old hidden slowdown). Warm, not green or grey, so it reads as a DIFFERENT
## kind of fact from range -- a seat can be both reached and crowded at
## once, and the two must not look like one thing.
const CROWD_EDGE := Color(1.0, 0.55, 0.3, 0.9)
## The whisper aura (learning-system-plan.md): how far the whispering of the
## child at the cursor carries -- a soft wash over every tile in reach, and a
## trail of dashes to each desk it touches. Lilac, like the chatter bubble,
## because it is the same thing seen from above.
const AURA_FILL := Color(0.72, 0.6, 0.95, 0.16)
const AURA_EDGE := Color(0.8, 0.7, 1.0, 0.65)
const AURA_LINK := Color(0.86, 0.76, 1.0, 0.95)

var _grid: Grid = null
var _ghost: Sprite2D = null
var _repeat := 0.0
var _reached: Array[int] = []


## How many SEATED students this placement would help — shown live, so the
## choice of where to put something is legible before you commit.
func reach_count() -> int:
	var n := 0
	for i: int in _reached:
		if Game.student_in_seat(i) != null:
			n += 1
	return n


## How many seated children are CURRENTLY close enough to someone to get
## talking (ten-commits.md step 4) -- independent of what is being placed,
## since crowding is about where the seats are, not item range. The same
## test the chatter itself uses, Game.too_close(); this only shows the
## state that already exists.
func crowd_count() -> int:
	var n := 0
	for i in Layout.seat_count():
		var s := Game.student_in_seat(i)
		if s != null and Game.too_close(s):
			n += 1
	return n


## Carry a desk. The ghost is the desk sprite and the cursor tracks the SEAT
## tile, so the pair moves as one and the chair keeps its place behind it.
func begin_desk(index: int, grid: Grid) -> void:
	z_index = 100
	add_to_group("placement")
	item_id = ""
	desk_index = index
	_grid = grid
	tile = Layout.seat(index)
	active = true
	visible = true
	if _ghost == null:
		_ghost = Sprite2D.new()
		add_child(_ghost)
	_ghost.texture = load("res://art/desk.png")
	_refresh()


## Enter build mode empty-handed: a cursor over the whole room.
func begin_browse(grid: Grid, start: Vector2i) -> void:
	z_index = 100
	add_to_group("placement")
	item_id = ""
	desk_index = -1
	browsing = true
	_grid = grid
	tile = start
	active = true
	visible = true
	if _ghost == null:
		_ghost = Sprite2D.new()
		add_child(_ghost)
	_ghost.texture = null
	_refresh()


func begin(id: String, grid: Grid, start: Vector2i) -> void:
	browsing = false
	desk_index = -1
	# Draw above the room. This node lives in the y-sorted world at y=0, so
	# without this the range highlights sort to the very back and every
	# chair, desk and student is drawn over the top of them -- the overlay
	# was invisible exactly where it mattered most.
	z_index = 100
	add_to_group("placement")
	item_id = id
	_grid = grid
	tile = _wall_start(id, start) if Items.is_wall(id) else start
	if Items.is_desk_top(id):
		tile = _desk_top_start(start)
	active = true
	visible = true
	if _ghost == null:
		_ghost = Sprite2D.new()
		add_child(_ghost)
	var def := Items.get_def(id)
	_ghost.texture = load("res://art/%s.png" % String(def["art"]))
	_refresh()


## A hung piece starts on the wall, at the free slot closest to where the
## teacher is standing (or, moving one that is already up, where it was).
func _wall_start(id: String, start: Vector2i) -> Vector2i:
	var best := Vector2i(clampi(start.x, 1, maxi(1, Grid.W - 1 - Items.width(id))), Layout.WALL_ROW)
	var best_d := 9999
	for tx in range(1, Grid.W - 1):
		var t := Vector2i(tx, Layout.WALL_ROW)
		if Layout.wall_slot_ok(id, t) and Game.item_fits(id, t) and absi(tx - start.x) < best_d:
			best = t
			best_d = absi(tx - start.x)
	return best


## A desk-top piece (the study folder) starts on the free desk nearest the
## teacher -- or where it came from, when it is being moved -- and the cursor
## sits on the DESK's tile, so the ghost stands where the piece will.
func _desk_top_start(start: Vector2i) -> Vector2i:
	var here := Layout.seat_at_tile(start)
	if here >= 0:
		return Layout.desk_tile(here)
	var best := start
	var best_d := 9999
	for i in Layout.seat_count():
		var t := Layout.desk_tile(i)
		if not Game.desk_top_free(t):
			continue
		var d := absi(t.x - start.x) + absi(t.y - start.y)
		if d < best_d:
			best = t
			best_d = d
	return best


## The next desk from the cursor in direction `d`: nearest along it, with a
## sideways step costing double, so pressing right goes to the desk to the
## right rather than to one two rows away that happens to be a little nearer.
## Stays put at the edge of the class.
func _next_desk(d: Vector2i) -> Vector2i:
	var best := tile
	var best_score := 99999
	for i in Layout.seat_count():
		var t := Layout.desk_tile(i)
		var off := t - tile
		var along := off.x * d.x + off.y * d.y
		if along <= 0:
			continue
		var across := absi(off.x * d.y) + absi(off.y * d.x)
		var score := along + across * 2
		if score < best_score:
			best = t
			best_score = score
	return best


func finish() -> void:
	browsing = false
	active = false
	visible = false
	desk_index = -1
	_reached.clear()
	queue_redraw()


## Valid means: on the floor, nothing already there, AND — the important one
## — placing it must not cut any seat off from the door.
func is_valid() -> bool:
	if _grid == null:
		return false
	if desk_index >= 0:
		return _desk_is_valid()
	if item_id == "":
		return false
	if Items.is_desk_top(item_id):
		# On a desk that is out, with nothing already standing on it. Takes no
		# floor, so it can never cut anybody off from the door.
		return Game.desk_top_free(tile)
	if Items.is_wall(item_id):
		# On the wall: its own rules, and it can never trap anyone because it
		# takes no floor.
		return Layout.wall_slot_ok(item_id, tile) and Game.item_fits(item_id, tile)
	for t: Vector2i in Items.footprint(item_id, tile):
		if not _grid.is_free(t):
			return false
	if not Game.item_fits(item_id, tile):
		return false
	return not _would_trap_anyone()


## A desk needs its own two tiles free, must not land on another desk, and —
## the one that matters — must not cut anybody off from the door.
##
## Its CURRENT tiles are treated as free, because the desk is in the player's
## hands: measuring against where it still happens to be would stop you
## nudging a desk one tile sideways, which is the commonest move there is.
func _desk_is_valid() -> bool:
	var here := _desk_tiles()
	var from: Array[Vector2i] = [Layout.seat(desk_index),
		Layout.seat(desk_index) + Layout.DESK_OFFSET]
	for t: Vector2i in here:
		if not Grid.in_bounds(t):
			return false
		if from.has(t):
			continue
		if not _grid.is_free(t):
			return false
	if not Game.item_at(tile).is_empty():
		return false
	for i in Layout.seat_count():
		if i == desk_index and here.has(Layout.seat(i)):
			continue
		if i != desk_index and (here.has(Layout.seat(i))
				or here.has(Layout.seat(i) + Layout.DESK_OFFSET)):
			return false
	return not _desk_would_trap_anyone()


## The pair of tiles a carried desk would occupy: the seat, and the desk one
## tile below it.
func _desk_tiles() -> Array[Vector2i]:
	return [tile, tile + Layout.DESK_OFFSET]


## Same simulate-then-restore trick as _would_trap_anyone(), but it has to
## move the seat as well as block a tile: a seat nobody can walk to is just
## as broken as a seat walled in.
func _desk_would_trap_anyone() -> bool:
	var old_seats := Layout.seats().duplicate()
	var here := _desk_tiles()
	var from: Array[Vector2i] = [old_seats[desk_index],
		old_seats[desk_index] + Layout.DESK_OFFSET]

	var before: Array[int] = []
	for t: Vector2i in from:
		before.append(_grid.get_cell(t))
		_grid.set_cell(t, Grid.Cell.FREE)
	var after: Array[int] = []
	for t: Vector2i in here:
		after.append(_grid.get_cell(t))
	_grid.set_cell(here[0], Grid.Cell.SEAT)
	_grid.set_cell(here[1], Grid.Cell.BLOCKED)
	Layout.move_seat(desk_index, tile)

	var trapped := false
	for s: StudentData in Game.roster:
		if s.seat_index < 0:
			continue
		if not _grid.reachable(Layout.DOOR, Layout.seat(s.seat_index)):
			trapped = true
			break

	Layout.set_seats(old_seats)
	for i in here.size():
		_grid.set_cell(here[i], after[i])
	for i in from.size():
		_grid.set_cell(from[i], before[i])
	return trapped


## Simulate the placement on the real grid, test every seat, then put it
## back. Without this a player can wall their own class off from the door and
## quietly break the game with no warning — and it is only possible because
## the grid has been the single spatial authority since Phase 0.
func _would_trap_anyone() -> bool:
	var tiles := Items.footprint(item_id, tile)
	var before: Array[int] = []
	for t: Vector2i in tiles:
		before.append(_grid.get_cell(t))
		_grid.set_cell(t, Grid.Cell.BLOCKED)

	var trapped := false
	for s: StudentData in Game.roster:
		if s.seat_index < 0:
			continue
		if not _grid.reachable(Layout.DOOR, Layout.seat(s.seat_index)):
			trapped = true
			break

	for i in tiles.size():
		_grid.set_cell(tiles[i], before[i])
	return trapped


func _refresh() -> void:
	if _ghost == null:
		return
	if browsing:
		# nothing in hand: the cursor is just a marker over whatever is here
		_ghost.texture = null
		_reached.clear()
		queue_redraw()
		return
	# A null ghost texture is not reachable through begin()'s own sequencing
	# today (browsing is set first, which returns above), but nothing stops
	# a future caller from setting tile/desk_index before the texture is
	# assigned -- and get_height() on null is a hard crash, not a graceful
	# no-op. Treat "no texture yet" as "nothing to anchor by" instead.
	var ghost_h: float = _ghost.texture.get_height() if _ghost.texture != null else 0.0
	if desk_index >= 0:
		# anchored on the DESK tile, so the ghost sits where the desk will
		_ghost.position = Layout.span_anchor([tile + Layout.DESK_OFFSET]) \
			- Vector2(0, ghost_h / 2.0)
		_ghost.modulate = OK_TINT if is_valid() else BAD_TINT
		_reached.clear()
		queue_redraw()
		return
	if Items.is_desk_top(item_id):
		# Stood on the desk exactly as RoomBuilder.dress_desk() will stand it,
		# and "helps" the one child who sits there.
		var seat := Layout.seat_at_tile(tile)
		var body_at := Grid.tile_to_world(Layout.desk_tile(seat) if seat >= 0 else tile)
		_ghost.position = body_at + RoomBuilder.DESK_TOP_CENTRE
		_ghost.modulate = OK_TINT if is_valid() else BAD_TINT
		_reached.clear()
		if seat >= 0 and is_valid():
			_reached.append(seat)
		queue_redraw()
		return
	var tiles := Items.footprint(item_id, tile)
	var anchor := Layout.wall_anchor(tiles) if Items.is_wall(item_id) else Layout.span_anchor(tiles)
	_ghost.position = anchor - Vector2(0, ghost_h / 2.0)
	_ghost.modulate = OK_TINT if is_valid() else BAD_TINT
	_reached = Items.seats_in_range(item_id, tile)
	queue_redraw()


## Highlight the desks this item would actually reach.
##
## Range-based placement is the most interesting system in the game and it
## was completely invisible: you could not tell, while spending your coins,
## whom a bookshelf was going to help. The ghost only ever told you whether
## the tile was legal.
func _draw() -> void:
	if not active:
		return
	if browsing:
		var r := Rect2(Vector2(tile) * Grid.TILE, Vector2(Grid.TILE, Grid.TILE))
		var on_something: bool = not _thing_at(tile).is_empty()
		draw_rect(r, REACH_FILL if on_something else Color(1, 1, 1, 0.12))
		draw_rect(r, REACH_EDGE if on_something else Color(1, 1, 1, 0.5), false, 2.0)   # doubled line width
	else:
		for i in Layout.seat_count():
			var occupied := Game.student_in_seat(i) != null
			var r := Rect2(
				Vector2(Layout.seat(i)) * Grid.TILE + Vector2(2, 2),
				Vector2(Grid.TILE - 4, Grid.TILE - 4))   # doubled inset, was 1/2
			if i in _reached:
				draw_rect(r, REACH_FILL if occupied else EMPTY_SEAT)
				draw_rect(r, REACH_EDGE, false, 2.0)   # doubled line width
			elif occupied:
				draw_rect(r, Color(0, 0, 0, 0.12))
		if Items.is_desk_top(item_id):
			# Every desk it could still go on, outlined, so the choice is the
			# whole class at once and not one desk at a time.
			for i in Layout.seat_count():
				var dt := Layout.desk_tile(i)
				if Game.desk_top_free(dt):
					draw_rect(Rect2(Vector2(dt) * Grid.TILE + Vector2(2, 2),
						Vector2(Grid.TILE - 4, Grid.TILE - 4)), Color(1, 1, 1, 0.5), false, 2.0)
	_draw_aura()
	_draw_crowding()


## Which desks are close enough to get talking, drawn as a border ON TOP of
## everything else above -- an outline rather than a fill, so it accents a
## reached or occupied seat's own colour instead of replacing it. Runs
## whether you are holding something or just browsing (ten-commits.md step
## 4): crowding is a fact about the room, not about what is in your hands.
func _draw_crowding() -> void:
	for i in Layout.seat_count():
		var s := Game.student_in_seat(i)
		if s == null or not Game.too_close(s):
			continue
		var r := Rect2(
			Vector2(Layout.seat(i)) * Grid.TILE + Vector2(2, 2),
			Vector2(Grid.TILE - 4, Grid.TILE - 4))
		draw_rect(r, CROWD_EDGE, false, 2.0)


## The whisper aura of the child whose desk the cursor is on, or whose desk
## you are carrying: {} when there is none, otherwise {seat, centre, reach,
## links} -- the seat index, the tile it is (or would be) at, how many tiles
## their whispering carries, and the seat tile of every desk it reaches. Read
## from the same rules the chatter itself uses (Game.pair_reach()), so what it
## shows is what will happen. While a desk is carried it follows the cursor, so
## the answer to "what would this crowd?" is on screen before you put it down.
func aura() -> Dictionary:
	var idx := desk_index
	if idx < 0:
		if not browsing:
			return {}
		idx = Layout.seat_at_tile(tile)
	if idx < 0:
		return {}
	var s := Game.student_in_seat(idx)
	if s == null:
		return {}
	var centre: Vector2i = tile if desk_index >= 0 else Layout.seat(idx)
	var mine := Game.distraction_radius_of(s)
	var links: Array[Vector2i] = []
	for o: StudentData in Game.roster:
		if o == s or o.seat_index < 0:
			continue
		var there: Vector2i = Layout.seat(o.seat_index)
		var d := maxi(absi(there.x - centre.x), absi(there.y - centre.y))
		if d <= Game.pair_reach(mine, Game.distraction_radius_of(o)):
			links.append(there)
	return {"seat": idx, "centre": centre, "reach": Game.pair_reach(mine, mine),
		"links": links}


func _draw_aura() -> void:
	var a := aura()
	if a.is_empty():
		return
	var centre: Vector2i = a["centre"]
	var reach: int = a["reach"]
	var tile_px := Vector2(Grid.TILE, Grid.TILE)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dy == 0:
				continue
			var t := centre + Vector2i(dx, dy)
			if Grid.in_bounds(t):
				draw_rect(Rect2(Vector2(t) * Grid.TILE, tile_px), AURA_FILL)
	draw_rect(Rect2(Vector2(centre - Vector2i(reach, reach)) * Grid.TILE,
		tile_px * float(2 * reach + 1)), AURA_EDGE, false, 2.0)
	var from := Vector2(centre) * Grid.TILE + tile_px / 2.0
	# Running dashes: the trail moves from the whisperer towards each desk.
	var phase := fmod(float(Time.get_ticks_msec()) * 0.03, 11.0)
	for there: Vector2i in a["links"]:
		_draw_trail(from, Vector2(there) * Grid.TILE + tile_px / 2.0, phase)


## A dashed line from `a` to `b`, the dashes slid along by `phase`.
func _draw_trail(a: Vector2, b: Vector2, phase: float) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var dir := (b - a) / length
	var at := -phase
	while at < length:
		var from_at := maxf(at, 0.0)
		var to_at := minf(at + 6.0, length)
		if to_at > from_at:
			draw_line(a + dir * from_at, a + dir * to_at, AURA_LINK, 3.0)
		at += 11.0
	draw_circle(b, 4.0, AURA_LINK)


## What build mode can pick up under the cursor: a piece on the floor or the
## wall, or one standing on a desk ({id, tile}, the desk's tile for that).
func _thing_at(t: Vector2i) -> Dictionary:
	var here := Game.item_at(t)
	return here if not here.is_empty() else Game.desk_item_at(t)


func move_by(d: Vector2i) -> void:
	var want := tile + d
	if desk_index < 0 and not browsing and Items.is_wall(item_id):
		# A hung piece slides along the wall; up and down do nothing.
		want = Vector2i(tile.x + d.x, Layout.WALL_ROW)
	elif desk_index < 0 and not browsing and Items.is_desk_top(item_id):
		# A desk-top piece hops desk to desk: the floor between them is
		# nowhere it could go.
		want = _next_desk(d)
	if Grid.in_bounds(want):
		tile = want
		_refresh()


func _physics_process(_d: float) -> void:
	if active:
		_handle_input()


func _process(delta: float) -> void:
	if not active:
		return
	if not active:
		return
	# Held-key repeat, so crossing the room isn't 18 separate taps.
	_repeat -= delta
	var d := Vector2i(
		int(Input.get_axis("move_left", "move_right")),
		int(Input.get_axis("move_up", "move_down")))
	if d == Vector2i.ZERO:
		_repeat = 0.0
	elif _repeat <= 0.0:
		move_by(d)
		Sfx.play("blip")
		_repeat = 0.14
	# The aura's trail runs, so it is redrawn while it is up.
	if desk_index >= 0 or browsing:
		queue_redraw()


## Polled, not event-driven — see the note in scripts/ui/hud.gd. This is
## also why the ghost is driven from _process rather than from input events.
func _handle_input() -> void:
	if browsing:
		if Input.is_action_just_pressed("cancel") 				or Input.is_action_just_pressed("build"):
			finish()
			cancelled.emit()
		elif Game.claim_interact():
			var here := _thing_at(tile)
			if here.is_empty():
				Sfx.play("deny")
			else:
				Sfx.play("confirm")
				picked_up.emit(String(here["id"]), here["tile"])
		elif Game.claim_action("manage"):
			var here2 := _thing_at(tile)
			if here2.is_empty():
				Sfx.play("deny")
			else:
				Sfx.play("confirm")
				stored.emit(here2["tile"])
		return

	if Input.is_action_just_pressed("cancel"):
		finish()
		cancelled.emit()
	elif Game.claim_interact():
		if not is_valid():
			Sfx.play("deny")
			return
		Sfx.play("confirm")
		if desk_index >= 0:
			desk_placed.emit(desk_index, tile)
		else:
			placed.emit(item_id, tile)
		finish()
