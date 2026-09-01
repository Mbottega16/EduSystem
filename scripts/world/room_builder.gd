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
const PROP_AD_POSTER := preload("res://art/ad_poster.png")
const PROP_MESS_TRASH := preload("res://art/mess_trash.png")
const PROP_MESS_SPILL := preload("res://art/mess_spill.png")
const SHADOW_TEX := preload("res://art/shadow.png")

const DESK_STATION_SCRIPT := preload("res://scripts/interact/desk_station.gd")
const DESK_MOVER_SCRIPT := preload("res://scripts/interact/desk_mover.gd")
const PODIUM_SCRIPT := preload("res://scripts/interact/podium.gd")
const QUIZ_CALLER_SCRIPT := preload("res://scripts/interact/quiz_caller.gd")
const TEST_CALLER_SCRIPT := preload("res://scripts/interact/test_caller.gd")
const MARKING_DESK_SCRIPT := preload("res://scripts/interact/marking_desk.gd")
const HOMEWORK_DESK_SCRIPT := preload("res://scripts/interact/homework_desk.gd")
const DESK_INTERRUPTION_SCRIPT := preload("res://scripts/interact/desk_interruption.gd")
const BELL_SCRIPT := preload("res://scripts/interact/bell.gd")
const BOARD_SCRIPT := preload("res://scripts/interact/noticeboard.gd")
const AD_POSTER_SCRIPT := preload("res://scripts/interact/ad_poster.gd")
const CURRICULUM_SCRIPT := preload("res://scripts/interact/curriculum_board.gd")
const HALL_DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const PLACED_SCRIPT := preload("res://scripts/interact/placed_item.gd")
const MESS_SCRIPT := preload("res://scripts/interact/mess.gd")


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
		block: Vector2, sort_bias: float = 0.0,
		with_shadow: bool = true) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at + Vector2(0, sort_bias)
	body.collision_layer = 1     # world
	body.collision_mask = 0

	# A contact shadow, added FIRST so it draws under the prop. Doing it here
	# rather than painting it into each sprite means everything standing on
	# the floor gets one -- including furniture the player buys, which
	# previously only had a shadow if its text grid remembered to ask.
	if with_shadow:
		var shade := Sprite2D.new()
		shade.texture = SHADOW_TEX
		shade.position = Vector2(0, -4)   # doubled, was -2
		shade.scale = Vector2(maxf(1.0, tex.get_width() / 32.0), 1.0)   # was /16.0
		body.add_child(shade)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = Vector2(0, -tex.get_height() / 2.0)   # bottom edge on the anchor
	body.add_child(spr)

	if block != Vector2.ZERO:
		body.add_child(make_box(block, Vector2(0, -block.y / 2.0)))
	# Every prop is part of the ROOM rather than part of the cast, so the
	# geometry can be torn down and rebuilt when the room grows without
	# disturbing the students and the teacher standing in it.
	body.add_to_group("room_part")
	parent.add_child(body)
	return body


## How many speckle variants of each floor shade exist on disk. Must match
## FLOOR_VARIANTS in tools/make_art.py.
const FLOOR_VARIANTS := 4


## The floor and walls, composed at runtime into ONE image.
##
## This used to be a single baked room.png, which was the right call while
## the room was a constant -- one draw call, no editor tile-painting. The
## moment the room can be bought bigger, a fixed image cannot answer for it.
##
## Still one draw call: the pieces are stamped into an Image and uploaded as
## a single ImageTexture, rather than becoming several hundred Sprite2Ds.
## Occupancy stays in Grid; this is only what you can see.
static func build_floor(parent: Node2D) -> void:
	var floor_spr := Sprite2D.new()
	floor_spr.texture = compose_room()
	floor_spr.centered = false
	floor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_spr.add_to_group("room_floor")
	floor_spr.add_to_group("room_part")
	parent.add_child(floor_spr)


static func _tile_img(name: String) -> Image:
	var tex: Texture2D = load("res://art/%s.png" % name)
	return tex.get_image() if tex != null else null


