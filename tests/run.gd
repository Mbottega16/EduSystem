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
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		push_error("watchdog: suite exceeded 420s")
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


## Hold a button long enough to satisfy a hold-to-confirm interactable.
## The podium and the bell deliberately cannot be triggered by a tap.
func hold_confirm(action: String = "manage", seconds: float = 0.8) -> void:
	Input.action_press(action)
	await step(int(seconds * 60.0) + 4)
	Input.action_release(action)
	await step(2)


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
	test_events()
	test_economy()
	test_term()
	test_settings()
	await test_title()
	await test_sprint()
	await test_buttons()
	test_curriculum()
	test_names()
	test_lifetime_counters()
	await test_bio()
	test_student_levels()
	test_teacher_levels()
	test_graduation()
	test_coaching()
	await test_shop_and_staff()
	await test_bio_actions()
	test_catalogue()
	test_curator()
	test_cheats()
	await test_moving_desks()
	await test_quiz()
	test_concepts()
	test_transcript()
	test_unlockables()
	await test_unit_test()
	await test_two_buttons_one_landmark()
	await test_growing_the_room()
	await test_panels_fit()
	await test_systems_together()
	await test_a_whole_day()
	await test_overlays()
	await test_marking()
	await test_shop()
	await test_progress_bar()

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
		Game.roster.size() == Balance.class_start, Game.roster.size())
	chk("day starts at 1 with the starting purse",
		Game.day == 1 and Game.coins == Balance.start_coins, Game.coins)

	var seats: Array = []
	for s: StudentData in Game.roster:
		seats.append(s.seat_index)
	seats.sort()
	chk("starting students take the lowest seats, no duplicates",
		seats == [0, 1, 2, 3], seats)

	# growth into the fixed eight-desk room
	while Game.roster.size() < Balance.class_cap:
		Game.enrol()
	chk("the roster grows to the class cap", Game.roster.size() == Balance.class_cap)
	chk("enrolling past the cap is refused", Game.enrol() == null)
	var all_seats := {}
	for s: StudentData in Game.roster:
		all_seats[s.seat_index] = true
	chk("every student has a distinct seat", all_seats.size() == Balance.class_cap)

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
		not s0.is_struggling() and s0.work_state == StudentData.Work.NONE)


func test_layout() -> void:
	section("LAYOUT")
	chk("there are eight desks for the class cap",
		Layout.seat_count() == Balance.class_cap, Layout.seat_count())

	var uniq := {}
	for s: Vector2i in Layout.seats():
		uniq[s] = true
	chk("no two seats share a tile", uniq.size() == Layout.seat_count())

	# every desk must sit one tile TOWARD the camera from its seat, or the
	# desk won't depth-sort in front of the student and the whole "sitting
	# at a desk" read collapses
	var ok := true
	for i in Layout.seat_count():
		if Layout.desk_tile(i) != Layout.seat(i) + Vector2i(0, 1):
			ok = false
	chk("every desk is one tile in front of its seat", ok)

	# nothing may be placed inside a wall
	var inside := true
	for i in Layout.seat_count():
		for t: Vector2i in [Layout.seat(i), Layout.desk_tile(i)]:
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
		if world.grid.get_cell(Layout.seat(i)) != Grid.Cell.SEAT:
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
		if not world.grid.reachable(start, Layout.seat(i)):
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
		var want := Grid.tile_to_world(Layout.seat(s.seat_index))
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

	# --- working through it ---
	# Work takes Balance.work_seconds of UNSTUCK time, and they now stall
	# repeatedly, so getting the class finished means actually unsticking
	# them — which is the point.
	var short_of_it := int(Balance.work_seconds * 60.0) - 5
	for i in short_of_it:
		for s: StudentData in Game.roster:
			s.tick_work(1.0 / 60.0, null)
	var early := false
	for s: StudentData in Game.roster:
		if s.has_work_to_collect():
			early = true
	chk("nobody can finish sooner than the work actually takes", not early)

	for i in 600:
		for s: StudentData in Game.roster:
			if s.is_struggling():
				s.help()
			s.tick_work(1.0 / 60.0, Game.rng)
	await step(2)
	var all_done := true
	for s: StudentData in Game.roster:
		if not s.has_work_to_collect():
			all_done = false
	chk("helping them through gets the whole class finished", all_done)

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
		var want := Grid.tile_to_world(Layout.seat(s.seat_index))
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
	var seat_y: float = Grid.tile_to_world(Layout.seat(0)).y
	var desk_y: float = Grid.tile_to_world(Layout.desk_tile(0)).y
	var chair := _body_near(Vector2(Grid.tile_to_world(Layout.seat(0)).x, seat_y - 1.0))
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
	# These three rows ARE the design pillar. They are now measured by
	# actually SIMULATING a lesson — ticking the real work model at the real
	# physics rate — rather than by assigning the inputs by hand.
	#
	# The previous version set `attention_credit` directly and asserted on
	# that. It passed for weeks while the game could never produce more than
	# a third of the value it was asserting, because no gameplay path could
	# reach the state under test. A contract you can only satisfy by cheating
	# is worse than no contract: it manufactures confidence.
	Balance.ensure_loaded()

	var bare_taught := _simulate_lesson(false, true)
	var rich_ignored := _simulate_lesson(true, false)
	var rich_taught := _simulate_lesson(true, true)

	chk("a bare room with a perfect teacher earns a C",
		Game.grade_letter(bare_taught) == "C", "%.2f" % bare_taught)
	chk("a perfect room with an absent teacher ALSO earns a C",
		Game.grade_letter(rich_ignored) == "C", "%.2f" % rich_ignored)
	chk("room AND teaching together earn an A",
		Game.grade_letter(rich_taught) == "A", "%.2f" % rich_taught)
	chk("neither input alone gets near the top",
		bare_taught < 0.75 and rich_ignored < 0.75)

	var bare_ignored := _simulate_lesson(false, false)
	chk("doing neither is well below a pass",
		bare_ignored < 0.50, "%.2f  %s" % [bare_ignored, Game.grade_letter(bare_ignored)])

	# helping is the ONLY way a stuck student progresses
	Game.new_run(SEED)
	var st: StudentData = Game.roster[0]
	st.assign_work()
	st.confusion = 1.0
	var frozen: float = st.work_timer
	for i in 600:
		st.tick_work(1.0 / 60.0, Game.rng)
	chk("an unreached student never progresses at all",
		is_equal_approx(st.work_timer, frozen))
	chk("helping a student who is fine does nothing", (func() -> bool:
		st.confusion = 0.0
		return not st.help()).call())
	# The old model rolled ONE stall moment per lesson and cleared it when it
	# fired, so the teacher could only ever matter once. Averaged over runs
	# so this doesn't hinge on a single unlucky seed.
	var total_stalls := 0
	for i in 20:
		total_stalls += _count_stalls(0.3)
	chk("a student gets stuck several times across a lesson",
		total_stalls >= 30, "%d stalls over 20 lessons" % total_stalls)


## Run real lessons through the actual work model and return the MEAN grade.
## `furnish` caps the room; `teach` unsticks them the moment they stall.
##
## Averaged over many students on purpose. A single lesson is dominated by
## one student's stall luck — an early version of this asserted on one
## student and swung between a C and a B depending only on the seed, which
## would have made the contract flaky rather than meaningful.
func _simulate_lesson(furnish: bool, teach: bool) -> float:
	var total := 0.0
	var runs := 0
	for seed_offset in 6:
		Game.new_run(SEED + seed_offset)
		if furnish:
			var guard := 0
			while Game.room_score(0) < Balance.room_cap - 0.001 and guard < 60:
				Game.room_items.append({
					"id": Items.order()[guard % Items.order().size()],
					"tile": Layout.seat(0) + Vector2i(0, 1)})
				guard += 1
		for s: StudentData in Game.roster:
			s.seat_index = 0 if furnish else s.seat_index
			s.assign_work()
		var t := 0.0
		while t < Balance.lesson_seconds:
			t += 1.0 / 60.0
			for s: StudentData in Game.roster:
				s.tick_work(1.0 / 60.0, Game.rng)
				if teach and s.is_struggling():
					s.help()
		for s: StudentData in Game.roster:
			if teach:
				s.collect_work()
			total += Game.grade_for(s)
			runs += 1
	return total / float(runs)


func test_items() -> void:
	section("ITEMS")
	Game.new_run(SEED)
	chk("every catalogue entry has art, a cost and an effect", (func() -> bool:
		for id: String in Items.order():
			var d := Items.get_def(id)
			if d.is_empty() or int(d["cost"]) <= 0 or float(d["bonus"]) <= 0.0:
				return false
			if not ResourceLoader.exists("res://art/%s.png" % String(d["art"])):
				return false
		return true).call())
	# Cheapest first WITHIN each category, which is the list you actually
	# scan -- the shop shows one tab at a time now, so a global ordering
	# would only mean the categories had to be priced in bands.
	chk("each category is ordered cheapest first", (func() -> bool:
		var last := -1
		var cat := ""
		for id: String in Items.order():
			var c := Items.cost(id)
			var this_cat := Items.category_of(id)
			if this_cat != cat:
				cat = this_cat
				last = -1
			if c < last:
				return false
			last = c
		return true).call())
	chk("and the list is grouped, so a category is never split up",
		(func() -> bool:
			var seen: Array[String] = []
			var cat := ""
			for id: String in Items.order():
				var this_cat := Items.category_of(id)
				if this_cat == cat:
					continue
				if seen.has(this_cat):
					return false       # we already left this one and came back
				seen.append(this_cat)
				cat = this_cat
			return seen.size() == Items.categories().size()).call())

	# range is the whole point of item placement
	Game.room_items.clear()
	var far := Layout.seat(0) + Vector2i(9, 0)
	Game.room_items.append({"id": "bookshelf", "tile": far})
	chk("an item out of range helps nobody",
		is_equal_approx(Game.room_score(0), Balance.room_base),
		Game.room_score(0))
	Game.room_items[0]["tile"] = Layout.seat(0) + Vector2i(2, 0)
	chk("the same item in range does help",
		Game.room_score(0) > Balance.room_base, Game.room_score(0))

	# a 2-tile item should reach from either end, not just its anchor
	Game.room_items.clear()
	Game.room_items.append({"id": "lab_bench",
		"tile": Layout.seat(0) + Vector2i(-4, 0)})
	chk("a wide item measures from its NEAREST tile, not its anchor",
		Game.room_score(0) > Balance.room_base, Game.room_score(0))

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
	var still_out := 0
	for s: StudentData in Game.roster:
		if s.hw_state == StudentData.HW.DONE:
			done += 1
		elif s.hw_state == StudentData.HW.ASSIGNED:
			still_out += 1
	chk("overnight, no homework is left hanging as still-assigned",
		still_out == 0, still_out)
	# NOT_DONE used to be terminal: a student who missed one night was never
	# asked again for the rest of the run, silently. With forgiveness on they
	# land back on NONE and get asked tomorrow.
	chk("a student who missed it is asked again rather than locked out",
		(func() -> bool:
			if not Balance.not_done_forgiveness:
				return true
			for st: StudentData in Game.roster:
				if st.hw_state == StudentData.HW.NOT_DONE:
					return false
			return true).call())
	chk("and they can be set homework again immediately",
		Game.assign_homework() > 0)
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
	chk("the podium offers to teach today's real lesson by name",
		world.podium.can_interact()
		and world.podium.prompt_text() == "Teach %s" % String(Game.lesson["name"]),
		world.podium.prompt_text())

	var assigned: int = world.start_lesson()
	chk("starting the lesson sets the whole class working",
		assigned == Game.roster.size() and Game.phase == Game.Phase.LESSON, assigned)
	chk("the podium now offers to END the lesson",
		world.podium.prompt_text().begins_with("End the lesson"),
		world.podium.prompt_text())
	chk("the bell still refuses mid-lesson", not world.bell.can_interact())

	# give one student credit so the grades are not all identical
	# Teach the first student properly and ignore the second, so the grades
	# genuinely differ for the reason the game says they should.
	for i in Game.roster.size():
		var st: StudentData = Game.roster[i]
		if st.work_state == StudentData.Work.NONE:
			st.assign_work()
		var guard := 0
		while not st.has_work_to_collect() and guard < 20000 and i == 0:
			st.tick_work(1.0 / 60.0, Game.rng)
			if st.is_struggling():
				st.help()
			guard += 1
		if i == 0:
			st.collect_work()
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

	# Arrival itself is covered by the ARRIVAL section; walking it out again
	# costs ~30 real seconds, so seat them directly here.
	for n: Actor in world.students:
		if n.data != null:
			n.seat_at(Grid.tile_to_world(Layout.seat(n.data.seat_index)))
	await step(2)
	chk("the new day's class is seated and ready", world.everyone_seated())

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
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s := StudentData.new()
	s.aptitude = 0.5

	s.assign_work()
	chk("work starts un-stuck and empty",
		not s.is_struggling() and is_equal_approx(s.work_fraction(), 0.0))

	# tick until they stall, which now happens by continuous roll rather
	# than at a single moment scheduled up front
	var guard := 0
	while not s.is_struggling() and guard < 6000:
		s.tick_work(1.0 / 60.0, Game.rng)
		guard += 1
	chk("a student gets stuck eventually", s.is_struggling(), guard)
	chk("they never stall in the first moment of the work",
		guard > int(Balance.stall_grace_seconds * 60.0), guard)

	var frozen: float = s.work_timer
	var frac: float = s.work_fraction()
	for i in 600:
		s.tick_work(1.0 / 60.0, Game.rng)
	chk("a stuck student's work is completely frozen",
		is_equal_approx(s.work_timer, frozen))
	chk("so their work fraction stops rising too",
		is_equal_approx(s.work_fraction(), frac))
	chk("and they never finish on their own", not s.has_work_to_collect())

	chk("helping unfreezes them and is counted", (func() -> bool:
		var before := s.helps_received
		return s.help() and not s.is_struggling() and s.helps_received == before + 1).call())

	# see it through to the end, helping whenever needed
	guard = 0
	while not s.has_work_to_collect() and guard < 20000:
		s.tick_work(1.0 / 60.0, Game.rng)
		if s.is_struggling():
			s.help()
		guard += 1
	chk("with help they do finish", s.has_work_to_collect())
	chk("a finished student is at 100%", is_equal_approx(s.work_fraction(), 1.0))

	# aptitude has to matter, or the students really are interchangeable
	var dim_stalls := 0
	var bright_stalls := 0
	for i in 40:
		dim_stalls += _count_stalls(0.1)
		bright_stalls += _count_stalls(0.9)
	chk("a weaker student gets stuck more often than a stronger one",
		dim_stalls > bright_stalls, "%d vs %d over 40 lessons" % [dim_stalls, bright_stalls])

	# and a sheet you wrongly waved through leaves them secretly behind
	var honest := 0
	var misjudged := 0
	for i in 40:
		honest += _count_stalls(0.5, false)
		misjudged += _count_stalls(0.5, true)
	chk("a student whose homework you misjudged struggles more",
		misjudged > honest, "%d vs %d" % [misjudged, honest])


