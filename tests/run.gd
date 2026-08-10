extends Node2D

## PixelRoom test suite.
##
##   godot --headless --path . res://tests/run.tscn
##
## Exits 0 on pass, 1 on failure, so it is CI-able and can sit behind a
## double-clickable Run Tests.bat.
##
## TIMING DISCIPLINE — read before adding a test.
## Never use get_tree().create_timer() to wait for movement.
## Engine.max_physics_steps_per_frame (default 8) clamps catch-up, so any
## main-thread stall — a screenshot save being the obvious one — desyncs
## simulation time from wall-clock time and every timer-based assertion
## silently lies. This already bit this project: a "3 second" held input
## produced under 1 second of travel and made the player look like it
## stopped short of obstacles it had never reached. Physics frames are the
## only honest clock. Use step().

const SEED := 20260809

var passed := 0
var failed := 0
var world: Node2D = null


func _ready() -> void:
	# Never let a broken run hang a terminal.
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		push_error("watchdog: suite exceeded 120s")
		get_tree().quit(1))
	_main()


func chk(label: String, cond: bool, extra: Variant = null) -> void:
	if cond:
		passed += 1
		print("  [ok] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s%s" % [label, "" if extra == null else "  -> %s" % str(extra)])


func section(name: String) -> void:
	print("\n== %s ==" % name)


func step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await step(frames)
	Input.action_release(action)
	await step(1)


## A single press. Held for two frames so the player's
## is_action_just_pressed() check is guaranteed to see it.
func tap(action: String) -> void:
	Input.action_press(action)
	await step(2)
	Input.action_release(action)
	await step(2)


## Stand the teacher on `tile` facing `dir`, ready to interact.
func place_player(tile: Vector2i, dir: int) -> void:
	world.player.global_position = Grid.tile_to_world(tile)
	world.player.facing = dir
	await step(2)