## Paint the room at its current size, piece by piece.
static func compose_room() -> ImageTexture:
	var w := Grid.W
	var h := Grid.H
	var t := Grid.TILE
	var im := Image.create(w * t, h * t, false, Image.FORMAT_RGBA8)

	var floors: Array[Image] = []
	for i in FLOOR_VARIANTS:
		floors.append(_tile_img("tile_floor_a%d" % i))
		floors.append(_tile_img("tile_floor_b%d" % i))
	var wall_top0 := _tile_img("tile_wall_top0")
	var wall_top1 := _tile_img("tile_wall_top1")
	var wall_side := _tile_img("tile_wall_side")
	var wall_bottom := _tile_img("tile_wall_bottom")
	var door_top := _tile_img("tile_door_top")
	var door_bottom := _tile_img("tile_door_bottom")
	var win := [[_tile_img("tile_window_l0"), _tile_img("tile_window_r0")],
		[_tile_img("tile_window_l1"), _tile_img("tile_window_r1")]]

	var door_tiles := Layout.DOOR_TILES
	var src := Rect2i(0, 0, t, t)

	for ty in h:
		for tx in w:
			var here := Vector2i(tx, ty)
			var img: Image = null
			if door_tiles.has(here):
				img = door_top if here == door_tiles[0] else door_bottom
			elif ty < Layout.TOP_WALL and _window_col(tx, w) >= 0:
				img = win[ty][_window_col(tx, w)]
			elif ty == 0:
				img = wall_top0
			elif ty < Layout.TOP_WALL:
				img = wall_top1
			elif ty == h - 1:
				img = wall_bottom
			elif tx == 0 or tx == w - 1:
				img = wall_side
			else:
				# Position-hashed rather than random, so the speckle is
				# stable between runs and between rebuilds -- the floor must
				# not visibly reshuffle when you buy a tile.
				var shade := (tx + ty) % 2
				var v := absi(tx * 7919 + ty * 104729) % FLOOR_VARIANTS
				img = floors[v * 2 + shade]
			if img != null:
				im.blit_rect(img, src, here * t)

	return ImageTexture.create_from_image(im)


## Which half of a window this column is, or -1 for plain wall.
##
## The windows REPEAT rather than sitting at two fixed columns, so a room
## bought wider gets more of them instead of one lit end and a long blank
## stretch. The first pair lands where it always did.
const WINDOW_FIRST := 5
const WINDOW_EVERY := 7

static func _window_col(tx: int, w: int) -> int:
	if tx < WINDOW_FIRST or tx >= w - 2:
		return -1
	var off := (tx - WINDOW_FIRST) % WINDOW_EVERY
	return off if off <= 1 else -1


## Walls as a list of segments rather than four fixed boxes — which is
## exactly what lets the left wall have a doorway in it.
static func build_walls(parent: Node2D, grid: Grid) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("room_part")
	parent.add_child(body)

	grid.block_rect(Rect2i(0, 0, Grid.W, Grid.H), Grid.Cell.BLOCKED)
	grid.block_rect(Layout.floor_rect(), Grid.Cell.FREE)

	for seg: Rect2i in Layout.wall_segments():
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
		var seat: Vector2i = Layout.seat(i)
		var desk: Vector2i = Layout.desk_tile(i)

		# The chair is nudged 1px up so it always sorts BEHIND its occupant.
		var chair := add_prop(parent, PROP_CHAIR, Grid.tile_to_world(seat), Vector2.ZERO, -1.0)
		var body := add_prop(parent, PROP_DESK, Grid.tile_to_world(desk), Vector2(28, 16))   # doubled, was 14,8
		# Grouped so the room can tear the seating down and rebuild it when a
		# desk moves. Without this the old chair and desk stay behind as
		# scenery you can walk through.
		chair.add_to_group("desk_part")
		body.add_to_group("desk_part")

		# The finished sheet, hidden until they're done with it.
		var paper := Sprite2D.new()
		paper.texture = PROP_PAPER
		paper.position = Vector2(0, -36)   # doubled, was -18
		paper.visible = false
		body.add_child(paper)

		var station := Interactable.new()
		station.set_script(DESK_STATION_SCRIPT)
		station.seat_index = i
		station.paper = paper
		body.add_child(station)
		stations.append(station)

		# The same desk, on the other button: F picks the whole thing up.
		var mover := Interactable.new()
		mover.set_script(DESK_MOVER_SCRIPT)
		mover.seat_index = i
		mover.station = station      # it yields to whatever E offers
		body.add_child(mover)
		# One of these exists per desk -- up to 24 of them, all sharing F
		# with the noticeboard and the bell. At the default radius, a desk
		# placed adjacent to either could out-score it for the prompt: the
		# picker is pure proximity/facing, with no notion that "furniture
		# shop" matters more than "move this desk". `Audit the Room.bat`
		# caught exactly that at seed 4242 -- the noticeboard answered
		# "Move Ava's desk" in the afternoon. Same fix as the noticeboard
		# and curriculum board already use: shrink what shares a border.
		mover.set_pick_radius(16.0)

		grid.set_cell(seat, Grid.Cell.SEAT)
		grid.set_cell(desk, Grid.Cell.BLOCKED)
	return stations


static func build_podium(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_PODIUM, Grid.tile_to_world(Layout.PODIUM), Vector2(24, 16))   # doubled, was 12,8
	var it := Interactable.new()
	it.set_script(PODIUM_SCRIPT)
	body.add_child(it)

	# The same lectern, on the other button: E calls a quiz while F starts
	# and ends the lesson. They are never both live -- the podium only offers
	# anything in MORNING or at the END of a lesson, and the quiz only
	# DURING one -- so the picker is never asked to choose between them.
	var quiz := Interactable.new()
	quiz.set_script(QUIZ_CALLER_SCRIPT)
	quiz.add_to_group("quiz_caller")
	body.add_child(quiz)

	# And the unit test, also on E but only in the MORNING -- so it and the
	# quiz are never offered in the same phase.
	var unit := Interactable.new()
	unit.set_script(TEST_CALLER_SCRIPT)
	unit.add_to_group("test_caller")
	body.add_child(unit)

	grid.set_cell(Layout.PODIUM, Grid.Cell.BLOCKED)
	return it


