extends Actor

## The teacher. You.
##
## Movement is read through INPUT ACTIONS, never Input.is_physical_key_pressed.
## That distinction is load-bearing: Input.action_press() can drive an action
## from a test, but nothing can fake a physical key press, so the old WASD
## handling was untestable by construction.

signal target_changed(target: Interactable)
signal carrying_changed(count: int)

@onready var zone: Area2D = $InteractZone
@onready var carry_icon: Sprite2D = $CarryIcon

var target: Interactable = null
var carrying: int = 0        ## classwork sheets in your arms
var carrying_hw: int = 0     ## homework collected, waiting to be marked
## Set while a full-screen overlay owns the input, so you don't wander off
## behind the catalogue.
var input_locked: bool = false


func _ready() -> void:
	_apply_reach()
	# teacher_desk.gd finds the carrier through this group rather than
	# needing a wired reference, so its prompt is answerable before anyone
	# has interacted with anything.
	add_to_group("carrier")
	_refresh_carry_icon()


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not input_locked:
		dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
	walk(dir, delta)

	# The thing you were standing at can be destroyed under you — sell a
	# bookshelf and its node is freed while this still points at it. Drop a
	# dead target before anything reads it.
	if target != null and not is_instance_valid(target):
		target = null
		target_changed.emit(null)

	# AFTER move_and_slide, always: Area2D overlap state updates one physics
	# frame behind transform changes, so picking before moving would select
	# against where you were last frame.
	var found := _pick_target()
	if found != target:
		target = found
		target_changed.emit(target)

	if not input_locked:
		_tick_hold(delta)


## Nearest interactable, but strongly preferring whatever you are facing.
## Pure-nearest is ambiguous the moment two desks are in range, and a
## raycast fired from between two desks misses both.
func _pick_target() -> Interactable:
	var best: Interactable = null
	var best_score := -INF
	var f := facing_vector()
	for a in zone.get_overlapping_areas():
		if not (a is Interactable):
			continue
		var it := a as Interactable
		if not it.can_interact():
			continue
		var to: Vector2 = it.global_position - global_position
		var dist := to.length()
		var aligned := 1.0 if dist < 0.01 else f.dot(to / dist)
		var score := (100.0 if aligned > 0.2 else 0.0) - dist
		if score > best_score:
			best_score = score
			best = it
	return best


## How far through a hold-to-confirm we are, 0..1. The HUD draws this.
var hold_progress: float = 0.0
var _held: float = 0.0


## Route the press to the right BUTTON, and make anything irreversible
## require a HOLD.
##
## Before this, one key did everything: help, collect, hand in, start the
## lesson, end the lesson, ring the bell. Reaching to help a student who
## happened to be standing near the podium ended the whole lesson, which is
## about the worst possible thing a stray keypress can do in this game.
##
##   interact (E) - help, collect, hand in. Mashable, never destructive.
##   manage   (F) - lesson, bell, shop. Separate finger, separate intent.
##
## and on top of that, the two that cannot be undone need the key held.
func _tick_hold(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_held = 0.0
		hold_progress = 0.0
		return

	var action: String = target.action_name()
	var need: float = target.hold_time

	if need <= 0.0:
		hold_progress = 0.0
		if Game.claim_action(action):
			target.interact(self)
			# what you just did usually changes what is on offer
			target = _pick_target()
			target_changed.emit(target)
		return

	if Input.is_action_pressed(action):
		_held += delta
		hold_progress = clampf(_held / need, 0.0, 1.0)
		if _held >= need:
			_held = -999.0            # fire once per hold, not once per frame
			hold_progress = 0.0
			target.interact(self)
			target = _pick_target()
			target_changed.emit(target)
	else:
		if _held > -1.0:
			_held = 0.0
		if not Input.is_action_pressed(action):
			_held = 0.0
		hold_progress = 0.0


## Perks raise the teacher's base speed, so this is expressed as a ratio
## against the Actor constant rather than as a flat multiplier.
func speed_scale() -> float:
	var base: float = Progress.speed(Game.perk_ranks) / SPEED
	return base * (SPRINT if Input.is_action_pressed("sprint") else 1.0)


## Only the teacher's footsteps are audible.
func on_step() -> void:
	Sfx.play_varied("step", 0.12 if speed_scale() <= 1.0 else 0.2)


## Long Reach widens the pick zone. Re-applied when a perk is bought.
func _apply_reach() -> void:
	if zone == null:
		return
	for c in zone.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
			((c as CollisionShape2D).shape as CircleShape2D).radius = 				Progress.pick_radius(Game.perk_ranks)


func carry_work(n: int) -> void:
	carrying += n
	_refresh_carry_icon()
	carrying_changed.emit(carrying)


func drop_all_work() -> void:
	carrying = 0
	_refresh_carry_icon()
	carrying_changed.emit(carrying)


func carry_homework(n: int) -> void:
	carrying_hw += n
	_refresh_carry_icon()
	carrying_changed.emit(carrying)


func drop_all_homework() -> void:
	carrying_hw = 0
	_refresh_carry_icon()
	carrying_changed.emit(carrying)


func _refresh_carry_icon() -> void:
	if carry_icon == null:
		return
	carry_icon.visible = (carrying + carrying_hw) > 0
