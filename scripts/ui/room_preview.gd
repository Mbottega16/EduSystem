class_name RoomPreview
extends Control

## A half-size picture of a room-ideas template (RoomTemplates), drawn from the
## game's own art: the opening room's floor, walls and windows, its eight desks
## and fixtures, the starting wall decor that is still showing, and the
## template's pieces in place. Half size, because the art is drawn at twice its
## pixel size, so 0.5 lands back on the original pixels exactly.

const HALF := 0.5
const PROP_CHAIR := preload("res://art/chair.png")
const PROP_DESK := preload("res://art/desk.png")
const PROP_PODIUM := preload("res://art/podium.png")
const PROP_TEACHER_DESK := preload("res://art/teacher_desk.png")
const PROP_CABINET := preload("res://art/cabinet_body.png")

var template: Dictionary = {}
var _room: Texture2D = null
var _cache: Dictionary = {}


func _init() -> void:
	size = Vector2(Grid.BASE_W, Grid.BASE_H) * float(Grid.TILE) * HALF
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_template(t: Dictionary) -> void:
	template = t
	# A texture drawn in the same frame it was first loaded can come out as a
	# blank white box until it is redrawn, so everything the picture needs is
	# loaded first and the picture is drawn again a frame later.
	for e: Dictionary in RoomTemplates.entries(t):
		_tex(String(e["id"]))
	for seed_row: Array in RoomBuilder.DECOR_SEED:
		_tex(String(seed_row[0]))
	queue_redraw()
	_redraw_next_frame.call_deferred()


func _redraw_next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
		queue_redraw()


## An item's sprite, loaded once.
func _tex(id: String) -> Texture2D:
	if not _cache.has(id):
		_cache[id] = load("res://art/%s.png" % String(Items.get_def(id).get("art", id)))
	return _cache[id]


## The sprite whose bottom-centre sits on `anchor` (the game's convention).
func _put(tex: Texture2D, anchor: Vector2, lift: float = 0.0) -> void:
	draw_texture(tex, anchor - Vector2(tex.get_width() / 2.0, tex.get_height() - lift))


func _draw() -> void:
	if template.is_empty():
		return
	if _room == null:
		_room = RoomBuilder.compose_room(Grid.BASE_W, Grid.BASE_H)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(HALF, HALF))
	draw_texture(_room, Vector2.ZERO)
	# the HUD's status strip dims the top of the wall in the real room; so does this
	draw_rect(Rect2(0, 0, Grid.BASE_W * Grid.TILE, 30), Color(0.06, 0.05, 0.08, 0.7))

	var entries := RoomTemplates.entries(template)
	var hung_cols: Array[int] = []
	var hung: Array = []        # [tex, anchor]
	var standing: Array = []    # [sort_y, tex, anchor]
	for e: Dictionary in entries:
		var id := String(e["id"])
		var tex: Texture2D = _tex(id)
		var tiles := Items.footprint(id, e["tile"])
		if Items.is_wall(id):
			for t: Vector2i in tiles:
				hung_cols.append(t.x)
			hung.append([tex, Layout.wall_anchor(tiles)])
		else:
			var a := Layout.span_anchor(tiles)
			standing.append([a.y, tex, a])

	# on the wall: the fixtures that hang there for good (the shop's corkboard, the
	# curriculum poster, the treat shelf, the intercom), the starting decor that
	# has not given way, then the template's own
	for f: Array in RoomBuilder.hung_fixtures():
		_put(f[0] as Texture2D, RoomBuilder.hung_fixture_anchor(f[1] as Array, float(f[2])))
	for seed_row: Array in RoomBuilder.visible_seeds(hung_cols):
		var sid := String(seed_row[0])
		var stex: Texture2D = _tex(sid)
		_put(stex, Layout.wall_anchor(Items.footprint(sid, seed_row[1] as Vector2i)))
	for h: Array in hung:
		_put(h[0] as Texture2D, h[1] as Vector2)

	# on the floor, back to front: desks and fixtures with the template's pieces
	for seat: Vector2i in Layout.DEFAULT_SEATS:
		standing.append([Grid.tile_to_world(seat).y - 1.0, PROP_CHAIR, Grid.tile_to_world(seat)])
		standing.append([Grid.tile_to_world(seat + Layout.DESK_OFFSET).y, PROP_DESK,
			Grid.tile_to_world(seat + Layout.DESK_OFFSET)])
	standing.append([Grid.tile_to_world(Layout.PODIUM).y, PROP_PODIUM, Grid.tile_to_world(Layout.PODIUM)])
	standing.append([Grid.tile_to_world(Layout.CABINET).y, PROP_CABINET, Grid.tile_to_world(Layout.CABINET)])
	var td := Layout.span_anchor(Layout.TEACHER_DESK)
	standing.append([td.y, PROP_TEACHER_DESK, td])
	standing.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(a[0] as float, b[0] as float):
			return (a[0] as float) < (b[0] as float)
		return (a[2] as Vector2).x < (b[2] as Vector2).x)
	for s: Array in standing:
		_put(s[1] as Texture2D, s[2] as Vector2)