static func build_teacher_desk(parent: Node2D, grid: Grid) -> Interactable:
	var anchor := Layout.span_anchor(Layout.TEACHER_DESK)
	var body := add_prop(parent, PROP_TEACHER_DESK, anchor, Vector2(60, 20))   # doubled, was 30,10
	var it := Interactable.new()
	it.set_script(MARKING_DESK_SCRIPT)
	body.add_child(it)
	# Same tile, other new key: marking homework used to share this
	# Interactable's own prompt: see homework_desk.gd for why it split off.
	var hw := Interactable.new()
	hw.set_script(HOMEWORK_DESK_SCRIPT)
	body.add_child(hw)
	# Third job, third key, same tile -- the phone/parent interruption the
	# roguelike pivot added. Same reasoning as homework's own split above.
	var rp := Interactable.new()
	rp.set_script(DESK_INTERRUPTION_SCRIPT)
	body.add_child(rp)
	for t: Vector2i in Layout.TEACHER_DESK:
		grid.set_cell(t, Grid.Cell.BLOCKED)
	return it


static func build_bell(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_BELL, Grid.tile_to_world(Layout.BELL), Vector2(24, 16))   # doubled, was 12,8
	var it := Interactable.new()
	it.set_script(BELL_SCRIPT)
	body.add_child(it)
	grid.set_cell(Layout.BELL, Grid.Cell.BLOCKED)
	return it


static func build_noticeboard(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_BOARD, Grid.tile_to_world(Layout.BOARD), Vector2(24, 16))   # doubled, was 12,8
	var it := Interactable.new()
	it.set_script(BOARD_SCRIPT)
	body.add_child(it)
	# Same reason as the curriculum board it shares a tile with: at the
	# default the shop answered from the BELL's square two tiles away, so
	# the morning offered "Furniture shop" while standing at the bell.
	it.set_pick_radius(24.0)   # doubled Aug 2026, was 12.0

	# Same board, other button: E is the shop, F is what you have learned to
	# teach. Both are always live, which is fine -- the picker only has to
	# choose between things that share an action.
	var cur := Interactable.new()
	cur.set_script(CURRICULUM_SCRIPT)
	cur.add_to_group("curriculum_board")
	body.add_child(cur)
	# The board sits two tiles from the BELL, and reach is the sum of both
	# circles -- so at the default it answered from the bell's own tile and
	# took the prompt with it. You have to be at the board to read the board.
	cur.set_pick_radius(18.0)   # doubled Aug 2026, was 9.0

	grid.set_cell(Layout.BOARD, Grid.Cell.BLOCKED)
	return it


static func build_ad_poster(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_AD_POSTER, Grid.tile_to_world(Layout.AD_POSTER), Vector2(24, 16))
	var it := Interactable.new()
	it.set_script(AD_POSTER_SCRIPT)
	body.add_child(it)
	# Deliberately NOT grid.set_cell(..., BLOCKED) -- unlike the bell/board/
	# podium, this is flat on the wall, not something standing in the
	# floor. Blocking its tile cost the room a seat right at the hard cap
	# and broke "desks keep their aisles" the first time this was tried;
	# a poster does not need to occupy walkable floor to be interactable.
	return it


## One piece of daily clutter -- trash or a spill -- dropped on an open
## floor tile. Unlike every other build_* here it does NOT block the grid:
## `block` stays Vector2.ZERO, so students and the teacher walk straight
## over it, which is the whole point of "clean it before or after class
## starts" rather than it becoming an obstacle to route around.
static func build_mess(parent: Node2D, tile: Vector2i, kind: String) -> Interactable:
	var tex: Texture2D = PROP_MESS_SPILL if kind == "spill" else PROP_MESS_TRASH
	var body := add_prop(parent, tex, Grid.tile_to_world(tile), Vector2.ZERO,
		0.0, false)   # no shadow -- both sprites are flat floor decals
	var it := Interactable.new()
	it.set_script(MESS_SCRIPT)
	it.kind = kind
	body.add_child(it)
	return it


## The hole in the left wall, which is already a walkable gap students spawn
## through. No sprite and no collider of its own -- the wall art already
## draws the doorway, and blocking it would undo the very thing that makes
## it a door. Just a trigger sitting where the wall already has a hole.
static func build_hall_door(parent: Node2D, _grid: Grid) -> Interactable:
	var it := Interactable.new()
	it.set_script(HALL_DOOR_SCRIPT)
	it.door_kind = "home"
	it.leads_out = true
	it.position = Grid.tile_to_world(Layout.DOOR)
	parent.add_child(it)
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
			Vector2(Items.width(id) * Grid.TILE - 4, 16), 0.0,   # was * 16 - 2, 8
			not Items.is_flat(id))
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
