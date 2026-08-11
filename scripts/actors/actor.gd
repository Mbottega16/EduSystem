class_name Actor
extends CharacterBody2D

## Shared movement and walk animation for anyone on two legs — the teacher
## and every student. Subclasses only decide WHERE to go: the player reads
## input, a student follows a path. Neither touches the animation.

## SPEED is a multiple of 60 on purpose. At the default 60Hz physics tick
## that makes it exactly 1px per physics frame, so movement assertions in
## the tests are integer arithmetic instead of float tolerance.
const SPEED := 60.0
## Held-sprint multiplier. The lesson clock makes crossing the room a real
## cost, so there has to be a way to spend effort to cross it faster.
const SPRINT := 1.7
const FRAME_TIME := 0.14

# Rows in the sprite sheets, in the order tools/make_art.py writes them.
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3

## Frames 0 and 2 are the standing pose, 1 and 3 the two steps. Cycling
## stand-step-stand-otherstep is what reads as walking rather than a flick
## between two poses.
const WALK_CYCLE := [0, 1, 2, 3]
const SIT_FRAME := 4

@onready var sprite: Sprite2D = $Sprite2D

var facing := DIR_DOWN
var seated := false

var _cycle_pos := 0
var _frame_timer := 0.0
## Phase offset so a room full of seated people does not breathe in unison.
var idle_phase := 0.0
var _step_side := false


## Move in `dir` (unnormalised is fine) and animate accordingly.
func walk(dir: Vector2, delta: float) -> void:
	if seated:
		velocity = Vector2.ZERO
		return

	# Normalised so walking diagonally isn't faster than walking straight.
	velocity = dir.normalized() * SPEED * speed_scale()
	move_and_slide()

	if dir == Vector2.ZERO:
		set_idle()
		return

	# Left/right wins over up/down when moving diagonally: a side-on sprite
	# reads better than a front-on one sliding sideways.
	if dir.x > 0.0:
		facing = DIR_RIGHT
	elif dir.x < 0.0:
		facing = DIR_LEFT
	elif dir.y > 0.0:
		facing = DIR_DOWN
	elif dir.y < 0.0:
		facing = DIR_UP

	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer -= FRAME_TIME
		_cycle_pos = (_cycle_pos + 1) % WALK_CYCLE.size()
		# a footfall on each of the two stepping frames
		if WALK_CYCLE[_cycle_pos] % 2 == 1:
			_step_side = not _step_side
			on_step()
	_set_frame(WALK_CYCLE[_cycle_pos])


## Stop on a standing frame rather than mid-step.
func set_idle() -> void:
	_cycle_pos = 0
	_frame_timer = 0.0
	_set_frame(0)


func sit(face := DIR_DOWN) -> void:
	seated = true
	facing = face
	velocity = Vector2.ZERO
	_set_frame(SIT_FRAME)


func stand() -> void:
	seated = false
	set_idle()


func face_towards(point: Vector2) -> void:
	var d := point - global_position
	if absf(d.x) > absf(d.y):
		facing = DIR_RIGHT if d.x > 0.0 else DIR_LEFT
	else:
		facing = DIR_DOWN if d.y > 0.0 else DIR_UP
	_set_frame(SIT_FRAME if seated else 0)


## 1.0 normally. The player overrides this to sprint; students never do.
func speed_scale() -> float:
	return 1.0


func facing_vector() -> Vector2:
	match facing:
		DIR_LEFT: return Vector2.LEFT
		DIR_RIGHT: return Vector2.RIGHT
		DIR_UP: return Vector2.UP
	return Vector2.DOWN


## Overridden by the player so only the teacher's own footsteps are heard —
## eight students walking in at once would be a stampede.
func on_step() -> void:
	pass


## A slow breath while seated. Eight identical frozen poses was the dominant
## image of the game and read as a room of mannequins; this is two lines and
## fixes most of that.
func idle_bob(delta: float) -> void:
	if not seated or sprite == null:
		return
	idle_phase += delta
	var lift := -12.0 + sin(idle_phase * 1.9) * 0.6
	sprite.position.y = lift


func _set_frame(f: int) -> void:
	if sprite != null:
		sprite.frame_coords = Vector2i(f, facing)
