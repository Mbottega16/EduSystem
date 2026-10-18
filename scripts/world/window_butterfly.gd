extends Node2D

## The classroom's butterfly, at the second window (Oct 2026, the owner's ask:
## "get the butterfly to open and go in and out of the window it's next to").
##
## It rests on the sill, opening and closing its wings. Every so often the
## window swings open, it takes off, flies out through it and is gone, and the
## window shuts behind it. A while later the window opens again and it comes
## back: you see it outside first, then it flutters in, goes once round the
## front of the room, and settles on the sill again.
##
## Visual only, like prop_anim.gd: a fixed timetable, no randomness (so nothing
## here can disturb the seeded Game.rng), and nothing reads it back. Drawn by
## hand rather than as a Sprite2D, because while it is outside it has to be cut
## to the open window -- it is behind the frame, not in front of the wall.
## Positions are local to the decor body it hangs from, which is where it rests.

const IDLE := preload("res://art/window_butterfly_anim.png")
const FLY := preload("res://art/butterfly_fly_anim.png")
## The first frame of each, as the importer cut them: a frame's size.
const IDLE_STILL := preload("res://art/window_butterfly.png")
const FLY_STILL := preload("res://art/butterfly_fly.png")
const OPEN := preload("res://art/window_open.png")
const FRAMES := 4
const IDLE_FPS := 6.0
const FLY_FPS := 10.0

## The timetable, in seconds, in the order it plays.
const REST := 7.0          # on the sill
const OUT_FLY := 1.4       # up off the sill to the open window
const OUT_FADE := 1.6      # through it and away, getting fainter
const AWAY := 9.0          # gone; the window shut
const IN_FADE := 1.4       # back into view outside, to the window
const IN_LOOP := 4.0       # in through it, once round the front of the room
const IN_LAND := 1.2       # down onto the sill
## The window stays open this long after it has gone through, either way.
const LINGER := 0.6
const CYCLE := REST + OUT_FLY + OUT_FADE + AWAY + IN_FADE + IN_LOOP + IN_LAND

## Where it sits: the middle of its 32x14 frame, standing on the body's origin.
const SILL := Vector2(0, -7)

## How far it goes from the window, round the front of the room and back.
const LOOP_REACH := Vector2(40, 34)

## The window's art and the part of it you can see out of, local to the body.
var window_rect := Rect2()
var opening := Rect2()
var _t := 0.0
var _anim := 0.0
var _open: Sprite2D = null
var _pos := SILL
var _alpha := 1.0
var _flying := false
var _outside := false


## `window` is the window's art in local pixels; `see_through` the opening,
## in the window's own pixels (RoomBuilder.WINDOW_OPENING).
func setup(window: Rect2, see_through: Rect2) -> void:
	window_rect = window
	opening = Rect2(window.position + see_through.position, see_through.size)
	_open = Sprite2D.new()
	_open.name = "WindowOpen"
	_open.texture = OPEN
	_open.centered = false
	_open.position = window.position
	_open.visible = false
	# Under the butterfly: on the same body, just before this node.
	get_parent().add_child(_open)
	get_parent().move_child(_open, get_index())
	_step(0.0)


func _process(delta: float) -> void:
	_t = fmod(_t + delta, CYCLE)
	_anim += delta
	_step(_t)
	# Flying round the room it is in front of everybody; resting or outside,
	# it belongs to the wall.
	z_index = 1 if (_flying and not _outside) else 0
	queue_redraw()


## Where it is and how it looks `c` seconds into a cycle.
func _step(c: float) -> void:
	var mid := opening.get_center()
	# Away up and to one side, back in from the other -- kept low in the
	# opening, under the status strip's dimming.
	var far_out := opening.position + Vector2(4, 14)
	var back_in := opening.end - Vector2(6, 6)
	_alpha = 1.0
	_flying = true
	_outside = false
	var t := c
	if t < REST:
		_flying = false
		_pos = SILL
		_set_open(false)
		return
	t -= REST
	if t < OUT_FLY:
		var u := t / OUT_FLY
		_pos = SILL.lerp(mid, _ease(u)) + Vector2(0, -sin(u * PI) * 10.0)
		_set_open(true)
		return
	t -= OUT_FLY
	if t < OUT_FADE:
		var u := t / OUT_FADE
		_pos = mid.lerp(far_out, u)
		_alpha = 1.0 - u
		_outside = true
		_set_open(true)
		return
	t -= OUT_FADE
	if t < AWAY:
		_alpha = 0.0
		_set_open(t < LINGER)
		return
	t -= AWAY
	if t < IN_FADE:
		var u := t / IN_FADE
		_pos = back_in.lerp(mid, u)
		_alpha = u
		_outside = true
		_set_open(true)
		return
	t -= IN_FADE
	if t < IN_LOOP:
		# Once round: out over the floor in front of the window and back, the
		# far side of the loop down where the children sit.
		var u := t / IN_LOOP
		var a := u * TAU
		_pos = mid + Vector2(sin(a) * LOOP_REACH.x, (1.0 - cos(a)) * LOOP_REACH.y) \
			+ Vector2(0, sin(a * 3.0) * 4.0)
		_set_open(t < LINGER)
		return
	t -= IN_LOOP
	var u2 := clampf(t / IN_LAND, 0.0, 1.0)
	_pos = mid.lerp(SILL, _ease(u2)) + Vector2(0, -sin(u2 * PI) * 6.0)
	_set_open(false)


func _set_open(on: bool) -> void:
	if _open != null:
		_open.visible = on


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Is the window open right now? (The suite asserts it shuts again.)
func is_open() -> bool:
	return _open != null and _open.visible


## Is it out of the room right now -- outside, or gone altogether?
func is_out() -> bool:
	return _outside or _alpha <= 0.0


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var tex: Texture2D = FLY if _flying else IDLE
	var still: Texture2D = FLY_STILL if _flying else IDLE_STILL
	var fps := FLY_FPS if _flying else IDLE_FPS
	var fw := float(still.get_width())
	var fh := float(still.get_height())
	var frame := int(_anim * fps) % FRAMES
	# On the room's 2px art grid, so it never sits between two of its pixels.
	var at := ((_pos - Vector2(fw, fh) / 2.0) / 2.0).round() * 2.0
	var dest := Rect2(at, Vector2(fw, fh))
	var src := Rect2(frame * fw, 0.0, fw, fh)
	if _outside:
		# Behind the frame: only what shows through the opening.
		var cut := dest.intersection(opening)
		if cut.size.x <= 0.0 or cut.size.y <= 0.0:
			return
		src = Rect2(src.position + (cut.position - dest.position), cut.size)
		dest = cut
	draw_texture_rect_region(tex, dest, src, Color(1, 1, 1, _alpha))
