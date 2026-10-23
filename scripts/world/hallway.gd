extends Node2D

## The corridor between the rooms you hold.
##
## Replaces the abstract School screen's door-picking with an actual one:
## walk to the door that is the room you want, press F. Your own room is
## always the first door. Every room in Game.rooms gets one after it, in
## the order you opened them. One more door appears at the end for the
## next room you could open, but only when Game.can_open_room() says you
## actually can -- a locked door with nothing behind it is exactly the
## "offers nothing" failure this project already had to fix once, at the
## podium, so it is not one to reintroduce here.
##
## PLACEMENT: main.tscn parks this node 10000px below the classroom.
## `visible = false` alone was not enough -- a hidden StaticBody2D still
## collides, so the corridor's own walls were overlapping the classroom's
## coordinate space and the player was colliding with an invisible wall in
## their OWN room. Caught by an existing test failing ("the top wall stops
## the player"), not by anything written for this feature -- worth
## remembering next time two scenes share an origin.
##
## WHAT WALKING THROUGH ONE DOES NOT DO: put the player inside that room to
## teach it. A delegated room is still resolved by RoomSim, same as it
## always was. Since Oct 2026 a staffed room's door does put you IN the room
## -- as a visitor (VisitRoom): its class, its teacher, its last day replayed
## from RoomSim's own frames, E at the front for the watch screen -- but
## nothing in there is played; it is not a second body to puppet. Teaching two rooms at once is not a thing this game's model
## supports, and pretending otherwise here would be exactly the kind of
## plausible-looking feature CLAUDE.md warns against.
##
## THE GRADE WING (Oct 2026, the owner's ask). Above the corridor, behind its
## wall, a classroom for every stage of the school -- elementary, middle, high,
## college -- each one a LiveRoom running forever: a class at work, a teacher
## walking to raised hands. They are what the next stage looks like, so the
## corridor is a map of where the career goes. Each has a door in the corridor
## wall and a plaque beside it; E at the door reads the stage's card, and the
## card is where you move up (Game.move_up()). The corridor floor is three
## tiles, not four, so the wing, the corridor and its doors fit one screen.

signal door_chosen(kind: String, room_index: int)
## E at a grade-wing door -- main.gd opens that stage's card.
signal stage_chosen(tier_index: int)

const DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const SPACING := 96.0   # doubled Aug 2026, was 48.0
const MARGIN := 64.0   # doubled Aug 2026, was 32.0
## Three floor tiles since the grade wing (Oct 2026): four was 128, and the
## wing, the corridor and the doors would not fit one screen.
const HEIGHT := 96.0
## The classroom's own door art (tile_door_top over tile_door_bottom),
## reused rather than drawing new art -- a hallway door should look like
## the door it already is, not invent a second design.
const DOOR_TOP := preload("res://art/tile_door_top.png")
const DOOR_BOTTOM := preload("res://art/tile_door_bottom.png")
const PROP_ANIM_SCRIPT := preload("res://scripts/world/prop_anim.gd")

## The corridor's look (Oct 2026). It was a flat dark rectangle with the doors
## standing on it. Now it is painted from the classroom's own LimeZu tiles --
## a wall along the top, the same floor, a skirting wall along the bottom that
## the doors stand against, the ends walled off -- and the top wall is lined
## with what a school corridor has. All existing art, none of it collides, and
## it is built once with the bounds (the corridor's width never changes).
const WALL_H := 64.0            # two wall tiles above the floor
## What lines the top wall, left to right, repeating: [art, "stand" on the
## floor with its back to the wall, or "hang" on the wall's face].
const LINING := [
	["cabinet_body", "stand"], ["cabinet_body", "stand"], ["cabinet_body", "stand"],
	["noticeboard", "hang"], ["plant", "stand"], ["wall_clock", "hang"],
	["water_cooler", "stand"], ["coat_hooks", "hang"], ["fish_tank", "stand"],
	["sticker_chart", "hang"], ["cabinet_body", "stand"], ["cabinet_body", "stand"],
	["certificate", "hang"], ["plant", "stand"], ["world_map", "hang"],
]
const LINING_GAP := 10.0
## The trophy case (TrophyCase) stands against the wall between the office
## door and the mentor's, centred here; the lining leaves it a gap.
const TROPHY_CASE_X := 232.0

