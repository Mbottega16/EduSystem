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
## The mug on the teacher's desk, steaming (LimeZu's animated coffee, six
## frames) -- part of the desk, not an item. See build_teacher_desk().
const TEACHER_COFFEE := preload("res://art/teacher_coffee.png")
const TEACHER_COFFEE_ANIM := preload("res://art/teacher_coffee_anim.png")
const TEACHER_COFFEE_FRAMES := 6
const TEACHER_COFFEE_FPS := 5.0
## Someone's birthday (the day event): three of LimeZu's party balloons bob
## over the teacher's desk, tied at its left corner. Built hidden with the
## desk; classroom._tick_ambient() shows them on that day only, so they take
## themselves away -- an event's decoration, never shop clutter.
const BALLOONS := [
	[preload("res://art/balloon_red.png"), preload("res://art/balloon_red_anim.png")],
	[preload("res://art/balloon_blue.png"), preload("res://art/balloon_blue_anim.png")],
	[preload("res://art/balloon_yellow.png"), preload("res://art/balloon_yellow_anim.png")],
]
const BALLOON_FRAMES := 5
const BALLOON_FPS := 3.0
## The other days get something on the desk itself (Oct 2026), the same way:
## built hidden with the desk, shown by classroom._tick_ambient() on that day
## only. event id -> [art, frames (1 = still), fps]. The art is LimeZu's
## (tools/limezu_manifest.json), except the book stack, which no pack draws
## lying flat and is hand-drawn in his palette (tools/sprites/book_stack.txt).
## Cosmetic, so like WEATHER it may live in code: nothing reads it back.
const EVENT_DESK := {
	"cold_snap": ["snow_globe", 8, 6.0],
	"book_fair": ["book_stack", 1, 0.0],
	"heatwave": ["ice_cream", 1, 0.0],
	"bug": ["tissue_box", 1, 0.0],
	"sports_day": ["desk_ball", 1, 0.0],
	"budget": ["cash_bills", 1, 0.0],
	"small_grant": ["cash_bills", 1, 0.0],
	"parents_evening": ["donut_plate", 1, 0.0],
	"new_face": ["flower_vase", 1, 0.0],
}
## Where a desk-top piece stands: bottom-centre, on the front of the desk's
## top at its left end -- the register lies open in the middle and the mug and
## pen pot hold the right, so it rests on the register's near corner.
const EVENT_DESK_SPOT := Vector2(-14, -16)
## Sunlight through each window, lying on the floor below it (build_sunlight).
const SUN_COLOUR := Color(1.0, 0.93, 0.72, 0.16)
const SUN_DEPTH := 96            # px down the floor it reaches (3 tiles)
const SUN_LEAN := 28             # px it slides right over that depth
const PROP_PAPER := preload("res://art/paper.png")
const PROP_BELL := preload("res://art/bell.png")
const PROP_BOARD := preload("res://art/noticeboard.png")
const PROP_AD_POSTER := preload("res://art/ad_poster.png")
const PROP_CABINET := preload("res://art/cabinet_body.png")
const PROP_MESS_TRASH := preload("res://art/mess_trash.png")
const PROP_MESS_SPILL := preload("res://art/mess_spill.png")
const SHADOW_TEX := preload("res://art/shadow.png")

