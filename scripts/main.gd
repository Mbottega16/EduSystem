extends Node2D

## Wires the world to the UI.
##
## Neither half should have to know how the other is built, and neither
## _ready() can assume it runs first — so the connecting happens here, in the
## parent of both, once.

@onready var world: Node2D = $World
@onready var hud: Control = $UI/HUD

var placement: Placement = null


func _ready() -> void:
	placement = Placement.new()
	placement.visible = false
	world.add_child(placement)

	world.podium.lesson_ended.connect(hud.show_lesson_report)
	world.quiz_requested.connect(_run_quiz)
	world.bell.day_ended.connect(hud.show_day_report)
	world.bell.term_ended.connect(hud.show_exam)
	world.noticeboard.catalogue_opened.connect(hud.open_catalogue)
	world.teacher_desk.marking_requested.connect(hud.open_marking)

	hud.item_chosen.connect(_start_placing)
	hud.perk_bought.connect(func() -> void: world.player._apply_reach())
	world.add_to_group("classroom")
	placement.set_process(true)
	world.item_move_requested.connect(_start_moving)
	world.desk_move_requested.connect(_start_moving_desk)
	placement.placed.connect(_finish_placing)
	placement.desk_placed.connect(_finish_moving_desk)
	placement.cancelled.connect(_unlock)


func _start_placing(id: String) -> void:
	world.player.input_locked = true
	placement.begin(id, world.grid, Grid.world_to_tile(world.player.global_position))


func _finish_placing(id: String, tile: Vector2i) -> void:
	if _moving_from == NOWHERE:
		Game.place_item(id, tile)          # a new purchase, so it costs
	else:
		Game.add_item(id, tile)            # already owned, just relocated
		_moving_from = NOWHERE
	_unlock()


## Picking up something you already own. It comes off the floor immediately
## so the ghost can be moved through the space it was occupying, and goes
## back exactly where it was if the move is cancelled.
const NOWHERE := Vector2i(-999, -999)
var _moving_from: Vector2i = NOWHERE

func _start_moving(id: String, tile: Vector2i) -> void:
	var placed := Game.item_at(tile)
	if placed.is_empty():
		return
	_moving_from = placed["tile"]
	Game.remove_item(_moving_from)
	world.player.input_locked = true
	placement.begin(id, world.grid, _moving_from)


func _run_quiz() -> void:
	hud.show_quiz_report(world.run_quiz())


## Carrying a desk. Unlike a bought item this is NOT lifted off the grid
## first: a desk has a child sitting in it, and taking the seat away while
## the ghost is in flight would strand them. Placement treats the desk's own
## two tiles as free instead, so nudging it one square still works.
func _start_moving_desk(seat_index: int) -> void:
	world.player.input_locked = true
	placement.begin_desk(seat_index, world.grid)


func _finish_moving_desk(seat_index: int, tile: Vector2i) -> void:
	world.move_desk(seat_index, tile)
	_unlock()


func _unlock() -> void:
	# a cancelled MOVE must put the item back, or it vanishes
	if _moving_from != NOWHERE:
		Game.add_item(placement.item_id, _moving_from)
		_moving_from = NOWHERE
	world.player.input_locked = false