## The grade wing: one LiveRoom per stage, side by side above the corridor
## wall, a wall tile between each. A room's door is in the corridor wall at
## WING_DOOR_COL, its plaque to the left of the door.
const WING_ROOM_W := LiveRoom.W
const WING_DIVIDER := 32.0
const WING_STRIDE := WING_ROOM_W + WING_DIVIDER
const WING_TOP := -(WALL_H + LiveRoom.FLOOR + LiveRoom.WALL)
const WING_DOOR_COL := 3
const PLAQUE_X := 6.0
const PLAQUE_SIZE := Vector2(76, 32)
const PLAQUE_FONT := preload("res://fonts/Galmuri9.ttf")
const STAGE_DOOR_SCRIPT := preload("res://scripts/interact/stage_door.gd")
## The rooms, the doors and the plaques, in Balance.tier_order -- for the tests.
var wing_rooms: Array = []
var wing_doors: Array = []
var plaques: Array = []
var _wing: Node2D = null
var _w := 0.0
## The props along the wall, for the tests.
var lining: Array = []
var trophy_case: TrophyCase = null

## Someone pressed E at the trophy case -- main.gd opens the list.
signal trophies_viewed()

var doors: Array = []
var _door_art: Array = []
var _walls_built: bool = false


func _ready() -> void:
	_build_bounds()
	rebuild()
	# The wing's rooms only run while you can see them.
	visibility_changed.connect(_wake_wing)
	_wake_wing()


func _wake_wing() -> void:
	if _wing != null:
		_wing.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED


## Top and bottom walls plus the two ends, built once at a generous width so
## a rebuild (a room opened mid-visit) never needs to redo them. A corridor
## has no furniture to collide with, so this is the whole of its geometry.
func _build_bounds() -> void:
	if _walls_built:
		return
	_walls_built = true
	Balance.ensure_loaded()
	# Wide enough for every door the corridor can ever have (home, office,
	# mentor, every room, the next to open), and for the whole grade wing.
	var w := maxf(MARGIN * 2.0 + SPACING * float(Balance.max_rooms + 3), _wing_width())
	_w = w

	# The dark beyond the corridor's walls -- the old floor's colour, now only
	# what the camera sees past the building.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.16, 0.14, 0.13)
	backdrop.position = Vector2(-MARGIN - 600.0, WING_TOP - 600.0)
	backdrop.size = Vector2(w + MARGIN * 2.0 + 1200.0, HEIGHT - WING_TOP + 1232.0)
	backdrop.z_index = -11
	add_child(backdrop)
	var floor_spr := Sprite2D.new()
	floor_spr.name = "HallFloor"
	floor_spr.texture = _compose(w)
	floor_spr.centered = false
	floor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_spr.position = Vector2(-MARGIN, WING_TOP)
	floor_spr.z_index = -10
	add_child(floor_spr)
	_build_wing()
	_line_the_wall(w)

	for seg: Rect2 in [
		Rect2(0.0, -16.0, w, 16.0),          # top
		Rect2(0.0, HEIGHT, w, 16.0),        # bottom
		Rect2(-16.0, -16.0, 16.0, HEIGHT + 32.0),   # left end
		Rect2(w, -16.0, 16.0, HEIGHT + 32.0),      # right end
	]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = seg.size
		shape.shape = rect
		shape.position = seg.position + seg.size * 0.5
		body.add_child(shape)
		add_child(body)


