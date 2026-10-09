extends Node2D

## The principal's office, off the hallway (Oct 2026).
##
## It was only ever a menu: the hallway's second door opened THE PRINCIPAL'S
## OFFICE screen on the spot. Now the door leads into a room -- her desk
## between two windows, the school's charts on the wall behind her, a sofa
## for visitors, her shelves and files -- and she is in it, sat at her desk.
## Walk up and press E for the same screen as before (hud.show_office()).
##
## Like the mentor's room it is a place you visit, not one you run: nothing
## here is graded, saved or ticked, and she is a sprite in a chair, not a
## StudentData. PLACEMENT, the lesson the hallway learned: a hidden
## StaticBody2D still collides, so main.tscn parks this node far below the
## others -- hallway at y=10000, the mentor at 20000, this at 30000.

## The player used the door back to the hallway.
signal exit_chosen()
## The player pressed E at her desk -- main.gd opens the office screen.
signal talk_chosen()

const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")
const DOOR_SCRIPT := preload("res://scripts/interact/hall_door.gd")
const TALK_SCRIPT := preload("res://scripts/interact/principal_talk.gd")
const PRINCIPAL_TEX := preload("res://art/principal.png")
const DESK_TEX := preload("res://art/principal_desk.png")
const CHAIR_TEX := preload("res://art/exec_chair.png")

const ROOM_W := 320.0
const ROOM_H := 224.0
## Where the back wall meets the floor -- the same construction as the
## mentor's room: the wall stands inside the top of the room so the centred
## camera never cuts it off.
const WALL_FOOT := 48.0
## Back-wall columns (of ROOM_W / TILE) that are windows, as pairs.
const WINDOWS := [2, 6]
## Her desk, bottom-centre: in the middle, a little way out from the wall.
const DESK_AT := Vector2(ROOM_W * 0.5, 130.0)
## Where she sits, behind it, and where you stand to talk to her, in front.
const SEAT_AT := Vector2(ROOM_W * 0.5, 96.0)
const TALK_AT := Vector2(ROOM_W * 0.5, 146.0)

## [art, anchor, kind] -- the same kinds the mentor's room uses:
##   "wall"  hung flat, no floor contact, no collider, drawn behind actors
##   "rug"   flat on the floor, drawn under everything but the floor itself
##   "floor" stands on the floor: a small collider, y-sorted
##   "prop"  free-standing decoration, y-sorted, but NO collider
## Authored, not rolled: an office is arranged by the person who works in it.
const DRESSING := [
	# the wall behind her: certificates one side, a print the other, the
	# school's charts between the windows, right behind her chair
	["certificate",   Vector2(28, 8),    "wall"],
	["duty_roster",   Vector2(64, 10),   "wall"],
	["office_chart",  Vector2(160, 2),   "wall"],
	["wall_clock",    Vector2(258, 6),   "wall"],
	["office_art",    Vector2(296, 6),   "wall"],
	# a visitors' corner by the door: a sofa and a plant; a rug before her desk
	["rug",           Vector2(160, 168), "rug"],
	["sofa",          Vector2(92, 214),  "floor"],
	# two chairs for whoever is called in, facing her across the desk
	["visitor_chair", Vector2(120, 182), "floor"],
	["visitor_chair", Vector2(200, 182), "floor"],
	["office_plant",  Vector2(22, 222),  "prop"],
	["water_cooler",  Vector2(22, 96),   "floor"],
	# her own side: shelves and files against the right wall
	["bookshelf",     Vector2(300, 112), "floor"],
	["filing_cart",   Vector2(300, 168), "floor"],
	["plant",         Vector2(300, 222), "prop"],
]

var principal: Node = null
var talk: Interactable = null
var _built := false


func _ready() -> void:
	add_to_group("principal_office")
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	var room_art := Sprite2D.new()
	room_art.name = "RoomArt"
	room_art.texture = _compose()
	room_art.centered = false
	room_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_art.position = Vector2(-Grid.TILE, -16.0)
	room_art.z_index = -20
	add_child(room_art)

	# Walls as segments, a gap in the left one for the way back -- the same
	# construction as the mentor's room.
	for seg: Rect2 in [
		Rect2(0.0, WALL_FOOT - 16.0, ROOM_W, 16.0),
		Rect2(0.0, ROOM_H, ROOM_W, 16.0),
		Rect2(-16.0, -16.0, 16.0, 120.0),
		Rect2(-16.0, 168.0, 16.0, ROOM_H - 168.0 + 16.0),
		Rect2(ROOM_W, -16.0, 16.0, ROOM_H + 32.0),
	]:
		add_child(_box(seg))

	for i in DRESSING.size():
		var row: Array = DRESSING[i]
		_add_prop(i, String(row[0]), row[1] as Vector2, String(row[2]))

	# Her chair, then her, then her desk in front of both: the desk hides her
	# lap the way a pupil's desk does.
	var chair := Sprite2D.new()
	chair.name = "Chair"
	chair.texture = CHAIR_TEX
	chair.centered = false
	chair.position = SEAT_AT + Vector2(-CHAIR_TEX.get_width() * 0.5, -CHAIR_TEX.get_height() + 2.0)
	chair.z_index = int(DESK_AT.y) - 2
	add_child(chair)

	principal = STUDENT_SCENE.instantiate()
	add_child(principal)
	if principal.has_node("Sprite2D"):
		(principal.get_node("Sprite2D") as Sprite2D).texture = PRINCIPAL_TEX
	principal.name = "Principal"
	principal.position = SEAT_AT
	principal.idle_phase = 0.4
	principal.sit(Actor.DIR_DOWN)
	principal._set_collision(false)
	principal.z_index = int(DESK_AT.y) - 1

	var desk := Sprite2D.new()
	desk.name = "Desk"
	desk.texture = DESK_TEX
	desk.centered = false
	desk.position = DESK_AT - Vector2(DESK_TEX.get_width() * 0.5, DESK_TEX.get_height())
	desk.z_index = int(DESK_AT.y)
	add_child(desk)
	add_child(_box(Rect2(DESK_AT.x - 30.0, DESK_AT.y - 22.0, 60.0, 22.0)))

	talk = TALK_SCRIPT.new()
	talk.position = TALK_AT
	talk.set_pick_radius(30.0)
	talk.used.connect(func(_by: Node) -> void: talk_chosen.emit())
	add_child(talk)

	var door := DOOR_SCRIPT.new()
	door.door_kind = "home"
	door.leads_out = true
	door.position = Vector2(-4.0, 136.0)
	door.set_pick_radius(28.0)
	door.chosen.connect(func(_k: String, _i: int) -> void: exit_chosen.emit())
	add_child(door)


