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

@onready var bubble: Sprite2D = $Bubble

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


## `tint` distinguishes WHY the bubble is up: the ordinary amber one means
## stuck right now, a cooler one means the quiz caught them out. Same shape
## on purpose — it is the same instruction either way, go to that desk.
func set_bubble(on: bool, tint: Color = Color.WHITE) -> void:
	if bubble != null:
		bubble.modulate = tint
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


## Colours for the little bar over their head.
const BAR_W := 15.0
const BAR_BG := Color(0.10, 0.09, 0.12, 0.85)
const BAR_TRACK := Color(0.30, 0.29, 0.34)
const BAR_FILL := Color(0.42, 0.78, 0.45)
const BAR_STUCK := Color(0.86, 0.42, 0.36)


## How far through their work they are. Redrawn every frame they are
## working, which is also the frame the bar visibly stops moving if they get
## stuck — the bar freezing is the tell, as much as the "?" is.
func _draw() -> void:
	if data == null or data.work_state != StudentData.Work.WORKING:
		return
	var frac: float = data.work_fraction()
	var x := -BAR_W / 2.0
	var y := -30.0
	draw_rect(Rect2(x - 1.0, y - 1.0, BAR_W + 2.0, 5.0), BAR_BG)
	draw_rect(Rect2(x, y, BAR_W, 3.0), BAR_TRACK)
	draw_rect(Rect2(x, y, BAR_W * frac, 3.0),
		BAR_STUCK if data.is_struggling() else BAR_FILL)


func _physics_process(delta: float) -> void:
	idle_bob(delta)
	tick_pose(delta)
	if data != null:
		var working: bool = data.work_state == StudentData.Work.WORKING
		if working:
			queue_redraw()
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