const DESK_STATION_SCRIPT := preload("res://scripts/interact/desk_station.gd")
const DESK_MOVER_SCRIPT := preload("res://scripts/interact/desk_mover.gd")
const PODIUM_SCRIPT := preload("res://scripts/interact/podium.gd")
const QUIZ_CALLER_SCRIPT := preload("res://scripts/interact/quiz_caller.gd")
const ANSWER_ALL_CALLER_SCRIPT := preload("res://scripts/interact/answer_all_caller.gd")
const TEST_CALLER_SCRIPT := preload("res://scripts/interact/test_caller.gd")
const MARKING_DESK_SCRIPT := preload("res://scripts/interact/marking_desk.gd")
const HOMEWORK_DESK_SCRIPT := preload("res://scripts/interact/homework_desk.gd")
const DESK_INTERRUPTION_SCRIPT := preload("res://scripts/interact/desk_interruption.gd")
const BELL_SCRIPT := preload("res://scripts/interact/bell.gd")
const BOARD_SCRIPT := preload("res://scripts/interact/noticeboard.gd")
const AD_POSTER_SCRIPT := preload("res://scripts/interact/ad_poster.gd")
const CABINET_SCRIPT := preload("res://scripts/interact/cabinet.gd")
const CURRICULUM_SCRIPT := preload("res://scripts/interact/curriculum_board.gd")
const HALL_DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const PLACED_SCRIPT := preload("res://scripts/interact/placed_item.gd")
const MESS_SCRIPT := preload("res://scripts/interact/mess.gd")
const SPEECH_BUBBLE_SCENE := preload("res://scenes/actors/speech_bubble.tscn")
const PROP_ANIM_SCRIPT := preload("res://scripts/world/prop_anim.gd")


