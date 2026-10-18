extends Node2D

## Small things that move in the idle classroom (Oct 2026, the owner's ask: more
## ambient movement -- "something coming out of the window, a drip from the
## ceiling, etc."). Five touches, each on its own fixed timetable:
##
##   * a drip that swells at the foot of the back wall, falls, splashes into a
##     small puddle and ripples;
##   * a leaf that drifts past the first window once it swings open;
##   * a small bird that crosses the same open window;
##   * a spider that lets itself down a thread, hangs, and climbs back up;
##   * the intercom's four lights, which chase each other now and then.
##
## Visual only, like window_butterfly.gd: fixed timetables and no randomness,
## so nothing here can touch the seeded Game.rng, and nothing reads it back.
## It takes no floor (no body, no grid cell) and keeps clear of the hung
## fixtures: everything starts below Layout.WALL_HANG_Y, or sits on a fixture's
## own lights. Drawn in LimeZu's palette with the keyline #3a3a50, on the room's
## 2px art grid. Off while a lesson runs, so a lesson costs it no frames.

const OPEN := preload("res://art/window_open.png")
const KEYLINE := Color("#3a3a50")

## --- drip ---
const DRIP_X := 480.0
const DRIP_TOP := 58.0
const DRIP_PUDDLE_Y := 92.0
const DRIP_CYCLE := 5.5
const DRIP_SWELL := 3.0
const DRIP_FALL := 0.4
const DRIP_SPLASH := 1.4
const WATER := Color("#8ec5e8")
const WATER_DARK := Color("#5f9fcb")

## --- window: closed, then open with a leaf and a bird going past ---
const WIN_CYCLE := 26.0
const WIN_OPEN_AT := 10.0
const WIN_SHUT_AT := 20.5
const LEAF_AT := 10.8
const LEAF_TIME := 5.2
const BIRD_AT := 16.4
const BIRD_TIME := 3.2

## --- spider ---
const SPIDER_X := 548.0
const SPIDER_TOP := 58.0
const SPIDER_DROP := 34.0
const SPIDER_CYCLE := 20.0
const THREAD := Color(0.88, 0.88, 0.94, 0.7)

## --- intercom lights (offsets from the intercom's anchor, and their bright colours) ---
const LIGHT_DX := [-10.0, -4.0, 2.0, 8.0]
const LIGHT_DY := -26.0
const LIGHT_ON := [Color("#ff6a6a"), Color("#ff6a6a"), Color("#6aa8ff"), Color("#86e89a")]
const LIGHT_CYCLE := 13.0
const LIGHT_STEP := 0.22

const BIRD_UP := ["..X.X..", ".XXXXX.", "..XXXXY", "...XX.."]
const BIRD_DOWN := ["...XX..", "XXXXXXY", ".XXXXX.", "..X.X.."]
const LEAF_A := [".XX.", "XYYX", ".XX."]
const LEAF_B := ["X...", "XYX.", ".XYX", "..XX"]
const SPIDER := ["X.X.X", ".XXX.", "X.X.X"]

var _t := 0.0
var _open: Sprite2D = null
var _sky: Node2D = null
## The first window, and the part of it you see out of, in room pixels.
var window_pos := Vector2.ZERO
var opening := Rect2()
var intercom := Vector2.ZERO
var _spider_y := -1.0


## Builds the node on `parent` (the classroom) and returns it.
static func build(parent: Node2D) -> Node2D:
	var me := Node2D.new()
	me.set_script(load("res://scripts/world/ambient_touches.gd"))
	me.name = "AmbientTouches"
	me.add_to_group("room_part")
	me.add_to_group("ambient_touches")
	parent.add_child(me)
	me.setup()
	return me


