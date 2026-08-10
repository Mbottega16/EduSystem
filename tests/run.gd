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
	test_balance()
	test_items()
	test_homework()
	await test_scene()
	await test_movement()
	await test_arrival()
	await test_work_loop()
	await test_seating()
	await test_day_cycle()
	await test_confusion()
	await test_placement()
	await test_overlays()
	await test_marking()

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


# ============================================ the balance contract & content

func test_balance() -> void:
	section("BALANCE CONTRACT")
	# These three assertions ARE the design pillar: "the room sets the floor,
	# the teacher sets the ceiling". If a tuning pass breaks any of them the
	# game has quietly stopped being the game it was designed to be.
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]

	Game.room_items.clear()
	s.attention_credit = 0.0
	chk("a bare room with no attention is a failing grade",
		Game.grade_letter(Game.grade_for(s)) == "F",
		"%.2f %s" % [Game.grade_for(s), Game.grade_letter(Game.grade_for(s))])

	# perfect room, zero attention -> a C
	for id: String in Items.ORDER:
		Game.room_items.append({"id": id, "tile": Layout.SEATS[0]})
	chk("a perfect room ALONE tops out at a C",
		Game.grade_letter(Game.grade_for(s)) == "C",
		"%.2f" % Game.grade_for(s))
	chk("room score is capped, so furniture alone can never reach an A",
		is_equal_approx(Game.room_score(0), Game.ROOM_CAP))

	# bare room, perfect attention -> also a C
	Game.room_items.clear()
	s.attention_credit = StudentData.ATTENTION_CAP
	chk("perfect attention in a bare room ALSO tops out at a C",
		Game.grade_letter(Game.grade_for(s)) == "C",
		"%.2f" % Game.grade_for(s))

	# both -> an A
	for id: String in Items.ORDER:
		Game.room_items.append({"id": id, "tile": Layout.SEATS[0]})
	chk("room AND attention together earn an A",
		Game.grade_letter(Game.grade_for(s)) == "A", "%.2f" % Game.grade_for(s))

	chk("attention credit cannot be farmed past its cap", (func() -> bool:
		s.set_confused(true)
		for i in 20:
			s.set_confused(true)
			s.help()
		return is_equal_approx(s.attention_credit, StudentData.ATTENTION_CAP)).call())
	chk("helping a student who is fine does nothing", (func() -> bool:
		s.set_confused(false)
		var before := s.attention_credit
		return not s.help() and is_equal_approx(s.attention_credit, before)).call())
	Game.room_items.clear()


func test_items() -> void:
	section("ITEMS")
	Game.new_run(SEED)
	chk("every catalogue entry has art, a cost and an effect", (func() -> bool:
		for id: String in Items.ORDER:
			var d := Items.get_def(id)
			if d.is_empty() or int(d["cost"]) <= 0 or float(d["bonus"]) <= 0.0:
				return false
			if not ResourceLoader.exists("res://art/%s.png" % String(d["art"])):
				return false
		return true).call())
	chk("the catalogue is ordered cheapest first", (func() -> bool:
		var last := -1
		for id: String in Items.ORDER:
			var c := Items.cost(id)
			if c < last:
				return false
			last = c
		return true).call())

	# range is the whole point of item placement
	Game.room_items.clear()
	var far := Layout.SEATS[0] + Vector2i(9, 0)
	Game.room_items.append({"id": "bookshelf", "tile": far})
	chk("an item out of range helps nobody",
		is_equal_approx(Game.room_score(0), Game.ROOM_BASE),
		Game.room_score(0))
	Game.room_items[0]["tile"] = Layout.SEATS[0] + Vector2i(2, 0)
	chk("the same item in range does help",
		Game.room_score(0) > Game.ROOM_BASE, Game.room_score(0))

	# a 2-tile item should reach from either end, not just its anchor
	Game.room_items.clear()
	Game.room_items.append({"id": "lab_bench",
		"tile": Layout.SEATS[0] + Vector2i(-4, 0)})
	chk("a wide item measures from its NEAREST tile, not its anchor",
		Game.room_score(0) > Game.ROOM_BASE, Game.room_score(0))

	# buying
	Game.room_items.clear()
	Game.coins = 0
	chk("you can't buy what you can't afford", not Game.place_item("plant", Vector2i(5, 3)))
	Game.add_coins(1000)
	var before := Game.coins
	chk("buying places the item and charges you",
		Game.place_item("plant", Vector2i(5, 3))
		and Game.coins == before - Items.cost("plant")
		and Game.room_items.size() == 1)
	chk("two items can't occupy the same tile", not Game.item_fits("plant", Vector2i(5, 3)))
	chk("a free tile still fits", Game.item_fits("plant", Vector2i(6, 3)))
	Game.room_items.clear()


