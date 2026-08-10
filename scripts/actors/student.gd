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


func bind(d: StudentData) -> void:
	data = d
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


func set_bubble(on: bool) -> void:
	if bubble != null:
		bubble.visible = on


func _physics_process(delta: float) -> void:
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