func setup() -> void:
	intercom = Layout.span_anchor([Layout.BELL] as Array[Vector2i])
	for tx in Grid.W:
		if RoomBuilder._window_col(tx, Grid.W) == 0:
			window_pos = Vector2(tx * Grid.TILE, 0) + RoomBuilder.WINDOW_INSET
			opening = Rect2(window_pos + RoomBuilder.WINDOW_OPENING.position,
				RoomBuilder.WINDOW_OPENING.size)
			break
	_open = Sprite2D.new()
	_open.name = "WindowOpen"
	_open.texture = OPEN
	_open.centered = false
	_open.position = window_pos
	_open.visible = false
	add_child(_open)
	# A child of its own, so what flies past is drawn over the open sashes.
	_sky = Node2D.new()
	_sky.name = "Outside"
	add_child(_sky)
	_sky.draw.connect(_draw_outside)
	draw.connect(_draw_room)


func _process(delta: float) -> void:
	var idle := Game.phase != Game.Phase.LESSON
	if visible != idle:
		visible = idle
	if not idle:
		return
	_t += delta
	step(_t)


## Moves everything to `t` seconds in. (The suite calls this to sample a cycle.)
func step(t: float) -> void:
	_t = t
	_open.visible = window_is_open(t)
	_spider_y = spider_y(t)
	queue_redraw()
	_sky.queue_redraw()


## --- timetables, all pure functions of time ---------------------------------

## The window is open from WIN_OPEN_AT to WIN_SHUT_AT of its cycle.
static func window_is_open(t: float) -> bool:
	var c := fposmod(t, WIN_CYCLE)
	return c >= WIN_OPEN_AT and c < WIN_SHUT_AT


## Where the drop is in its cycle: [stage, u], stage "swell", "fall" or "splash"
## (u runs 0..1 through it), or "" while it waits.
static func drip_state(t: float) -> Array:
	var c := fposmod(t, DRIP_CYCLE)
	if c < DRIP_SWELL:
		return ["swell", c / DRIP_SWELL]
	c -= DRIP_SWELL
	if c < DRIP_FALL:
		return ["fall", c / DRIP_FALL]
	c -= DRIP_FALL
	if c < DRIP_SPLASH:
		return ["splash", c / DRIP_SPLASH]
	return ["", 0.0]


## How far down its thread the spider hangs (0 = out of sight at the top).
static func spider_y(t: float) -> float:
	var c := fposmod(t, SPIDER_CYCLE)
	if c < 4.0:
		return 0.0
	if c < 7.0:
		return SPIDER_DROP * _ease((c - 4.0) / 3.0)
	if c < 12.0:
		return SPIDER_DROP + sin((c - 7.0) * 1.6) * 3.0
	if c < 15.0:
		return SPIDER_DROP * (1.0 - _ease((c - 12.0) / 3.0))
	return 0.0


## Which intercom light is lit now (0..3), or -1.
static func light_on(t: float) -> int:
	var c := fposmod(t, LIGHT_CYCLE)
	var i := int(c / LIGHT_STEP)
	return i if c < LIGHT_STEP * 4.0 else -1


## The leaf's centre, or (-1, -1) when it is not in view. Drifts across the
## opening from the right, swaying, sinking as it goes.
func leaf_pos(t: float) -> Vector2:
	var u := (fposmod(t, WIN_CYCLE) - LEAF_AT) / LEAF_TIME
	if u < 0.0 or u > 1.0:
		return Vector2(-1, -1)
	return Vector2(opening.end.x + 4.0 - (opening.size.x + 12.0) * u,
		opening.position.y + 8.0 + opening.size.y * 0.5 * u + sin(u * TAU * 2.0) * 5.0)


## The bird's centre, or (-1, -1): across the upper opening, left to right.
func bird_pos(t: float) -> Vector2:
	var u := (fposmod(t, WIN_CYCLE) - BIRD_AT) / BIRD_TIME
	if u < 0.0 or u > 1.0:
		return Vector2(-1, -1)
	return Vector2(opening.position.x - 8.0 + (opening.size.x + 16.0) * u,
		opening.position.y + 16.0 - sin(u * PI) * 3.0)


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## --- drawing ----------------------------------------------------------------