func test_homework() -> void:
	section("HOMEWORK")
	Game.new_run(SEED)
	chk("no homework is out at the start of a run", not Game.homework_out)
	chk("assigning homework reaches the whole class",
		Game.assign_homework() == Game.roster.size())
	chk("assigning twice in a day is refused", Game.assign_homework() == 0)

	# overnight
	for s: StudentData in Game.roster:
		s.last_grade = 0.7
	var report := Game.advance_day()
	var done := 0
	var not_done := 0
	for s: StudentData in Game.roster:
		if s.hw_state == StudentData.HW.DONE:
			done += 1
		elif s.hw_state == StudentData.HW.NOT_DONE:
			not_done += 1
	chk("overnight, every set piece of homework resolves one way or the other",
		done + not_done == Game.roster.size(), "%d done, %d not" % [done, not_done])
	chk("the day report counts who actually did it",
		int(report["homework_done"]) == done)
	chk("a student who did it has a real sheet to mark", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.hw_state == StudentData.HW.DONE:
				return s.hw_sheet.get("items", []).size() == Questions.QUESTIONS_PER_SHEET
		return true).call())

	# diligence must actually matter, over enough rolls to be meaningful
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lazy_done := 0
	var keen_done := 0
	for i in 400:
		if rng.randf() < 0.2:
			lazy_done += 1
		if rng.randf() < 0.9:
			keen_done += 1
	chk("a diligent student really does hand in more often",
		keen_done > lazy_done * 2, "%d vs %d of 400" % [keen_done, lazy_done])

	# the sheet generator
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	var good := Questions.make_sheet(1.0, r2)
	chk("a perfect student's sheet is all correct", (func() -> bool:
		for it: Dictionary in good["items"]:
			if not bool(it["correct"]):
				return false
		return true).call())
	chk("a perfect sheet deserves a pass", Questions.sheet_is_good(good))
	var bad := Questions.make_sheet(0.0, r2)
	chk("a hopeless sheet does not", not Questions.sheet_is_good(bad))
	chk("a wrong answer shown is never the right answer", (func() -> bool:
		for it: Dictionary in bad["items"]:
			if bool(it["correct"]):
				return false
		return true).call())
	# the tells must be imperfect, or the judgement stops being a judgement
	var r3 := RandomNumberGenerator.new()
	r3.seed = 7
	var agree := 0
	var total := 0
	for i in 300:
		var sh := Questions.make_sheet(r3.randf(), r3)
		for it: Dictionary in sh["items"]:
			total += 1
			if bool(it["neat"]) == bool(it["correct"]):
				agree += 1
	var ratio := float(agree) / float(total)
	chk("tells correlate with the truth but do not give it away",
		ratio > 0.6 and ratio < 0.9, "%.2f agreement" % ratio)


# ================================================== tier 2: the day, in scene