func _count_stalls(aptitude: float, misjudged: bool = false) -> int:
	var t := StudentData.new()
	t.aptitude = aptitude
	t.misjudged = misjudged
	t.assign_work()
	var stalls := 0
	for i in 20000:
		if t.tick_work(1.0 / 60.0, Game.rng):
			break
		if t.is_struggling():
			stalls += 1
			t.help()
	return stalls


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
			if Game.room_score(i) > Balance.room_base:
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


func test_moving_desks() -> void:
	section("MOVING DESKS")
	Game.new_run(SEED)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	chk("the room opens in its default arrangement",
		Layout.seats() == Layout.DEFAULT_SEATS)
	chk("and the class can only be as big as the desks it has",
		Game.seat_capacity() == Layout.seat_count())

	# --- what the ghost will and will not accept ---
	var place := Placement.new()
	world.add_child(place)
	place.begin_desk(0, world.grid)
	chk("a desk starts on its own seat", place.tile == Layout.seat(0))
	chk("and where it already is counts as valid, so a cancel is safe",
		place.is_valid())

	place.tile = Vector2i(5, 3)
	place._refresh()
	chk("a clear tile with room for the desk below is fine", place.is_valid())

	place.tile = Vector2i(7, 3)
	place._refresh()
	chk("but not if the DESK half would land on another desk's seat",
		not place.is_valid(), place.tile)

	place.tile = Layout.seat(1)
	place._refresh()
	chk("nor straight on top of another desk", not place.is_valid())

	place.tile = Vector2i(0, 0)
	place._refresh()
	chk("nor inside a wall", not place.is_valid())

	# The whole reason a desk's own tiles are treated as free: without it the
	# desk blocks itself and the commonest move of all becomes illegal.
	place.tile = Layout.seat(0) + Vector2i(1, 0)
	place._refresh()
	chk("and nudging a desk one tile sideways is allowed", place.is_valid())
	place.finish()
	place.queue_free()

	# --- the move itself ---
	var s: StudentData = Game.roster[0]
	var from: Vector2i = Layout.seat(s.seat_index)
	var to := Vector2i(5, 3)
	chk("the desk moves", world.move_desk(s.seat_index, to))
	chk("and the seating record went with it", Layout.seat(s.seat_index) == to)
	chk("the desk is still one tile in front of the chair",
		Layout.desk_tile(s.seat_index) == to + Layout.DESK_OFFSET)
	chk("the tile it left is walkable again", world.grid.is_free(from),
		world.grid.get_cell(from))
	chk("the tile it left is not still a seat",
		world.grid.get_cell(from) != Grid.Cell.SEAT)
	chk("the new tile is a seat on the grid",
		world.grid.get_cell(to) == Grid.Cell.SEAT, world.grid.get_cell(to))
	chk("and the desk half of it blocks",
		world.grid.get_cell(to + Layout.DESK_OFFSET) == Grid.Cell.BLOCKED)

	await step(2)
	var node: Actor = world.student_node(s.seat_index)
	chk("the child went with their desk rather than being left behind",
		node != null and node.global_position == Grid.tile_to_world(to),
		node.global_position if node != null else "no node")
	chk("nobody has been cut off from the door", (func() -> bool:
		for st: StudentData in Game.roster:
			if not world.grid.reachable(Layout.DOOR, Layout.seat(st.seat_index)):
				return false
		return true).call())

	# no two desks may ever share a tile, whatever the player tries
	chk("a desk cannot be dropped onto another desk",
		not world.move_desk(s.seat_index, Layout.seat(1)))

	# --- it survives the night ---
	Game.save_game()
	var arrangement := Layout.seats().duplicate()
	Game.new_run(1)
	chk("a new run starts from the default arrangement again",
		Layout.seats() == Layout.DEFAULT_SEATS)
	Game.load_game()
	chk("but a saved room remembers where you left the desks",
		Layout.seats() == arrangement, Layout.seats())
	Game.delete_save()

	Game.new_run(SEED)
	world.move_desk(0, Layout.DEFAULT_SEATS[0])   # leave the room as we found it
	await step(2)


func test_quiz() -> void:
	section("THE QUICK QUIZ")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	world.start_lesson()
	await step(4)

	chk("a fresh lesson has not had its quiz yet", not Game.quiz_done)
	chk("nobody has a score before one is set", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.quiz_score >= 0.0:
				return false
		return true).call())

	var time_before: float = world.lesson_left
	var result: Dictionary = world.run_quiz()

	chk("the quiz costs lesson time, which is what makes it a decision",
		world.lesson_left < time_before,
		"%.1f -> %.1f" % [time_before, world.lesson_left])
	chk("and it costs what the table says it costs",
		is_equal_approx(time_before - world.lesson_left, Balance.quiz_seconds_cost))
	chk("it cannot be run twice in one lesson", Game.quiz_done)

	chk("everyone sat it", result["rows"].size() == Game.roster.size())
	chk("every score is a real fraction of the questions asked",
		(func() -> bool:
			for r: Dictionary in result["rows"]:
				if int(r["right"]) < 0 or int(r["right"]) > Balance.quiz_questions:
					return false
				if not is_equal_approx(float(r["score"]),
						float(r["right"]) / float(Balance.quiz_questions)):
					return false
			return true).call())

	# The order IS the screen: this is read with the clock running, so it has
	# to be a queue of who to walk to, not a table to study.
	chk("the results are worst first", (func() -> bool:
		var last := -1.0
		for r: Dictionary in result["rows"]:
			if last >= 0.0 and float(r["score"]) < last:
				return false
			last = float(r["score"])
		return true).call())

	chk("whoever fell below the line is flagged", (func() -> bool:
		for r: Dictionary in result["rows"]:
			var want: bool = float(r["score"]) < Balance.quiz_flag_below
			if bool(r["flagged"]) != want:
				return false
		return true).call())

	# --- what the flag is FOR ---
	var flagged: StudentData = null
	for s: StudentData in Game.roster:
		if s.quiz_flagged:
			flagged = s
			break
	if flagged != null:
		var st: Interactable = world.station(flagged.seat_index)
		chk("a flagged child offers a verb their desk did not have before",
			st != null and st.action() == st.Action.GO_OVER, st.action())
		chk("and the prompt says what it is",
			st.prompt_text().contains("Go over"), st.prompt_text())
		var work_before: float = flagged.work_timer
		chk("going over it works", flagged.resolve_quiz())
		chk("it clears the flag", not flagged.quiz_flagged)
		chk("and it genuinely moves their work along",
			flagged.work_timer < work_before,
			"%.1f -> %.1f" % [work_before, flagged.work_timer])
		chk("going over it twice does nothing -- it is not a second Help",
			not flagged.resolve_quiz())
	else:
		chk("SKIPPED: this seed flagged nobody", true)

	# The quiz must never be a way to score points directly; the three-row
	# balance contract is measured without one, so any grade weight here
	# would move the pillar without anything saying so.
	var s0: StudentData = Game.roster[0]
	var grade_before := Game.grade_for(s0)
	s0.quiz_score = 1.0
	chk("a quiz score is worth no grade by itself",
		is_equal_approx(Game.grade_for(s0), grade_before))

	# retrieval practice: being asked is itself a small piece of learning
	Game.new_run(SEED)
	await step(2)
	world.start_lesson()
	await step(4)
	var s1: StudentData = Game.roster[0]
	s1.work_timer = Balance.work_seconds
	s1.take_quiz(Game.rng, Game.lesson_strand())
	chk("being asked is itself a little bit of learning, for everyone",
		s1.work_timer < Balance.work_seconds,
		"%.1f" % s1.work_timer)

	# understanding is built from what the game already knows
	var a := StudentData.new()
	a.aptitude = 0.9
	var b := StudentData.new()
	b.aptitude = 0.2
	chk("a stronger child understands more of the lesson",
		a.understanding("math") > b.understanding("math"))
	var c := StudentData.new()
	c.aptitude = 0.5
	c.favourite = "math"
	var d := StudentData.new()
	d.aptitude = 0.5
	chk("and their own subject helps them",
		c.understanding("math") > d.understanding("math"))
	var e := StudentData.new()
	e.aptitude = 0.5
	e.misjudged = true
	chk("a sheet you waved through shows up here, before it becomes a grade",
		e.understanding("math") < d.understanding("math"))

	world.end_lesson()
	await step(2)


func test_concepts() -> void:
	section("CONCEPTS & STANDARDS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("there are concepts to learn", Curriculum.concept_count() > 0,
		Curriculum.concept_count())
	chk("every lesson has some", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			if Curriculum.concepts_of(String(l.get("id", ""))).is_empty():
				return false
		return true).call())

	# THE HONESTY RULE. A concept is a component of its lesson's standard and
	# cites that same real code. Inventing a plausible sub-code would be a
	# fabricated citation, which is worse than none -- and no test would ever
	# catch that by itself, because a made-up code looks exactly like a real
	# one. What CAN be checked is that no new code was minted here.
	chk("every concept carries a standard code", (func() -> bool:
		for c: Dictionary in Curriculum.concepts():
			if String(c.get("standard", "")) == "":
				return false
		return true).call())
	chk("and it is its own lesson's code, never a newly minted one",
		(func() -> bool:
			for c: Dictionary in Curriculum.concepts():
				var parent := Curriculum.by_id(String(c["lesson"]))
				if String(c["standard"]) != String(parent.get("standard", "")):
					return false
			return true).call())
	chk("every concept id is unique", (func() -> bool:
		var seen := {}
		for c: Dictionary in Curriculum.concepts():
			var cid := String(c.get("id", ""))
			if seen.has(cid):
				return false
			seen[cid] = true
		return true).call())

	# --- unlocking by teaching ---
	chk("you start knowing nothing", Game.concepts.is_empty())
	chk("and it is worth nothing", is_equal_approx(Game.concept_bonus(), 0.0))

	var lid := String(Curriculum.lessons[0].get("id", ""))
	var first := Game.record_taught(lid)
	chk("teaching a lesson once teaches YOU something", not first.is_empty(), first)
	chk("it is recorded against that lesson", Game.times_taught(lid) == 1)
	chk("and it is now worth something to every grade",
		Game.concept_bonus() > 0.0)

	# EduSystems' own notes: concepts that unlocked a name on a list and
	# changed nothing were "the single clearest reason the learning system
	# doesn't make sense". So this has to show up in a real grade.
	var s0: StudentData = Game.roster[0]

	# A child who has done none of the work gains NOTHING from your
	# expertise. The term simulator caught this as a flat bonus: a player
	# who never helped anybody climbed a whole letter grade over a term
	# purely for having stood at the podium. Expertise pays for teaching,
	# not for attendance.
	var idle_before := Game.grade_for(s0)
	for i in 30:
		Game.record_taught(lid)
	chk("expertise is worth nothing to a child who did no work",
		is_equal_approx(Game.grade_for(s0), idle_before),
		"%.3f -> %.3f" % [idle_before, Game.grade_for(s0)])

	# ...but it shows up plainly in a child who did.
	Game.concepts.clear()
	s0.assign_work()
	s0.work_timer = 0.0
	s0.work_state = StudentData.Work.COLLECTED
	var without := Game.grade_for(s0)
	for i in 30:
		Game.record_taught(lid)
	chk("knowing your material shows up in what a working class scores",
		Game.grade_for(s0) > without,
		"%.3f -> %.3f" % [without, Game.grade_for(s0)])

	# Teaching ONE lesson thirty times cannot make you a rounded teacher: it
	# unlocks that lesson's concepts and then nothing, however long you keep
	# at it. Breadth is the only route to the cap.
	chk("hammering a single lesson only unlocks that lesson's concepts",
		Game.concepts.size() == Curriculum.concepts_of(lid).size(),
		Game.concepts.size())
	chk("which is well short of the cap",
		Game.concept_bonus() < Balance.concept_bonus_cap, Game.concept_bonus())

	for l: Dictionary in Curriculum.lessons:
		for i in 10:
			Game.record_taught(String(l.get("id", "")))
	chk("teaching broadly does get you there",
		Game.concepts.size() == Curriculum.concept_count(), Game.concepts.size())
	chk("but it is capped, so it never replaces the room or turning up",
		is_equal_approx(Game.concept_bonus(), Balance.concept_bonus_cap),
		Game.concept_bonus())
	chk("and teaching forever cannot unlock more than exists",
		Game.concepts.size() <= Curriculum.concept_count())
	chk("nothing is ever learned twice", (func() -> bool:
		var seen := {}
		for cid: String in Game.concepts:
			if seen.has(cid):
				return false
			seen[cid] = true
		return true).call())

	# --- the pillar it must NOT move ---
	# The three-row contract is measured on a fresh run where nothing has
	# been taught, so concept knowledge has to be worth exactly zero there.
	Game.new_run(SEED)
	chk("a fresh run knows nothing, which is why the contract is unmoved",
		is_equal_approx(Game.concept_bonus(), 0.0))

	# --- it survives the night ---
	Game.record_taught(lid)
	var known := Game.concepts.size()
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("what you learned to teach survives a save",
		Game.concepts.size() == known and Game.times_taught(lid) == 1,
		"%d concepts, taught %d" % [Game.concepts.size(), Game.times_taught(lid)])
	Game.delete_save()