static func make_box(size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	return shape


## A prop standing on the floor. `sort_bias` breaks exact y ties, which Godot
## otherwise resolves by tree order — silently order-dependent and miserable
## to debug. `art_offset` shifts ONLY the visible sprite (and its shadow),
## leaving the body, its collider and any Interactable child on the anchor
## tile — used to hang the noticeboard up on the brick while you still walk
## up to it on the floor.
static func add_prop(parent: Node2D, tex: Texture2D, at: Vector2,
		block: Vector2, sort_bias: float = 0.0,
		with_shadow: bool = true, art_offset: Vector2 = Vector2.ZERO) -> StaticBody2D:
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
		shade.position = Vector2(0, -4) + art_offset   # doubled, was -2
		shade.scale = Vector2(maxf(1.0, tex.get_width() / 32.0), 1.0)   # was /16.0
		body.add_child(shade)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.position = Vector2(0, -tex.get_height() / 2.0) + art_offset   # bottom edge on the anchor
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


## The other floor-and-wall pairs a space off the corridor can wear
## (tools/limezu_room.json "looks"): the principal's office, and one per room
## you hold, cycled. Each is the same 18 tiles with `_<look>` on the name.
const LOOKS := ["office", "room_a", "room_b", "room_c", "room_d", "room_e"]
const ROOM_LOOKS := ["room_a", "room_b", "room_c", "room_d", "room_e"]


## A room tile by name, in `look` if one is given -- the classroom's own
## otherwise, and the classroom's own if that look has no such tile.
static func _tile_img(name: String, look: String = "") -> Image:
	var tex: Texture2D = null
	if look != "" and ResourceLoader.exists("res://art/%s_%s.png" % [name, look]):
		tex = load("res://art/%s_%s.png" % [name, look])
	if tex == null:
		tex = load("res://art/%s.png" % name)
	return tex.get_image() if tex != null else null


## Paint the room at its current size, piece by piece. `w_in`/`h_in` paint a
## different size instead (the room-ideas preview always shows the opening 20x11).
static func compose_room(w_in: int = -1, h_in: int = -1) -> ImageTexture:
	var w := Grid.W if w_in < 0 else w_in
	var h := Grid.H if h_in < 0 else h_in
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

## True when something hung at this column would cover a window (in a room `w`
## tiles wide; the current room when omitted).
static func is_window_col(tx: int, w: int = -1) -> bool:
	return _window_col(tx, Grid.W if w < 0 else w) >= 0


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
##
## The opening scene withholds some: Game.desks_in_store is how many are
## still folded up in the cabinet, so this builds seat_count() minus that,
## from seat 0 up, and the room fills in as the teacher pulls them out.
static func build_desks(parent: Node2D, grid: Grid) -> Array:
	var stations: Array = []
	var built := maxi(0, Layout.seat_count() - Game.desks_in_store)
	for i in built:
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

	# Same lectern, its own key (J): the mass-help skill. Only live DURING a
	# lesson and only once its cooldown is up, so it never competes with the
	# lesson-start/quiz prompts for the picker.
	var answer_all := Interactable.new()
	answer_all.set_script(ANSWER_ALL_CALLER_SCRIPT)
	answer_all.add_to_group("answer_all_caller")
	body.add_child(answer_all)

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
	# A mug of coffee on the right of the desk, steaming. The room had
	# nothing that moved on its own but a fish tank and a butterfly; a
	# teacher's desk with a hot drink on it is lived in. Sits on the desk's
	# top edge, in front of the pen pot.
	var mug := Sprite2D.new()
	mug.texture = TEACHER_COFFEE
	mug.position = Vector2(17, -17 - TEACHER_COFFEE.get_height() / 2.0)
	mug.name = "Coffee"
	body.add_child(mug)
	var steam := Node.new()
	steam.set_script(PROP_ANIM_SCRIPT)
	body.add_child(steam)
	steam.setup(mug, TEACHER_COFFEE_ANIM,
		{"frames": TEACHER_COFFEE_FRAMES, "fps": TEACHER_COFFEE_FPS}, 0.0)
	var bunch := Node2D.new()
	bunch.name = "Balloons"
	bunch.visible = false
	bunch.add_to_group("birthday_balloons")
	body.add_child(bunch)
	# Fanned out from one knot at the desk's left corner, the middle one
	# highest, each a beat out of step so they do not bob in unison.
	var spots := [Vector2(-34, -6), Vector2(-24, -16), Vector2(-14, -4)]
	for i in BALLOONS.size():
		var b := Sprite2D.new()
		b.texture = BALLOONS[i][0]
		b.position = Vector2(spots[i].x, -20 + spots[i].y - BALLOONS[i][0].get_height() / 2.0)
		bunch.add_child(b)
		var bob := Node.new()
		bob.set_script(PROP_ANIM_SCRIPT)
		bunch.add_child(bob)
		bob.setup(b, BALLOONS[i][1], {"frames": BALLOON_FRAMES, "fps": BALLOON_FPS}, 0.45 * i)
	bunch.add_to_group("event_decor")
	bunch.set_meta("event", "birthday")
	build_event_desk(body)
	for t: Vector2i in Layout.TEACHER_DESK:
		grid.set_cell(t, Grid.Cell.BLOCKED)
	return it


## One hidden piece per EVENT_DESK row on the teacher's desk, each in the
## "event_decor" group with its day's id as meta -- classroom._tick_ambient()
## shows the one whose day it is. Added after the register and the mug, so it
## draws over them; no z_index, which would lift it over people too.
static func build_event_desk(desk: Node2D) -> void:
	for id: String in EVENT_DESK:
		var row: Array = EVENT_DESK[id]
		var tex: Texture2D = load("res://art/%s.png" % String(row[0]))
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.name = "OnDesk_%s" % id
		spr.texture = tex
		spr.position = EVENT_DESK_SPOT - Vector2(0, tex.get_height() / 2.0)
		spr.visible = false
		spr.add_to_group("event_decor")
		spr.set_meta("event", id)
		desk.add_child(spr)
		if int(row[1]) > 1:
			var drive := Node.new()
			drive.set_script(PROP_ANIM_SCRIPT)
			spr.add_child(drive)
			drive.setup(spr, load("res://art/%s_anim.png" % String(row[0])),
				{"frames": int(row[1]), "fps": float(row[2])}, 0.0)


## Sunlight through each window, lying on the floor below it: a pale, warm
## band that leans away from the light (the sun is up and to the left),
## stepped on the room's 2px grid so its edge reads as pixel art, and fading
## out in three steps at its far end. It sits at y = 0 in a y-sorted room,
## added straight after the floor, so desks, people and props all stand IN it
## rather than under a sheet of glass. Overcast days hide it and fair ones
## send dust drifting through it (classroom._tick_ambient). Decoration only.
## -> [{node, rect}] -- `rect` is the band's bounding box, where dust can float.
static func build_sunlight(parent: Node2D) -> Array:
	var out: Array = []
	var w := Grid.W
	var y0 := float(Layout.TOP_WALL * Grid.TILE)
	for tx in w:
		if _window_col(tx, w) != 0:
			continue
		var x0 := float(tx * Grid.TILE + 6)
		var width := float(2 * Grid.TILE - 12)
		var beam := Node2D.new()
		beam.name = "Sunlight%d" % tx
		beam.add_to_group("room_part")
		beam.add_to_group("sunlight")
		parent.add_child(beam)
		beam.draw.connect(func() -> void:
			var rows := SUN_DEPTH / 2
			for i in rows:
				var lean := floorf(float(SUN_LEAN) * i / rows / 2.0) * 2.0
				var a := SUN_COLOUR.a
				if i >= rows * 2 / 3:
					a *= 0.35
				elif i >= rows / 3:
					a *= 0.7
				beam.draw_rect(Rect2(x0 + lean, y0 + i * 2.0, width, 2.0),
					Color(SUN_COLOUR, a)))
		beam.queue_redraw()
		out.append({"node": beam,
			"rect": Rect2(x0, y0, width + SUN_LEAN, float(SUN_DEPTH))})
	return out


static func build_bell(parent: Node2D, grid: Grid) -> Interactable:
	var body := add_prop(parent, PROP_BELL, Grid.tile_to_world(Layout.BELL), Vector2(24, 16))   # doubled, was 12,8
	var it := Interactable.new()
	it.set_script(BELL_SCRIPT)
	body.add_child(it)
	grid.set_cell(Layout.BELL, Grid.Cell.BLOCKED)
	return it


static func build_cabinet(parent: Node2D, grid: Grid) -> Interactable:
	# Stands on the floor against the back wall, so it blocks its tile the
	# same way the podium and bell do -- you walk up to the row below it.
	var body := add_prop(parent, PROP_CABINET, Grid.tile_to_world(Layout.CABINET),
		Vector2(28, 18))
	var it := Interactable.new()
	it.set_script(CABINET_SCRIPT)
	body.add_child(it)
	grid.set_cell(Layout.CABINET, Grid.Cell.BLOCKED)
	return it


static func build_noticeboard(parent: Node2D, grid: Grid) -> Interactable:
	# The board art is two tiles wide and hangs UP on the brick: art_offset
	# lifts the sprite ~a tile clear of the floor while the body, collider
	# and both Interactables stay on the tile you walk up to. No floor
	# contact shadow either -- it is on the wall, not standing on the floor.
	var body := add_prop(parent, PROP_BOARD, Grid.tile_to_world(Layout.BOARD),
		Vector2(24, 16), 0.0, false, Vector2(0, -34))
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
	# No collider (Vector2.ZERO), not just an unblocked grid cell: it is flat
	# on the wall, so you walk straight past it and reach it by proximity.
	# It sits in the bottom-left corner now (Layout.AD_POSTER), which is the
	# exact tile the "left wall stops the player" test walks through -- a
	# 24x16 collider there stopped the player a tile short of the wall.
	var body := add_prop(parent, PROP_AD_POSTER, Grid.tile_to_world(Layout.AD_POSTER), Vector2.ZERO)
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


## A few pieces of decor the room simply STARTS with -- part of what a
## classroom looks like on day one, not something bought or earned. Flat
## against the back wall and non-blocking (like the ad poster), so they
## cost the room no floor and never land on a path. Rebuilt with the room;
## never entered into Game.room_items, so they are not owned, sold, moved
## or scored -- purely the difference between a bare room and a lived-in
## one. Ids confirmed against the cat:"decor" block in data/balance.json.
## They HANG: on the wall row (Layout.WALL_ROW == 1, written as a literal here
## so these two scripts do not reference each other's constants; the suite
## asserts they agree), in the wall's own band, not on the first row of floor
## where they used to stand like furniture. The frieze sits at 14-15 because
## the second window covers 12-13.
## The butterfly is the first of these that MOVES, and the first that was
## never for sale (`"shop": false` -- see Items.in_shop()). It sits on the
## window columns, which no bought piece may cover, so it is the one seed
## that can never be hung over.
## The clock is the second (Oct 2026): a cuckoo clock whose pendulum swings,
## in place of the still square one -- which is still in the shop.
const DECOR_SEED := [
	["cuckoo_clock", Vector2i(8, 1)],
	["class_banner", Vector2i(10, 1)],
	["window_butterfly", Vector2i(13, 1)],
	["alphabet_frieze", Vector2i(14, 1)],
]

## The wall columns the player has hung something on.
static func hung_cols() -> Array[int]:
	var out: Array[int] = []
	for placed: Dictionary in Game.room_items:
		var pid := String(placed.get("id", ""))
		if Items.is_wall(pid):
			for t: Vector2i in Items.footprint(pid, placed["tile"]):
				out.append(t.x)
	return out


## The starting decor that is still showing: a seeded piece gives way as soon
## as a bought one is hung over any column of it, and comes back when that is
## taken down. `hung` is the columns in use (see hung_cols()).
static func visible_seeds(hung: Array[int]) -> Array:
	var out: Array = []
	for row: Array in DECOR_SEED:
		var covered := false
		for t: Vector2i in Items.footprint(String(row[0]), row[1] as Vector2i):
			if hung.has(t.x):
				covered = true
		if not covered:
			out.append(row)
	return out


static func build_decor(parent: Node2D, _grid: Grid) -> Array:
	var nodes: Array = []
	for row: Array in visible_seeds(hung_cols()):
		var id := String(row[0])
		var def := Items.get_def(id)
		if def.is_empty():
			continue
		var tiles := Items.footprint(id, row[1] as Vector2i)
		var tex: Texture2D = load("res://art/%s.png" % String(def["art"]))
		if tex == null:
			continue
		# Vector2.ZERO block -> no collider, and no grid.set_cell(): a wall
		# decoration does not stand on the floor, so it does not occupy it.
		var body := add_prop(parent, tex, Layout.wall_anchor(tiles),
			Vector2.ZERO, 0.0, false)
		body.add_to_group("seeded_decor")
		# Seeded decor animates on the same hook a bought piece does, so the
		# room's own pieces are not second-class: one `anim` block and it moves.
		_animate_if_it_moves(body, def, row[1] as Vector2i)
		nodes.append(body)
	return nodes


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


## An item whose def carries an `anim` block plays an animation strip once it is
## standing in the room (the shop's ghost keeps the still first frame). Only the
## prop's own sprite is swapped, AFTER add_prop() sized the shadow and the
## collider from the still art, so an animated item occupies exactly the space
## its still one did.
static func _animate_if_it_moves(body: Node2D, def: Dictionary, tile: Vector2i) -> void:
	var anim: Variant = def.get("anim", null)
	if not (anim is Dictionary):
		return
	var strip: Texture2D = load("res://art/%s.png" % String((anim as Dictionary).get("art", "")))
	var spr: Sprite2D = null
	for c: Node in body.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != SHADOW_TEX:
			spr = c as Sprite2D
	if spr == null or strip == null:
		return
	var driver := Node.new()
	driver.set_script(PROP_ANIM_SCRIPT)
	body.add_child(driver)
	driver.setup(spr, strip, anim as Dictionary, float(tile.x * 7 + tile.y * 3) * 0.37)
	driver.name = "PropAnim"


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
		var hung := Items.is_wall(id)
		var anchor := Layout.wall_anchor(tiles) if hung else Layout.span_anchor(tiles)
		var tex: Texture2D = load("res://art/%s.png" % String(def["art"]))
		# A hung piece has no collider and no shadow, and (below) takes no floor.
		var body := add_prop(parent, tex, anchor,
			Vector2.ZERO if hung else Vector2(Items.width(id) * Grid.TILE - 4, 16), 0.0,   # was * 16 - 2, 8
			not (hung or Items.is_flat(id)))
		body.add_to_group("purchased")
		if hung:
			body.add_to_group("hung")
		_animate_if_it_moves(body, def, placed["tile"])

		# every bought item can be picked up again
		var it := Interactable.new()
		it.set_script(PLACED_SCRIPT)
		it.item_id = id
		it.origin = placed["tile"]
		body.add_child(it)
		nodes.append(body)
		if hung:
			continue          # on the wall: no floor tile is used up
		for t: Vector2i in tiles:
			grid.set_cell(t, Grid.Cell.BLOCKED)
	return nodes