static func _snap(v: Vector2) -> Vector2:
	return (v / 2.0).round() * 2.0


## Draws a pattern of 2px cells ('X' keyline, 'Y' the pattern's own colour),
## each cell only if it lies wholly inside `clip` (an empty clip means no limit).
func _cells(ci: CanvasItem, at: Vector2, rows: Array, body: Color, clip: Rect2) -> void:
	var o := _snap(at)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var r := Rect2(o + Vector2(x, y) * 2.0, Vector2(2, 2))
			if clip.size != Vector2.ZERO and not clip.encloses(r):
				continue
			ci.draw_rect(r, KEYLINE if ch == "X" else body)


func _draw_room() -> void:
	# The puddle: always there, small, the drop lands in it.
	var pc := Vector2(DRIP_X, DRIP_PUDDLE_Y)
	draw_rect(Rect2(pc + Vector2(-6, -1), Vector2(12, 2)), Color(WATER_DARK, 0.55))
	draw_rect(Rect2(pc + Vector2(-4, -3), Vector2(8, 2)), Color(WATER, 0.5))
	var d := drip_state(_t)
	match d[0]:
		"swell":
			var u: float = d[1]
			var h := 2.0 + floorf(u * 3.0) * 2.0 / 1.0
			var w := 2.0 if u < 0.7 else 4.0
			draw_rect(Rect2(_snap(Vector2(DRIP_X - w / 2.0, DRIP_TOP)), Vector2(w, minf(h, 6.0))), WATER)
		"fall":
			var u: float = d[1]
			var y := lerpf(DRIP_TOP + 4.0, DRIP_PUDDLE_Y - 6.0, u * u)
			draw_rect(Rect2(_snap(Vector2(DRIP_X - 1.0, y)), Vector2(2, 6)), WATER)
		"splash":
			var u: float = d[1]
			var rx := 2.0 + u * 12.0
			var a := (1.0 - u) * 0.9
			for i in 20:
				var ang := float(i) / 20.0 * TAU
				var p := _snap(pc + Vector2(cos(ang) * rx, sin(ang) * rx * 0.35 - 2.0))
				draw_rect(Rect2(p, Vector2(2, 2)), Color(WATER, a))
			if u < 0.3:
				# Two flecks thrown up from the landing.
				var up := sin(u / 0.3 * PI) * 6.0
				draw_rect(Rect2(_snap(pc + Vector2(-5, -up - 4)), Vector2(2, 2)), WATER)
				draw_rect(Rect2(_snap(pc + Vector2(4, -up - 4)), Vector2(2, 2)), WATER)
	# The spider's thread is out whenever it has dropped any, and its body hangs
	# at the end of it.
	if _spider_y > 0.5:
		var top := Vector2(SPIDER_X, SPIDER_TOP)
		draw_rect(Rect2(top, Vector2(2, _spider_y)), THREAD)
		_cells(self, top + Vector2(-4, _spider_y), SPIDER, KEYLINE, Rect2())
	# The intercom's lights, one after another.
	var on := light_on(_t)
	if on >= 0:
		var at := Vector2(intercom.x + float(LIGHT_DX[on]), Layout.WALL_HANG_Y + LIGHT_DY)
		draw_rect(Rect2(at, Vector2(4, 4)), LIGHT_ON[on])


func _draw_outside() -> void:
	if not _open.visible:
		return
	var leaf := leaf_pos(_t)
	if leaf.x >= 0.0:
		var flip := int(_t * 3.0) % 2 == 0
		_cells(_sky, leaf - Vector2(4, 4), LEAF_A if flip else LEAF_B, Color("#d9873c"), opening)
	var bird := bird_pos(_t)
	if bird.x >= 0.0:
		var up := int(_t * 8.0) % 2 == 0
		_cells(_sky, bird - Vector2(7, 4), BIRD_UP if up else BIRD_DOWN, Color("#e8c89a"), opening)