func _main() -> void:
	test_grid()
	test_game()
	test_layout()
	await test_scene()
	await test_movement()
	await test_arrival()
	await test_work_loop()
	await test_seating()

	print("")
	if failed == 0:
		print("ALL PIXELROOM CHECKS PASSED  (%d assertions)" % passed)
	else:
		print("FAILURES: %d of %d" % [failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


# =============================================== tier 1: pure logic, no scene

func test_grid() -> void:
	section("GRID")
	var g := Grid.new()

	chk("a tile's anchor is its bottom-centre",
		Grid.tile_to_world(Vector2i(0, 0)) == Vector2(8, 16),
		Grid.tile_to_world(Vector2i(0, 0)))
	chk("tile -> world -> tile round-trips",
		Grid.world_to_tile(Grid.tile_to_world(Vector2i(7, 4))) == Vector2i(7, 4))
	# The classic off-by-one: a point exactly on a tile's bottom edge belongs
	# to THAT tile, not the one below it.
	chk("a point on a tile's bottom edge belongs to that tile",
		Grid.world_to_tile(Vector2(8, 16)) == Vector2i(0, 0),
		Grid.world_to_tile(Vector2(8, 16)))
	chk("out-of-bounds tiles are rejected",
		not Grid.in_bounds(Vector2i(-1, 0)) and not Grid.in_bounds(Vector2i(Grid.W, 0)))

	chk("a fresh grid is entirely free", g.free_tiles().size() == Grid.W * Grid.H)
	g.set_cell(Vector2i(5, 5), Grid.Cell.BLOCKED)
	chk("blocking a tile removes it from the free list",
		g.free_tiles().size() == Grid.W * Grid.H - 1 and not g.is_free(Vector2i(5, 5)))
	chk("an out-of-bounds cell reads as blocked, never as free",
		g.get_cell(Vector2i(-3, 2)) == Grid.Cell.BLOCKED)

	g.block_rect(Rect2i(2, 2, 2, 2))
	chk("block_rect blocks every tile in the rect",
		not g.is_free(Vector2i(2, 2)) and not g.is_free(Vector2i(3, 3))
		and g.is_free(Vector2i(4, 4)))

	# pathing
	var g2 := Grid.new()
	var p := g2.path(Vector2i(1, 1), Vector2i(4, 1))
	chk("a straight path is found and includes both ends",
		p.size() == 4 and p[0] == Vector2i(1, 1) and p[-1] == Vector2i(4, 1), p)

	# a wall of blocked tiles with no gap must make the target unreachable
	var g3 := Grid.new()
	for y in Grid.H:
		g3.set_cell(Vector2i(5, y), Grid.Cell.BLOCKED)
	chk("a solid wall makes the far side unreachable",
		not g3.reachable(Vector2i(1, 1), Vector2i(9, 1)))
	g3.set_cell(Vector2i(5, 3), Grid.Cell.FREE)
	chk("opening one tile in that wall makes it reachable again",
		g3.reachable(Vector2i(1, 1), Vector2i(9, 1)))

	# a seat is solid to routing but still reachable as a destination —
	# otherwise a student could never path onto their own chair
	var g4 := Grid.new()
	g4.set_cell(Vector2i(6, 6), Grid.Cell.SEAT)
	chk("a seat is not a through-route", not g4.is_free(Vector2i(6, 6)))
	chk("but a seat can still be pathed TO as a goal",
		not g4.path(Vector2i(1, 1), Vector2i(6, 6)).is_empty())

	var g5 := Grid.new()
	g5.set_cell(Vector2i(3, 3), Grid.Cell.BLOCKED)
	chk("approach tiles are the free orthogonal neighbours",
		g5.approach_tiles(Vector2i(3, 3)).size() == 4)


func test_game() -> void:
	section("GAME STATE")
	Game.new_run(SEED)
	chk("a new run enrols the starting class",
		Game.roster.size() == Game.CLASS_START, Game.roster.size())
	chk("day starts at 1 and coins at 0", Game.day == 1 and Game.coins == 0)

	var seats: Array = []
	for s: StudentData in Game.roster:
		seats.append(s.seat_index)
	seats.sort()
	chk("starting students take the lowest seats, no duplicates",
		seats == [0, 1, 2, 3], seats)

	# growth into the fixed eight-desk room
	while Game.roster.size() < Game.CLASS_CAP:
		Game.enrol()
	chk("the roster grows to the class cap", Game.roster.size() == Game.CLASS_CAP)
	chk("enrolling past the cap is refused", Game.enrol() == null)
	var all_seats := {}
	for s: StudentData in Game.roster:
		all_seats[s.seat_index] = true
	chk("every student has a distinct seat", all_seats.size() == Game.CLASS_CAP)

	# determinism — the whole grading/homework test story depends on this
	Game.new_run(SEED)
	var first: Array = []
	for s: StudentData in Game.roster:
		first.append("%s|%.4f|%.4f" % [s.display_name, s.aptitude, s.diligence])
	Game.new_run(SEED)
	var second: Array = []
	for s: StudentData in Game.roster:
		second.append("%s|%.4f|%.4f" % [s.display_name, s.aptitude, s.diligence])
	chk("the same seed produces the same class", first == second, first)

	# grade letters (carried over from EduSystems, E is a real letter)
	chk("grade letters map at their thresholds",
		Game.grade_letter(0.95) == "A" and Game.grade_letter(0.88) == "A"
		and Game.grade_letter(0.87) == "B" and Game.grade_letter(0.62) == "C"
		and Game.grade_letter(0.38) == "E" and Game.grade_letter(0.37) == "F")

	# save round-trip
	Game.new_run(SEED)
	Game.add_coins(250)
	Game.advance_day()
	var before := Game.to_dict()
	Game.from_dict(before)
	chk("save round-trips without drift", Game.to_dict() == before)
	chk("a save missing every key still loads with defaults", (func() -> bool:
		Game.from_dict({})
		return Game.day == 1 and Game.coins == 0 and Game.roster.is_empty()).call())

	Game.new_run(SEED)
	var s0: StudentData = Game.roster[0]
	s0.confusion = 0.7
	chk("a confused student reads as struggling", s0.is_struggling())
	s0.reset_lesson()
	chk("resetting the lesson clears confusion and attention",
		not s0.is_struggling() and s0.attention_credit == 0.0)


func test_layout() -> void:
	section("LAYOUT")
	chk("there are eight desks for the class cap",
		Layout.seat_count() == Game.CLASS_CAP, Layout.seat_count())

	var uniq := {}
	for s: Vector2i in Layout.SEATS:
		uniq[s] = true
	chk("no two seats share a tile", uniq.size() == Layout.SEATS.size())

	# every desk must sit one tile TOWARD the camera from its seat, or the
	# desk won't depth-sort in front of the student and the whole "sitting
	# at a desk" read collapses
	var ok := true
	for i in Layout.seat_count():
		if Layout.desk_tile(i) != Layout.SEATS[i] + Vector2i(0, 1):
			ok = false
	chk("every desk is one tile in front of its seat", ok)

	# nothing may be placed inside a wall
	var inside := true
	for i in Layout.seat_count():
		for t: Vector2i in [Layout.SEATS[i], Layout.desk_tile(i)]:
			if t.x < 1 or t.x > 18 or t.y < 2 or t.y > 9:
				inside = false
	chk("every seat and desk is inside the walls", inside)
	chk("podium and bell are inside the walls",
		Layout.PODIUM.y >= 2 and Layout.BELL.y >= 2
		and Layout.PODIUM.x >= 1 and Layout.BELL.x <= 18)
	chk("podium and bell are far apart, so ending the day is a walk",
		absi(Layout.PODIUM.x - Layout.BELL.x) >= 6)


# ========================================== tier 2: the real scene, stepped

func test_scene() -> void:
	section("SCENE")
	Game.new_run(SEED)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await step(2)
	world = main.get_node_or_null("World")
	chk("the World node exists and is y-sorted", world != null and world.y_sort_enabled)
	chk("a UI CanvasLayer exists and is NOT inside the y-sorted world",
		main.get_node_or_null("UI") is CanvasLayer)
	chk("the player spawned", world.player != null)
	chk("students spawned for the whole roster",
		world.students.size() == Game.roster.size(), world.students.size())

	# the grid must agree with the furniture that was actually built
	var seats_marked := true
	var desks_marked := true
	for i in Layout.seat_count():
		if world.grid.get_cell(Layout.SEATS[i]) != Grid.Cell.SEAT:
			seats_marked = false
		if world.grid.get_cell(Layout.desk_tile(i)) != Grid.Cell.BLOCKED:
			desks_marked = false
	chk("every seat tile is marked SEAT on the grid", seats_marked)
	chk("every desk tile is marked BLOCKED on the grid", desks_marked)
	chk("the walls are blocked on the grid",
		not world.grid.is_free(Vector2i(0, 5)) and not world.grid.is_free(Vector2i(9, 0)))

	# the room must not be able to trap anyone
	var start := Grid.world_to_tile(world.player.global_position)
	var all_reachable := true
	var unreachable: Array = []
	for i in Layout.seat_count():
		if not world.grid.reachable(start, Layout.SEATS[i]):
			all_reachable = false
			unreachable.append(i)
	chk("every seat is reachable from where the teacher starts",
		all_reachable, unreachable)
	chk("the door tile is reachable from the teacher's start",
		world.grid.reachable(start, Layout.DOOR))


func test_movement() -> void:
	section("MOVEMENT")
	var p: Actor = world.player

	# SPEED 60 at 60Hz physics == exactly 1px per frame, so this is integer
	# arithmetic rather than a tolerance.
	#
	# Row 3 is an aisle (seats are on rows 4 and 7, desks on 5 and 8). The
	# corridor is asserted clear FIRST: an earlier version of this test
	# started on row 5 between two desks, correctly travelled only 20px into
	# a desk, and looked like a movement bug. If a future layout change puts
	# furniture in this aisle, that shows up here as a failure rather than
	# quietly making the movement assertion meaningless.
	var lane_clear := true
	for tx in range(2, 8):
		if not world.grid.is_free(Vector2i(tx, 3)):
			lane_clear = false
	chk("the test corridor on row 3 is actually clear", lane_clear)

	p.global_position = Grid.tile_to_world(Vector2i(2, 3))
	await step(1)
	var x0: float = p.global_position.x
	await hold("move_right", 40)
	chk("holding move_right for 40 physics frames advances exactly 40px",
		is_equal_approx(p.global_position.x - x0, 40.0),
		"moved %.1f" % (p.global_position.x - x0))
	chk("facing is RIGHT after walking right", p.facing == Actor.DIR_RIGHT)

	# and the converse: furniture DOES stop you, which is what the bad
	# version of the test above was accidentally proving
	p.global_position = Grid.tile_to_world(Vector2i(9, 5))
	await step(1)
	var dx0: float = p.global_position.x
	await hold("move_right", 60)
	chk("a desk stops the player well short of 60px",
		p.global_position.x - dx0 < 30.0,
		"moved %.1f before hitting the desk at tile 11" % (p.global_position.x - dx0))

	var y0: float = p.global_position.y
	await hold("move_down", 20)
	chk("holding move_down for 20 frames advances exactly 20px",
		is_equal_approx(p.global_position.y - y0, 20.0),
		"moved %.1f" % (p.global_position.y - y0))
	chk("facing is DOWN after walking down", p.facing == Actor.DIR_DOWN)

	# WASD and the arrow keys are the same action, which is the entire point
	# of the Phase 0 input refactor — the old is_physical_key_pressed() read
	# could not be driven by a test at all.
	chk("move_right is bound to both D and Right", (func() -> bool:
		var keys: Array = []
		for e in InputMap.action_get_events("move_right"):
			if e is InputEventKey:
				keys.append((e as InputEventKey).physical_keycode)
		return keys.has(KEY_D) and keys.has(KEY_RIGHT)).call())

	# diagonal must not be faster than straight
	p.global_position = Grid.tile_to_world(Vector2i(9, 5))
	await step(1)
	var before := p.global_position
	Input.action_press("move_right")
	Input.action_press("move_down")
	await step(30)
	Input.action_release("move_right")
	Input.action_release("move_down")
	await step(1)
	var travelled: float = before.distance_to(p.global_position)
	chk("walking diagonally is not faster than walking straight",
		travelled <= 31.0, "travelled %.1f in 30 frames" % travelled)

	# --- walls ---
	# Column 6 is clear all the way to the top wall. Column 2 is NOT: the
	# teacher's desk sits at tiles (2,2)-(3,2), and an earlier version of
	# this test walked up that column, correctly stopped against the desk,
	# and read as a wall-collision bug. Assert the column first so furniture
	# moving into it fails loudly instead of weakening the assertion.
	chk("the test column is clear up to the top wall",
		world.grid.is_free(Vector2i(6, 2)) and world.grid.is_free(Vector2i(6, 3)))
	p.global_position = Grid.tile_to_world(Vector2i(6, 3))
	await step(1)
	await hold("move_up", 60)
	chk("the top wall stops the player and they stay inside the room",
		p.global_position.y > 32.0 and p.global_position.y < 48.0,
		"y=%.1f" % p.global_position.y)

	# Row 9 runs clear to the left wall, below the door and under the desks.
	p.global_position = Grid.tile_to_world(Vector2i(6, 9))
	await step(1)
	await hold("move_left", 90)
	chk("the left wall stops the player with no tunnelling",
		p.global_position.x > 16.0 and p.global_position.x < 28.0,
		"x=%.1f" % p.global_position.x)

	# The doorway is a genuine hole, so you can stand in it.
	p.global_position = Grid.tile_to_world(Vector2i(1, 8))
	await step(1)
	await hold("move_left", 30)
	chk("you can walk into the doorway itself",
		p.global_position.x < 16.0, "x=%.1f" % p.global_position.x)


func test_arrival() -> void:
	section("ARRIVAL")
	# The class walks in from the doorway. Budget generously — the far seats
	# are a long way from the door at 1px per frame — but FAIL on timeout
	# rather than waiting forever.
	var frames := 0
	while frames < 2000 and not world.everyone_seated():
		await step(20)
		frames += 20
	chk("every student walks in and takes a seat",
		world.everyone_seated(), "gave up after %d frames" % frames)

	var on_seat := true
	var report: Array = []
	for s: StudentData in Game.roster:
		var node: Actor = world.student_node(s.seat_index)
		var want := Grid.tile_to_world(Layout.SEATS[s.seat_index])
		if node == null or not node.global_position.is_equal_approx(want):
			on_seat = false
			report.append("seat %d" % s.seat_index)
	chk("each one ends up exactly on their own seat tile", on_seat, report)
	chk("nobody is left walking", (func() -> bool:
		for n: Actor in world.students:
			if n.is_walking():
				return false
		return true).call())


func test_work_loop() -> void:
	section("WORK LOOP")
	var p: Actor = world.player
	p.drop_all_work()

	# --- assigning ---
	var assigned: int = world.assign_work_to_class()
	chk("assigning work reaches every seated student",
		assigned == Game.roster.size(), assigned)
	var all_working := true
	for s: StudentData in Game.roster:
		if s.work_state != StudentData.Work.WORKING:
			all_working = false
	chk("they are all now working", all_working)
	chk("assigning again is refused while they're still working",
		world.assign_work_to_class() == 0)

	# --- the five seconds ---
	# The tick is on the fixed physics step, so this is exact: 5s = 300
	# frames. One frame short must NOT be finished.
	await step(299)
	var any_done := false
	for s: StudentData in Game.roster:
		if s.has_work_to_collect():
			any_done = true
	chk("nobody is finished one frame before the five seconds are up", not any_done)

	await step(3)
	var all_done := true
	for s: StudentData in Game.roster:
		if not s.has_work_to_collect():
			all_done = false
	chk("after five seconds every sheet is finished", all_done)

	var st0: Interactable = world.station(0)
	chk("a finished sheet appears on the desk", st0.paper.visible)
	chk("a desk with finished work offers to be collected", st0.can_interact())
	chk("its prompt names the student",
		st0.prompt_text().begins_with("Collect"), st0.prompt_text())

	# --- collecting ---
	# Stand below seat 0's desk, facing it.
	await place_player(Layout.desk_tile(0) + Vector2i(0, 1), Actor.DIR_UP)
	chk("standing at a desk selects THAT desk", p.target == st0, p.target)
	await tap("interact")
	chk("collecting picks the sheet up", p.carrying == 1, p.carrying)
	chk("the sheet is gone from the desk", not st0.paper.visible)
	chk("that student's work is marked collected",
		Game.student_in_seat(0).work_state == StudentData.Work.COLLECTED)
	chk("an already-collected desk stops offering", not st0.can_interact())

	# collect the rest of the class
	for i in range(1, Game.roster.size()):
		await place_player(Layout.desk_tile(i) + Vector2i(0, 1), Actor.DIR_UP)
		await tap("interact")
	chk("the whole class's work can be collected",
		p.carrying == Game.roster.size(), p.carrying)

	# --- handing in ---
	chk("your own desk offers to take them", world.teacher_desk.can_interact())
	chk("its prompt counts what you're carrying",
		world.teacher_desk.prompt_text().contains(str(p.carrying)),
		world.teacher_desk.prompt_text())
	await place_player(Vector2i(3, 3), Actor.DIR_UP)
	chk("standing at your own desk selects it", p.target == world.teacher_desk, p.target)
	var carried: int = p.carrying
	await tap("interact")
	chk("handing in empties your arms", p.carrying == 0, p.carrying)
	chk("the desk counted what was handed in",
		world.teacher_desk.handed_in == carried, world.teacher_desk.handed_in)
	chk("an empty-handed teacher gets no hand-in prompt",
		not world.teacher_desk.can_interact())

	# --- the picker ---
	# Between two desks, facing one of them, it must choose the one faced.
	var s1: Interactable = world.station(1)
	Game.student_in_seat(1).work_state = StudentData.Work.DONE
	Game.student_in_seat(0).work_state = StudentData.Work.DONE
	await place_player(Layout.desk_tile(0) + Vector2i(0, 1), Actor.DIR_UP)
	chk("facing a desk picks it, not a nearby one", p.target == st0, p.target)
	chk("a desk with nothing to give is never picked", (func() -> bool:
		Game.student_in_seat(0).work_state = StudentData.Work.COLLECTED
		return not st0.can_interact()).call())
	# tidy up for whatever runs next
	Game.student_in_seat(1).work_state = StudentData.Work.COLLECTED
	s1.show_paper(false)
	st0.show_paper(false)


func test_seating() -> void:
	section("SEATING & DEPTH")
	var seated_ok := true
	var report: Array = []
	for s: StudentData in Game.roster:
		var node: Actor = world.student_node(s.seat_index)
		if node == null:
			seated_ok = false
			report.append("seat %d has no node" % s.seat_index)
			continue
		var want := Grid.tile_to_world(Layout.SEATS[s.seat_index])
		if not node.global_position.is_equal_approx(want):
			seated_ok = false
			report.append("seat %d at %s want %s" % [s.seat_index, node.global_position, want])
		if not node.seated:
			seated_ok = false
			report.append("seat %d not seated" % s.seat_index)
	chk("every student is seated exactly on their seat tile", seated_ok, report)

	var st: Actor = world.student_node(0)
	chk("a seated student uses the seated sprite frame",
		st.sprite.frame_coords.x == Actor.SIT_FRAME, st.sprite.frame_coords)
	chk("the sprite sheet actually has a seated column",
		st.sprite.hframes == 5, st.sprite.hframes)

	# A seated body would let the teacher wedge into a 16px aisle.
	var has_live_collision := false
	for c in st.get_children():
		if c is CollisionShape2D and not (c as CollisionShape2D).disabled:
			has_live_collision = true
	chk("a seated student has no live collision box", not has_live_collision)

	# Depth order is the whole reason for the floor-anchor convention:
	# chair behind, student, desk in front occluding their lap.
	var seat_y: float = Grid.tile_to_world(Layout.SEATS[0]).y
	var desk_y: float = Grid.tile_to_world(Layout.desk_tile(0)).y
	var chair := _body_near(Vector2(Grid.tile_to_world(Layout.SEATS[0]).x, seat_y - 1.0))
	var desk := _body_near(Vector2(Grid.tile_to_world(Layout.desk_tile(0)).x, desk_y))
	chk("a chair sits 1px behind its seat so the y-sort tie is broken",
		chair != null, "no StaticBody2D at seat anchor -1px")
	chk("a desk body exists in front of the seat", desk != null)
	chk("draw order is chair, then student, then desk",
		chair != null and desk != null
		and chair.global_position.y < st.global_position.y
		and st.global_position.y < desk.global_position.y,
		"chair %.1f student %.1f desk %.1f" % [
			chair.global_position.y if chair else -1.0,
			st.global_position.y,
			desk.global_position.y if desk else -1.0])


func _body_near(p: Vector2) -> StaticBody2D:
	for c in world.get_children():
		if c is StaticBody2D and (c as StaticBody2D).global_position.distance_to(p) < 0.6:
			return c
	return null
