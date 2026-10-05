extends Actor

## A student. Walks in through the door, finds their seat, sits down, and
## then does whatever work you assign them.
##
## Students do NOT collide with each other (layer `actors`, mask `world`
## only). Mutual avoidance between eight bodies in a 16px aisle is a rabbit
## hole that buys nothing here — they never need to swap places, and a
## deadlocked pair would strand the whole lesson.

## How close counts as having reached a waypoint. Below the 1px-per-frame
## step size you can orbit a waypoint forever without ever "arriving".
const ARRIVE_EPSILON := 1.5

signal arrived()

## Everything over their head hangs off ONE node, drawn above the room
## (z_index on the Notice node in student.tscn) rather than behind the
## furniture. The bar used to be drawn on the student body itself, which
## put it UNDER their own sprite — a bar nobody could see was no use as
## the tell that somebody has stopped. Moving the whole column together
## also means the bar and the mark can never come apart when the layout
## pass shifts them (see Classroom._layout_notices()).
@onready var notice: Node2D = $Notice
@onready var bubble: Sprite2D = $Notice/Bubble

var data: StudentData = null

var _path: Array[Vector2i] = []
var _path_i: int = 0
var _delay: float = 0.0
var _seat_world := Vector2.ZERO
var _was_working := false      # edge-detects WORKING -> DONE, for the jump


func bind(d: StudentData) -> void:
	data = d
	idle_phase = float(d.id) * 0.9      # so they don't breathe in unison
	var tex: Texture2D = load("res://art/%s.png" % d.art)
	if tex != null:
		sprite.texture = tex


## Drop straight into a seat with no walk — used when a day starts with the
## class already in place, and by tests that don't care about the entrance.
func seat_at(world_pos: Vector2) -> void:
	global_position = world_pos
	_seat_world = world_pos
	_path.clear()
	sit(DIR_DOWN)
	_set_collision(false)


## Walk a tile path and sit down at the end of it. `delay` staggers the class
## so they file in rather than surging through the door as one block.
func walk_to_seat(path: Array[Vector2i], delay: float = 0.0) -> void:
	stand()
	_set_collision(true)
	_path = path
	_path_i = 0
	_delay = delay
	if not path.is_empty():
		_seat_world = Grid.tile_to_world(path[path.size() - 1])


func is_walking() -> bool:
	return not _path.is_empty()


## The marks a bubble can carry. The shape says WHAT, the tint says how
## urgent — before Oct 2026 the tint was carrying both, so four different
## problems were the same "?" in four colours. That is unreadable at a
## glance across thirty tiles and invisible to a colour-blind player.
##
## Every one of these is LimeZu's own blank bubble with a hand-set mark
## (tools/limezu_ui.py), because the sprite is multiplied by `tint` at
## runtime and his coloured emote sheet would come out as mud.
const MARK_STUCK := "stuck"
const MARK_FLARE := "flare"
const MARK_NOISE := "noise"
const MARK_BEHIND := "behind"
const MARK_NERVES := "nerves"
const MARK_HELPED := "helped"
const MARK_DRIFT := "drift"

const MARK_ART := {
	MARK_STUCK: preload("res://art/bubble_q.png"),
	MARK_FLARE: preload("res://art/bubble_excl.png"),
	MARK_NOISE: preload("res://art/bubble_note.png"),
	MARK_BEHIND: preload("res://art/bubble_dots.png"),
	MARK_NERVES: preload("res://art/bubble_drop.png"),
	MARK_HELPED: preload("res://art/bubble_heart.png"),
	MARK_DRIFT: preload("res://art/bubble_zzz.png"),
}


