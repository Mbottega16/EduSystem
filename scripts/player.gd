extends CharacterBody2D

## The character you walk around the room.

const SPEED := 60.0          ## px/sec — about four tiles a second
const FRAME_TIME := 0.14     ## seconds per walk frame

# Rows in art/player.png, in the order make_art.py writes them.
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3

# Frames 0 and 2 are the standing pose; 1 and 3 are the two steps. Cycling
# stand-step-stand-otherstep is what makes it read as walking rather than
# just flicking between two poses.
const WALK_CYCLE := [0, 1, 2, 3]

@onready var sprite: Sprite2D = $Sprite2D

var facing := DIR_DOWN
var cycle_pos := 0
var frame_timer := 0.0


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0

	# Normalise so walking diagonally isn't faster than walking straight.
	velocity = dir.normalized() * SPEED
	move_and_slide()

	if dir == Vector2.ZERO:
		# Stop on a standing frame rather than mid-step.
		cycle_pos = 0
		frame_timer = 0.0
		_set_frame(0)
		return

	# Left/right win over up/down when moving diagonally: a side-on sprite
	# reads better than a front-on one sliding sideways.
	if dir.x > 0.0:
		facing = DIR_RIGHT
	elif dir.x < 0.0:
		facing = DIR_LEFT
	elif dir.y > 0.0:
		facing = DIR_DOWN
	elif dir.y < 0.0:
		facing = DIR_UP

	frame_timer += delta
	if frame_timer >= FRAME_TIME:
		frame_timer -= FRAME_TIME
		cycle_pos = (cycle_pos + 1) % WALK_CYCLE.size()
	_set_frame(WALK_CYCLE[cycle_pos])


func _set_frame(f: int) -> void:
	sprite.frame_coords = Vector2i(f, facing)