func test_transcript() -> void:
	section("A CHILD'S OWN RECORD")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]

	chk("a new child has no record yet", s.transcript.is_empty())

	Game.lesson = Curriculum.by_id("basic_arithmetic")
	Game.grade_class()
	chk("a graded lesson writes one line into it", s.transcript.size() == 1)
	var row: Dictionary = s.transcript[0]
	chk("the line names the lesson", String(row["name"]) == "Basic Arithmetic", row)
	chk("and carries its real standard code",
		String(row["standard"]) == "3.OA.C.7", row)
	chk("and the day it happened", int(row["day"]) == Game.day)
	chk("the record agrees with the grade they were actually given",
		is_equal_approx(float(row["grade"]), s.last_grade))

	Game.lesson = Curriculum.by_id("reading_fluency")
	Game.grade_class()
	chk("a second lesson appends rather than replacing", s.transcript.size() == 2)
	chk("and the record spans both subjects", (func() -> bool:
		var names := {}
		for r: Dictionary in s.transcript:
			names[String(r["name"])] = true
		return names.size() == 2).call())

	# Strongest BY RESULT, which is not always the favourite they were born
	# with. That difference is most of the reason to keep a record at all.
	s.transcript = [
		{"lesson": "a", "name": "Maths", "standard": "x", "day": 1, "grade": 0.9},
		{"lesson": "b", "name": "English", "standard": "y", "day": 2, "grade": 0.3},
	]
	chk("their strongest subject is the one they actually did best in",
		s.best_subject() == "Maths", s.best_subject())

	# it is THEIRS, so it goes with them
	Game.new_run(SEED)
	var t: StudentData = Game.roster[0]
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	Game.grade_class()
	var n := t.transcript.size()
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("a record survives a save", (func() -> bool:
		for st: StudentData in Game.roster:
			if st.display_name == t.display_name:
				return st.transcript.size() == n
		return false).call())
	Game.delete_save()


func test_unlockables() -> void:
	section("UNLOCKABLES")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	var gated: Array = []
	var teachers: Array = []
	for id: String in Items.order():
		if Items.requires(id) != "":
			gated.append(id)
		if Items.teaches(id) != "":
			teachers.append(id)
	chk("some furniture has to be earned rather than only afforded",
		not gated.is_empty(), gated.size())
	chk("and some of it teaches a concept outright",
		not teachers.is_empty(), teachers.size())

	chk("every gate names a concept that really exists", (func() -> bool:
		for id: String in gated:
			if Curriculum.concept(Items.requires(id)).is_empty():
				return false
		return true).call())
	chk("and so does everything claiming to teach one", (func() -> bool:
		for id: String in teachers:
			if Curriculum.concept(Items.teaches(id)).is_empty():
				return false
		return true).call())

	var locked: String = String(gated[0])
	chk("a gated item is locked to begin with", not Items.is_unlocked(locked))
	chk("and the shop does not list it",
		not Items.available_in_category(Items.category_of(locked)).has(locked))

	Game.concepts.append(Items.requires(locked))
	chk("learning the concept puts it on sale", Items.is_unlocked(locked))
	chk("and the shop lists it now",
		Items.available_in_category(Items.category_of(locked)).has(locked))

	# furniture that teaches: the room feeding back into the curriculum
	Game.new_run(SEED)
	var teacher_item: String = String(teachers[0])
	var cid := Items.teaches(teacher_item)
	chk("you do not know it yet", not Game.knows_concept(cid))
	Game.room_items.append({"id": teacher_item, "tile": Vector2i(9, 6)})
	Game.record_taught(String(Curriculum.lessons[0].get("id", "")))
	chk("owning the item that teaches it is enough to learn it",
		Game.knows_concept(cid), cid)

	chk("ungated furniture is always on sale", (func() -> bool:
		for id: String in Items.order():
			if Items.requires(id) == "" and not Items.is_unlocked(id):
				return false
		return true).call())


func test_unit_test() -> void:
	section("THE UNIT TEST")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	var lid := "basic_arithmetic"
	chk("you cannot test a unit you have never taught", not Game.can_test(lid))
	chk("so the podium offers no test at all", Game.testable_lesson().is_empty())
	chk("and asking for one anyway is refused", world.start_test(lid) == -1)

	for i in Balance.test_requires_taught:
		Game.record_taught(lid)
	chk("teaching it enough times unlocks the test", Game.can_test(lid))
	chk("and the podium now has one to offer",
		String(Game.testable_lesson().get("id", "")) == lid,
		Game.testable_lesson().get("id", ""))

	# --- sitting it ---
	Game.set_phase(Game.Phase.MORNING)
	var seated: int = world.start_test(lid)
	chk("the whole class sits it", seated == Game.roster.size(), seated)
	chk("the room knows a test is running", Game.test_active)
	chk("it runs on the lesson clock", world.lesson_left > 0.0)
	chk("and for the time the table says",
		is_equal_approx(world.lesson_left, Balance.test_seconds))
	chk("today's subject became the unit being tested",
		String(Game.lesson.get("id", "")) == lid)

	# THE INSTRUMENT: every verb you have is switched off.
	var s0: StudentData = Game.roster[0]
	s0.confusion = 1.0                      # even if somebody IS stuck
	var st: Interactable = world.station(s0.seat_index)
	chk("you cannot help anyone during a test", not st.can_interact())
	s0.work_state = StudentData.Work.DONE
	chk("nor collect their paper", not st.can_interact())
	s0.confusion = 0.0
	s0.work_state = StudentData.Work.WORKING

	chk("and you cannot quiz your way through it", (func() -> bool:
		for q in get_tree().get_nodes_in_group("quiz_caller"):
			if q.can_interact():
				return false
		return true).call())

	# Nobody stalls in a test, because you would not be allowed to unstick
	# them. classroom passes a null rng, and tick_work only stalls with one.
	var stalled := false
	for i in 400:
		await step(1)
		for s: StudentData in Game.roster:
			if s.is_struggling():
				stalled = true
		if world.lesson_left <= 0.0:
			break
	chk("nobody gets stuck in a test", not stalled)

	# --- marking it ---
	var before: int = Game.roster[0].transcript.size()
	var results: Array = world.end_test()
	chk("every child gets a result", results.size() == Game.roster.size())
	chk("the test is over", not Game.test_active)
	chk("and the day moves on", Game.phase == Game.Phase.AFTERNOON)
	chk("it goes into their record", Game.roster[0].transcript.size() == before + 1)
	chk("marked AS a test, so a record can tell the two apart",
		Game.roster[0].tests_taken().size() == 1)
	chk("no homework is set -- the unit is finished", not Game.homework_out)

	# --- what it measures ---
	# Not the same formula as a lesson: no homework term, and no credit for
	# collecting, because you were not allowed to collect.
	Game.new_run(SEED)
	var a: StudentData = Game.roster[0]
	a.hw_state = StudentData.HW.MARKED
	a.hw_true_accuracy = 1.0
	a.hw_player_verdict = 1
	var with_hw := Game.test_grade_for(a)
	a.hw_state = StudentData.HW.NONE
	chk("homework counts for nothing on a test",
		is_equal_approx(with_hw, Game.test_grade_for(a)))

	# It IS moved by the room you built and by what you know -- that is the
	# whole argument for the instrument.
	var bare := Game.test_grade_for(a)
	Game.room_items.append({"id": "bookshelf", "tile": Layout.seat(a.seat_index) + Vector2i(1, 0)})
	chk("but the room you built counts", Game.test_grade_for(a) > bare,
		"%.3f -> %.3f" % [bare, Game.test_grade_for(a)])

	var furnished := Game.test_grade_for(a)
	for l: Dictionary in Curriculum.lessons:
		for i in 10:
			Game.record_taught(String(l.get("id", "")))
	chk("and so does knowing your material",
		Game.test_grade_for(a) > furnished)

	# A test is worth more than a day's lesson, which is what "high stakes"
	# has to mean mechanically rather than in the prose.
	chk("a test can carry more than a single lesson ever could",
		Balance.test_cap > Balance.lesson_cap,
		"%.2f vs %.2f" % [Balance.test_cap, Balance.lesson_cap])

	Game.new_run(SEED)
	await step(2)


func test_two_buttons_one_landmark() -> void:
	section("TWO BUTTONS AT ONE LANDMARK")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var p: Actor = world.player

	# The picker used to keep ONE target for both buttons, so whenever two
	# interactables shared a tile the loser was silently unreachable and the
	# tie was settled by node order. Every landmark that has grown a second
	# verb has run into it.
	chk("each button has its own target", p.targets.has("interact")
		and p.targets.has("manage"))

	# --- the podium in the morning: teach on F, unit test on E ---
	for i in Balance.test_requires_taught:
		Game.record_taught("basic_arithmetic")
	Game.set_phase(Game.Phase.MORNING)
	await step(30)                       # let everyone reach their chairs
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)

	chk("MANAGE offers the lesson", p.targets["manage"] == world.podium,
		p.targets["manage"])
	chk("and USE offers the unit test at the same moment", (func() -> bool:
		var t: Interactable = p.targets["interact"]
		return t != null and t.prompt_text().begins_with("Unit test")).call(),
		p.targets["interact"])
	chk("both are on offer together", p.offers().size() == 2, p.offers().size())

	# --- a desk: help on E, move it on F ---
	Game.set_phase(Game.Phase.AFTERNOON)
	var s0: StudentData = Game.roster[0]
	s0.work_state = StudentData.Work.DONE
	await place_player(Layout.seat(s0.seat_index) + Vector2i(1, 1), Actor.DIR_LEFT)
	await step(2)
	# A desk is the deliberate EXCEPTION to two-verbs-at-once: the mover
	# stands down whenever there is something you could be doing for the
	# child, so "move this desk" can never shoulder "collect their work" off
	# the prompt.
	chk("with work to collect, the desk offers only that",
		p.offers().size() == 1, p.offers().map(func(t: Interactable) -> String:
			return t.prompt_text()))
	chk("and it is on the USE button", (func() -> bool:
		var t: Interactable = p.targets["interact"]
		return t != null and t.prompt_text().contains("Collect")).call())

	s0.work_state = StudentData.Work.COLLECTED       # nothing left to do for them
	await step(2)
	chk("with nothing to do for the child, MANAGE offers the move instead",
		(func() -> bool:
			var t: Interactable = p.targets["manage"]
			return t != null and t.prompt_text().contains("desk")).call(),
		p.targets["manage"])

	# THE CRASH THIS GUARDS. Reading a freed node into a TYPED variable
	# throws "Trying to assign invalid previously freed instance", which
	# aborted the rest of _physics_process -- every frame, forever. Targets
	# stopped refreshing and every button in the game went dead, and nothing
	# in the suite noticed because the error is not a failed assertion.
	Game.room_items.clear()
	Game.add_item("plant", Vector2i(9, 6))
	await step(3)
	await place_player(Vector2i(9, 7), Actor.DIR_UP)
	await step(3)
	chk("the plant is what you are standing at", (func() -> bool:
		var t: Interactable = p.targets["interact"]
		return t != null and t.prompt_text().contains("Plant")).call())
	Game.remove_item(Vector2i(9, 6))     # frees the node under the player
	await step(3)
	chk("removing it under your feet does not leave a dead target",
		p.targets["interact"] == null or is_instance_valid(p.targets["interact"]))

	Game.add_item("bookshelf", Vector2i(9, 6))
	await step(4)
	chk("and the picker recovers rather than staying dead forever",
		(func() -> bool:
			var t: Interactable = p.targets["interact"]
			return t != null and t.prompt_text().contains("Bookshelf")).call(),
		p.targets["interact"])

	Game.room_items.clear()
	Game.new_run(SEED)
	await step(2)