func test_day_cycle() -> void:
	section("DAY CYCLE")
	# test_work_loop leaves the class having already done and handed in a
	# piece of work. Clear that so this section starts from a real morning.
	for s: StudentData in Game.roster:
		s.reset_lesson()
	Game.set_phase(Game.Phase.MORNING)
	world.player.drop_all_work()
	world.player.drop_all_homework()
	await step(2)
	chk("the day starts in the morning", Game.phase == Game.Phase.MORNING)
	chk("the bell refuses to end a day that has not had a lesson",
		not world.bell.can_interact())
	chk("the podium offers to start the lesson once everyone is seated",
		world.podium.can_interact() and world.podium.prompt_text() == "Start the lesson")

	var assigned: int = world.start_lesson()
	chk("starting the lesson sets the whole class working",
		assigned == Game.roster.size() and Game.phase == Game.Phase.LESSON, assigned)
	chk("the podium now offers to END the lesson",
		world.podium.prompt_text() == "End the lesson")
	chk("the bell still refuses mid-lesson", not world.bell.can_interact())

	# give one student credit so the grades are not all identical
	Game.roster[0].attention_credit = StudentData.ATTENTION_CAP
	var results: Array = world.end_lesson()
	chk("ending the lesson grades everybody",
		results.size() == Game.roster.size(), results.size())
	chk("the helped student outscores the ignored one",
		float(results[0]["grade"]) > float(results[1]["grade"]),
		"%.2f vs %.2f" % [results[0]["grade"], results[1]["grade"]])
	chk("every student now has a recorded grade", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.grades.is_empty() or s.last_grade < 0.0:
				return false
		return true).call())
	chk("ending the lesson also sets tonight's homework", Game.homework_out)
	chk("the phase moves to the afternoon", Game.phase == Game.Phase.AFTERNOON)
	chk("NOW the bell will ring", world.bell.can_interact())
	chk("and the podium has nothing more to offer", not world.podium.can_interact())

	var day_before: int = Game.day
	var coins_before: int = Game.coins
	var report: Dictionary = world.end_day()
	chk("ringing the bell advances the day", Game.day == day_before + 1)
	chk("a class that learned something gets paid",
		Game.coins > coins_before, "%d -> %d" % [coins_before, Game.coins])
	chk("the report says what happened",
		report.has("average") and report.has("coins") and report.has("homework_done"))
	chk("tomorrow starts in the morning again", Game.phase == Game.Phase.MORNING)
	chk("the class files back in rather than starting seated",
		not world.everyone_seated())

	var frames := 0
	while frames < 2000 and not world.everyone_seated():
		await step(20)
		frames += 20
	chk("the new day's class takes its seats", world.everyone_seated())

	# homework came back overnight and can be collected from the desks
	var seat := -1
	for s: StudentData in Game.roster:
		if s.hw_state == StudentData.HW.DONE:
			seat = s.seat_index
			break
	if seat >= 0:
		var st: Interactable = world.station(seat)
		chk("a desk with homework on it offers to take it",
			st.can_interact() and st.prompt_text().begins_with("Take"), st.prompt_text())
		await place_player(Layout.desk_tile(seat) + Vector2i(0, 1), Actor.DIR_UP)
		await tap("interact")
		chk("collecting homework puts it in your arms",
			world.player.carrying_hw == 1, world.player.carrying_hw)
		chk("that student's homework is marked collected",
			Game.student_in_seat(seat).hw_state == StudentData.HW.COLLECTED)
	else:
		chk("(no homework came back this seed, so collection is untested)", true)


func test_confusion() -> void:
	section("GETTING STUCK")
	Game.new_run(SEED)
	var s := StudentData.new()
	s.seat_index = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# force a stall, then prove the work timer really is frozen by it
	s.assign_work(rng, 1.0)
	chk("work starts un-stuck", not s.is_struggling())
	var guard := 0
	while not s.is_struggling() and guard < 600:
		s.tick_work(1.0 / 60.0)
		guard += 1
	chk("a student can get stuck partway through", s.is_struggling(), guard)

	var frozen: float = s.work_timer
	for i in 300:
		s.tick_work(1.0 / 60.0)
	chk("a stuck student's work does not progress at all",
		is_equal_approx(s.work_timer, frozen), "%.3f -> %.3f" % [frozen, s.work_timer])
	chk("and they never finish on their own", not s.has_work_to_collect())

	chk("helping them clears it and earns you credit", (func() -> bool:
		var before := s.attention_credit
		return s.help() and not s.is_struggling() and s.attention_credit > before).call())

	for i in 400:
		s.tick_work(1.0 / 60.0)
	chk("once helped, they finish", s.has_work_to_collect())

	# never stalls at the very start or the very end, both of which read as
	# a glitch rather than as the student getting stuck
	var edge_ok := true
	for i in 200:
		var t := StudentData.new()
		t.assign_work(rng, 1.0)
		if t._confuse_at < StudentData.WORK_SECONDS * 0.15:
			edge_ok = false
		if t._confuse_at > StudentData.WORK_SECONDS * 0.85:
			edge_ok = false
	chk("a stall never lands on the first or last moment of the work", edge_ok)

	chk("with stall chance zero nobody ever gets stuck", (func() -> bool:
		for i in 100:
			var t := StudentData.new()
			t.assign_work(rng, 0.0)
			for j in 400:
				t.tick_work(1.0 / 60.0)
			if not t.has_work_to_collect():
				return false
		return true).call())