## The corridor as one image, from the classroom's tiles: MARGIN of end wall
## each side; above the corridor wall, the walls round the grade wing's rooms
## (the rooms paint their own insides); two rows of corridor wall with the
## wing's doors in it; the floor; one row of skirting wall. Origin at
## (-MARGIN, WING_TOP).
func _compose(w: float) -> ImageTexture:
	var t := Grid.TILE
	var cols := int(ceil((w + MARGIN * 2.0) / float(t)))
	var floor_rows := int(HEIGHT / float(t))
	var wing_rows := int((-WING_TOP - WALL_H) / float(t))
	var rows := wing_rows + 2 + floor_rows + 1
	var im := Image.create(cols * t, rows * t, false, Image.FORMAT_RGBA8)
	var floors: Array[Image] = []
	for i in RoomBuilder.FLOOR_VARIANTS:
		floors.append(RoomBuilder._tile_img("tile_floor_a%d" % i))
		floors.append(RoomBuilder._tile_img("tile_floor_b%d" % i))
	var top0 := RoomBuilder._tile_img("tile_wall_top0")
	var top1 := RoomBuilder._tile_img("tile_wall_top1")
	var side := RoomBuilder._tile_img("tile_wall_side")
	var bottom := RoomBuilder._tile_img("tile_wall_bottom")
	var door_top := RoomBuilder._tile_img("tile_door_top")
	var door_bottom := RoomBuilder._tile_img("tile_door_bottom")
	var src := Rect2i(0, 0, t, t)
	var end_cols := int(MARGIN / float(t))
	var door_cols: Array = []
	for i in Game.tier_count():
		door_cols.append(end_cols + int(wing_door_x(i) / float(t)))
	for ty in rows:
		for tx in cols:
			var img: Image
			var x := float((tx - end_cols) * t)
			var inside := tx >= end_cols and x < w
			if not inside:
				img = side
			elif ty < wing_rows:
				# A wing room's own tiles are its LiveRoom's; between and
				# beyond them, the building's wall.
				if _in_wing_room(x):
					continue
				img = top0 if ty == 0 else (top1 if ty == 1 else side)
			elif ty == wing_rows:
				img = door_top if door_cols.has(tx) else top0
			elif ty == wing_rows + 1:
				img = door_bottom if door_cols.has(tx) else top1
			elif ty == rows - 1:
				img = bottom
			else:
				# Hashed by position, as the classroom's floor is: stable
				# between visits rather than reshuffled.
				var v := absi(tx * 7919 + (ty - wing_rows) * 104729) % RoomBuilder.FLOOR_VARIANTS
				img = floors[v * 2 + (tx + ty) % 2]
			if img != null:
				im.blit_rect(img, src, Vector2i(tx, ty) * t)
	return ImageTexture.create_from_image(im)


## Line the top wall with LINING, repeating, end to end. A "stand" prop's
## bottom sits a few pixels onto the floor, back to the wall; a "hang" one is
## centred on the wall's face. The fish tank plays its strip, as a bought one does.
func _line_the_wall(w: float) -> void:
	trophy_case = TrophyCase.new()
	trophy_case.name = "TrophyCase"
	trophy_case.position = Vector2(TROPHY_CASE_X, 8.0)
	trophy_case.z_index = -9
	add_child(trophy_case)
	trophy_case.looked.connect(func() -> void: trophies_viewed.emit())
	var half := TrophyCase.CASE.get_width() / 2.0
	# Kept clear: the trophy case, and each wing room's plaque and door.
	var keep_clear: Array = [Vector2(TROPHY_CASE_X - half - LINING_GAP, TROPHY_CASE_X + half + LINING_GAP)]
	for t in Game.tier_count():
		keep_clear.append(Vector2(wing_x(t) + PLAQUE_X - LINING_GAP,
			wing_door_x(t) + Grid.TILE + LINING_GAP))
	var x := 18.0
	var i := 0
	while true:
		var row: Array = LINING[i % LINING.size()]
		var tex: Texture2D = load("res://art/%s.png" % String(row[0]))
		if tex == null:
			i += 1
			continue
		# Step round whatever is kept clear: what would overlap it goes after it.
		var moved := true
		while moved:
			moved = false
			for span: Vector2 in keep_clear:
				if x + tex.get_width() > span.x and x < span.y:
					x = span.y
					moved = true
		if x + tex.get_width() > w - 18.0:
			break
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.name = "Lining%d_%s" % [i, String(row[0])]
		var cy := -WALL_H * 0.5 - 2.0 if String(row[1]) == "hang" else 8.0 - tex.get_height() / 2.0
		spr.position = Vector2(x + tex.get_width() / 2.0, cy)
		spr.z_index = -9
		add_child(spr)
		lining.append(spr)
		var anim: Variant = Items.get_def(String(row[0])).get("anim", null)
		if anim is Dictionary:
			var strip: Texture2D = load("res://art/%s.png" % String((anim as Dictionary).get("art", "")))
			var drive := Node.new()
			drive.set_script(PROP_ANIM_SCRIPT)
			drive.name = "PropAnim"
			spr.add_child(drive)
			drive.setup(spr, strip, anim, 0.3 * float(i))
		x += tex.get_width() + LINING_GAP
		i += 1


