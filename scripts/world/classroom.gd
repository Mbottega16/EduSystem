extends Node2D

## The world root. Owns the grid, builds the room, spawns everyone, and runs
## the school day.
##
## Attached to the `World` node, which is y-sorted — so every child is drawn
## in the order its floor-anchor sits down the screen, and a teacher standing
## below a desk is drawn in front of it with no special casing.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")

## Where the teacher starts the day: front of the room, beside the podium.
const TEACHER_START := Vector2i(9, 3)

signal lesson_tick(seconds_left: float)
signal lesson_timed_out()

signal work_finished(seat_index: int)
signal day_started(day: int)
signal item_move_requested(id: String, tile: Vector2i)
signal desk_move_requested(seat_index: int)
signal desks_changed()

var grid := Grid.new()
var player: Actor = null
var students: Array[Actor] = []
var stations: Array = []
var podium: Interactable = null
var teacher_desk: Interactable = null
var bell: Interactable = null
var noticeboard: Interactable = null

var lesson_left: float = 0.0
var _purchased: Array = []
## Tiles the bought furniture is currently occupying, so they can be handed
## back when it moves or the room is cleared.
var _purchased_tiles: Array[Vector2i] = []


func _ready() -> void:
	# Explicit, because an autoload's _ready() does not fire under the custom
	# MainLoop the headless tests use. Initialising here means the game and
	# the tests take exactly the same path.
	Game.ensure_run()
	build()
	Game.room_changed.connect(_rebuild_purchased)


func build() -> void:
	RoomBuilder.build_floor(self)
	RoomBuilder.build_walls(self, grid)
	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()
	podium = RoomBuilder.build_podium(self, grid)
	teacher_desk = RoomBuilder.build_teacher_desk(self, grid)
	bell = RoomBuilder.build_bell(self, grid)
	noticeboard = RoomBuilder.build_noticeboard(self, grid)
	_purchased = RoomBuilder.build_purchased(self, grid)
	_connect_placed()
	_spawn_students()
	_spawn_player()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Grid.tile_to_world(TEACHER_START)
	add_child(player)


## Everyone starts at the doorway and walks to their own chair. If a seat
## somehow can't be reached they are placed directly rather than left
## standing in the doorway forever.
func _spawn_students() -> void:
	var n := 0
	for s: StudentData in Game.roster:
		if s.seat_index < 0 or s.seat_index >= Layout.seat_count():
			continue
		var node: Actor = STUDENT_SCENE.instantiate()
		add_child(node)                  # in the tree before bind(), so $Sprite2D resolves
		node.bind(s)
		node.position = Grid.tile_to_world(Layout.DOOR)

		var seat: Vector2i = Layout.seat(s.seat_index)
		var path := grid.path(Layout.DOOR, seat)
		if path.is_empty():
			push_warning("seat %d unreachable from the door — seating directly" % s.seat_index)
			node.seat_at(Grid.tile_to_world(seat))
		else:
			node.walk_to_seat(path, n * Balance.entry_stagger)
		students.append(node)
		n += 1


## Deliberately _physics_process, not _process. The physics tick is a fixed
## step, so "five seconds of work" is exactly 300 frames and a test can
## assert on it. On the idle tick it would be however many variable-length
## frames the machine happened to render, which is not assertable at all.
func _physics_process(delta: float) -> void:
	if Game.phase == Game.Phase.LESSON:
		# The clock is what makes this a game rather than a chore list.
		# Without it nothing ended the lesson but the player, so you could
		# always reach every student and there was no triage to do.
		lesson_left = maxf(0.0, lesson_left - delta)
		lesson_tick.emit(lesson_left)
		for s: StudentData in Game.roster:
			if s.tick_work(delta, Game.rng):
				_on_work_done(s)
		if lesson_left <= 0.0:
			lesson_timed_out.emit()
	_refresh_bubbles()


## The "?" over a stuck student and the finished sheet on their desk, both
## driven from STATE every frame rather than from a one-off event.
##
## The paper used to be shown only by _on_work_done(), which meant the
## display was correct only if this node happened to be the thing that
## advanced the work. Reading state instead makes the room always agree with
## the data, whoever moved it.
func _refresh_bubbles() -> void:
	for n: Actor in students:
		if n.data != null:
			n.set_bubble(n.seated and n.data.is_struggling())
	for st: Interactable in stations:
		var s := Game.student_in_seat(st.seat_index)
		st.show_paper(s != null and s.has_work_to_collect())


func _on_work_done(s: StudentData) -> void:
	var st := station(s.seat_index)
	if st != null:
		st.show_paper(true)
	work_finished.emit(s.seat_index)


func station(seat_index: int) -> Interactable:
	for st: Interactable in stations:
		if st.seat_index == seat_index:
			return st
	return null


func student_node(seat_index: int) -> Actor:
	for n: Actor in students:
		if n.data != null and n.data.seat_index == seat_index:
			return n
	return null


func everyone_seated() -> bool:
	if students.is_empty():
		return false
	for n: Actor in students:
		if not n.seated:
			return false
	return true


