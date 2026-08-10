extends Node2D

## The world root. Owns the grid, builds the room, spawns everyone, and runs
## the classwork clock.
##
## Attached to the `World` node, which is y-sorted — so every child is drawn
## in the order its floor-anchor sits down the screen, and a teacher standing
## below a desk is drawn in front of it with no special casing.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")

## Where the teacher starts the day: front of the room, beside the podium.
const TEACHER_START := Vector2i(9, 3)

## Students file in rather than surging through the door as one block.
const ENTRY_STAGGER := 0.35

signal work_finished(seat_index: int)

var grid := Grid.new()
var player: Actor = null
var students: Array[Actor] = []
var stations: Array = []
var podium: Interactable = null
var teacher_desk: Interactable = null


func _ready() -> void:
	# Explicit, because an autoload's _ready() does not fire under the custom
	# MainLoop the headless tests use. Initialising here means the game and
	# the tests take exactly the same path.
	Game.ensure_run()
	build()


func build() -> void:
	RoomBuilder.build_floor(self)
	RoomBuilder.build_walls(self, grid)
	stations = RoomBuilder.build_desks(self, grid)
	podium = RoomBuilder.build_podium(self, grid)
	teacher_desk = RoomBuilder.build_teacher_desk(self, grid)
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

		var seat: Vector2i = Layout.SEATS[s.seat_index]
		var path := grid.path(Layout.DOOR, seat)
		if path.is_empty():
			push_warning("seat %d unreachable from the door — seating directly" % s.seat_index)
			node.seat_at(Grid.tile_to_world(seat))
		else:
			node.walk_to_seat(path, n * ENTRY_STAGGER)
		students.append(node)
		n += 1


## Deliberately _physics_process, not _process. The physics tick is a fixed
## step, so "five seconds of work" is exactly 300 frames and a test can
## assert on it. On the idle tick it would be however many variable-length
## frames the machine happened to render, which is not assertable at all.
func _physics_process(delta: float) -> void:
	for s: StudentData in Game.roster:
		if s.tick_work(delta):
			_on_work_done(s)


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


## The student node sitting in `seat_index`, or null.
func student_node(seat_index: int) -> Actor:
	for n: Actor in students:
		if n.data != null and n.data.seat_index == seat_index:
			return n
	return null


func everyone_seated() -> bool:
	for n: Actor in students:
		if not n.seated:
			return false
	return true


## Assign work to every seated student. Exposed here as well as on the podium
## so tests and future systems can drive it without faking an interaction.
func assign_work_to_class() -> int:
	var n := 0
	for s: StudentData in Game.roster:
		var node := student_node(s.seat_index)
		if node != null and node.seated and s.assign_work():
			n += 1
	return n