func _box(r: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	sh.shape = rect
	sh.position = r.position + r.size * 0.5
	b.add_child(sh)
	return b


## The room as one image from the classroom's tiles, origin (-TILE, -16):
## a side wall each side, the back wall's two rows with WINDOWS in them, the
## floor, a skirting row, and the door in the left wall.
func _compose() -> ImageTexture:
	var t := Grid.TILE
	var cols := int(ROOM_W / t)
	var w := int(ROOM_W) + 2 * t
	var h := int(ROOM_H) + 16 + t
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var src := Rect2i(0, 0, t, t)
	var floors: Array[Image] = []
	for i in RoomBuilder.FLOOR_VARIANTS:
		floors.append(RoomBuilder._tile_img("tile_floor_a%d" % i))
		floors.append(RoomBuilder._tile_img("tile_floor_b%d" % i))
	var wall := [RoomBuilder._tile_img("tile_wall_top0"), RoomBuilder._tile_img("tile_wall_top1")]
	var win := [[RoomBuilder._tile_img("tile_window_l0"), RoomBuilder._tile_img("tile_window_r0")],
		[RoomBuilder._tile_img("tile_window_l1"), RoomBuilder._tile_img("tile_window_r1")]]
	var side := RoomBuilder._tile_img("tile_wall_side")
	var bottom := RoomBuilder._tile_img("tile_wall_bottom")
	var foot := int(WALL_FOOT) + 16
	var y := foot
	var row := 0
	while y < 16 + int(ROOM_H):
		for c in cols:
			var v := absi(c * 7919 + row * 104729) % RoomBuilder.FLOOR_VARIANTS
			im.blit_rect(floors[v * 2 + (c + row) % 2], src, Vector2i(t + c * t, y))
		y += t
		row += 1
	for c in cols:
		for r in 2:
			var img: Image = wall[r]
			for first: int in WINDOWS:
				if c == first or c == first + 1:
					img = win[r][c - first]
			im.blit_rect(img, src, Vector2i(t + c * t, foot - (2 - r) * t))
		im.blit_rect(bottom, src, Vector2i(t + c * t, 16 + int(ROOM_H)))
	var yy := 0
	while yy < h:
		im.blit_rect(side, src, Vector2i(0, yy))
		im.blit_rect(side, src, Vector2i(w - t, yy))
		yy += t
	im.blit_rect(RoomBuilder._tile_img("tile_door_top"), src, Vector2i(0, 16 + 104))
	im.blit_rect(RoomBuilder._tile_img("tile_door_bottom"), src, Vector2i(0, 16 + 136))
	return ImageTexture.create_from_image(im)


## One piece of dressing; `anchor` is the point it sits ON (bottom-centre on
## the floor, top-centre on the wall), as in the mentor's room.
func _add_prop(idx: int, tex_name: String, anchor: Vector2, kind: String) -> void:
	var tex: Texture2D = load("res://art/%s.png" % tex_name)
	if tex == null:
		push_error("principal's office: missing dressing texture %s" % tex_name)
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.name = "prop_%d_%s" % [idx, tex_name]
	spr.add_to_group("office_dressing")
	match kind:
		"wall":
			spr.position = anchor - Vector2(w * 0.5, 0.0)
			spr.z_index = -10
		"rug":
			spr.position = anchor - Vector2(w * 0.5, h * 0.5)
			spr.z_index = -15
		_:
			spr.position = anchor - Vector2(w * 0.5, h)
			spr.z_index = int(anchor.y)
	add_child(spr)
	if kind == "floor":
		add_child(_box(Rect2(anchor.x - minf(w - 6.0, 28.0) * 0.5, anchor.y - 10.0,
			minf(w - 6.0, 28.0), 10.0)))


## The player y-sorts by hand in here, as in the mentor's room.
func _physics_process(_delta: float) -> void:
	for c in get_children():
		if c is Actor and c.is_in_group("carrier"):
			(c as Node2D).z_index = int((c as Node2D).position.y)


## Just inside the door, facing in.
func entry_position() -> Vector2:
	return Vector2(40.0, 140.0)


## Pin the camera on the room: smaller than a screen, so centred. Limits are
## GLOBAL -- see mentor_room.gd for the bug that taught this.
func refresh_camera_limits(camera: Camera2D) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var view: Vector2 = camera.get_viewport_rect().size / camera.zoom
	var centre: Vector2 = global_position + Vector2(ROOM_W, ROOM_H) * 0.5
	camera.limit_left = int(centre.x - view.x * 0.5)
	camera.limit_right = int(centre.x + view.x * 0.5)
	camera.limit_top = int(centre.y - view.y * 0.5)
	camera.limit_bottom = int(centre.y + view.y * 0.5)