## `mark` is what the bubble shows and `tint` is how loud it is: "?" stuck,
## "!" flaring, a note for messing about, "..." behind but still working, a
## drop for exam nerves. Same position and same size on purpose — it is the
## same instruction either way, go to that desk.
##
## The texture is set even when the bubble is already up, so a child whose
## problem CHANGES while you watch changes mark without popping again.
func set_bubble(on: bool, tint: Color = Color.WHITE, mark: String = MARK_STUCK) -> void:
	if bubble != null:
		bubble.modulate = tint
		var art: Texture2D = MARK_ART.get(mark, MARK_ART[MARK_STUCK])
		if bubble.texture != art:
			bubble.texture = art
	if bubble == null or bubble.visible == on:
		return
	bubble.visible = on
	if on:
		# a small pop, and a sound, because a boolean toggle thirty tiles
		# away in a static frame is genuinely easy to miss
		Sfx.play_varied("stuck")
		bubble.scale = Vector2(0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(bubble, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		play_pose(POSE_SAD)


## The notice column over their head: the work bar, and the "?" bubble
## above it. Widened from 15 in Sept 2026 on the owner's call — at this zoom
## the old bar read as a smudge rather than as progress, and a bar you
## cannot see moving cannot be the tell that somebody is stuck.
##
## 26 and not wider: with BAR_PAD either side the whole box is 30, and desks
## stand one 32px tile apart at their closest. A bar that fills its own tile
## leaves a visible gap to the next one, so a row of stuck children reads as
## four bars and not as one long line — which is what 30 looked like when it
## was screenshotted. Anything wider has to start climbing over its
## neighbours to be legible, and a bar that has moved is harder to read than
## a slightly shorter one that has not.
const BAR_W := 26.0
const BAR_H := 4.0
const BAR_Y := -30.0
const BAR_PAD := 2.0
const BAR_BG := Color(0.10, 0.09, 0.12, 0.85)
const BAR_TRACK := Color(0.30, 0.29, 0.34)
const BAR_FILL := Color(0.42, 0.78, 0.45)
const BAR_STUCK := Color(0.86, 0.42, 0.36)
## The line back down to whoever a shifted notice belongs to. Only drawn
## once the column has actually been pushed off its own head — see
## Classroom._layout_notices(), which does the pushing.
const LEADER := Color(0.85, 0.83, 0.78, 0.5)
const LEADER_MIN := 3.0

## How far this student's notice column has been moved so that it does not
## sit on top of somebody else's. Written every frame by the classroom's
## layout pass; nothing else should set it. `_shift` is what is actually
## drawn, eased toward it, so a column slides aside instead of teleporting
## the frame a neighbour's bubble appears.
var notice_offset := Vector2.ZERO
var _shift := Vector2.ZERO
const SHIFT_SPEED := 120.0
## Where the "?" sits inside the column. Fixed: the whole column moves, the
## halves of it never move relative to each other.
@onready var _bubble_home: Vector2 = bubble.position if bubble != null else Vector2.ZERO


func _ready() -> void:
	# The bar is drawn by this script but on the Notice node, so it lands
	# above the room's furniture instead of behind it.
	if notice != null:
		notice.draw.connect(_draw_notice)


## Whether this student has anything over their head at all. The layout pass
## only places columns that exist; a calm child working away quietly is not
## an obstacle to anybody.
func has_notice() -> bool:
	if data == null:
		return false
	return (bubble != null and bubble.visible) \
		or data.work_state == StudentData.Work.WORKING


## The box this student's notices fill when nothing is in the way, in LOCAL
## pixels around their own feet. The bubble is only counted while it is up,
## so a working child takes the bar's slim box and a stuck one takes the
## whole column — which is the difference between a room that packs
## tightly and one that pushes everything sky-high over a single "?".
func notice_box() -> Rect2:
	var w := BAR_W + BAR_PAD * 2.0
	var top := BAR_Y - BAR_PAD
	var bottom := BAR_Y + BAR_H + BAR_PAD
	if bubble != null and bubble.visible and bubble.texture != null:
		var size: Vector2 = bubble.texture.get_size()
		w = maxf(w, size.x)
		top = minf(top, _bubble_home.y - size.y / 2.0)
	return Rect2(-w / 2.0, top, w, bottom - top)


## Where this student's notices actually ended up, in world pixels: their
## own box, moved by whatever the layout pass gave them. The one place to
## ask "is anything sitting on top of anything else" — the suite asserts
## against these, and so does anything that wants to reason about the room
## rather than about one child.
func notice_world_box() -> Rect2:
	var box := notice_box()
	box.position += global_position + notice_offset
	return box


## How far through their work they are. Drawn on the Notice node rather
## than on the student, so it sits above the room instead of under their own
## sprite, and redrawn every frame they are working — which is also the
## frame the bar visibly stops moving if they get stuck. The bar freezing is
## the tell, as much as the "?" is.
func _draw_notice() -> void:
	if data == null or notice == null:
		return
	var working: bool = data.work_state == StudentData.Work.WORKING
	if not working:
		return
	var frac: float = data.work_fraction()
	var x := -BAR_W / 2.0
	var y := BAR_Y
	notice.draw_rect(Rect2(x - BAR_PAD, y - BAR_PAD,
		BAR_W + BAR_PAD * 2.0, BAR_H + BAR_PAD * 2.0), BAR_BG)
	notice.draw_rect(Rect2(x, y, BAR_W, BAR_H), BAR_TRACK)
	notice.draw_rect(Rect2(x, y, BAR_W * frac, BAR_H),
		BAR_STUCK if data.is_struggling() else BAR_FILL)


## Shifted off their own head: say whose it is, or a crowded room turns into
## a row of notices belonging to nobody in particular. Drawn on the student
## body, not the column, because it is the one part that has to stay put.
func _draw() -> void:
	if _shift.length() <= LEADER_MIN or not has_notice():
		return
	draw_line(Vector2(0.0, BAR_Y + BAR_H + BAR_PAD + 4.0),
		Vector2(_shift.x, BAR_Y + BAR_H + BAR_PAD + _shift.y), LEADER, 1.0)


## Slide the column toward wherever the layout pass put it. One node moves,
## so the bar and the mark travel together and cannot come apart mid-slide.
func _ease_notice(delta: float) -> void:
	if _shift.is_equal_approx(notice_offset):
		return
	_shift = _shift.move_toward(notice_offset, SHIFT_SPEED * delta)
	if notice != null:
		notice.position = _shift
	queue_redraw()                  # the leader line, which stays put
	if notice != null:
		notice.queue_redraw()


func _physics_process(delta: float) -> void:
	idle_bob(delta)
	tick_pose(delta)
	_ease_notice(delta)
	if data != null:
		var working: bool = data.work_state == StudentData.Work.WORKING
		if working and notice != null:
			notice.queue_redraw()
		elif _was_working and data.work_state == StudentData.Work.DONE:
			play_pose(POSE_JUMP)      # finished the work -- a little cheer
			# Fx.flash() had zero callsites in the whole game before this --
			# the moment a sheet actually finishes is exactly the "something
			# landed" beat it exists for.
			Fx.flash(sprite)
		_was_working = working
	if _path.is_empty():
		return
	if _delay > 0.0:
		_delay -= delta
		return

	var goal := Grid.tile_to_world(_path[_path_i])
	if global_position.distance_to(goal) <= ARRIVE_EPSILON:
		global_position = goal
		_path_i += 1
		if _path_i >= _path.size():
			_arrive()
			return
		goal = Grid.tile_to_world(_path[_path_i])
	walk(goal - global_position, delta)


func _arrive() -> void:
	_path.clear()
	global_position = _seat_world
	sit(DIR_DOWN)
	# The desk and chair already block these tiles. Leaving a body here would
	# let the teacher wedge into a 16px aisle with no way back out.
	_set_collision(false)
	arrived.emit()


func _set_collision(on: bool) -> void:
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", not on)
