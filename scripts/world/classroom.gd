extends Node2D

## The world root. Owns the grid, builds the room, and spawns everyone.
##
## Attached to the `World` node, which is y-sorted — so every child is drawn
## in the order its floor-anchor sits down the screen, and a teacher standing
## below a desk is drawn in front of it with no special casing.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const STUDENT_SCENE := preload("res://scenes/actors/student.tscn")

## Where the teacher starts the day: front of the room, beside the podium.
const TEACHER_START := Vector2i(9, 3)

var grid := Grid.new()
var player: Actor = null
var students: Array[Actor] = []


func _ready() -> void:
	# Explicit, because an autoload's _ready() does not fire under the custom
	# MainLoop the headless tests use. Initialising here means the game and
	# the tests take exactly the same path.
	Game.ensure_run()
	build()


func build() -> void:
	RoomBuilder.build_floor(self)
	RoomBuilder.build_walls(self, grid)
	RoomBuilder.build_desks(self, grid)
	_spawn_students()
	_spawn_player()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Grid.tile_to_world(TEACHER_START)
	add_child(player)


func _spawn_students() -> void:
	for s: StudentData in Game.roster:
		if s.seat_index < 0 or s.seat_index >= Layout.seat_count():
			continue
		var node: Actor = STUDENT_SCENE.instantiate()
		add_child(node)                      # in the tree before bind(), so $Sprite2D resolves
		node.bind(s)
		node.seat_at(Grid.tile_to_world(Layout.SEATS[s.seat_index]))
		students.append(node)


## The student node sitting in `seat_index`, or null.
func student_node(seat_index: int) -> Actor:
	for n: Actor in students:
		if n.data != null and n.data.seat_index == seat_index:
			return n
	return null
