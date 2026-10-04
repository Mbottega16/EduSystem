class_name Actor
extends CharacterBody2D

## Shared movement and walk animation for anyone on two legs — the teacher
## and every student. Subclasses only decide WHERE to go: the player reads
## input, a student follows a path. Neither touches the animation.

## SPEED is a multiple of 60 on purpose. At the default 60Hz physics tick
## that makes it exactly 2px per physics frame, so movement assertions in
## the tests are integer arithmetic instead of float tolerance.
##
## Doubled to 120 in Aug 2026 alongside Grid.TILE doubling to 32 -- the
## room is drawn at twice the pixel density but is still the SAME layout,
## and the old 60 would have made every crossing take twice as long in
## practice: half the lesson spent walking is a real balance change, not
## a cosmetic one, and nothing about this pass was meant to touch pacing.
const SPEED := 120.0
## Crossing the room faster is the player's tap-dash (player.gd, and
## teacher.dash_* in balance.json), not a held sprint multiplier here.
const FRAME_TIME := 0.14

# Rows in the sprite sheets, in the order tools/make_art.py writes them.
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3

## Frames 0 and 2 are the standing pose, 1 and 3 the two steps. Cycling
## stand-step-stand-otherstep is what reads as walking rather than a flick
## between two poses. This is the OLD four-frame cycle, still what a 9-wide
## sheet (anything drawn by tools/make_art.py) plays.
const WALK_CYCLE := [0, 1, 2, 3]
const SIT_FRAME := 4

## A 15-wide sheet (every LimeZu character, tools/limezu_chars.py) carries the
## pack's own six-frame walk in columns 9-14. Played in order that is a real
## stride -- the two big steps are cycle positions 1 and 4, and the four frames
## between them are the passing poses that give the body its bob. The old cycle
## repeated one standing frame and flicked between two steps, which read as two
## poses, not a walk.
const WALK_CYCLE_FULL := [9, 10, 11, 12, 13, 14]
const FULL_SHEET_COLS := 15
const FULL_STRIDES := [1, 4]            ## cycle positions where a foot lands
## Six frames in 0.6s is a stride about every 1.2 tiles at SPEED -- the same
## ground the old 0.56s four-frame cycle covered, so pacing is unchanged.
const FRAME_TIME_FULL := 0.1
const CELL_W := 32

## One-shot poses, columns 5-8 of every character sheet (tools/make_art.py).
## Not part of the walk cycle -- played for a fixed beat by play_pose() and
## then handed back to whatever idle/seated frame was showing before.
const POSE_HANDOFF := 5   # passing a paper across, either direction
const POSE_CHAT := 6      # mid-conversation
const POSE_JUMP := 7      # jumping for joy
const POSE_SAD := 8       # head down
const POSE_HOLD_TIME := 0.6

@onready var sprite: Sprite2D = $Sprite2D

var facing := DIR_DOWN
var seated := false

var _cycle_pos := 0
var _frame_timer := 0.0
## Phase offset so a room full of seated people does not breathe in unison.
var idle_phase := 0.0
var _step_side := false
var _pose_timer := 0.0     # >0 while a one-shot pose (POSE_*) is being held


## Play a one-shot pose (POSE_HANDOFF/CHAT/JUMP/SAD) for POSE_HOLD_TIME,
## then fall back to whatever idle/seated frame was showing. Callers still
## have to call tick_pose(delta) each frame (walk() and idle_bob() do not,
## since a seated or moving actor is exactly when this matters least).
func play_pose(pose: int) -> void:
	_pose_timer = POSE_HOLD_TIME
	_set_frame(pose, true)


## Advance a held pose; call once a frame from whatever drives this actor.
## No-op unless play_pose() is mid-hold.
func tick_pose(delta: float) -> void:
	if _pose_timer <= 0.0:
		return
	_pose_timer -= delta
	if _pose_timer <= 0.0:
		_set_frame(SIT_FRAME if seated else 0)


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

	_fit_sheet()
	var full := has_full_walk()
	var cycle: Array = WALK_CYCLE_FULL if full else WALK_CYCLE
	var step_time := FRAME_TIME_FULL if full else FRAME_TIME
	_frame_timer += delta
	if _frame_timer >= step_time:
		_frame_timer -= step_time
		_cycle_pos = (_cycle_pos + 1) % cycle.size()
		# a footfall each time a foot lands: the two big strides of the six-frame
		# walk, or the two stepping frames of the old four-frame one
		var lands: bool = (_cycle_pos in FULL_STRIDES) if full else (cycle[_cycle_pos] % 2 == 1)
		if lands:
			_step_side = not _step_side
			on_step()
	_set_frame(cycle[_cycle_pos])


## True when this actor's sheet carries LimeZu's six-frame walk.
func has_full_walk() -> bool:
	return sprite != null and sprite.hframes >= FULL_SHEET_COLS


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


## The scenes say 15 columns, but a texture can be swapped in at runtime (a
## student's own sheet, the mentor's) and an older sheet is 9 wide. Cells are
## always 32px, so the column count is simply the texture's width over that --
## otherwise a 9-wide sheet read at 15 would show every frame sliced wrong.
func _fit_sheet() -> void:
	if sprite == null or sprite.texture == null:
		return
	var cols := int(sprite.texture.get_width() / CELL_W)
	if cols > 0 and sprite.hframes != cols:
		sprite.hframes = cols


func _set_frame(f: int, force: bool = false) -> void:
	if not force and _pose_timer > 0.0:
		return
	if sprite != null:
		_fit_sheet()
		sprite.frame_coords = Vector2i(f, facing)