func test_growing_the_room() -> void:
	section("A ROOM YOU CAN GROW")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	chk("a new run opens in the base classroom",
		Grid.W == Grid.BASE_W and Grid.H == Grid.BASE_H,
		"%dx%d" % [Grid.W, Grid.H])

	# THE THING THAT MUST NOT CHANGE. At the opening size the room is exactly
	# the viewport, so the camera limits pin it dead still -- which is what
	# keeps the whole-room-at-a-glance reading that the "?" bubble, the audio
	# design and the Practised Eye perk were all argued from.
	chk("there is a camera", world.camera != null)
	chk("and at the opening size it is pinned to the room exactly",
		world.camera.limit_right == Grid.BASE_W * Grid.TILE
		and world.camera.limit_bottom == Grid.BASE_H * Grid.TILE,
		"%d x %d" % [world.camera.limit_right, world.camera.limit_bottom])

	# --- buying space ---
	chk("you cannot expand on an empty purse", (func() -> bool:
		Game.coins = 0
		return Game.expand_room("wide") != "").call())
	chk("and the room did not grow anyway", Grid.W == Grid.BASE_W)

	Game.coins = 100000
	var cost := Game.expand_cost("wide")
	chk("a column has a price", cost > 0, cost)
	var coins_before: int = Game.coins
	chk("and it can be bought", Game.expand_room("wide") == "")
	chk("the room really is wider", Grid.W == Grid.BASE_W + 1, Grid.W)
	chk("it was paid for", Game.coins == coins_before - cost,
		"%d -> %d" % [coins_before, Game.coins])
	chk("and the next one costs more than the last",
		Game.expand_cost("wide") > cost,
		"%d then %d" % [cost, Game.expand_cost("wide")])

	await step(2)
	chk("the camera now has room to move",
		world.camera.limit_right == Grid.W * Grid.TILE, world.camera.limit_right)

	# --- the room rebuilt itself around everyone ---
	chk("the walls moved with it", (func() -> bool:
		# the old right-hand wall column is floor now
		return world.grid.is_free(Vector2i(Grid.BASE_W - 1, 5))).call(),
		world.grid.get_cell(Vector2i(Grid.BASE_W - 1, 5)))
	chk("and the new right-hand column is wall",
		world.grid.get_cell(Vector2i(Grid.W - 1, 5)) == Grid.Cell.BLOCKED)
	chk("the door is still where it always was",
		world.grid.is_free(Layout.DOOR))
	chk("every seat is still reachable from it", (func() -> bool:
		for st: StudentData in Game.roster:
			if not world.grid.reachable(Layout.DOOR, Layout.seat(st.seat_index)):
				return false
		return true).call())
	chk("the desks are still there", world.stations.size() == Layout.seat_count())
	chk("and so is everyone sitting at them",
		world.students.size() == Game.roster.size())
	chk("the podium survived the rebuild",
		world.podium != null and is_instance_valid(world.podium))

	# growing must never move what is already placed
	Game.room_items.clear()
	Game.add_item("plant", Vector2i(6, 6))
	await step(2)
	Game.coins = 100000
	Game.expand_room("tall")
	await step(2)
	chk("furniture keeps the tile it was put on",
		Game.room_items.size() == 1 and Game.room_items[0]["tile"] == Vector2i(6, 6),
		Game.room_items)
	chk("and it is still solid on the rebuilt grid",
		not world.grid.is_free(Vector2i(6, 6)))
	chk("the room got longer", Grid.H == Grid.BASE_H + 1, Grid.H)

	# --- limits ---
	Game.coins = 100000
	var guard := 0
	while Game.can_expand("wide") and guard < 40:
		Game.coins = 100000000      # the cost rises steeply; this is about the LIMIT
		Game.expand_room("wide")
		guard += 1
	chk("the room stops at a sensible maximum", Grid.W == Grid.MAX_W, Grid.W)
	chk("and asking again is refused rather than ignored",
		Game.expand_room("wide") != "")

	# --- it survives the night ---
	var w := Grid.W
	var h := Grid.H
	Game.save_game()
	Game.new_run(1)
	chk("a new run is back to the base room", Grid.W == Grid.BASE_W)
	Game.load_game()
	chk("but a saved room remembers how big you built it",
		Grid.W == w and Grid.H == h, "%dx%d" % [Grid.W, Grid.H])
	Game.delete_save()

	Game.new_run(SEED)
	await step(2)


## How many lines of body text a panel can actually show.
##
## Measured from real screenshots, NOT from get_line_count(). Headless Godot
## has no renderer and falls back to different font metrics, where it insists
## six lines are wrapping that plainly do not wrap on screen -- so a layout
## assertion built on it fails honest code and would eventually be deleted
## for crying wolf. Written lines against a measured budget is the same
## question, and it gives the same answer in both places.
##
## The two numbers are the two font sizes the overlays use: the REPORT
## default, and the smaller one the denser screens switch to.
const PANEL_LINES := 5
const PANEL_LINES_SMALL := 9


func _lines_in(label: Label) -> int:
	return label.text.split("\n").size()


func _fits(label: Label, budget: int) -> bool:
	return _lines_in(label) <= budget


func _overflow(label: Label, budget: int) -> String:
	return "%d lines, room for %d" % [_lines_in(label), budget]


