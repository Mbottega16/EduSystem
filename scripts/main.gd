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

	# Signals that belong to the WORLD itself survive a rebuild, so they are
	# connected once.
	world.quiz_requested.connect(_run_quiz)
	world.curriculum_requested.connect(hud.show_curriculum)
	world.test_requested.connect(func(lid: String) -> void: world.start_test(lid))
	world.lesson_auto_ended.connect(_on_lesson_ended)
	world.inspected.connect(func(r: Dictionary) -> void:
		_bump(3.0 if not bool(r.get("passed", false)) else 1.5)
		hud.show_inspection(r))
	world.test_auto_ended.connect(hud.show_test_report)
	world.room_rebuilt.connect(_wire_room)
	_wire_room()

	# Onboarding, in one sentence at the moment it explains something the
	# player has just watched happen. Game owns the threshold; hint_once
	# owns the "only say it once" and respects Settings.show_hints.
	Game.class_drifted.connect(func() -> void:
		hud.hint_once("class_drifted",
			"Work only moves while you are at the front."))

	hud.item_chosen.connect(_start_placing)
	hud.assignment_chosen.connect(_start_chosen_lesson)
	hud.perk_bought.connect(func() -> void: world.player._apply_reach())
	world.add_to_group("classroom")
	add_to_group("main_wiring")
	placement.set_process(true)
	world.item_move_requested.connect(_start_moving)
	world.desk_move_requested.connect(_start_moving_desk)
	placement.placed.connect(_finish_placing)
	placement.desk_placed.connect(_finish_moving_desk)
	placement.cancelled.connect(_unlock)
	placement.picked_up.connect(_start_moving)
	placement.sold.connect(func(tile: Vector2i) -> void:
		Game.sell_item(tile))


## The fixed props are NEW NODES after the room is rebuilt at a bigger size,
## so their signals have to be reconnected to match.
##
## Connecting them once in _ready() was correct only while the room was a
## constant. The moment rebuild_room() existed, every one of these pointed at
## a freed node and the podium, the bell, the shop and the marking desk all
## silently stopped working -- with the prompt still cheerfully offering
## them, because the interactables themselves were fine.
## On an inspection day the inspector's verdict IS the day's headline, and
## it already carries the class average -- so it replaces the ordinary
## lesson report rather than stacking a second screen behind it.
func _on_lesson_ended(results: Array) -> void:
	if Game.being_inspected():
		return
	hud.show_lesson_report(results)


## The bell and the exam get a bump. These are the two moments a day and a
## term actually resolve, and a shake reserved for them keeps meaning "that
## mattered" -- one fired on every event would mean nothing.
func _on_day_ended(report: Dictionary) -> void:
	_bump(1.5)
	hud.show_day_report(report)


func _on_term_ended(result: Dictionary) -> void:
	_bump(3.5)
	hud.show_exam(result)


func _wire_room() -> void:
	var pairs := [
		[world.podium, "hand_requested", _offer_hand],
		[world.podium, "lesson_ended", _on_lesson_ended],
		[world.podium, "test_ended", hud.show_test_report],
		[world.bell, "day_ended", _on_day_ended],
		[world.bell, "term_ended", _on_term_ended],
		[world.noticeboard, "catalogue_opened", hud.open_catalogue],
		[world.teacher_desk, "marking_requested", hud.open_marking],
	]
	for row: Array in pairs:
		var node: Object = row[0]
		if node == null or not is_instance_valid(node):
			continue
		var sig: String = row[1]
		var target: Callable = row[2]
		if not node.is_connected(sig, target):
			node.connect(sig, target)


func _start_placing(id: String) -> void:
	world.player.input_locked = true
	placement.begin(id, world.grid, Grid.world_to_tile(world.player.global_position))


## Squash-and-settle on whatever was just put down, once the room has
## rebuilt around it. Deferred because the node does not exist yet at the
## moment the placement is confirmed -- Game.add_item() triggers the rebuild.
func _land_at(tile: Vector2i) -> void:
	await get_tree().process_frame
	for n in get_tree().get_nodes_in_group("purchased"):
		if n is Node2D and Grid.world_to_tile((n as Node2D).global_position) == tile:
			Fx.land(n)
			Fx.puff(world, (n as Node2D).global_position, Color(1, 1, 1, 0.7), 4)
			return


func _finish_placing(id: String, tile: Vector2i) -> void:
	if _moving_from == NOWHERE:
		Game.place_item(id, tile)          # a new purchase, so it costs
	else:
		Game.add_item(id, tile)            # already owned, just relocated
		_moving_from = NOWHERE
	_land_at(tile)
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


## The three moments worth a bump: the bell, an inspection, the exam. Not
## every event -- a shake that fires often stops meaning "this mattered".
func _bump(strength: float = 2.0) -> void:
	if world != null and world.camera != null:
		Fx.shake(world.camera, strength)


## Build mode. A cursor over the WHOLE room, so rearranging is not a series
## of walks to individual pieces of furniture.
##
## Deliberately not available mid-lesson, which is the rule every other way
## of moving furniture already follows: sliding desks about while the class
## works would dodge the point of planning the room in advance.
func _toggle_build() -> void:
	if placement.active:
		placement.finish()
		_unlock()
		return
	if Game.phase == Game.Phase.LESSON:
		hud.hint_once("build_lesson", "Not while the class is working.")
		return
	world.player.input_locked = true
	placement.begin_browse(world.grid,
		Grid.world_to_tile(world.player.global_position))


## Draw three papers and let the player pick one; the lesson starts with
## whichever they took.
func _offer_hand() -> void:
	Game.draw_hand()
	hud.show_hand()


func _start_chosen_lesson(i: int) -> void:
	Game.choose_assignment(i)
	world.podium.lesson_started.emit(world.start_lesson())


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