## The left edge of stage `i`'s room, in corridor x.
func wing_x(i: int) -> float:
	return float(i) * WING_STRIDE


## The left edge of stage `i`'s door in the corridor wall.
func wing_door_x(i: int) -> float:
	return wing_x(i) + float(WING_DOOR_COL * Grid.TILE)


func _wing_width() -> float:
	return float(Game.tier_count()) * WING_STRIDE - WING_DIVIDER


func _in_wing_room(x: float) -> bool:
	if x < 0.0 or x >= _wing_width():
		return false
	return fmod(x, WING_STRIDE) < WING_ROOM_W


## A LiveRoom per stage above the corridor wall, its door below it in the wall,
## its plaque beside the door. Built once: the stages never change; what the
## plaques say does, and rebuild() refreshes them.
func _build_wing() -> void:
	_wing = Node2D.new()
	_wing.name = "GradeWing"
	_wing.z_index = -7
	add_child(_wing)
	for i in Game.tier_count():
		var room := LiveRoom.new()
		room.name = "Wing_%s" % Game.tier_id(i)
		room.position = Vector2(wing_x(i), WING_TOP)
		_wing.add_child(room)
		room.setup(Game.tier_id(i), i * 3 + 1)
		wing_rooms.append(room)

		var d := STAGE_DOOR_SCRIPT.new()
		d.tier_index = i
		d.position = Vector2(wing_door_x(i) + Grid.TILE / 2.0, 14.0)
		d.set_pick_radius(14.0)
		d.chosen.connect(func(ti: int) -> void: stage_chosen.emit(ti))
		add_child(d)
		wing_doors.append(d)

		plaques.append(_plaque(Vector2(wing_x(i) + PLAQUE_X, -WALL_H + 14.0)))