func test_panels_fit() -> void:
	section("PANELS THAT FIT")
	var hud := _hud()
	Game.new_run(SEED)
	Game.add_coins(50000)
	await step(2)

	# EVERY overlay in this project has needed two or three passes to stop
	# running off the bottom of its panel, and until now nothing caught it --
	# a screen that overflows is not a failed assertion, it is just wrong on
	# screen. The unit-test report, the curriculum screen and the student
	# file were all shipped overflowing in the same afternoon.

	Game.set_phase(Game.Phase.MORNING)
	await step(30)
	world.start_lesson()
	hud.show_quiz_report(world.run_quiz())
	chk("the quiz report fits a full class",
		_fits(hud.body, PANEL_LINES_SMALL),
		_overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	# a FULL class is the hard case for any per-student list
	while Game.enrol() != null:
		pass
	chk("the class really is full", Game.roster.size() == Game.seat_capacity())

	Game.lesson = Curriculum.by_id("basic_arithmetic")
	hud.show_lesson_report(Game.grade_class())
	chk("the lesson report fits a full class",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	for i in Balance.test_requires_taught:
		Game.record_taught("basic_arithmetic")
	hud.show_test_report(Game.grade_test())
	chk("the unit test report fits a full class",
		_fits(hud.body, PANEL_LINES), _overflow(hud.body, PANEL_LINES))
	hud.close()

	hud.show_curriculum()
	chk("the curriculum screen fits when you know nothing",
		_fits(hud.body, PANEL_LINES), _overflow(hud.body, PANEL_LINES))
	hud.close()
	for l: Dictionary in Curriculum.lessons:
		for i in 10:
			Game.record_taught(String(l.get("id", "")))
	hud.show_curriculum()
	chk("and still fits when you know everything",
		_fits(hud.body, PANEL_LINES), _overflow(hud.body, PANEL_LINES))
	hud.close()

	# the student file, with everything on it at once
	var s: StudentData = Game.roster[0]
	Game.lesson = Curriculum.by_id("reading_fluency")
	Game.grade_class()
	s.hw_state = StudentData.HW.MARKED
	s.hw_player_verdict = 1
	while not s.is_ready_to_graduate():
		s.add_xp(1)
	hud.show_student(s)
	chk("a student file fits with every line filled in",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	chk("and it still offers all three actions",
		hud.body.text.contains("Extra tuition")
		and hud.body.text.contains("parents")
		and hud.body.text.contains("Send them up"), hud.body.text)
	hud.close()

	hud.show_class_list()
	chk("the class list fits a full class",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	# every shop tab
	hud.open_catalogue()
	for tab in [hud.Shop.BUY, hud.Shop.SELL, hud.Shop.STAFF, hud.Shop.ROOM]:
		hud._shop = tab
		hud._sel = 0
		hud._render_catalogue()
		chk("shop tab %d fits" % tab, _fits(hud.body, PANEL_LINES_SMALL),
			_overflow(hud.body, PANEL_LINES_SMALL))
	# the busiest category, at the bottom of its list
	hud._shop = hud.Shop.BUY
	var biggest := 0
	for i in Items.categories().size():
		if Items.available_in_category(String(Items.categories()[i])).size() \
				> Items.available_in_category(String(Items.categories()[biggest])).size():
			biggest = i
	hud._cat = biggest
	hud._sel = Items.available_in_category(
		String(Items.categories()[biggest])).size() - 1
	hud._render_catalogue()
	chk("the fullest shop category fits, scrolled to the end",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	# Put the shop back on its first category. A section that leaves UI
	# state behind breaks a later one somewhere unrelated.
	hud._cat = 0
	hud._sel = 0
	hud.close()

	# The two end screens, with everything they can possibly show at once:
	# somebody joining, an event tomorrow, and a full class.
	var report := Game.advance_day()
	report["joined"] = "Someone New"
	report["event"] = "A wasp in the room"
	report["event_blurb"] = "Nobody is going to concentrate today."
	hud.show_day_report(report)
	chk("the end-of-day report fits with everything on it",
		_fits(hud.body, PANEL_LINES), _overflow(hud.body, PANEL_LINES))
	hud.close()

	Game.cheated = true          # the cheat notice is one more line
	hud.show_exam(Game.sit_exam())
	chk("the end-of-term exam fits a full class",
		_fits(hud.body, PANEL_LINES), _overflow(hud.body, PANEL_LINES))
	Game.cheated = false
	hud.close()

	hud.show_title()
	chk("the title screen fits",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	hud.show_pause()
	chk("the pause menu fits",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	Game.new_run(SEED)
	await step(2)


func test_systems_together() -> void:
	section("THE NEW SYSTEMS, TOGETHER")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	Game.coins = 100000
	await step(2)

	# --- move a desk, THEN grow the room ---
	# Growing rebuilds the seating from Layout, so a desk you moved has to
	# survive being rebuilt around. If it did not, the room getting bigger
	# would silently undo your arrangement.
	var s0: StudentData = Game.roster[0]
	var moved := Vector2i(5, 3)
	chk("the desk moves", world.move_desk(s0.seat_index, moved))
	Game.expand_room("wide")
	await step(2)
	chk("and it is still where you put it after the room grows",
		Layout.seat(s0.seat_index) == moved, Layout.seat(s0.seat_index))
	chk("the grid agrees",
		world.grid.get_cell(moved) == Grid.Cell.SEAT, world.grid.get_cell(moved))
	chk("and the child is still sitting at it", (func() -> bool:
		var n: Actor = world.student_node(s0.seat_index)
		return n != null and n.global_position == Grid.tile_to_world(moved)).call())
	chk("everyone can still reach the door", (func() -> bool:
		for st: StudentData in Game.roster:
			if not world.grid.reachable(Layout.DOOR, Layout.seat(st.seat_index)):
				return false
		return true).call())

	# --- the arrangement AND the size survive the same save ---
	var seats := Layout.seats().duplicate()
	var w := Grid.W
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("a save remembers the arrangement and the size together",
		Layout.seats() == seats and Grid.W == w,
		"%dx%d, seat0 %s" % [Grid.W, Grid.H, Layout.seat(0)])
	Game.delete_save()

	# --- a quiz, then a test, on the same day ---
	Game.new_run(SEED)
	await step(30)
	world.start_lesson()
	await step(2)
	world.run_quiz()
	chk("a quiz flags people during an ordinary lesson", Game.quiz_done)
	world.end_lesson()
	await step(2)

	for i in Balance.test_requires_taught:
		Game.record_taught(String(Game.lesson.get("id", "")))
	Game.set_phase(Game.Phase.MORNING)
	world.start_test(String(Game.lesson.get("id", "")))
	chk("a test can be sat after a lesson day", Game.test_active)
	chk("and it clears any quiz flag left over, because you cannot act on one",
		(func() -> bool:
			for st: StudentData in Game.roster:
				if st.quiz_flagged:
					return false
			return true).call())
	world.end_test()
	await step(2)

	# --- concepts unlock furniture, which unlocks concepts ---
	Game.new_run(SEED)
	var gated := ""
	for id: String in Items.order():
		if Items.requires(id) != "":
			gated = id
			break
	chk("the gated item starts locked", not Items.is_unlocked(gated))
	# teach the lesson its gate belongs to until the concept opens
	var need := Items.requires(gated)
	var lesson_id := String(Curriculum.concept(need).get("lesson", ""))
	var guard := 0
	while not Game.knows_concept(need) and guard < 40:
		Game.record_taught(lesson_id)
		guard += 1
	chk("teaching its subject unlocks it", Items.is_unlocked(gated), gated)
	chk("and it appears in the shop", (func() -> bool:
		return Items.available_in_category(Items.category_of(gated)).has(gated)).call())

	Game.new_run(SEED)
	await step(2)


func test_a_whole_day() -> void:
	section("ONE WHOLE DAY, THROUGH THE REAL BUTTONS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var hud := _hud()
	var p: Actor = world.player
	await step(40)                      # let the class walk in and sit down

	# Everything else drives the day by calling world.start_lesson() and
	# world.end_day() directly. Nothing walked a teacher to a landmark and
	# pressed the button a player would press, which is why "you cannot end
	# the day" was able to be true while every test passed.
	chk("the class is seated and it is morning",
		world.everyone_seated() and Game.phase == Game.Phase.MORNING, Game.phase)

	# --- start the lesson at the podium ---
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)
	chk("the podium offers to teach", (func() -> bool:
		var t: Interactable = p.targets["manage"]
		return t != null and t.prompt_text().begins_with("Teach")).call(),
		p.targets["manage"])
	await tap("manage")
	chk("tapping manage starts the lesson", Game.phase == Game.Phase.LESSON,
		Game.phase)

	# --- let the clock run all the way out ---
	var guard := 0
	while world.lesson_left > 0.0 and guard < 4000:
		await step(1)
		guard += 1
	chk("the lesson clock reaches zero", world.lesson_left <= 0.0,
		world.lesson_left)

	# THE BUG. The clock running out emitted lesson_timed_out and NOTHING
	# listened, so the day simply stopped: still in LESSON, so the bell --
	# which only rings in the afternoon -- was never on offer, and there was
	# no way left to end the day at all.
	await step(10)
	chk("a lesson that runs out of time actually ENDS",
		Game.phase == Game.Phase.AFTERNOON, Game.phase)
	_hud().close()
	await step(2)

	# --- ring the bell ---
	await place_player(Layout.BELL + Vector2i(0, 1), Actor.DIR_UP)
	chk("the bell is now on offer", world.bell.can_interact())
	chk("and MANAGE is pointing at it", p.targets["manage"] == world.bell)
	var day_before: int = Game.day
	await hold_confirm("manage", 0.9)
	chk("holding at the bell ends the day", Game.day == day_before + 1,
		"day %d phase %d" % [Game.day, Game.phase])
	chk("and the day report is on screen",
		hud.mode == hud.Mode.REPORT, hud.mode)
	await tap("interact")
	await step(2)
	chk("E closes it and hands you back the room",
		hud.mode == hud.Mode.NONE and not p.input_locked, hud.mode)
	chk("tomorrow has begun", Game.phase == Game.Phase.MORNING, Game.phase)


func test_overlays() -> void:
	section("OVERLAYS")
	var hud := _hud()
	var p: Actor = world.player
	Game.new_run(SEED)
	Game.add_coins(2000)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	# The noticeboard is a MANAGE interactable, so it answers to F and NOT
	# to E. That separation is the point: E is mashed all lesson long and
	# must never reach anything session-level.
	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	# The board carries two things now -- the shop on F, the curriculum on E
	# -- so the question is which BUTTON offers the shop.
	chk("standing at the noticeboard offers the catalogue", (func() -> bool:
		var t: Interactable = p.targets["manage"]
		return t != null and t.prompt_text().begins_with("Furniture")).call(),
		p.targets["manage"])
	chk("the noticeboard listens for the manage button, not the use button",
		world.noticeboard.action_name() == "manage",
		world.noticeboard.action_name())
	await tap("interact")
	chk("pressing the USE button does NOT open the shop",
		hud.mode != hud.Mode.CATALOGUE, hud.mode)
	chk("it opens the curriculum instead, which costs you nothing",
		hud.title.text.begins_with("CURRICULUM"), hud.title.text)
	# Closed directly rather than with a key: a REPORT closes on E, and
	# tapping E while standing at the board would simply reopen it.
	hud.close()
	await step(2)
	chk("and it really did close", hud.mode == hud.Mode.NONE, hud.mode)
	await tap("manage")
	chk("pressing the MANAGE button opens the catalogue",
		hud.mode == hud.Mode.CATALOGUE,
		hud.mode)
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
	await tap("manage")
	var opened_once: bool = hud.mode == hud.Mode.CATALOGUE
	await tap("cancel")
	await step(2)
	chk("one press does one thing — closing a menu never re-opens it",
		hud.mode == hud.Mode.NONE, hud.mode)
	chk("(and the press that opened it genuinely did open it)", opened_once)

	# order something, and place it. Opening the board is a MANAGE action;
	# confirming a row inside the overlay is still the ordinary use button.
	await tap("manage")
	# The row that is actually highlighted. Items.order()[_sel] is the FLAT
	# catalogue, but the shop shows one category at a time -- the two agree
	# only while you are on the first category, which is exactly the kind of
	# coincidence that holds until something else moves.
	var chosen: String = String(hud._shop_rows()[hud._sel])
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
	await tap("manage")
	await tap("interact")
	await step(3)
	var mid_coins: int = Game.coins
	await tap("cancel")
	await step(3)
	chk("cancelling placement leaves you unlocked and un-charged",
		not main.placement.active and not p.input_locked and Game.coins == mid_coins)
	# A section that leaves a screen up poisons every section after it, and
	# the failure surfaces somewhere unrelated. Cheap to pin here.
	chk("BUTTONS leaves no overlay open behind it",
		_hud().mode == _hud().Mode.NONE, _hud().title.text)


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


func test_shop() -> void:
	section("BUY, SELL, MOVE")
	var hud := _hud()
	var p: Actor = world.player
	var main: Node = world.get_parent()
	Game.new_run(SEED)
	Game.add_coins(2000)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	chk("the day has a named subject", Game.subject != "", Game.subject)
	chk("and it is a real lesson from the curriculum", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			if String(l["name"]) == Game.subject:
				return true
		return false).call(), Game.subject)

	# --- selling ---
	Game.add_item("bookshelf", Vector2i(6, 6))
	Game.add_item("plant", Vector2i(8, 6))
	await step(2)
	chk("two items are in the room", Game.room_items.size() == 2)

	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	await tap("manage")
	chk("the shop opens on the BUY list",
		hud.mode == hud.Mode.CATALOGUE and hud._shop == hud.Shop.BUY)
	await tap("menu")
	chk("Tab switches to the SELL list", hud._shop == hud.Shop.SELL)
	chk("the sell list shows what is actually in the room",
		hud.body.text.contains("Bookshelf") and hud.body.text.contains("Potted Plant"),
		hud.body.text)

	var coins_before: int = Game.coins
	var refund: int = Game.sell_value(String(Game.room_items[hud._sel]["id"]))
	await tap("interact")
	await step(2)
	chk("selling removes the item and pays you back",
		Game.room_items.size() == 1 and Game.coins == coins_before + refund,
		"%d items, %d coins (+%d expected)" % [Game.room_items.size(), Game.coins, refund])
	chk("you get back half, not the full price",
		refund == int(floor(Items.cost("bookshelf") * Balance.sell_fraction))
		or refund == int(floor(Items.cost("plant") * Balance.sell_fraction)), refund)
	chk("the sold item's tile is free to build on again",
		world.grid.is_free(Vector2i(6, 6)) or world.grid.is_free(Vector2i(8, 6)))

	# Tab is a four-stop cycle: buy -> sell -> staff room -> the room -> buy
	await tap("menu")
	chk("Tab goes on to the staff room", hud._shop == hud.Shop.STAFF)
	await tap("menu")
	chk("then to the room itself", hud._shop == hud.Shop.ROOM)
	await tap("menu")
	chk("and round again to buying", hud._shop == hud.Shop.BUY)
	await tap("cancel")
	chk("Esc closes the shop", hud.mode == hud.Mode.NONE and not p.input_locked)

	# --- moving ---
	Game.room_items.clear()
	Game.add_item("plant", Vector2i(6, 6))
	await step(3)
	var placed_body: Node = null
	for n in get_tree().get_nodes_in_group("purchased"):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			placed_body = n
	chk("a bought item exists in the world", placed_body != null)

	await place_player(Vector2i(6, 7), Actor.DIR_UP)
	chk("standing at your own furniture offers to move it",
		p.target != null and p.target.prompt_text().begins_with("Move"),
		"" if p.target == null else p.target.prompt_text())

	var coins_at_move: int = Game.coins
	await tap("interact")
	await step(3)
	chk("moving lifts it off the floor", Game.room_items.is_empty(), Game.room_items.size())
	chk("and starts the ghost cursor", main.placement.active)
	chk("moving something you own is free", Game.coins == coins_at_move)

	main.placement.tile = Vector2i(11, 3)
	main.placement._refresh()
	chk("the new spot is valid", main.placement.is_valid())
	await tap("interact")
	await step(3)
	chk("putting it down again re-places it, still free",
		Game.room_items.size() == 1 and Game.coins == coins_at_move,
		"%d items, %d coins" % [Game.room_items.size(), Game.coins])
	chk("it is at the NEW tile", Game.room_items[0]["tile"] == Vector2i(11, 3),
		Game.room_items[0]["tile"])
	chk("the old tile is free again", world.grid.is_free(Vector2i(6, 6)))
	chk("and you can walk once more", not p.input_locked)

	# cancelling a move must put it back, not delete it
	await place_player(Vector2i(11, 4), Actor.DIR_UP)
	await tap("interact")
	await step(3)
	chk("a move is in progress",
		main.placement.active and Game.room_items.is_empty(),
		"active=%s  items=%d" % [main.placement.active, Game.room_items.size()])
	main.placement.tile = Vector2i(9, 6)
	main.placement._refresh()
	await tap("cancel")
	await step(3)
	chk("cancelling a move puts the item back where it was",
		Game.room_items.size() == 1 and Game.room_items[0]["tile"] == Vector2i(11, 3),
		Game.room_items)
	chk("nothing was lost or charged",
		Game.coins == coins_at_move and not p.input_locked)

	chk("furniture cannot be rearranged mid-lesson", (func() -> bool:
		Game.set_phase(Game.Phase.LESSON)
		for n in get_tree().get_nodes_in_group("purchased"):
			if not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
				continue
			for c in (n as Node).get_children():
				if c is Interactable and c.has_signal("move_requested"):
					return not (c as Interactable).can_interact()
		return false).call())
	Game.set_phase(Game.Phase.AFTERNOON)


func test_progress_bar() -> void:
	section("PROGRESS BAR")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var frames := 0
	while frames < 2000 and not world.everyone_seated():
		await step(20)
		frames += 20

	var node: Actor = world.student_node(0)
	var s := Game.student_in_seat(0)
	s.reset_lesson()
	chk("nothing is drawn before work is set",
		s.work_state == StudentData.Work.NONE
		and is_equal_approx(s.work_fraction(), 0.0))

	s.assign_work()
	chk("the bar has something to show once work starts",
		s.work_state == StudentData.Work.WORKING)

	# tick the model directly so a stall can't make this flaky
	var at_start: float = s.work_fraction()
	for i in 120:
		s.tick_work(1.0 / 60.0, null)          # null rng = never stalls
	var later: float = s.work_fraction()
	chk("it fills as they work", later > at_start,
		"%.2f -> %.2f" % [at_start, later])
	chk("two seconds in it is about 2s worth of the work",
		absf(later - 2.0 / Balance.work_seconds) < 0.05, "%.2f" % later)

	s.confusion = 1.0
	var frozen: float = s.work_fraction()
	for i in 600:
		s.tick_work(1.0 / 60.0, null)
	chk("it stops dead while they are stuck",
		is_equal_approx(s.work_fraction(), frozen), s.work_fraction())
	chk("and the student reads as struggling, so the bar turns red",
		s.is_struggling())

	s.help()
	for i in 200:
		s.tick_work(1.0 / 60.0, null)
	chk("it fills again once you have helped", s.work_fraction() > frozen,
		"%.2f -> %.2f" % [frozen, s.work_fraction()])

	for i in int(Balance.work_seconds * 60.0):
		s.tick_work(1.0 / 60.0, null)
	chk("at 100% the work is done and the bar is dropped",
		s.work_state == StudentData.Work.DONE)
	chk("the node is still alive to draw it", is_instance_valid(node))


# ================================================ term, events, economy

func test_events() -> void:
	section("DAY EVENTS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("a fresh run starts on an ordinary day",
		String(Game.event.get("id", "")) == "none", Game.event)

	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 600:
		seen[String(DayEvent.roll(rng)["id"])] = true
	chk("every event in the table can actually come up",
		seen.size() == DayEvent.TABLE.size(),
		"%d of %d" % [seen.size(), DayEvent.TABLE.size()])

	chk("every event has a name and a blurb the player can read", (func() -> bool:
		for e: Dictionary in DayEvent.TABLE:
			if String(e.get("name", "")) == "" or String(e.get("blurb", "")) == "":
				return false
		return true).call())

	# the multipliers must actually reach the systems they claim to
	Game.event = DayEvent.by_id("restless")
	var restless := Game.event_stall_multiplier()
	Game.event = DayEvent.by_id("focused")
	var focused := Game.event_stall_multiplier()
	chk("a restless day really does make stalls more likely",
		restless > 1.0 and focused < 1.0, "%.2f vs %.2f" % [restless, focused])

	Game.event = DayEvent.by_id("short_day")
	var short := Game.lesson_length()
	Game.event = DayEvent.by_id("long_day")
	var long := Game.lesson_length()
	Game.event = DayEvent.by_id("none")
	chk("assembly shortens the lesson and a double period lengthens it",
		short < Balance.lesson_seconds and long > Balance.lesson_seconds,
		"%.0f / %.0f / %.0f" % [short, Balance.lesson_seconds, long])

	# A student's favourite should genuinely help them. Note it is a STRAND
	# (math / ela / science / social), not a subject word: lessons are real
	# curriculum entries now, and stall_chance reads Game.lesson_strand().
	# Setting Game.subject alone does nothing, which is what this used to do.
	var s := StudentData.new()
	s.aptitude = 0.5
	s.favourite = "math"
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	var good_day := s.stall_chance()
	Game.lesson = Curriculum.by_id("reading_fluency")
	var normal_day := s.stall_chance()
	chk("a student stalls less on a lesson in their own strand",
		good_day < normal_day, "%.4f (%s) vs %.4f (%s)" % [
			good_day, Game.lesson_strand(), normal_day,
			String(Curriculum.by_id("reading_fluency").get("strand", "?"))])

	s.misjudged = true
	chk("and more if you waved their homework through",
		s.stall_chance() > normal_day)


func test_economy() -> void:
	section("ECONOMY")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	chk("you start with something to spend", Game.coins > 0)
	chk("the cheapest item is affordable on day one", (func() -> bool:
		for id: String in Items.order():
			if Game.can_afford(Items.cost(id)):
				return true
		return false).call())

	# upkeep: coins must not simply pile up once the room is capped
	Game.new_run(SEED)
	Game.add_coins(5000)
	for i in 6:
		Game.room_items.append({"id": "plant", "tile": Vector2i(2 + i, 8)})
	var before: int = Game.coins
	for s: StudentData in Game.roster:
		s.last_grade = 0.0
		s.grades.append(0.0)
	Game.advance_day()
	chk("furniture costs something to keep",
		Game.coins < before, "%d -> %d" % [before, Game.coins])

	chk("selling gives back half, rounded down",
		Game.sell_value("bookshelf") == int(floor(Items.cost("bookshelf") * Balance.sell_fraction)))
	chk("upkeep cannot push you into debt", (func() -> bool:
		Game.coins = 0
		Game.advance_day()
		return Game.coins >= 0).call())


func test_term() -> void:
	section("END OF TERM")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	chk("a run does not start finished", not Game.term_over)
	chk("a term is a fixed number of days", Balance.term_days > 0)

	# a class that did well should pass; one that did badly should not
	for s: StudentData in Game.roster:
		s.grades.assign([0.9, 0.92, 0.88])
	var good := Game.sit_exam()
	chk("a class you taught well passes its exam",
		int(good["passed"]) == int(good["total"]), good)
	chk("the exam reports a letter for the class",
		String(good["letter"]) == "A" or String(good["letter"]) == "B", good["letter"])

	for s: StudentData in Game.roster:
		s.grades.assign([0.2, 0.25, 0.18])
	var bad := Game.sit_exam()
	chk("a class you neglected does not", int(bad["passed"]) == 0, bad)
	chk("every student gets a row in the result",
		bad["rows"].size() == Game.roster.size())
	chk("a better term really does produce a better exam",
		float(good["average"]) > float(bad["average"]))

	# the room they sat in counts toward the exam too
	for s: StudentData in Game.roster:
		s.grades.assign([0.5])
	var bare := float(Game.sit_exam()["average"])
	# beside the seats the students actually occupy -- placed anywhere else
	# they are out of range and correctly count for nothing
	for s2: StudentData in Game.roster:
		Game.room_items.append({
			"id": "lab_bench",
			"tile": Layout.seat(s2.seat_index) + Vector2i(1, 0)})
	var furnished := float(Game.sit_exam()["average"])
	chk("the room you built them counts toward the exam",
		furnished > bare, "%.3f vs %.3f" % [furnished, bare])
	Game.room_items.clear()

	# rolling past the last day ends the term
	Game.new_run(SEED)
	var guard := 0
	while not Game.term_over and guard < 200:
		Game.advance_day()
		guard += 1
	chk("playing past the last day ends the term", Game.term_over, guard)
	chk("and it ends at about the right time",
		guard <= Balance.term_days + 2, guard)


# ====================================================== settings & title

func test_settings() -> void:
	section("SETTINGS")
	Settings.reset_all()

	chk("every rebindable action has a default binding", (func() -> bool:
		for entry: Dictionary in Settings.ACTIONS:
			var a := String(entry["action"])
			if not Settings.DEFAULTS.has(a) or (Settings.DEFAULTS[a] as Array).is_empty():
				return false
		return true).call())
	chk("every action reaches the real InputMap", (func() -> bool:
		for entry: Dictionary in Settings.ACTIONS:
			var a := String(entry["action"])
			if not InputMap.has_action(a) or InputMap.action_get_events(a).is_empty():
				return false
		return true).call())
	chk("every action has a label a player can read", (func() -> bool:
		for entry: Dictionary in Settings.ACTIONS:
			if String(entry.get("label", "")) == "":
				return false
		return true).call())

	# rebinding
	chk("rebinding takes effect immediately", (func() -> bool:
		var err := Settings.rebind("interact", KEY_J)
		if err != "":
			return false
		for ev in InputMap.action_get_events("interact"):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_J:
				return true
		return false).call())
	chk("the controls screen shows the new key",
		Settings.binding_text("interact").findn("J") >= 0,
		Settings.binding_text("interact"))

	# THE thing a controls screen must not do: leave one key on two actions
	Settings.reset_bindings()
	Settings.rebind("sprint", KEY_E)      # E is interact's default
	var clash := 0
	for entry: Dictionary in Settings.ACTIONS:
		for code: int in Settings.bindings.get(String(entry["action"]), []):
			if code == KEY_E:
				clash += 1
	chk("a key taken from another action is not left bound to both",
		clash == 1, "%d actions still hold E" % clash)
	chk("and the action it was taken from is not left unusable",
		not (Settings.bindings["interact"] as Array).is_empty())

	chk("Escape cannot be stolen from Back",
		Settings.rebind("interact", KEY_ESCAPE) != "")

	Settings.reset_bindings()
	chk("resetting restores the defaults",
		Settings.bindings["interact"] == Settings.DEFAULTS["interact"])

	# volumes
	Settings.master_volume = 0.5
	Settings.sfx_volume = 0.25
	Settings.apply_audio()
	chk("sfx volume reaches the sound system", Sfx.enabled and Sfx.volume_db < 0.0)
	Settings.sfx_volume = 0.0
	Settings.apply_audio()
	chk("zero volume actually silences it", not Sfx.enabled)
	Settings.sfx_volume = 0.9
	Settings.apply_audio()

	# persistence, and it must be separate from the save file
	Settings.window_scale = 5
	Settings.show_hints = false
	Settings.rebind("menu", KEY_C)
	Settings.save_settings()
	var snapshot := Settings.to_dict()
	Settings.from_dict({})
	chk("wiping settings in memory really does reset them",
		Settings.window_scale != 5 or Settings.show_hints)
	Settings.load_settings()
	chk("settings survive a reload", Settings.to_dict() == snapshot)
	chk("...including the rebound key",
		Settings.binding_text("menu").findn("C") >= 0)

	Game.delete_save()
	chk("erasing the SAVE does not erase your settings",
		Settings.window_scale == 5 and not Settings.show_hints)

	chk("a corrupt settings file falls back to defaults rather than crashing",
		(func() -> bool:
			var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
			f.store_string("{ not json at all")
			f.close()
			Settings.load_settings()
			return not Settings.bindings.is_empty()).call())
	Settings.reset_all()


func test_title() -> void:
	section("TITLE SCREEN")
	var scene: PackedScene = load("res://scenes/ui/title.tscn")
	chk("the title scene loads", scene != null)
	chk("it is the project's main scene",
		String(ProjectSettings.get_setting("application/run/main_scene"))
			== "res://scenes/ui/title.tscn")

	var t: Node2D = scene.instantiate()
	add_child(t)
	await step(3)

	Game.delete_save()
	t._go(t.Page.MAIN)
	chk("with no save there is no Continue option",
		not t._rows().has("continue"), t._rows())
	chk("but you can always start a new term", t._rows().has("new"))

	Game.new_run(SEED)
	Game.day = 7
	Game.save_game()
	t._go(t.Page.MAIN)
	chk("with a save, Continue appears", t._rows().has("continue"))
	chk("and it can say which day you were on", Game.saved_day() == 7, Game.saved_day())
	chk("erasing is only offered when there is something to erase",
		t._rows().has("wipe"))

	# every page must be reachable and non-empty
	var pages := [t.Page.MAIN, t.Page.SETTINGS, t.Page.CONTROLS,
		t.Page.HOWTO, t.Page.CREDITS, t.Page.CONFIRM_WIPE]
	var all_ok := true
	for p: int in pages:
		t._go(p)
		if t.menu.text.strip_edges() == "" and p != t.Page.MAIN:
			all_ok = false
	chk("every page renders something", all_ok)

	t._go(t.Page.SETTINGS)
	chk("the settings page lists a volume row", t._rows().has("master"))
	var before: float = Settings.sfx_volume
	t.sel = t._rows().find("sfx")
	t._adjust(-1)
	chk("Left really does turn the volume down", Settings.sfx_volume < before)
	t._adjust(1)

	t._go(t.Page.CONTROLS)
	chk("the controls page lists every rebindable action", (func() -> bool:
		for entry: Dictionary in Settings.ACTIONS:
			if not t._rows().has(String(entry["action"])):
				return false
		return true).call())

	t._go(t.Page.CONFIRM_WIPE)
	chk("erasing asks first, and No comes before Yes",
		t._rows() == ["no", "yes"], t._rows())

	# selecting No must keep the save
	Game.new_run(SEED)
	Game.save_game()
	t._go(t.Page.CONFIRM_WIPE)
	t.sel = 0
	t._activate()
	chk("answering No keeps your save", Game.has_save())

	t._go(t.Page.CONFIRM_WIPE)
	t.sel = 1
	t._activate()
	chk("answering Yes erases it", not Game.has_save())

	t.queue_free()
	await step(2)
	Game.delete_save()


func test_sprint() -> void:
	section("SPRINT")
	chk("sprint is a real, bound action",
		InputMap.has_action("sprint")
		and not InputMap.action_get_events("sprint").is_empty())

	Game.delete_save()
	Game.new_run(SEED)
	# row 6 is the clear aisle between the front desks (row 5) and the back
	# seats (row 7). Row 5 has desks in it, so both runs used to stop dead
	# against the same one and "sprint" looked like it did nothing.
	var start := Grid.tile_to_world(Vector2i(3, 6))
	world.player.global_position = start
	await step(2)
	await hold("move_right", 30)
	var walked: float = world.player.global_position.x - start.x

	world.player.global_position = start
	await step(2)
	Input.action_press("sprint")
	await hold("move_right", 30)
	Input.action_release("sprint")
	var sprinted: float = world.player.global_position.x - start.x

	chk("holding sprint covers more ground in the same time",
		sprinted > walked, "%.0f vs %.0f px in 30 frames" % [sprinted, walked])
	chk("and it is the multiplier the code says it is",
		absf(sprinted / maxf(1.0, walked) - Actor.SPRINT) < 0.25,
		"%.2fx" % (sprinted / maxf(1.0, walked)))


# ============================================ two buttons, and real lessons

func test_buttons() -> void:
	section("TWO BUTTONS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var frames := 0
	while frames < 2500 and not world.everyone_seated():
		await step(20)
		frames += 20

	chk("manage is a real, separately bound action",
		InputMap.has_action("manage")
		and not InputMap.action_get_events("manage").is_empty())
	chk("it is not the same key as interact", (func() -> bool:
		var use := {}
		for ev in InputMap.action_get_events("interact"):
			if ev is InputEventKey:
				use[(ev as InputEventKey).physical_keycode] = true
		for ev in InputMap.action_get_events("manage"):
			if ev is InputEventKey and use.has((ev as InputEventKey).physical_keycode):
				return false
		return true).call())

	# the important split: session-level things are NOT on the use button
	chk("the podium is a manage thing", world.podium.action_name() == "manage")
	chk("the bell is a manage thing", world.bell.action_name() == "manage")
	chk("the noticeboard is a manage thing", world.noticeboard.action_name() == "manage")
	chk("a student's desk is on the ordinary use button",
		world.station(0).action_name() == "interact")
	chk("and so is your own desk", world.teacher_desk.action_name() == "interact")

	# THE BUG THIS FIXES.
	# Standing at the podium and pressing the button you mash all lesson
	# long used to end the lesson.
	Game.set_phase(Game.Phase.MORNING)
	world.start_lesson()
	await step(2)
	chk("the lesson is running", Game.phase == Game.Phase.LESSON)
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)
	# The podium has two verbs now (E quizzes, F ends the lesson), so the
	# question is which button points at it, not what the single target is.
	chk("the podium is what MANAGE is pointing at",
		world.player.targets["manage"] == world.podium)
	# E at the podium is the QUICK QUIZ now. That is the point of the split:
	# the mashable button reaches only the safe, reversible verb, however
	# many times you hit it.
	for i in 4:
		await tap("interact")
	chk("mashing the USE button at the podium cannot end the lesson",
		Game.phase == Game.Phase.LESSON, Game.phase)
	chk("all it can do is call a quiz", Game.quiz_done)
	_hud().close()          # the quiz report must not leak into the next test
	await step(2)

	# nor can a TAP of manage, because ending a lesson is held
	chk("ending a lesson requires a hold, not a tap", world.podium.hold_time > 0.0)
	await tap("manage")
	chk("a quick tap of manage does not end it either",
		Game.phase == Game.Phase.LESSON, Game.phase)

	await hold_confirm("manage", 0.9)
	chk("holding manage DOES end the lesson",
		Game.phase == Game.Phase.AFTERNOON, Game.phase)

	# same protection on the bell
	chk("ending the day is a hold too", world.bell.hold_time > 0.0)
	await place_player(Layout.BELL + Vector2i(0, 1), Actor.DIR_UP)
	var day_before: int = Game.day
	for i in 3:
		await tap("interact")
	await tap("manage")
	chk("neither mashing use nor tapping manage ends the day",
		Game.day == day_before, Game.day)

	# ...but HOLDING it must. This was asserted only in the negative until
	# now -- the suite proved the bell could not be rung by accident and
	# never once proved it could be rung on purpose, and it called
	# world.end_day() directly everywhere else.
	chk("the bell is what MANAGE is pointing at",
		world.player.targets["manage"] == world.bell,
		world.player.targets["manage"])
	chk("and it is offering to end the day", world.bell.can_interact())
	await hold_confirm("manage", 0.9)
	chk("holding manage at the bell DOES end the day",
		Game.day == day_before + 1, "day %d, phase %d" % [Game.day, Game.phase])
	_hud().close()
	await step(2)

	# ...but starting a lesson is instant, because it costs nothing to undo
	Game.set_phase(Game.Phase.MORNING)
	for s: StudentData in Game.roster:
		s.reset_lesson()
	await step(2)
	chk("the prompt names the key you actually press",
		world.podium.key_hint() == Settings.binding_text("manage").split(",")[0].strip_edges(),
		world.podium.key_hint())


func test_curriculum() -> void:
	chk("CURRICULUM starts with a clean screen",
		_hud().mode == _hud().Mode.NONE, _hud().title.text)
	section("CURRICULUM")
	Curriculum.ensure_loaded()
	chk("the curriculum loads", Curriculum.count() > 0, Curriculum.count())
	chk("it cites its source documents", Curriculum.sources.size() >= 3)

	var seen_std := {}
	var ok := true
	var bad: Array = []
	for l: Dictionary in Curriculum.lessons:
		for key: String in ["id", "name", "short", "strand", "standard", "source", "objective"]:
			if String(l.get(key, "")).strip_edges() == "":
				ok = false
				bad.append("%s missing %s" % [l.get("name", "?"), key])
		# a fabricated citation is worse than none, so every lesson must
		# carry a real code AND say which document it came from
		if not String(l.get("source", "")).findn("maryland") >= 0 \
				and not String(l.get("source", "")).findn("ngss") >= 0:
			pass
		seen_std[String(l.get("standard", ""))] = true
	chk("every lesson has a name, a standard, a source and an objective", ok, bad)
	chk("no two lessons share a standard code",
		seen_std.size() == Curriculum.count(), seen_std.size())

	chk("every source names a real document", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			var src := String(l.get("source", "")).to_lower()
			if src.find("maryland") < 0:
				return false
		return true).call())

	chk("objectives are real sentences, not placeholders", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			if String(l["objective"]).length() < 40:
				return false
		return true).call())

	# strands, which are what tie a lesson to its homework
	var strands := Curriculum.strands()
	chk("there are several subject strands", strands.size() >= 3, strands)
	chk("every strand has a readable label", (func() -> bool:
		for st: String in strands:
			if Curriculum.strand_label(st) == "":
				return false
		return true).call())

	# the game actually teaches them
	Game.new_run(SEED)
	chk("a run starts with a real lesson from the curriculum",
		Game.lesson.has("standard") and Game.subject == String(Game.lesson["name"]),
		Game.subject)
	var picked := {}
	for i in 200:
		picked[Game.pick_subject()] = true
	chk("over a term you teach the whole curriculum",
		picked.size() == Curriculum.count(), picked.size())

	# homework must come from the lesson's own strand
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var math_sheet := Questions.make_sheet(1.0, rng, "math")
	var ela_sheet := Questions.make_sheet(1.0, rng, "ela")
	chk("a maths lesson sets maths homework",
		String(math_sheet["items"][0]["q"]).findn("x") >= 0
		or String(math_sheet["items"][0]["q"]).findn("+") >= 0,
		math_sheet["items"][0]["q"])
	chk("an English lesson does NOT set arithmetic", (func() -> bool:
		for it: Dictionary in ela_sheet["items"]:
			var q := String(it["q"])
			if q.findn(" x ") >= 0 or q.findn(" + ") >= 0:
				return false
		return true).call())
	chk("every strand has its own bank of questions", (func() -> bool:
		var seen := {}
		for st: String in strands:
			var b: Array = Questions.bank_for(st)
			if b.size() < 4:
				return false
			seen[str(b[0])] = true
		return seen.size() >= 3).call())

	# a student's favourite is a strand, and it still helps them
	Game.new_run(SEED)
	var s := StudentData.new()
	s.aptitude = 0.5
	s.favourite = "math"
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	var good := s.stall_chance()
	Game.lesson = Curriculum.by_id("reading_fluency")
	var other := s.stall_chance()
	chk("a student does better on a lesson in their own strand",
		good < other, "%.4f(%s) vs %.4f(%s) fav=%s bonus=%.2f" % [
			good, String(Curriculum.by_id("basic_arithmetic").get("strand", "?")),
			other, String(Curriculum.by_id("reading_fluency").get("strand", "?")),
			s.favourite, Balance.affinity_bonus])

	# and the lesson survives a save
	Game.new_run(SEED)
	var was := String(Game.lesson.get("id", ""))
	var snap := Game.to_dict()
	Game.from_dict(snap)
	chk("the lesson survives a save/load", String(Game.lesson.get("id", "")) == was,
		Game.lesson.get("id", ""))


# =============================================== names, and a file per child

func test_names() -> void:
	section("NAMES")
	Balance.ensure_loaded()

	chk("the first-name pool comfortably outnumbers the class",
		Names.FIRST.size() > Balance.class_cap * 2,
		"%d names, cap %d" % [Names.FIRST.size(), Balance.class_cap])
	chk("no name appears twice in the pool itself", (func() -> bool:
		var seen := {}
		for n: String in Names.FIRST:
			if seen.has(n):
				return false
			seen[n] = true
		var seen2 := {}
		for n: String in Names.LAST:
			if seen2.has(n):
				return false
			seen2[n] = true
		return true).call())

	# THE BUG THIS FIXES. The old generator drew independently with no memory
	# of the roster, so at a class of eight there was a ~71% chance two
	# students had the same first name -- and every screen in the game shows
	# the first name only.
	var clashes: Array = []
	for i in 40:
		Game.new_run(SEED + i)
		while Game.enrol() != null:
			pass
		var seen := {}
		for s: StudentData in Game.roster:
			if seen.has(s.first_name()):
				clashes.append("seed %d: two %s" % [SEED + i, s.first_name()])
			seen[s.first_name()] = true
	chk("no class ever has two students with the same first name",
		clashes.is_empty(), clashes)

	chk("every student has a surname too", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.surname() == "":
				return false
		return true).call())
	chk("first_name and surname split the display name",
		Game.roster[0].display_name
			== "%s %s" % [Game.roster[0].first_name(), Game.roster[0].surname()])

	# the fallback, which cannot be reached in play but must not return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	chk("an exhausted pool still yields a name",
		Names.unique_name(rng, Names.FIRST.duplicate()) != "")

	# determinism, which the whole suite leans on
	Game.new_run(SEED)
	var first: Array = []
	for s: StudentData in Game.roster:
		first.append(s.display_name)
	Game.new_run(SEED)
	var second: Array = []
	for s: StudentData in Game.roster:
		second.append(s.display_name)
	chk("the same seed still produces the same class", first == second, first)


func test_bio() -> void:
	section("STUDENT FILE")
	var hud := _hud()
	var p: Actor = world.player
	Game.new_run(SEED)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	await tap("menu")
	chk("Tab opens the class list", hud.mode == hud.Mode.CLASS_LIST, hud.mode)
	chk("it opens on the first student", hud._sel == 0, hud._sel)
	chk("the selection marker is drawn", hud.body.text.contains(">"))

	await tap("move_down")
	chk("Down moves the selection", hud._sel == 1, hud._sel)
	await tap("move_up")
	await tap("move_up")
	chk("Up from the top wraps to the last student",
		hud._sel == Game.roster.size() - 1, hud._sel)
	await tap("move_down")
	chk("and Down from the bottom wraps back to the first", hud._sel == 0)

	# open a student who is NOT first, so "returns to the same row" means
	# something
	await tap("move_down")
	var who: StudentData = Game.roster[hud._sel]
	var row: int = hud._sel
	await tap("interact")
	chk("E opens their file", hud.mode == hud.Mode.STUDENT, hud.mode)
	chk("the file is headed with their FULL name, surname and all",
		hud.title.text.contains(who.surname()), hud.title.text)
	chk("the portrait is showing", hud.portrait.visible)
	chk("it is their own sprite sheet", (func() -> bool:
		var at := hud.portrait.texture as AtlasTexture
		return at != null and at.atlas.resource_path.ends_with(who.art + ".png")).call(),
		hud.portrait.texture)
	chk("and it is one standing frame, not the whole sheet", (func() -> bool:
		var at := hud.portrait.texture as AtlasTexture
		return at != null and at.region == Rect2(0, 0, 16, 24)).call())
	chk("the file says which seat and when they joined",
		hud.body.text.contains("Seat %d" % (who.seat_index + 1))
		and hud.body.text.contains("day %d" % who.joined_day), hud.body.text)

	# Esc is the way back out of the file. E is no longer -- it acts on the
	# highlighted row now (tuition / parents / send them up), so a player
	# leafing through the class cannot buy something by mashing to exit.
	await tap("cancel")
	chk("Esc goes BACK to the class list rather than out to the game",
		hud.mode == hud.Mode.CLASS_LIST, hud.mode)
	chk("and it comes back on the same student", hud._sel == row, hud._sel)

	await tap("cancel")
	chk("Esc closes the class list", hud.mode == hud.Mode.NONE)
	chk("and hands control back", not p.input_locked)

	# THE DESIGN RULE, enforced rather than trusted: prose, never numbers.
	var s0: StudentData = Game.roster[0]
	s0.aptitude = 0.7321
	s0.diligence = 0.2917
	s0.grades.assign([0.71, 0.83, 0.9])
	s0.hw_set_total = 7
	s0.hw_done_total = 5
	s0.helps_total = 3
	hud.show_student(s0)
	chk("a student's file never shows a raw ability number",
		not hud.body.text.contains("0."), hud.body.text)
	chk("nor a percentage", not hud.body.text.contains("%"), hud.body.text)
	chk("it describes their ability in words",
		hud.body.text.contains("quickly") or hud.body.text.contains("steady")
		or hud.body.text.contains("longer"), hud.body.text)
	chk("it reports homework as a word, not a fraction",
		hud.body.text.contains("most") or hud.body.text.contains("about half")
		or hud.body.text.contains("all"), hud.body.text)
	chk("it says how often you helped them",
		hud.body.text.contains("help"), hud.body.text)
	chk("grades are letters, with a count of lessons",
		hud.body.text.contains("Averaging a") and hud.body.text.contains("3 lesson"),
		hud.body.text)

	# a brand-new student's file must still read as a sentence
	var fresh := StudentData.new()
	fresh.display_name = "Tess Vega"
	fresh.art = "student_a"
	fresh.favourite = "math"
	hud.show_student(fresh)
	chk("an ungraded student's file says so rather than showing a blank",
		hud.body.text.contains("Not been graded"), hud.body.text)
	chk("and it still names them in full", hud.title.text.contains("Vega"))

	# the leak
	s0.misjudged = true
	hud.show_class_list()
	chk("the class list does NOT reveal a sheet you misjudged",
		not hud.body.text.contains("secretly"), hud.body.text)
	hud.show_student(s0)
	chk("and neither does their file", not hud.body.text.contains("secretly"))

	# The regression guard for _open() resetting the portrait. The shop DOES
	# show a picture now, so "not visible" is no longer the invariant -- what
	# must not happen is the child's face still hanging there over the
	# furniture, which is the actual leak this guard was written for.
	var face: Texture2D = hud.portrait.texture
	hud.close()
	Game.add_coins(500)
	hud.open_catalogue()
	chk("a child's face does not leak into the shop", hud.portrait.texture != face)
	hud.close()
	await step(2)


func test_lifetime_counters() -> void:
	chk("LIFETIME starts with a clean screen",
		_hud().mode == _hud().Mode.NONE, _hud().title.text)
	section("LIFETIME COUNTERS")
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]

	chk("a starting student joined on day one", s.joined_day == 1, s.joined_day)
	Game.day = 7
	var late := Game.enrol()
	chk("a student who joins mid-term records the day they arrived",
		late != null and late.joined_day == 7, late.joined_day if late else -1)
	Game.day = 1

	# helping is remembered past the end of the lesson -- helps_received is
	# wiped by reset_lesson(), which is exactly why a second counter exists
	s.assign_work()
	s.confusion = 1.0
	chk("helping counts", s.help() and s.helps_total == 1 and s.helps_received == 1)
	s.reset_lesson()
	chk("resetting the lesson clears the per-lesson count but NOT the total",
		s.helps_received == 0 and s.helps_total == 1,
		"%d / %d" % [s.helps_received, s.helps_total])

	# homework set and handed in
	Game.new_run(SEED)
	var n := Game.assign_homework()
	chk("setting homework is counted against every student", (func() -> bool:
		for st: StudentData in Game.roster:
			if st.hw_set_total != 1:
				return false
		return true).call(), n)
	for st: StudentData in Game.roster:
		st.last_grade = 0.7
		st.grades.append(0.7)
	var report := Game.advance_day()
	var done := 0
	for st: StudentData in Game.roster:
		done += st.hw_done_total
	chk("handing homework in is counted, and agrees with the day report",
		done == int(report["homework_done"]),
		"%d counted vs %d reported" % [done, int(report["homework_done"])])

	# and all four survive a save
	var t: StudentData = Game.roster[0]
	t.joined_day = 4
	t.helps_total = 11
	t.hw_set_total = 9
	t.hw_done_total = 6
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	var back: StudentData = Game.roster[0]
	chk("the lifetime counters survive a save and reload",
		back.joined_day == 4 and back.helps_total == 11
		and back.hw_set_total == 9 and back.hw_done_total == 6,
		"%d/%d/%d/%d" % [back.joined_day, back.helps_total,
			back.hw_set_total, back.hw_done_total])
	Game.delete_save()


# ==================================================== levels & graduation

func test_student_levels() -> void:
	section("STUDENT LEVELS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]

	chk("a new student starts at level one with no experience",
		s.level == 1 and s.xp == 0)
	chk("and is not ready to be sent up", not s.is_ready_to_graduate())

	var apt := s.aptitude
	var gained := s.add_xp(s.xp_for_next_level())
	chk("enough experience levels them up", gained == 1 and s.level == 2, s.level)
	chk("a level makes them a little better at the work", s.aptitude > apt)
	chk("but only a little, not a transformation",
		s.aptitude - apt < 0.1, s.aptitude - apt)

	# readiness is a threshold, not the top of the scale
	# one xp at a time, so we stop ON the threshold instead of sailing past it
	# -- see the note in test_graduation about xp being cumulative
	while s.level < Balance.stu_ready_level:
		s.add_xp(1)
	chk("they become ready at the ready level", s.is_ready_to_graduate(), s.level)
	chk("a child who has just qualified is barely prepared",
		s.readiness() < 0.2, s.readiness())

	# THE SOFT COST OF HOLDING THEM BACK: they stop learning from you.
	while not s.is_capped() and s.level < Balance.stu_max_level:
		s.add_xp(s.xp_for_next_level())
	var frozen_level := s.level
	var frozen_apt := s.aptitude
	for i in 20:
		s.add_xp(1000)
	chk("a child kept long past ready stops gaining anything",
		s.level == frozen_level and is_equal_approx(s.aptitude, frozen_apt),
		"%d -> %d" % [frozen_level, s.level])
	chk("which is a stagnation, not a punishment - nothing got worse",
		s.aptitude >= frozen_apt)

	# helping earns them experience too
	Game.new_run(SEED)
	var t: StudentData = Game.roster[1]
	var before := t.xp
	t.assign_work()
	t.confusion = 1.0
	t.help()
	chk("being helped is worth something to them", t.xp > before, t.xp)

	# and so is a lesson
	Game.new_run(SEED)
	var u: StudentData = Game.roster[0]
	var xp0 := u.xp
	Game.grade_class()
	chk("finishing a lesson earns experience", u.xp > xp0, u.xp)

	# save
	u.xp = 137
	u.level = 4
	u.coached = 2
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("levels and coaching survive a save",
		Game.roster[0].xp == 137 and Game.roster[0].level == 4
		and Game.roster[0].coached == 2)
	Game.delete_save()


func test_teacher_levels() -> void:
	section("TEACHER LEVELS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("you start at level one with nothing spent",
		Game.teacher_level == 1 and Game.perk_points_spent() == 0)
	chk("and with no points to spend yet", Game.perk_points_free() == 0)
	chk("so a perk cannot be bought", Game.buy_perk("brisk_walk") != "")

	Game.add_teacher_xp(Balance.teacher_xp_per_level)
	chk("experience levels you up", Game.teacher_level == 2, Game.teacher_level)
	chk("and a level is a point to spend", Game.perk_points_free() == 1)

	chk("a point buys a perk", Game.buy_perk("brisk_walk") == "")
	chk("which spends it", Game.perk_points_free() == 0
		and Game.perk_rank("brisk_walk") == 1)
	chk("and you cannot spend what you do not have",
		Game.buy_perk("long_reach") != "")

	# every perk must actually reach the number it claims to change
	var none := {}
	chk("Brisk Walk really does make you faster",
		Progress.speed({"brisk_walk": 2}) > Progress.speed(none))
	chk("Long Reach really does widen your reach",
		Progress.pick_radius({"long_reach": 1}) > Progress.pick_radius(none))
	chk("Steady Hands really does let you carry everything",
		Progress.carries_unlimited({"steady_hands": 1})
		and not Progress.carries_unlimited(none))
	chk("Calm Presence really does settle them",
		Progress.calm_multiplier({"calm_presence": 1}) < 1.0
		and is_equal_approx(Progress.calm_multiplier(none), 1.0))
	chk("Practised Marker really does cut the pile",
		Progress.sheets_skipped({"practised_marker": 2}) > 0
		and Progress.sheets_skipped(none) == 0)

	chk("a perk cannot be bought past its top rank", (func() -> bool:
		var id := "steady_hands"
		Game.add_teacher_xp(Balance.teacher_xp_per_level * 6)
		Game.buy_perk(id)
		return Game.buy_perk(id) != "").call())
	chk("nonsense is refused", Game.buy_perk("fly") != "")

	# teaching a day earns you something
	Game.new_run(SEED)
	var xp0: int = Game.teacher_xp
	for s: StudentData in Game.roster:
		s.last_grade = 0.8
		s.grades.append(0.8)
	Game.advance_day()
	chk("a day taught is experience for you too", Game.teacher_xp > xp0)

	# save
	Game.perk_ranks = {"brisk_walk": 2}
	Game.teacher_xp = 350
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("your level and perks survive a save",
		Game.teacher_xp == 350 and Game.perk_rank("brisk_walk") == 2
		and Game.teacher_level == Progress.level_for_xp(350))
	Game.delete_save()


func test_graduation() -> void:
	section("GRADUATION")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]
	var who := s.display_name

	chk("a child who is not ready cannot be sent up", Game.graduate(s).is_empty())
	chk("and nothing happened to the class", Game.roster.has(s))

	while not s.is_ready_to_graduate():
		s.add_xp(s.xp_for_next_level())
	var size_before := Game.roster.size()
	var coins_before: int = Game.coins
	var xp_before: int = Game.teacher_xp
	var rec := Game.graduate(s)

	chk("a ready child can be sent up", not rec.is_empty())
	chk("they leave the class", not Game.roster.has(s))
	chk("and it is recorded", Game.graduated.size() == 1
		and String(Game.graduated[0]["name"]) == who)
	chk("their desk is filled by someone new",
		Game.roster.size() == size_before, Game.roster.size())
	chk("the new arrival is a different child",
		Game.roster[Game.roster.size() - 1].display_name != who)

	# THE TRAP THIS AVOIDS. If sending a strong student up were a pure loss,
	# the best play would be to never graduate anyone -- which is not a
	# decision at all. It pays immediately, in coins and in your own
	# experience, so it trades against a thinner class at exam time.
	chk("sending them up pays", Game.coins > coins_before,
		"%d -> %d" % [coins_before, Game.coins])
	chk("and teaches you something", Game.teacher_xp > xp_before)

	# seeing a child all the way through is worth more than the minimum
	Game.new_run(SEED)
	var a: StudentData = Game.roster[0]
	# A single xp at a time, so this stops the INSTANT they qualify. xp is
	# cumulative while the bar is only level*per_level, so handing over a whole
	# xp_for_next_level() cascades several levels at once and sails past ready
	# to the cap -- which made "sent up the moment they qualify" and "seen all
	# the way through" the same child, and the comparison below vacuous.
	while not a.is_ready_to_graduate():
		a.add_xp(1)
	var min_pay := Balance.grad_base_coins
	var b: StudentData = Game.roster[1]
	# As far as a child is ALLOWED to go, which is is_capped() -- not
	# stu_max_level. add_xp() refuses once capped, so looping on the raw max
	# never terminates. That hang silently truncated every suite run for a
	# whole session, taking the summary line with it.
	while not b.is_capped():
		b.add_xp(b.xp_for_next_level())
	Game.coins = 0
	Game.graduate(a)
	var paid_early: int = Game.coins
	Game.coins = 0
	Game.graduate(b)
	chk("a child seen further through is worth more than one sent the moment they qualify",
		Game.coins > paid_early, "%d vs %d" % [Game.coins, paid_early])
	chk("and the minimum is what the table says", paid_early == min_pay, paid_early)

	chk("graduations survive a save", (func() -> bool:
		Game.save_game()
		var n := Game.graduated.size()
		Game.new_run(1)
		Game.load_game()
		return Game.graduated.size() == n).call())
	Game.delete_save()


func test_coaching() -> void:
	section("COACHING")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]
	Game.coins = 100000

	var apt := s.aptitude
	chk("extra tuition can be bought", Game.coach(s, "tuition") == "")
	chk("and it makes them better at the work", s.aptitude > apt)

	var dil := s.diligence
	chk("a word with the parents can be bought", Game.coach(s, "parents") == "")
	chk("and it makes them more reliable", s.diligence > dil)

	# rising cost is what makes it a decision about WHO rather than a tax
	var first := s.coaching_cost(Balance.coach_tuition_cost)
	Game.coach(s, "tuition")
	chk("each session for the same child costs more than the last",
		s.coaching_cost(Balance.coach_tuition_cost) > first,
		"%d then %d" % [first, s.coaching_cost(Balance.coach_tuition_cost)])
	chk("a child you have not spent on is still cheap",
		Game.roster[1].coaching_cost(Balance.coach_tuition_cost) < first + 1)

	while s.can_be_coached():
		Game.coach(s, "tuition")
	chk("there is a limit to how much extra one child can be given",
		Game.coach(s, "tuition") != "")

	Game.coins = 0
	chk("and you cannot coach on an empty purse",
		Game.coach(Game.roster[2], "tuition") != "")