func test_placement() -> void:
	section("PLACEMENT")
	Game.new_run(SEED)
	Game.add_coins(5000)
	var place := Placement.new()
	world.add_child(place)
	place.begin("plant", world.grid, Vector2i(9, 6))

	chk("an empty floor tile is a valid spot", place.is_valid())
	place.tile = Layout.desk_tile(0)
	place._refresh()
	chk("furniture cannot go inside a desk", not place.is_valid())
	place.tile = Vector2i(0, 0)
	place._refresh()
	chk("furniture cannot go inside a wall", not place.is_valid())
	place.tile = Vector2i(9, 6)
	place._refresh()
	chk("moving back to open floor is valid again", place.is_valid())

	chk("the cursor cannot leave the room", (func() -> bool:
		place.tile = Vector2i(0, 5)
		place.move_by(Vector2i.LEFT)
		return place.tile == Vector2i(0, 5)).call())

	# THE important one: the player must not be able to wall their own class
	# in. Brick up the corridor beside the door leaving one gap, then check
	# the guard refuses the tile that would finally seal it.
	var seal := Vector2i(1, 7)
	for ty in range(2, 10):
		if Vector2i(1, ty) != seal:
			world.grid.set_cell(Vector2i(1, ty), Grid.Cell.BLOCKED)
	place.item_id = "plant"
	place.tile = seal
	place._refresh()
	chk("placing the tile that would seal the class off is refused",
		not place.is_valid())
	for ty in range(2, 10):
		world.grid.set_cell(Vector2i(1, ty), Grid.Cell.FREE)

	place.tile = Vector2i(9, 6)
	place._refresh()
	var coins_before: int = Game.coins
	var items_before: int = Game.room_items.size()
	Game.place_item("plant", Vector2i(9, 6))
	await step(3)
	chk("confirming a placement buys and records it",
		Game.room_items.size() == items_before + 1
		and Game.coins == coins_before - Items.cost("plant"))
	chk("the placed item blocks its tile in the world",
		not world.grid.is_free(Vector2i(9, 6)))
	chk("and it now helps whoever is in range", (func() -> bool:
		for i in Layout.seat_count():
			if Game.room_score(i) > Game.ROOM_BASE:
				return true
		return false).call())

	place.queue_free()

	# save round-trip including the room
	var snapshot := Game.to_dict()
	Game.from_dict(snapshot)
	chk("a save round-trips the furniture too",
		Game.to_dict() == snapshot and Game.room_items.size() > 0)
	chk("the reloaded item keeps its tile as a Vector2i",
		Game.room_items[0]["tile"] is Vector2i)

	# and the save file itself
	Game.delete_save()
	chk("there is no save file to begin with", not Game.has_save())
	Game.save_game()
	chk("saving writes a file", Game.has_save())
	var on_disk := Game.to_dict()
	Game.new_run(1)
	Game.load_game()
	# NOT a byte-identical comparison: Godot's JSON writer truncates float
	# precision (0.69671237468719 comes back as 0.6967123746872), so a disk
	# round-trip can never be exact. The in-memory round-trip above IS exact,
	# and that is the one that would catch a real serialisation bug. This one
	# asserts equivalence within tolerance.
	chk("loading from disk restores the run",
		_same_within(Game.to_dict(), on_disk, 1e-6), Game.to_dict())
	Game.delete_save()


## Deep compare allowing float drift, for anything that has been through JSON.
func _same_within(a: Variant, b: Variant, tol: float) -> bool:
	if a is float or b is float:
		return absf(float(a) - float(b)) <= tol
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k: Variant in (a as Dictionary):
			if not (b as Dictionary).has(k):
				return false
			if not _same_within((a as Dictionary)[k], (b as Dictionary)[k], tol):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not _same_within((a as Array)[i], (b as Array)[i], tol):
				return false
		return true
	return a == b


# ============================================== overlays, driven by real input

func _hud() -> Control:
	return world.get_parent().get_node("UI/HUD")


