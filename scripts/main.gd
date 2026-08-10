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
	world.bell.day_ended.connect(hud.show_day_report)
	world.noticeboard.catalogue_opened.connect(hud.open_catalogue)
	world.teacher_desk.marking_requested.connect(hud.open_marking)

	hud.item_chosen.connect(_start_placing)
	placement.placed.connect(_finish_placing)
	placement.cancelled.connect(_unlock)


func _start_placing(id: String) -> void:
	world.player.input_locked = true
	placement.begin(id, world.grid, Grid.world_to_tile(world.player.global_position))


func _finish_placing(id: String, tile: Vector2i) -> void:
	Game.place_item(id, tile)
	_unlock()


func _unlock() -> void:
	world.player.input_locked = false