func test_shop_and_staff() -> void:
	section("SHOP & STAFF ROOM")
	var hud := _hud()
	Game.new_run(SEED)
	Game.add_coins(3000)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	hud.open_catalogue()
	chk("the shop opens on the buy list", hud._shop == hud.Shop.BUY)
	chk("you can SEE what you are buying", hud.portrait.visible)
	chk("the picture is the item you have selected", (func() -> bool:
		var want := String(Items.get_def(Items.order()[hud._sel]).get("art", ""))
		return hud.portrait.texture != null \
			and hud.portrait.texture.resource_path.ends_with(want + ".png")).call())
	chk("effects read as words, not decimals",
		hud.body.text.contains("helps") and not hud.body.text.contains("+0."),
		hud.body.text)

	await tap("menu")
	chk("Tab moves to the sell list", hud._shop == hud.Shop.SELL)
	await tap("menu")
	chk("Tab again reaches the staff room", hud._shop == hud.Shop.STAFF)
	chk("which shows your level", hud.body.text.contains("Level"), hud.body.text)
	chk("and no picture, because there is nothing to look at",
		not hud.portrait.visible)
	await tap("menu")
	chk("Tab again reaches the room itself", hud._shop == hud.Shop.ROOM)
	chk("which tells you how big your classroom is",
		hud.body.text.contains("%d by %d" % [Grid.W, Grid.H]), hud.body.text)
	await tap("menu")
	chk("and Tab cycles back round to buying", hud._shop == hud.Shop.BUY)

	# spending a point through the real screen
	Game.add_teacher_xp(Balance.teacher_xp_per_level * 3)
	await tap("menu")
	await tap("menu")
	var spent_before: int = Game.perk_points_spent()
	await tap("interact")
	chk("E in the staff room spends a point",
		Game.perk_points_spent() == spent_before + 1,
		Game.perk_points_spent())
	await tap("cancel")
	await step(2)


