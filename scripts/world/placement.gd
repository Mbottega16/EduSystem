class_name Placement
extends Node2D

## Ghost-cursor mode for putting a bought item down.
##
## The cursor is KEYBOARD-first and free-floating — not anchored to the tile
## the teacher happens to face, which is charming for about a minute and then
## makes the far corners of the room miserable to reach.

signal placed(id: String, tile: Vector2i)
signal cancelled()

const OK_TINT := Color(0.55, 1.0, 0.6, 0.75)
const BAD_TINT := Color(1.0, 0.45, 0.4, 0.7)

var active: bool = false
var item_id: String = ""
var tile: Vector2i = Vector2i(9, 5)

var _grid: Grid = null
var _ghost: Sprite2D = null
var _repeat := 0.0


func begin(id: String, grid: Grid, start: Vector2i) -> void:
	item_id = id
	_grid = grid
	tile = start
	active = true
	visible = true
	if _ghost == null:
		_ghost = Sprite2D.new()
		add_child(_ghost)
	var def := Items.get_def(id)
	_ghost.texture = load("res://art/%s.png" % String(def["art"]))
	_refresh()


func finish() -> void:
	active = false
	visible = false


## Valid means: on the floor, nothing already there, AND — the important one
## — placing it must not cut any seat off from the door.
func is_valid() -> bool:
	if _grid == null or item_id == "":
		return false
	for t: Vector2i in Items.footprint(item_id, tile):
		if not _grid.is_free(t):
			return false
	if not Game.item_fits(item_id, tile):
		return false
	return not _would_trap_anyone()


## Simulate the placement on the real grid, test every seat, then put it
## back. Without this a player can wall their own class off from the door and
## quietly break the game with no warning — and it is only possible because
## the grid has been the single spatial authority since Phase 0.
func _would_trap_anyone() -> bool:
	var tiles := Items.footprint(item_id, tile)
	var before: Array[int] = []
	for t: Vector2i in tiles:
		before.append(_grid.get_cell(t))
		_grid.set_cell(t, Grid.Cell.BLOCKED)

	var trapped := false
	for s: StudentData in Game.roster:
		if s.seat_index < 0:
			continue
		if not _grid.reachable(Layout.DOOR, Layout.SEATS[s.seat_index]):
			trapped = true
			break

	for i in tiles.size():
		_grid.set_cell(tiles[i], before[i])
	return trapped


func _refresh() -> void:
	if _ghost == null:
		return
	var tiles := Items.footprint(item_id, tile)
	_ghost.position = Layout.span_anchor(tiles) - Vector2(0, _ghost.texture.get_height() / 2.0)
	_ghost.modulate = OK_TINT if is_valid() else BAD_TINT


func move_by(d: Vector2i) -> void:
	var want := tile + d
	if Grid.in_bounds(want):
		tile = want
		_refresh()


func _physics_process(_d: float) -> void:
	if active:
		_handle_input()


func _process(delta: float) -> void:
	if not active:
		return
	if not active:
		return
	# Held-key repeat, so crossing the room isn't 18 separate taps.
	_repeat -= delta
	var d := Vector2i(
		int(Input.get_axis("move_left", "move_right")),
		int(Input.get_axis("move_up", "move_down")))
	if d == Vector2i.ZERO:
		_repeat = 0.0
	elif _repeat <= 0.0:
		move_by(d)
		_repeat = 0.14


## Polled, not event-driven — see the note in scripts/ui/hud.gd. This is
## also why the ghost is driven from _process rather than from input events.
func _handle_input() -> void:
	if Input.is_action_just_pressed("cancel"):
		finish()
		cancelled.emit()
	elif Game.claim_interact():
		if is_valid():
			placed.emit(item_id, tile)
			finish()