# ------------------------------------------------------------- the day

## Podium, in the morning. Sets the whole class working.
func start_lesson() -> int:
	Balance.ensure_loaded()
	Game.set_phase(Game.Phase.LESSON)
	lesson_left = Game.lesson_length()
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n


## Podium, during a lesson. Grades everyone on what actually happened, then
## sets tonight's homework.
func end_lesson() -> Array:
	lesson_left = 0.0
	var results := Game.grade_class()
	Game.assign_homework()
	Game.set_phase(Game.Phase.AFTERNOON)
	for s: StudentData in Game.roster:
		s.confusion = 0.0
	_refresh_bubbles()
	for st: Interactable in stations:
		st.show_paper(false)
	return results


## The bell. Pays out, rolls overnight homework, and starts tomorrow with the
## class filing back in.
func end_day() -> Dictionary:
	var report := Game.advance_day()
	if player != null:
		player.drop_all_work()
		player.drop_all_homework()
	for st: Interactable in stations:
		st.show_paper(false)
	_respawn_students()
	day_started.emit(Game.day)
	return report


func _respawn_students() -> void:
	for n: Actor in students:
		n.queue_free()
	students.clear()
	_spawn_students()
	if player != null:
		player.global_position = Grid.tile_to_world(TEACHER_START)


## Rebuild just the bought furniture. Cheaper and far less error-prone than
## rebuilding the whole room, and it keeps the students where they are.
##
## Releasing the OLD tiles first is not optional: without it, removing or
## replacing an item left its cells blocked forever, so the floor slowly
## filled up with invisible obstacles that pathfinding still respected.
func _rebuild_purchased() -> void:
	for n: Node in _purchased:
		if not is_instance_valid(n):
			continue
		# Detach BEFORE freeing. queue_free() leaves a node in its groups and
		# in the physics world until the end of the frame, so a just-sold
		# bookshelf could still be found by the player's interact zone and by
		# get_nodes_in_group() — you could walk up to furniture that no
		# longer exists. remove_child takes it out immediately.
		n.get_parent().remove_child(n)
		n.queue_free()
	for t: Vector2i in _purchased_tiles:
		grid.set_cell(t, Grid.Cell.FREE)
	_purchased_tiles.clear()
	_purchased = RoomBuilder.build_purchased(self, grid)
	_connect_placed()
	for placed: Dictionary in Game.room_items:
		for t: Vector2i in Items.footprint(String(placed["id"]), placed["tile"]):
			_purchased_tiles.append(t)


## The desks are rebuilt whenever one of them moves, so their movers are new
## objects each time -- same reason _connect_placed() exists.
func _connect_desk_movers() -> void:
	for n in get_tree().get_nodes_in_group("desk_part"):
		if not (n is Node) or n.get_parent() != self:
			continue
		for c in n.get_children():
			if c is Interactable and c.has_signal("desk_move_requested"):
				if not c.desk_move_requested.is_connected(_on_desk_move_requested):
					c.desk_move_requested.connect(_on_desk_move_requested)


func _on_desk_move_requested(seat_index: int) -> void:
	desk_move_requested.emit(seat_index)


## Bought furniture is rebuilt from data, so its interactables are new
## objects each time and have to be reconnected.
func _connect_placed() -> void:
	for body: Node in _purchased:
		for c in body.get_children():
			if c is Interactable and c.has_signal("move_requested"):
				if not c.move_requested.is_connected(_on_move_requested):
					c.move_requested.connect(_on_move_requested)


func _on_move_requested(id: String, tile: Vector2i) -> void:
	item_move_requested.emit(id, tile)


## Put one desk somewhere else, and take its chair and its occupant with it.
##
## The seating is torn down and rebuilt wholesale rather than nudged in
## place. There are eight desks: rebuilding is cheap, and it means the grid
## cells, the collision boxes and the interactables can never drift out of
## step with where the desks actually are — which they would, one edge case
## at a time, if this tried to patch the difference.
func move_desk(seat_index: int, to: Vector2i) -> bool:
	var old_seats := Layout.seats().duplicate()
	if not Layout.move_seat(seat_index, to):
		return false

	# free the tiles the old arrangement was holding
	for t: Vector2i in old_seats:
		grid.set_cell(t, Grid.Cell.FREE)
		grid.set_cell(t + Layout.DESK_OFFSET, Grid.Cell.FREE)

	for n in get_tree().get_nodes_in_group("desk_part"):
		if n is Node2D and (n as Node2D).get_parent() == self:
			remove_child(n)
			n.queue_free()

	stations = RoomBuilder.build_desks(self, grid)
	_connect_desk_movers()

	# whoever was sitting there is now sitting somewhere else
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null:
			node.seat_at(Grid.tile_to_world(Layout.seat(s.seat_index)))
	desks_changed.emit()
	return true


## Assign work to every seated student. Exposed so tests and future systems
## can drive it without faking an interaction.
func assign_work_to_class() -> int:
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n