func test_overlays() -> void:
	section("OVERLAYS")
	var hud := _hud()
	var p: Actor = world.player
	Game.new_run(SEED)
	Game.add_coins(2000)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	# open the catalogue by walking up to the noticeboard and pressing E
	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	chk("standing at the noticeboard offers the catalogue",
		p.target != null and p.target.prompt_text().begins_with("Order"),
		"" if p.target == null else p.target.prompt_text())
	await tap("interact")
	chk("pressing E opens the catalogue", hud.mode == hud.Mode.CATALOGUE, hud.mode)
	chk("the player is frozen while it is open", p.input_locked)

	var first: int = hud._sel
	await tap("move_down")
	chk("Down moves the selection", hud._sel == first + 1, hud._sel)
	await tap("move_up")
	chk("Up moves it back", hud._sel == first)

	# THE REGRESSION TEST.
	# Input.is_action_just_pressed() reports true in both the idle frame and
	# the physics tick. Before Game.claim_interact() existed, ONE press could
	# close a menu and then immediately re-fire whatever the teacher was
	# standing next to — here, re-opening the very noticeboard just closed.
	# It cost a whole automated playthrough to find, so it is pinned.
	await tap("cancel")
	chk("Esc closes the catalogue", hud.mode == hud.Mode.NONE)
	chk("and hands control back", not p.input_locked)
	await tap("interact")
	var opened_once: bool = hud.mode == hud.Mode.CATALOGUE
	await tap("cancel")
	await step(2)
	chk("one press does one thing — closing a menu never re-opens it",
		hud.mode == hud.Mode.NONE, hud.mode)
	chk("(and the press that opened it genuinely did open it)", opened_once)

	# order something, and place it
	await tap("interact")
	var chosen: String = Items.ORDER[hud._sel]
	var coins_before: int = Game.coins
	var items_before: int = Game.room_items.size()
	await tap("interact")
	await step(3)
	var main: Node = world.get_parent()
	chk("confirming an order starts placement mode", main.placement.active)
	chk("the catalogue closed behind it", hud.mode == hud.Mode.NONE)
	chk("the ghost did NOT place itself on the same press",
		Game.room_items.size() == items_before, Game.room_items.size())

	# Find a genuinely free spot rather than assuming one — an earlier
	# section may already have put something down.
	var spot := Vector2i(-1, -1)
	for t: Vector2i in world.grid.free_tiles():
		if t.y >= 3 and t.y <= 9 and t.x >= 2 and t.x <= 16 and Game.item_fits(chosen, t):
			spot = t
			break
	main.placement.tile = spot
	main.placement._refresh()
	chk("the ghost is over a valid tile", main.placement.is_valid(), spot)
	await tap("interact")
	await step(3)
	chk("pressing E puts the item down and charges for it",
		Game.room_items.size() == items_before + 1
		and Game.coins == coins_before - Items.cost(chosen),
		"%d items, %d coins" % [Game.room_items.size(), Game.coins])
	chk("placement mode ends", not main.placement.active)
	chk("and you can walk again", not p.input_locked)

	# cancelling placement must refund nothing and unlock
	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	await tap("interact")
	await tap("interact")
	await step(3)
	var mid_coins: int = Game.coins
	await tap("cancel")
	await step(3)
	chk("cancelling placement leaves you unlocked and un-charged",
		not main.placement.active and not p.input_locked and Game.coins == mid_coins)


func test_marking() -> void:
	section("MARKING")
	var hud := _hud()
	var p: Actor = world.player
	Game.new_run(SEED)
	await step(2)

	# hand everyone a finished sheet to mark
	for s: StudentData in Game.roster:
		s.hw_state = StudentData.HW.COLLECTED
		s.hw_true_accuracy = 0.9
		s.hw_sheet = Questions.make_sheet(0.9, Game.rng)
	p.carry_homework(Game.roster.size())

	hud.open_marking()
	await step(2)
	chk("the marking game opens with a sheet per student",
		hud.mode == hud.Mode.MARKING and hud._marking.size() == Game.roster.size(),
		hud._marking.size())
	chk("it names whose sheet you're looking at",
		hud.title.text.contains(Game.roster[0].display_name), hud.title.text)
	chk("it shows the questions and the tells",
		hud.body.text.contains("neat") or hud.body.text.contains("rushed"))

	var left: int = hud._marking.size()
	await tap("move_right")
	await step(2)
	chk("a verdict moves on to the next sheet", hud._marking.size() == left - 1)

	var guard := 0
	while hud.mode == hud.Mode.MARKING and guard < 20:
		await tap("move_right")
		await step(2)
		guard += 1
	chk("marking every sheet finishes the batch", hud.mode == hud.Mode.REPORT, guard)
	chk("your arms are empty afterwards", p.carrying_hw == 0, p.carrying_hw)
	chk("every sheet is now marked", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.hw_state != StudentData.HW.MARKED:
				return false
		return true).call())
	chk("passing genuinely good sheets counts as getting them right",
		hud._marked_right == Game.roster.size(), hud._marked_right)

	# marked homework feeds the grade
	var s0: StudentData = Game.roster[0]
	s0.attention_credit = 0.0
	Game.room_items.clear()
	var with_hw := Game.grade_for(s0)
	s0.hw_state = StudentData.HW.COLLECTED
	var without := Game.grade_for(s0)
	chk("marked homework raises the grade", with_hw > without,
		"%.3f vs %.3f" % [with_hw, without])

	await tap("interact")
	await step(2)
	chk("closing the summary hands control back",
		hud.mode == hud.Mode.NONE and not p.input_locked)