## A wooden plaque on the corridor wall: the stage's short name over its
## grades. Its colour says where you stand (_paint_plaques()).
func _plaque(at: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = at
	root.z_index = -8
	add_child(root)
	var edge := ColorRect.new()
	edge.name = "Edge"
	edge.size = PLAQUE_SIZE
	edge.color = Color("3a3a50")
	root.add_child(edge)
	var face := ColorRect.new()
	face.name = "Face"
	face.position = Vector2(2, 2)
	face.size = PLAQUE_SIZE - Vector2(4, 4)
	root.add_child(face)
	for k in 2:
		var l := Label.new()
		l.name = "Line%d" % k
		l.add_theme_font_override("font", PLAQUE_FONT)
		l.add_theme_font_size_override("font_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(2, 3 + k * 13)
		l.size = Vector2(PLAQUE_SIZE.x - 4, 12)
		root.add_child(l)
	return root


## Each plaque: the stage and its grades, in the colour of where you stand --
## gold for your own stage, green for the next one, wood for the rest.
func _paint_plaques() -> void:
	for i in plaques.size():
		var root: Node2D = plaques[i]
		var def := Game.tier_def(i)
		var short := String(def.get("name", "")).split(" ")[0].to_upper()
		var face: ColorRect = root.get_node("Face")
		var top: Label = root.get_node("Line0")
		var low: Label = root.get_node("Line1")
		top.text = short
		var grades := String(def.get("grades", "")).replace("Grades ", "")
		var ink := Color("f4ead2")
		if i == Game.age_tier:
			face.color = Color("e8b84a")
			ink = Color("3a2a14")
			low.text = "%s  YOU" % grades
		elif i == Game.age_tier + 1:
			face.color = Color("6fae5c")
			low.text = "%s  NEXT" % grades
		else:
			face.color = Color("7a5a3e") if i > Game.age_tier else Color("5e5a52")
			low.text = grades
		for l: Label in [top, low]:
			l.add_theme_color_override("font_color", ink)


## Called on entry, and again any time Game.rooms changes shape (a room
## opened, a hire made) while the hallway is still the active scene.
func rebuild() -> void:
	for d in doors:
		if is_instance_valid(d):
			d.queue_free()
	doors.clear()
	for a in _door_art:
		if is_instance_valid(a):
			a.queue_free()
	_door_art.clear()
	# A trophy won since the last visit is standing in the case now.
	if trophy_case != null:
		trophy_case.refresh()
	# A move up since the last visit shows on the wing's plaques.
	_paint_plaques()

	# Slots 0-2 are always home, the office, and the mentor teacher's room --
	# none of the three counts against Game.rooms or the max_rooms cap, all
	# three being about YOU rather than a room you are running. Rooms you
	# hold follow from slot 3.
	var n := 3 + Game.rooms.size() + (1 if Game.can_open_room() else 0)
	for i in n:
		var kind: String
		var idx := -1
		if i == 0:
			kind = "home"
		elif i == 1:
			kind = "office"
		elif i == 2:
			kind = "mentor"
		elif i <= 2 + Game.rooms.size():
			kind = "room"
			idx = i - 3
		else:
			kind = "open"
		var dx := MARGIN + float(i) * SPACING

		# The door itself: the classroom's own two-tile door art, bottom
		# edge on the floor line, same "bottom row meets the floor"
		# anchor every other prop in this game uses.
		#
		# TINTED BY KIND -- every door used the same untinted art, so
		# telling "home" from "the office" from "a room you hold" meant
		# walking up and reading the prompt, confirmed by screenshot as a
		# real "which one is which" problem rather than assumed. A colour
		# is not full signage, but it is the smallest change that turns
		# four identical doors into four doors you can tell apart from
		# across the corridor.
		var tint := _door_tint(kind, idx)
		var top_spr := Sprite2D.new()
		top_spr.texture = DOOR_TOP
		top_spr.centered = false
		top_spr.modulate = tint
		top_spr.position = Vector2(dx - 16.0, HEIGHT - 64.0)   # doubled, door art is 32x32/tile now
		add_child(top_spr)
		_door_art.append(top_spr)
		var bottom_spr := Sprite2D.new()
		bottom_spr.texture = DOOR_BOTTOM
		bottom_spr.centered = false
		bottom_spr.modulate = tint
		bottom_spr.position = Vector2(dx - 16.0, HEIGHT - 32.0)
		add_child(bottom_spr)
		_door_art.append(bottom_spr)

		var d := DOOR_SCRIPT.new()
		d.door_kind = kind
		d.room_index = idx
		d.position = Vector2(dx, HEIGHT - 16.0)
		# Doors 48px apart with the player's own 20px zone would overlap a
		# neighbour's reach at the default 20px circle -- same fix as the
		# noticeboard/curriculum board sharing a tile.
		d.set_pick_radius(32.0)   # doubled Aug 2026, was 8.0 -> 16.0 -> 32.0
		d.chosen.connect(func(k: String, ri: int) -> void: door_chosen.emit(k, ri))
		add_child(d)
		doors.append(d)


## The colour each door kind gets tinted, so the row reads at a glance
## rather than only on approach. Muted rather than saturated -- these are
## still the same door art, not a different prop, and a loud tint would
## fight the room's own palette rather than sit inside it.
func _door_tint(kind: String, idx: int) -> Color:
	match kind:
		"office":
			return Color(1.15, 1.0, 0.7)      # warm gold -- matches the
			                                    # principal's own colour
			                                    # everywhere else it appears
		"mentor":
			return Color(1.15, 0.85, 0.7)      # warm rust -- the mentor's own
			                                    # cardigan colour, and clearly
			                                    # not the office's gold
		"room":
			if idx >= 0 and idx < Game.rooms.size():
				var r: Dictionary = Game.rooms[idx]
				if (r.get("teacher", {}) as Dictionary).is_empty():
					# THE FIX: a flat 0.85 grey just darkens the same teal
					# the plain "home" door already is -- confirmed by a
					# zoomed screenshot to be nearly indistinguishable at
					# a glance, which defeats the entire point of tinting
					# by kind. A warm red-orange reads as "needs you"
					# clearly, and shares no hue with office (gold) or a
					# staffed room (blue).
					return Color(1.3, 0.55, 0.4)
				# A STAFFED room used to read identically whether its
				# teacher was thriving or had been failing for the whole
				# term -- found via /deep_critique running Simulate the
				# School.bat, which showed exactly that: a room stuck on a
				# failing grade for twenty straight days with nothing
				# anywhere hinting you should go deal with it short of
				# opening the school board and checking every room by
				# hand. A muted amber, distinct from unstaffed's stronger
				# red-orange (this room HAS a teacher, just a bad one), so
				# the hallway itself becomes the place you notice fire()
				# is worth using, not just the screen it lives on.
				var letter := String((r.get("last", {}) as Dictionary).get("letter", ""))
				if letter in ["D", "E"]:
					return Color(1.15, 0.75, 0.45)
			return Color(0.75, 0.9, 1.15)       # staffed and fine -- cool blue
		"open":
			return Color(0.55, 0.55, 0.6)       # dim -- not really a room yet
		_:
			return Color.WHITE                   # home: the door as drawn


## Where you stand coming back out of a room off the corridor: just in front
## of that room's own door, not back at the start of the corridor. Falls back
## to entry_position() for a door that is not there.
func spot_outside(kind: String, room_idx: int = -1) -> Vector2:
	for d in doors:
		if is_instance_valid(d) and String(d.door_kind) == kind 				and (kind != "room" or int(d.room_index) == room_idx):
			return (d as Node2D).position + Vector2(0, -30)
	return entry_position()


## Where a fresh arrival stands: just past the home door, facing in.
func entry_position() -> Vector2:
	return Vector2(MARGIN + 28.0, HEIGHT * 0.5 + 20.0)   # doubled, was 14.0/10.0


## The corridor's floor, end to end -- the camera's right limit.
func width() -> float:
	return _w


## Clamped to the corridor end to end, and from the top of the grade wing to
## the corridor floor's bottom edge -- which is exactly one screen tall, so
## the wing, the corridor wall and the doors are all in view wherever you
## walk. A taller window centres it (limits are GLOBAL: see mentor_room.gd).
func refresh_camera_limits(camera: Camera2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	camera.limit_left = int(global_position.x - MARGIN)
	camera.limit_right = int(global_position.x + width() + MARGIN)
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var top := global_position.y + WING_TOP
	var bottom := global_position.y + HEIGHT
	if view.y >= bottom - top:
		var mid := (top + bottom) * 0.5
		top = mid - view.y * 0.5
		bottom = mid + view.y * 0.5
	camera.limit_top = int(floor(top))
	camera.limit_bottom = int(ceil(bottom))