func test_bio_actions() -> void:
	section("ACTING ON A FILE")
	var hud := _hud()
	Game.new_run(SEED)
	Game.add_coins(5000)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	var s: StudentData = Game.roster[0]
	hud.show_student(s)
	chk("the file offers what you can do for them",
		hud.body.text.contains("Extra tuition")
		and hud.body.text.contains("Send them up"), hud.body.text)
	chk("and says plainly when they are not ready",
		hud.body.text.contains("not ready yet"), hud.body.text)

	var apt := s.aptitude
	hud._bio_sel = hud.Act.TUITION
	await tap("interact")
	chk("buying tuition from the file works", s.aptitude > apt, s.aptitude)
	chk("the file is still open afterwards", hud.mode == hud.Mode.STUDENT)

	await tap("move_down")
	chk("Down moves between the actions", hud._bio_sel == hud.Act.PARENTS)

	# graduating through the real screen
	while not s.is_ready_to_graduate():
		s.add_xp(s.xp_for_next_level())
	hud.show_student(s)
	chk("once ready, the file offers the payout rather than a refusal",
		not hud.body.text.contains("not ready yet"), hud.body.text)
	hud._bio_sel = hud.Act.GRADUATE
	await tap("interact")
	chk("sending them up leaves the file and says goodbye properly",
		hud.mode == hud.Mode.REPORT and hud.title.text.contains("MOVING UP"),
		hud.title.text)
	chk("and they really have gone", not Game.roster.has(s))

	await tap("interact")
	await step(2)
	hud.close()

	# the design rule still holds on the file
	var t: StudentData = Game.roster[0]
	t.aptitude = 0.7321
	hud.show_student(t)
	chk("a file with actions on it still shows no raw ability number",
		not hud.body.text.contains("0."), hud.body.text)
	hud.close()
	await step(2)


# ============================================ catalogue, curator, cheats

func test_catalogue() -> void:
	section("CATALOGUE")
	Balance.ensure_loaded()

	chk("the shop has grown well past a handful",
		Items.order().size() >= 24, Items.order().size())
	chk("there are several categories", Items.categories().size() >= 4,
		Items.categories())

	var bad: Array = []
	for id: String in Items.order():
		var d := Items.get_def(id)
		for key: String in ["name", "cat", "cost", "art", "range", "bonus", "blurb"]:
			if not d.has(key):
				bad.append("%s missing %s" % [id, key])
		if not Items.categories().has(String(d.get("cat", ""))):
			bad.append("%s has an unknown category" % id)
	chk("every item is complete and in a real category", bad.is_empty(), bad)

	# THE CHECK THE ART BROWSER EXISTS FOR: a missing PNG is a runtime crash
	var missing: Array = []
	for id: String in Items.order():
		var art := String(Items.get_def(id).get("art", ""))
		if not ResourceLoader.exists("res://art/%s.png" % art):
			missing.append("%s -> %s.png" % [id, art])
	chk("every item's picture actually exists", missing.is_empty(), missing)

	chk("every category has something in it", (func() -> bool:
		for c: String in Items.categories():
			if Items.in_category(c).is_empty():
				return false
		return true).call())
	chk("the categories partition the catalogue with nothing left over",
		(func() -> bool:
			var n := 0
			for c: String in Items.categories():
				n += Items.in_category(c).size()
			return n == Items.order().size()).call())

	# prices should broadly rise with what an item does, or the choice is fake
	var cheap_bonus := 0.0
	var dear_bonus := 0.0
	for id: String in Items.order():
		var d := Items.get_def(id)
		if int(d["cost"]) <= 90:
			cheap_bonus = maxf(cheap_bonus, float(d["bonus"]))
		if int(d["cost"]) >= 240:
			dear_bonus = maxf(dear_bonus, float(d["bonus"]))
	chk("expensive furniture does more than cheap furniture",
		dear_bonus > cheap_bonus, "%.2f vs %.2f" % [dear_bonus, cheap_bonus])

	chk("no two items share a name", (func() -> bool:
		var seen := {}
		for id: String in Items.order():
			var n := String(Items.get_def(id)["name"])
			if seen.has(n):
				return false
			seen[n] = true
		return true).call())


func test_curator() -> void:
	section("ART BROWSER")
	var c: Control = load("res://tools/curator.tscn").instantiate()
	add_child(c)
	c._scan_references()
	c._scan_files()

	chk("it finds the art", c._files.size() >= 40, c._files.size())
	chk("it finds where art is used", c._referenced.size() > 10, c._referenced.size())
	# This is the assertion that matters: art named in code or data but not
	# on disk would fail at runtime, and nothing else in the project checks.
	chk("nothing the game asks for is missing from disk",
		c._missing.is_empty(), c._missing)
	chk("it knows which script uses the player sprite",
		c._referenced.get("player", []).size() > 0)
	# The room tiles are loaded by a name built at runtime, so no regex over
	# the source can find them. If the curator does not know about them it
	# reports eighteen false alarms, and a report you have learned to ignore
	# is worth nothing.
	chk("and about the room tiles, which no regex could find",
		c._referenced.has("tile_floor_a0") and c._referenced.has("tile_wall_side"))
	# Nothing on disk should be unexplained. The two exceptions are sample
	# art for the text-grid sprite pipeline (tools/sprites/*.txt), which
	# exists to demonstrate that pipeline rather than to be used -- they are
	# named here so that a THIRD orphan appearing is a failure rather than
	# something that blends into an accepted list.
	const ART_SAMPLES := ["table", "poster_abc"]
	chk("nothing on disk is left unexplained", (func() -> bool:
		for f: String in c._files:
			if not c._referenced.has(f) and not ART_SAMPLES.has(f):
				return false
		return true).call(), (func() -> Array:
			var orphans: Array = []
			for f: String in c._files:
				if not c._referenced.has(f) and not ART_SAMPLES.has(f):
					orphans.append(f)
			return orphans).call())
	c.queue_free()


func test_cheats() -> void:
	section("CHEATS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("a fresh run is not marked as cheated", not Game.cheated)
	chk("and coins are finite", not Game.unlimited_coins)
	Game.coins = 10
	chk("so you cannot buy what you cannot afford", not Game.spend(500))

	Game.unlimited_coins = true
	Game.cheated = true
	chk("unlimited coins buys anything", Game.spend(999999))
	chk("and everything reads as affordable", Game.can_afford(123456))

	# the flag has to survive, or a cheated save launders itself clean
	Game.save_game()
	Game.new_run(1)
	chk("a new run clears the flag", not Game.cheated)
	Game.load_game()
	chk("but a cheated save is still marked when reloaded", Game.cheated)
	Game.delete_save()

	Game.new_run(SEED)
	Game.cheated = false
	Game.unlimited_coins = false
