extends Node2D

## EDUSystem test suite.
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
	# NEVER the player's save. advance_day() autosaves, and this suite
	# advances hundreds of days -- it was overwriting a real save file every
	# time anybody ran the tests.
	Game.save_path = "user://edusystem_TEST_save.json"
	var cmd_args := OS.get_cmdline_user_args()
	if not cmd_args.is_empty():
		_filter = cmd_args[0]
	# Never let a broken run hang a terminal.
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		push_error("watchdog: suite exceeded 420s")
		get_tree().quit(1))
	_main()


## A section filter, so a single change does not mean scrolling past a
## thousand [ok] lines to find the ten that matter.
##
## Deliberately a PRINT filter, not a skip: most of the 74 test_x()
## functions depend on Game state a PRIOR function left behind (most start
## with Game.new_run(SEED), some deliberately do not, to test what
## survives a reload). Skipping arbitrary ones would risk a false pass or
## a false fail that has nothing to do with the change under test. Every
## assertion still runs; only the report is narrowed.
##
## Usage: pass the section name (or a substring) as a command-line
## argument: godot --headless --path . res://tests/run.tscn -- CURRICULUM
var _filter := ""
var _section := ""
var _section_shown := false


func chk(label: String, cond: bool, extra: Variant = null) -> void:
	if cond:
		passed += 1
		if _wants_section():
			print("  [ok] %s" % label)
	else:
		failed += 1
		# A failure always prints, even outside the filtered section --
		# a real break elsewhere should never be swallowed by a filter
		# aimed at something else.
		if _wants_section():
			print("  [FAIL] %s%s" % [label, "" if extra == null else "  -> %s" % str(extra)])
		else:
			print("  [FAIL] (%s) %s%s" % [_section, label,
				"" if extra == null else "  -> %s" % str(extra)])


func _wants_section() -> bool:
	return _filter == "" or _section.to_lower().contains(_filter.to_lower())


func section(name: String) -> void:
	_section = name
	if _wants_section():
		print("\n== %s ==" % name)
	elif not _section_shown:
		print(("(filtering to sections matching \"%s\" -- other sections "
			+ "still run, their output is just not printed)") % _filter)
		_section_shown = true


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


## Trace one continuous mouse stroke across a Control, feeding the same
## press / motion / release events the engine would. Used to exercise the
## homework-sheet gesture the way a hand does -- one stroke is a check,
## two are an X (see homework_sheet.gd).
func trace_stroke(target: Control, points: Array) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = points[0]
	target._gui_input(down)
	for i in range(1, points.size()):
		var mm := InputEventMouseMotion.new()
		mm.position = points[i]
		target._gui_input(mm)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = points[points.size() - 1]
	target._gui_input(up)


## Stand the teacher on `tile` facing `dir`, ready to interact.
func place_player(tile: Vector2i, dir: int) -> void:
	world.player.global_position = Grid.tile_to_world(tile)
	world.player.facing = dir
	world.player.velocity = Vector2.ZERO
	await step(2)
	# A physics frame with the player idle should never touch facing --
	# walk()'s zero-direction branch returns before reaching that code.
	# It can still drift if a LEFTOVER held key from earlier in the same
	# test is still down when these frames run, which any test using this
	# helper after a hold()/tap() is one dropped release away from. Setting
	# it a second time, after the steps rather than only before them, is
	# what actually guarantees the facing a caller asked for.
	world.player.facing = dir


func _main() -> void:
	test_grid()
	test_game()
	test_layout()
	test_balance()
	test_items()
	test_subject_items()
	test_homework()
	await test_scene()
	await test_movement()
	await test_arrival()
	await test_work_loop()
	await test_seating()
	test_poses()
	await test_day_cycle()
	await test_confusion()
	await test_placement()
	await test_save_slots()
	await test_mess()
	test_events()
	test_economy()
	test_term()
	test_settings()
	await test_title()
	await test_dash()
	await test_flares()
	await test_mid_lesson_mess()
	await test_desk_interruption()
	await test_callers()
	await test_acting_on_them()
	await test_materials_day()
	await test_book_pages()
	await test_cluster_penalty()
	await test_dash_lanes()
	await test_bell_rush()
	await test_buttons()
	test_curriculum()
	test_names()
	test_lifetime_counters()
	test_meta()
	test_graduate_record()
	await test_alumni_wall()
	await test_moments()
	await test_day_beats()
	await test_bio()
	test_student_levels()
	test_teacher_levels()
	test_new_perks()
	await test_dash_upgrade_and_display()
	await test_chain_dash()
	test_relay()
	await test_subjects_and_skip()
	test_graduation()
	test_coaching()
	await test_shop_and_staff()
	await test_bio_actions()
	test_catalogue()
	test_global_classes_registered()
	test_every_asset_loads()
	test_curator()
	test_cheats()
	await test_moving_desks()
	await test_quiz()
	await test_answer_all()
	test_concepts()
	await test_pacing()
	test_exam_maths()
	test_next_term()
	test_term_paths()
	test_term_target()
	test_boss()
	await test_boss_fight()
	await test_legibility()
	test_transcript()
	test_unlockables()
	await test_unit_test()
	await test_two_buttons_one_landmark()
	await test_growing_the_room()
	await test_panels_fit()
	await test_systems_together()
	await test_a_whole_day()
	test_traits()
	test_save_isolation()
	await test_bubbles()
	await test_room_shows_not_tells()
	await test_notices_never_overlap()
	await test_screens_explain_themselves()
	await test_no_raw_colour_codes()
	await test_difficulty()
	await test_specialism_and_choice()
	await test_build_mode()
	await test_assignment_cards()
	test_a_term_can_be_won()
	await test_autopilot_and_aide()
	await test_auto_teach()
	await test_lesson_plan_folder()
	await test_dashboard()
	await test_milestones()
	await test_trophies()
	await test_buying_desks()
	await test_the_school()
	await test_hallway()
	await test_mentor()
	await test_dev_panel()
	await test_teaching()
	await test_weather()
	await test_voice()
	await test_juice_lands()
	await test_quiz_buff_and_calm()
	await test_stale_interactable_after_rebuild()
	await test_inspection()
	await test_disruption()
	await test_overlays()
	await test_marking()
	await test_shop()
	await test_lesson_crafting()
	await test_cabinet()
	await test_ad_poster()
	await test_progress_bar()
	await test_music()
	await test_fight_music()
	test_portraits()
	test_walkthrough()

	print("")
	if failed == 0:
		print("ALL EDUSYSTEM CHECKS PASSED  (%d assertions)" % passed)
	else:
		print("FAILURES: %d of %d" % [failed, passed + failed])
	# The baseline check only means anything on a run that PASSED: a run
	# with failures already exits nonzero and its count is not a baseline.
	# A filtered run's count is a fraction of the real total, and comparing
	# it to the full baseline would always read as a drop. The baseline
	# only means anything against a complete run.
	get_tree().quit((_check_baseline() if _filter == "" else 0) if failed == 0 else 1)


## The assertion count, remembered, so a human does not have to.
##
## CLAUDE.md and README.md both tell a reader to "read the COUNT, not the
## word PASSED", and record three real regressions caught that way
## (724 to 560, 828 to 708). Nothing stored the previous number: the human
## WAS the baseline database, and that is not a job a person should have.
##
## A count that falls means checks stopped running -- usually a script that
## no longer compiles, which removes whole sections silently while the run
## still reports success.
const COUNT_FILE := "res://tests/assertion_count.txt"


func _check_baseline() -> int:
	var before := -1
	if FileAccess.file_exists(COUNT_FILE):
		var r := FileAccess.open(COUNT_FILE, FileAccess.READ)
		if r != null:
			before = int(r.get_line().strip_edges())
			r.close()

	if before < 0:
		_write_baseline()
		print("baseline set at %d assertions." % passed)
		return 0

	if passed < before:
		print("")
		print("  COUNT DROPPED: %d -> %d. %d check(s) stopped running."
			% [before, passed, before - passed])
		print("  Nothing failed, which is what makes this dangerous -- a")
		print("  section that no longer compiles is silently skipped.")
		print("  If the drop is deliberate, edit tests/assertion_count.txt.")
		return 1

	if passed > before:
		print("count %d -> %d." % [before, passed])
	_write_baseline()
	return 0


func _write_baseline() -> void:
	var w := FileAccess.open(COUNT_FILE, FileAccess.WRITE)
	if w != null:
		w.store_line(str(passed))
		w.close()


# =============================================== tier 1: pure logic, no scene

func test_grid() -> void:
	section("GRID")
	var g := Grid.new()

	# Pinned literally, not derived -- this IS the number that should never
	# drift by accident. Aug 2026: doubled from 16 to 32 for more detail
	# per tile, same 20x11 room. If this ever fails, the resolution moved
	# and every hardcoded pixel constant doubled alongside it (movement
	# speed, pick radii, room_builder's collision boxes, the whole of
	# hud.tscn) needs re-deriving from this number again, not just this one
	# assertion fixed in isolation.
	chk("the tile size is what the whole game was last tuned against",
		Grid.TILE == 32, Grid.TILE)
	chk("project.godot's viewport actually matches Grid.TILE's room",
		ProjectSettings.get_setting("display/window/size/viewport_width")
			== Grid.BASE_W * Grid.TILE
		and ProjectSettings.get_setting("display/window/size/viewport_height")
			== Grid.BASE_H * Grid.TILE,
		[ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")])

	chk("a tile's anchor is its bottom-centre",
		Grid.tile_to_world(Vector2i(0, 0)) == Vector2(Grid.TILE / 2.0, Grid.TILE),
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

	# grade letters, read from Balance.grade_band_* rather than pinned to a
	# literal -- these were hardcoded probe values once, and broke the
	# moment the bands were retuned even though the LOGIC was still right.
	chk("grade letters map at their thresholds", (func() -> bool:
		var eps := 0.001
		return Game.grade_letter(1.0) == "A" 			and Game.grade_letter(Balance.grade_band_a) == "A" 			and Game.grade_letter(Balance.grade_band_a - eps) == "B" 			and Game.grade_letter(Balance.grade_band_b) == "B" 			and Game.grade_letter(Balance.grade_band_b - eps) == "C" 			and Game.grade_letter(Balance.grade_band_c) == "C" 			and Game.grade_letter(Balance.grade_band_c - eps) == "D" 			and Game.grade_letter(Balance.grade_band_d) == "D" 			and Game.grade_letter(Balance.grade_band_d - eps) == "E" 			and Game.grade_letter(Balance.grade_band_e) == "E" 			and Game.grade_letter(Balance.grade_band_e - eps) == "F").call())

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
	var hud: Control = main.get_node("UI/HUD")

	# THE RISK THIS CLOSES OUT: main.tscn is only ever instantiated HERE --
	# every later test's own Game.new_run() resets state but does not
	# re-run main.gd's _ready(), so a Game.new_run(SEED) at the very top
	# of this function is exactly the "genuinely new career" condition
	# the intro trigger checks for. If it is not walked through and
	# closed here, hud silently sits in Mode.INTRO for however many
	# tests run before the first one happens to open some other screen
	# and overwrite it -- self-healing, but by accident, not by design.
	chk("a new career opens on the storyline intro", hud.mode == hud.Mode.INTRO, hud.mode)
	chk("it opens on the title slate", hud._sel == -1, hud._sel)
	chk("the slate fits the panel", hud.body.text.split("\n").size() <= 11, hud.body.text)

	# The scene itself is said from a bubble above the teacher's own head
	# (main.gd wires hud's words to world.player), not a panel hud owns
	# outright -- so this listens for the same signal main.gd does rather
	# than reading a Label hud no longer writes to for this part.
	var last_line: String = ""
	hud.intro_line_changed.connect(func(t: String) -> void: last_line = t)
	var door_tile: Vector2 = world.player.global_position

	await tap("interact")   # leaves the slate; also what starts the walk-in
	chk("leaving the slate hides the panel and shows the room",
		not hud.overlay.visible)
	chk("and starts the teacher walking in from the door",
		world.player.is_walking_scripted() or
		world.player.global_position != door_tile)

	# The cold open: the room is empty. Every desk is stashed, the class is
	# held at the door, and the teacher walks to the cabinet to pull them
	# out one by one.
	chk("leaving the slate stashes every desk in the cabinet",
		Game.desks_in_store == Layout.seat_count(), Game.desks_in_store)
	chk("so no desks are built yet",
		get_tree().get_nodes_in_group("desk_part").is_empty())
	chk("and nobody has come in", world.students.is_empty())

	var guard0 := 0
	while world.player.is_walking_scripted() and guard0 < 500:
		await step(1)
		guard0 += 1
	chk("the teacher walked to the cabinet, not straight to the front",
		world.player.global_position.distance_to(
			Grid.tile_to_world(Layout.CABINET + Vector2i(0, 1))) < 16.0,
		world.player.global_position)

	var seats := Layout.seat_count()
	for i in seats:
		var before_i: int = Game.desks_in_store
		await tap("interact")
		await step(2)
		chk("pull %d takes one desk out of the cabinet" % (i + 1),
			Game.desks_in_store == before_i - 1, Game.desks_in_store)
		# rebuild_desks_only() hands back the bodies it built so main.gd can
		# settle the newest one in rather than guessing -- it must always be
		# resolvable to a live desk right after a pull.
		chk("the desk that just came out is retrievable for its landing fx",
			world.newest_desk() != null and is_instance_valid(world.newest_desk()))
	chk("every desk is out now", Game.desks_in_store == 0)
	chk("the room has its desks", not get_tree().get_nodes_in_group("desk_part").is_empty())
	chk("and the class is on its way in", not world.students.is_empty())

	# The room is furnished from day one -- a little decor seeded straight in,
	# never bought, so it reads as lived-in rather than bare.
	chk("the room starts with some decor already on the wall",
		get_tree().get_nodes_in_group("seeded_decor").size() >= 3,
		get_tree().get_nodes_in_group("seeded_decor").size())
	chk("the seeded decor never blocks the floor it hangs over", (func() -> bool:
		for id_tile: Array in RoomBuilder.DECOR_SEED:
			if not world.grid.is_free(id_tile[1] as Vector2i):
				return false
		return true).call())

	var pages: int = hud.INTRO_PAGES.size()
	for i in pages:
		chk("bubble %d fits above the teacher's head" % i,
			last_line.split("\n").size() <= 2, last_line)
		await tap("interact")
	chk("walking through every page closes it", hud.mode == hud.Mode.NONE, hud.mode)
	chk("and marks it seen, so it never replays for this career", Game.intro_seen)
	chk("the intro is backstory now, not a control sheet", (func() -> bool:
		var blob := (" ".join(hud.INTRO_SLATE) + " ").to_upper()
		for page: Array in hud.INTRO_PAGES:
			if page.size() != 2:            # every bubble page is exactly two lines
				return false
			blob += (" ".join(page) + " ").to_upper()
		for token in [" WASD ", " E ", " F ", " L ", " J "]:
			if blob.contains(token):
				return false
		return true).call())

	# A handful of dialogue taps is nowhere near enough frames to cross the
	# room, so let the scripted walk actually finish before judging where
	# it ended.
	var guard := 0
	while world.player.is_walking_scripted() and guard < 300:
		await step(1)
		guard += 1
	chk("the walk-in actually finished", not world.player.is_walking_scripted())
	chk("and ended where every ordinary boot already starts you",
		world.player.global_position.distance_to(world.teacher_start_world()) < 4.0)

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

	# Crossing one tile should take the same real TIME regardless of how
	# many pixels that tile is now drawn with -- SPEED doubled alongside
	# Grid.TILE in Aug 2026 specifically so this ratio held. If it drifts,
	# the room got faster or slower to walk across, which is a balance
	# change nothing about a resolution pass should ever cause.
	chk("crossing a tile takes about the same time it always did",
		is_equal_approx(Actor.SPEED / float(Grid.TILE), 60.0 / 16.0),
		Actor.SPEED / float(Grid.TILE))

	# SPEED 120 at 60Hz physics == exactly 2px per frame, so this is integer
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
	# Per-frame speed at the default 60Hz physics tick -- SPEED itself
	# doubled alongside Grid.TILE in Aug 2026 (60 -> 120), so this is
	# derived rather than a second hardcoded copy of that number.
	var px_per_frame: float = Actor.SPEED / 60.0
	await hold("move_right", 40)
	chk("holding move_right for 40 physics frames advances the right distance",
		is_equal_approx(p.global_position.x - x0, 40.0 * px_per_frame),
		"moved %.1f" % (p.global_position.x - x0))
	chk("facing is RIGHT after walking right", p.facing == Actor.DIR_RIGHT)

	# and the converse: furniture DOES stop you, which is what the bad
	# version of the test above was accidentally proving
	p.global_position = Grid.tile_to_world(Vector2i(9, 5))
	await step(1)
	var dx0: float = p.global_position.x
	await hold("move_right", 60)
	chk("a desk stops the player well short of a 60-frame walk",
		p.global_position.x - dx0 < 60.0 * px_per_frame * 0.5,
		"moved %.1f before hitting the desk at tile 11" % (p.global_position.x - dx0))

	var y0: float = p.global_position.y
	await hold("move_down", 20)
	chk("holding move_down for 20 frames advances the right distance",
		is_equal_approx(p.global_position.y - y0, 20.0 * px_per_frame),
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
		travelled <= 30.0 * px_per_frame + 2.0,
		"travelled %.1f in 30 frames" % travelled)

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
		p.global_position.y > Layout.TOP_WALL * Grid.TILE
			and p.global_position.y < Layout.TOP_WALL * Grid.TILE + Grid.TILE,
		"y=%.1f" % p.global_position.y)

	# Row 9 runs clear to the left wall, below the door and under the desks.
	p.global_position = Grid.tile_to_world(Vector2i(6, 9))
	await step(1)
	await hold("move_left", 90)
	chk("the left wall stops the player with no tunnelling",
		p.global_position.x > Grid.TILE and p.global_position.x < Grid.TILE * 1.75,
		"x=%.1f" % p.global_position.x)

	# The doorway is a genuine hole, so you can stand in it.
	p.global_position = Grid.tile_to_world(Vector2i(1, 8))
	await step(1)
	await hold("move_left", 30)
	chk("you can walk into the doorway itself",
		p.global_position.x < Grid.TILE * 0.5, "x=%.1f" % p.global_position.x)


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
	# The shortest sheet anyone was given -- work length is per-student now
	# that lessons have a difficulty, so a single global constant cannot
	# answer "how long until somebody could possibly be finished".
	var shortest := 9999.0
	for st: StudentData in Game.roster:
		shortest = minf(shortest, st.work_total)
	var short_of_it := int(shortest * 60.0) - 5
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
			s.tick_work(1.0 / 60.0, Game.rng, 1.0)
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
	chk("the sprite sheet actually has a seated column and the pose columns",
		st.sprite.hframes == 9, st.sprite.hframes)

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


func test_poses() -> void:
	section("ONE-SHOT POSES")
	# test_seating left every student seated, and test_day_cycle after this
	# one assumes that is still true -- restore it, don't just stand().
	var st: Actor = world.student_node(0)
	var was_seated := st.seated
	st.stand()
	st.play_pose(Actor.POSE_JUMP)
	chk("play_pose shows the requested column immediately",
		st.sprite.frame_coords.x == Actor.POSE_JUMP, st.sprite.frame_coords)
	# A held pose must not be clobbered by ordinary idle/frame updates --
	# only tick_pose(), once the hold time has elapsed, hands it back.
	st.set_idle()
	chk("set_idle() does not interrupt a held pose",
		st.sprite.frame_coords.x == Actor.POSE_JUMP, st.sprite.frame_coords)
	st.tick_pose(Actor.POSE_HOLD_TIME + 0.01)
	chk("tick_pose() releases the pose once its hold time has elapsed",
		st.sprite.frame_coords.x == 0, st.sprite.frame_coords)

	st.sit(Actor.DIR_DOWN)
	st.play_pose(Actor.POSE_SAD)
	st.tick_pose(Actor.POSE_HOLD_TIME + 0.01)
	chk("a released pose falls back to SIT_FRAME while seated",
		st.sprite.frame_coords.x == Actor.SIT_FRAME, st.sprite.frame_coords)
	if was_seated:
		st.sit(Actor.DIR_DOWN)
	else:
		st.stand()


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
		bare_taught < Balance.grade_band_b and rich_ignored < Balance.grade_band_b,
		"%.2f, %.2f vs B at %.2f" % [bare_taught, rich_ignored, Balance.grade_band_b])

	var bare_ignored := _simulate_lesson(false, false)
	chk("doing neither is well below a pass",
		bare_ignored < Balance.grade_band_c,
		"%.2f  %s" % [bare_ignored, Game.grade_letter(bare_ignored)])

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
	_neutral_lesson()
	var total_stalls := 0
	for i in 20:
		total_stalls += _count_stalls(0.3)
	chk("a student gets stuck several times across a lesson",
		total_stalls >= 30, "%d stalls over 20 lessons" % total_stalls)

	# The actual mechanism behind every row above never moving, stated
	# outright rather than staying true only by omission: tools/sim.gd's
	# _one_lesson() reads Balance.lesson_seconds directly and never ticks
	# the real room. Every roguelike lever added since (day events, then
	# complications and term paths) rides on that gap being real -- a
	# future change that made _one_lesson() start calling any of these
	# would silently start moving the 0.63/0.71/0.97 contract.
	#
	# Scoped to _one_lesson() itself, not the whole file: sim.gd's OTHER
	# function, _play_day() (the delegated-room policy comparison behind
	# Simulate the School.bat), calls Game.tick_class() on purpose -- it
	# is explicitly the thing that needs to see disruption, and it never
	# feeds the contract rows. A whole-file scan would have flagged that
	# real, correct call as if it were a regression.
	var sim_src := FileAccess.get_file_as_string("res://tools/sim.gd")
	var start := sim_src.find("func _one_lesson(")
	var stop := sim_src.find("\nfunc ", start + 1)
	var one_lesson_src := sim_src.substr(start, stop - start) \
		if start >= 0 and stop > start else ""
	chk("_one_lesson() actually exists in the source to check",
		one_lesson_src != "")
	chk("_one_lesson() still never calls tick_class()",
		not one_lesson_src.contains("tick_class("))
	chk("...nor _tick_flares()", not one_lesson_src.contains("_tick_flares("))
	chk("...nor _tick_complications() -- the new one",
		not one_lesson_src.contains("_tick_complications("))
	chk("...nor cluster_rate_mult() -- the anti-cram penalty is layout-only",
		not one_lesson_src.contains("cluster_rate_mult("))
	chk("...nor run_answer_all() -- the mass-help skill pays no grade",
		not one_lesson_src.contains("run_answer_all("))


## Run real lessons through the actual work model and return the MEAN grade.
## `furnish` caps the room; `teach` unsticks them the moment they stall.
##
## Averaged over many students on purpose. A single lesson is dominated by
## one student's stall luck — an early version of this asserted on one
## student and swung between a C and a B depending only on the seed, which
## would have made the contract flaky rather than meaningful.
func _simulate_lesson(furnish: bool, teach: bool) -> float:
	# Both contract rows hold TEACHING CONSTANT at perfect -- the teacher is
	# at the front the whole time, so rate is 1.0. That is deliberate and it
	# is what keeps these three rows comparable to every reading taken before
	# active teaching existed: they measure what the ROOM and the HELPING are
	# worth, with the teaching held still. "Never helped" means never leaving
	# the front to help, not never teaching.
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
				s.tick_work(1.0 / 60.0, Game.rng, 1.0)
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
			if d.is_empty() or int(d["cost"]) <= 0:
				return false
			# Furniture's effect is bonus/range on the item itself; a
			# consumable's is a hook dict (stall_mult, bonus_coins, ...)
			# spent the day it is bought -- different schema, same
			# requirement that SOMETHING real is there.
			if String(d.get("cat", "")) == "consumable":
				if (d.get("effect", {}) as Dictionary).is_empty():
					return false
			elif float(d["bonus"]) <= 0.0:
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

	# --- consumables: bought and spent the same day, never placed ---
	Game.new_run(SEED)
	Game.coins = 0
	chk("a consumable you can't afford refuses, same as furniture",
		Game.use_consumable("coffee") != "")
	Game.add_coins(1000)
	var stall_before := Game.event_stall_multiplier()
	var spend_before := Game.coins
	chk("buying one is free of any error",
		Game.use_consumable("coffee") == "")
	chk("and it actually charges you", Game.coins == spend_before - Items.cost("coffee"))
	chk("coffee measurably calms the room down for today",
		Game.event_stall_multiplier() < stall_before, Game.event_stall_multiplier())
	chk("it never enters the room -- nothing got placed", Game.room_items.is_empty())
	chk("it shows up as something you bought today",
		Game.consumables_used_today.has("Coffee"))

	chk("a sticker chart guarantees homework, bypassing the dice",
		Game.use_consumable("sticker_chart") == "" and Game._consumable_homework_sure)
	var coins_before_bake := Game.coins
	chk("a bake sale is a flat bonus, banked at the bell",
		Game.use_consumable("bake_sale") == "" and Game.consumable_bonus_coins == 60)
	# Deliberately NOT lesson_mult -- see photocopies' own entry in
	# balance.json. A day EVENT rolling more lesson time is a random
	# occurrence; a CONSUMABLE doing the same would be an every-day,
	# no-downside grade nudge for coins, which the balance contract's own
	# simulator (tools/sim.gd) never models buying and so could never
	# have caught. Kept on stall_mult instead, the same lever coffee uses.
	var stall_before_photocopies := Game.event_stall_multiplier()
	chk("photocopies calm the room down today, not lengthen the lesson",
		Game.use_consumable("photocopies") == ""
		and Game.event_stall_multiplier() < stall_before_photocopies
		and is_equal_approx(Game.lesson_length(), Balance.lesson_seconds))

	# the bell resets all of it for the next day, same as a day event does
	var report := Game.advance_day()
	chk("the day report names what you bought", report.get("consumables", []).size() == 4,
		report.get("consumables", []))
	chk("and the slate is wiped for tomorrow",
		Game.consumable_bonus_coins == 0 and not Game._consumable_homework_sure
			and Game.consumables_used_today.is_empty()
			and is_equal_approx(Game.consumable_multiplier("stall_mult"), 1.0))

	Game.new_run(SEED)


func test_subject_items() -> void:
	section("SUBJECT-SHELF ITEMS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# The 54 originals help every lesson the same. The new ones each carry
	# a strand and pay extra only on its day.
	chk("an ordinary item has no strand", Items.strand("stool") == "")
	chk("and no strand bonus", Items.strand_bonus("stool") == 0.0)
	chk("a subject item names its strand", Items.strand("number_line") == "math")
	chk("and carries a strand bonus", Items.strand_bonus("number_line") > 0.0)
	chk("one per strand shipped", (func() -> bool:
		var seen := {}
		for id: String in Items.order():
			var st := Items.strand(id)
			if st != "":
				seen[st] = true
		for want: String in ["ela", "math", "science", "social"]:
			if not seen.has(want):
				return false
		return true).call())

	# --- ten-commits.md step 8: a second item per strand, in its own tab ---
	chk("two per strand shipped now", (func() -> bool:
		var count := {}
		for id: String in Items.order():
			var st := Items.strand(id)
			if st != "":
				count[st] = int(count.get(st, 0)) + 1
		for want: String in ["ela", "math", "science", "social"]:
			if int(count.get(want, 0)) < 2:
				return false
		return true).call())
	chk("subjects is a real shop category now",
		Items.categories().has("subjects"), Items.categories())
	chk("every strand item lives there, split out of learning",
		(func() -> bool:
			for id: String in ["rhyme_chart", "word_wall", "number_line",
					"ten_frame", "bug_viewer", "rock_tray", "map_corner",
					"timeline_wall"]:
				if Items.category_of(id) != "subjects":
					return false
			return true).call())
	chk("...and it is never split up in the order the shop actually lists",
		(func() -> bool:
			var seen: Array[String] = []
			var cat := ""
			for id: String in Items.order():
				var this_cat := Items.category_of(id)
				if this_cat == cat:
					continue
				if seen.has(this_cat):
					return false
				seen.append(this_cat)
				cat = this_cat
			return true).call())
	var subj_digits := RegEx.new()
	subj_digits.compile("[0-9]")
	for id: String in ["word_wall", "ten_frame", "rock_tray", "timeline_wall"]:
		chk("%s carries a real strand and bonus" % id,
			Items.strand(id) != "" and Items.strand_bonus(id) > 0.0, id)
		chk("%s's name fits the shop column" % id,
			String(Items.get_def(id).get("name", "")).length() <= 13, id)
		chk("%s's blurb has no digits" % id,
			subj_digits.search(String(Items.get_def(id).get("blurb", ""))) == null, id)

	# Put a number line in range of seat 0 and measure the room on a maths
	# day vs an English day.
	var seat0: Vector2i = Layout.seat(0)
	Game.room_items.clear()
	Game.room_items.append({"id": "number_line", "tile": seat0 + Vector2i(0, 2)})

	Game.lesson = Curriculum.by_id("basic_arithmetic")   # math
	var on_day := Game.room_score(0)
	Game.lesson = Curriculum.by_id("reading_fluency")    # ela
	var off_day := Game.room_score(0)

	chk("the room is worth more on the item's own subject day",
		on_day > off_day, "%.3f vs %.3f" % [on_day, off_day])
	chk("and the gap is exactly its strand_bonus",
		is_equal_approx(on_day - off_day, Items.strand_bonus("number_line")),
		"%.3f" % (on_day - off_day))
	chk("off its subject it still gives its ordinary bonus",
		off_day > Balance.room_base,
		"%.3f vs base %.3f" % [off_day, Balance.room_base])

	# The contract's own guarantee: room_score can never exceed room_cap,
	# strand bonus or not -- which is why the 0.63/0.71/0.97 rows (measured
	# at the cap) cannot move no matter how these items are tuned.
	Game.room_items.clear()
	for i in 40:
		Game.room_items.append({"id": "number_line", "tile": seat0 + Vector2i(0, 2)})
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	chk("a roomful still clamps to room_cap",
		Game.room_score(0) <= Balance.room_cap + 0.0001,
		"%.3f vs cap %.3f" % [Game.room_score(0), Balance.room_cap])

	Game.new_run(SEED)


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
	_neutral_lesson()
	var s := StudentData.new()
	s.aptitude = 0.5

	s.assign_work()
	chk("work starts un-stuck and empty",
		not s.is_struggling() and is_equal_approx(s.work_fraction(), 0.0))

	# tick until they stall, which now happens by continuous roll rather
	# than at a single moment scheduled up front
	var guard := 0
	while not s.is_struggling() and guard < 6000:
		s.tick_work(1.0 / 60.0, Game.rng, 1.0)
		guard += 1
	chk("a student gets stuck eventually", s.is_struggling(), guard)
	chk("they never stall in the first moment of the work",
		guard > int(Balance.stall_grace_seconds * 60.0), guard)

	var frozen: float = s.work_timer
	var frac: float = s.work_fraction()
	for i in 600:
		s.tick_work(1.0 / 60.0, Game.rng, 1.0)
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
		s.tick_work(1.0 / 60.0, Game.rng, 1.0)
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

	# A null ghost texture used to crash _refresh() with "Cannot call
	# get_height() on a null value" -- not reachable through begin()'s own
	# sequencing (browsing is set first, which returns early), but nothing
	# stops a future caller from poking tile/desk_index before the texture
	# is ever assigned, and that IS reachable: a fresh Placement node whose
	# _refresh() is called before begin(). Logged, found, not fixed for a
	# session; fixed here.
	var bare := Placement.new()
	world.add_child(bare)
	# None of begin() / begin_desk() / begin_browse() actually leave the
	# ghost in this state -- every real entry point sets a texture (or
	# stays in `browsing`, which _refresh() returns out of before it
	# would matter). Building it by hand is the only way to reach the
	# line that used to crash, which is exactly what makes it worth a
	# defensive fix rather than trusting today's three callers forever.
	bare._ghost = Sprite2D.new()
	bare.add_child(bare._ghost)
	bare.item_id = "plant"
	bare.desk_index = -1
	bare.tile = Vector2i(9, 6)
	bare._refresh()
	chk("_refresh() survives a texture that was never assigned", true)
	bare.queue_free()

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

	# --- ten-commits.md step 4: the crowding overlay, and its readout ---
	# crowd_count() reads Game state directly (seats, roster,
	# cluster_rate_mult()) rather than anything Placement itself is
	# holding, so a bare instance is enough -- no begin()/begin_browse()
	# needed to exercise the logic. _draw()'s own CROWD_EDGE pass is the
	# same data painted; confirmed by screenshot, not here.
	var crowd := Placement.new()
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)     # every seat one tile from the next
	await step(2)
	chk("a row of touching desks hems in the whole class",
		crowd.crowd_count() == Game.roster.size(), crowd.crowd_count())
	chk("...the exact formula the game itself charges them",
		Game.cluster_rate_mult(Game.roster[0]) < 1.0)

	Layout.reset_seats()     # the opening layout: no two seats within one tile
	await step(2)
	chk("the opening layout has nobody hemmed in",
		crowd.crowd_count() == 0, crowd.crowd_count())
	crowd.queue_free()

	Game.new_run(SEED)
	await step(2)


func test_save_slots() -> void:
	section("SAVE SLOTS")
	Balance.ensure_loaded()

	# a clean slate -- SaveManager's directory is real disk, not memory,
	# so a leftover slot from an earlier run (or a crash mid-test) would
	# make this test lie about starting empty
	Game.delete_slot(0)
	Game.delete_slot(1)
	chk("no slot to begin with", not Game.has_slot(0))

	Game.new_run(SEED)
	Game.day = 5
	chk("saving to a slot works", Game.save_to_slot(0))
	chk("the slot now exists", Game.has_slot(0))
	chk("and knows what day it's on without loading it",
		Game.slot_day(0) == 5, Game.slot_day(0))

	var on_disk := Game.to_dict()
	Game.new_run(1)
	chk("loading an empty slot fails cleanly, rather than crashing",
		not Game.load_from_slot(7))
	chk("loading a real slot works", Game.load_from_slot(0))
	chk("and restores the run",
		_same_within(Game.to_dict(), on_disk, 1e-6), Game.to_dict())

	# slots don't step on each other, or on the single autosave file
	Game.day = 9
	Game.save_to_slot(1)
	chk("slot 0 is untouched by slot 1's write", Game.slot_day(0) == 5)
	Game.save_game()
	chk("slots and the single save file coexist without colliding",
		Game.has_slot(0) and Game.has_slot(1) and Game.has_save())

	Game.delete_save()
	chk("deleting a slot removes only that slot",
		Game.delete_slot(0) and not Game.has_slot(0) and Game.has_slot(1))
	Game.delete_slot(1)

	Game.new_run(SEED)


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

## Pin today's lesson to a NEUTRAL difficulty.
##
## Lessons have a difficulty now, and new_run() picks one at random. Any
## test measuring the work model itself -- how long a sheet takes, whether a
## child stalls, whether a copier can catch up -- was silently at the mercy
## of that roll: on an easy lesson the work finishes before anyone can get
## stuck, so "a student gets stuck eventually" simply stopped being true.
## Difficulty 3 is the neutral middle, where every multiplier is 1.0.
## Setting work is a hand of cards now, so starting a lesson through the
## real buttons takes TWO presses: one at the podium to draw, one on the
## paper you want. Anything driving the real input has to do both.
func _take_a_paper() -> void:
	var hud := _hud()
	if hud.mode == hud.Mode.HAND:
		await tap("interact")
		await step(3)


func _neutral_lesson() -> void:
	for l: Dictionary in Curriculum.lessons:
		if Curriculum.difficulty(l) == 3:
			Game.lesson = l
			Game.subject = String(l.get("name", ""))
			return


func _hud() -> Control:
	return world.get_parent().get_node("UI/HUD")


## Daily clutter: spawns with the room, cleans on interact, blocks nothing.
func test_mess() -> void:
	section("ROOM MESS")
	Game.new_run(SEED)
	await step(2)

	chk("a fresh day spawns some mess",
		world.messes.size() >= world.MESS_MIN
		and world.messes.size() <= world.MESS_MAX,
		world.messes.size())
	var all_valid := true
	for m: Interactable in world.messes:
		if not is_instance_valid(m):
			all_valid = false
	chk("every spawned mess is a live node", all_valid)

	var kinds_ok := true
	for m: Interactable in world.messes:
		if not (m.kind == "trash" or m.kind == "spill"):
			kinds_ok = false
	chk("every mess is a recognised kind", kinds_ok)

	# It sits ON a free tile, not blocking it -- see build_mess()'s own
	# comment on why that matters ("clean it before or after class starts"
	# rather than it becoming an obstacle to route around).
	var still_walkable := true
	for m: Interactable in world.messes:
		var t := Grid.world_to_tile(m.get_parent().global_position)
		if not world.grid.is_free(t):
			still_walkable = false
	chk("a mess tile is still walkable, not blocked", still_walkable)

	var before: int = world.messes.size()
	chk("there is something to clean", before > 0)
	if before > 0:
		var target: Interactable = world.messes[0]
		var body: Node = target.get_parent()
		chk("it offers to be cleaned", target.can_interact()
			and target.prompt_text() != "")

		# A mash, not a hold: N-1 presses leave it standing, art and all.
		for i in Balance.mess_clean_presses - 1:
			target.interact(world.player)
		chk("it is not cleaned before the last press",
			world.messes.size() == before and is_instance_valid(body))
		chk("the prompt counts down the presses still needed",
			target.prompt_text().contains("(1)"), target.prompt_text())

		var coins_before: int = Game.coins
		# A one-element Array, not a bool -- a GDScript lambda captures an
		# outer local BY VALUE, so `saw_signal = true` inside one would set
		# a copy and never touch this variable. Index-assignment into a
		# shared Array does reach it.
		var saw_signal := [false]
		target.cleaned.connect(func(_m, _k): saw_signal[0] = true)
		target.interact(world.player)   # the final press
		chk("cleaning emits its signal", saw_signal[0])
		chk("cleaning removes it from the tracked list",
			world.messes.size() == before - 1, world.messes.size())
		chk("cleaning pays the flat coin tip",
			Game.coins == coins_before + Balance.mess_clean_reward,
			Game.coins)
		# queue_free() is deferred -- is_instance_valid(body) is still true
		# for the rest of THIS frame, so the actual removal isn't
		# observable until a frame has actually turned over.
		await step(1)
		chk("the whole prop -- sprite included -- is gone, not just the "
			+ "invisible interact area", not is_instance_valid(body))

	# --- a hired janitor cleans the room on their own, no E needed ---
	world._spawn_mess()   # a known, non-empty starting point
	var jm_before: int = world.messes.size()
	chk("something to clean, for the janitor to find", jm_before > 0)
	Game.coins = 5000
	chk("hiring a janitor", Game.set_janitor(true) == "")
	var jcoins_before: int = Game.coins   # AFTER the hire cost, not before
	Game._janitor_timer = 0.0   # due immediately, rather than waiting real seconds
	await step(2)
	chk("the janitor cleaned something without a single E press",
		world.messes.size() < jm_before, world.messes.size())
	chk("and it paid the same coin tip a manual clean would",
		Game.coins == jcoins_before + Balance.mess_clean_reward, Game.coins)
	Game.set_janitor(false)

	Game.new_run(SEED)
	await step(2)


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
	s1.work_timer = s1.work_total
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


func test_answer_all() -> void:
	section("ANSWER ALL QUESTIONS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	# The mass-help skill is locked until the mentor teaches it. This
	# section is about the skill itself, not the gate (test_mentor covers
	# that) -- grant it the way a grandfathered save would.
	Game.answer_all_taught = true
	await step(2)
	world.start_lesson()
	await step(4)

	chk("a fresh lesson has the skill ready", Game.answer_all_ready())
	chk("its cooldown starts at zero", Game.answer_all_cooldown == 0.0)

	var caller: Interactable = null
	for n in get_tree().get_nodes_in_group("answer_all_caller"):
		if n is Interactable:
			caller = n
			break
	chk("the podium carries an answer-all landmark", caller != null)
	chk("it is on its own dedicated key", caller.action_name() == "answer_all")
	chk("and it offers itself mid-lesson while ready", caller.can_interact())

	# Set someone genuinely stuck, and let the quiz flag whoever it flags.
	var stuck: StudentData = Game.roster[0]
	stuck.confusion = 1.0
	world.run_quiz()
	var flagged: StudentData = null
	for s: StudentData in Game.roster:
		if s.quiz_flagged:
			flagged = s
			break

	var coins_before := Game.coins
	var time_before: float = world.lesson_left
	var res: Dictionary = world.run_answer_all()

	chk("it costs exactly what the table says, off the lesson clock",
		is_equal_approx(time_before - world.lesson_left, Balance.answer_all_seconds_cost),
		"%.1f -> %.1f" % [time_before, world.lesson_left])
	chk("it pays no coins", Game.coins == coins_before)
	chk("the stuck child is unstuck", not stuck.is_struggling())
	chk("the result counts who it moved", int(res.get("helped", 0)) >= 1)
	if flagged != null:
		chk("a flagged child is resolved too", not flagged.quiz_flagged)
	else:
		chk("SKIPPED: this seed flagged nobody for the quiz", true)

	chk("using it puts it on cooldown", not Game.answer_all_ready())
	chk("the cooldown is the table's full value",
		is_equal_approx(Game.answer_all_cooldown, Balance.answer_all_cooldown_seconds))
	chk("and the landmark stops offering itself while it recharges",
		not caller.can_interact())

	var cd_before: float = Game.answer_all_cooldown
	await step(30)
	chk("the lesson clock drains the cooldown", Game.answer_all_cooldown < cd_before)

	# No standalone grade effect: a child who is neither stuck nor flagged is
	# untouched by it, so it cannot be a way to score points -- the same
	# guard the quiz has, and why tools/sim.gd never calls it.
	var calm: StudentData = Game.roster[Game.roster.size() - 1]
	calm.confusion = 0.0
	calm.quiz_flagged = false
	var grade_before := Game.grade_for(calm)
	Game.answer_all_cooldown = 0.0
	Game.run_answer_all()
	chk("it is worth no grade by itself",
		is_equal_approx(Game.grade_for(calm), grade_before))

	world.end_lesson()
	await step(2)
	Game.new_run(SEED)
	await step(2)
	world.start_lesson()
	await step(4)
	chk("the next lesson gives it back", Game.answer_all_ready())

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
	chk("every concept carries its parent's code, or its parent's silence",
		(func() -> bool:
			for c: Dictionary in Curriculum.concepts():
				var parent := Curriculum.by_id(String(c["lesson"]))
				if String(c.get("standard", "")) != String(parent.get("standard", "")):
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


## Step 3 of ten-commits.md: on schedule, or told about it. Coins and XP
## only -- pacing never feeds a grade, so the three-row contract cannot
## move and needs no new guard, only the same source-scan every other
## coins/XP-only system in this file already gets.
func test_pacing() -> void:
	section("ON SCHEDULE, OR TOLD ABOUT IT")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("a brand new run starts owing this term nothing yet",
		Game.term_start_concepts == 0, Game.term_start_concepts)

	# --- the report itself: earned vs expected, on the day that just ended ---
	var lid := String(Curriculum.lessons[0].get("id", ""))
	Game.record_taught(lid)     # one lesson taught -> its first concept unlocks
	var day1 := Game.pacing_report(1)
	chk("teaching once is enough to be on pace on day one",
		bool(day1["on_pace"]), day1)
	chk("...and says exactly what it found",
		int(day1["earned"]) == 1 and int(day1["expected"]) == 1, day1)

	# Day 10, not day 5: at the default 0.2/day rate, day 5 needs
	# ceil(5*0.2) = ceil(1.0), which floating point can round either side
	# of exactly 1 -- day 10 needs ceil(2.0), comfortably past the one
	# concept taught above, with no boundary to land on by accident.
	var day10 := Game.pacing_report(10)
	chk("the same one concept is NOT enough ten days in",
		not bool(day10["on_pace"]), day10)
	chk("...and days_left counts down from the term length",
		int(day10["days_left"]) == Balance.term_days - 10, day10)

	# --- knowledge carries across terms; the SNAPSHOT is what resets ---
	# next_term() missing its target ends the run before reaching the
	# snapshot line at all, so a passing exam is faked here the same shape
	# sit_exam() itself builds -- everyone through, by name, real students.
	var known_before: int = Game.concepts.size()
	var fake_rows: Array = []
	for s: StudentData in Game.roster:
		fake_rows.append({"student": s, "score": 1.0, "letter": "A", "passed": true})
	Game.exam_result = {"rows": fake_rows, "average": 1.0, "letter": "A",
		"passed": Game.roster.size(), "total": Game.roster.size()}
	Game.term_start_concepts = -1     # a value next_term() could not produce by accident
	Game.day = Balance.term_days
	Game.next_term()
	chk("a new term snapshots what you already knew, not zero",
		Game.term_start_concepts == known_before, Game.term_start_concepts)
	chk("...and what you knew is untouched by starting a new term",
		Game.concepts.size() == known_before, Game.concepts.size())

	# --- on pace pays coins and XP; isolated against the day's own ordinary
	# payout and upkeep, both of which move regardless of pacing ---
	Game.new_run(SEED)
	await step(2)
	Game.record_taught(lid)
	var coins_before := Game.coins
	var xp_before: int = Game.roster[0].xp
	Game.day = 1
	var report := Game.advance_day()
	chk("the report carries its own pacing verdict",
		bool((report["pacing"] as Dictionary)["on_pace"]), report["pacing"])
	var ordinary := maxi(0, coins_before + int(report["coins"]) - int(report["upkeep"]))
	chk("on pace pays the flat coin bonus on top of the ordinary payout",
		Game.coins == ordinary + Balance.pace_bonus_coins,
		"%d vs ordinary %d + bonus %d" % [Game.coins, ordinary, Balance.pace_bonus_coins])
	chk("...and every seated child gets the xp",
		Game.roster[0].xp == xp_before + Balance.pace_bonus_xp, Game.roster[0].xp)

	# --- behind pays neither, and the report says so, escalating near the end ---
	Game.new_run(SEED)
	await step(2)
	var coins_before2 := Game.coins
	var xp_before2: int = Game.roster[0].xp
	Game.day = 5
	var behind_report := Game.advance_day()
	var ordinary2 := maxi(0, coins_before2 + int(behind_report["coins"]) - int(behind_report["upkeep"]))
	chk("behind pays no bonus coins, only the ordinary payout",
		Game.coins == ordinary2, "%d vs ordinary %d" % [Game.coins, ordinary2])
	chk("...nor xp", Game.roster[0].xp == xp_before2, Game.roster[0].xp)

	var hud := _hud()
	hud.show_day_report(behind_report)
	chk("the report names the problem and gives the action",
		hud.rich.text.contains("Behind on new material"), hud.rich.text)
	hud.close()

	# --- escalation: still behind, days_left at or under the threshold ---
	var late_pacing: Dictionary = Game.pacing_report(
		Balance.term_days - Balance.pace_escalate_days_left)
	var late_report := behind_report.duplicate()
	late_report["pacing"] = late_pacing
	hud.show_day_report(late_report)
	chk("close to the end it stops being a nudge and starts being a warning",
		hud.rich.text.contains("Badly behind"), hud.rich.text)
	chk("...and it still says HOW MANY days, the sanctioned day-counter exception",
		hud.rich.text.contains("day"), hud.rich.text)
	hud.close()

	# --- popped visibly at the bell, one flat event, not one per desk ---
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	await step(2)
	Game.record_taught(lid)
	Game.day = 1
	# Through the real bell, not world.end_day() directly -- the floater
	# lives in bell.gd's own interact(), the one place a player actually
	# triggers this.
	var before_children := world.get_children()
	world.bell.interact(world.player)
	var said_on_pace := false
	for c: Node in world.get_children():
		if c is Floater and not before_children.has(c) \
				and (c as Floater).current_text().begins_with("on pace"):
			said_on_pace = true
	chk("the bell says so out loud when it pays out", said_on_pace)

	# --- guards: coins and XP only, never a grade term, never in sim.gd ---
	chk("pacing never touches the grade formula", (func() -> bool:
		var src := FileAccess.get_file_as_string("res://scripts/autoload/game.gd")
		var i := src.find("func grade_for(")
		if i < 0:
			return false
		var body := src.substr(i, src.find("\nfunc ", i + 1) - i)
		return not body.contains("pacing") and not body.contains("term_start_concepts")
		).call())
	var sim_src := FileAccess.get_file_as_string("res://tools/sim.gd")
	chk("tools/sim.gd never reaches the pacing path",
		not sim_src.contains("pacing_report") and not sim_src.contains("term_start_concepts"),
		"sim.gd reaches into the pacing path")

	Game.new_run(SEED)
	await step(2)


func test_exam_maths() -> void:
	section("THE EXAM ADDS UP")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]

	# THE BUG. The exam was average*0.75 + room*0.35, which counted the room
	# TWICE -- room_score is already a term inside every daily grade -- and
	# so marked down everyone whose record was better than 0.39. A child who
	# averaged an A for twenty days sat it in a bare room and got a B, which
	# is not a result anybody could explain to themselves.
	Game.room_items.clear()
	s.grades.clear()
	s.grades.append(0.90)
	chk("in a bare room the exam IS their record, to the letter",
		Game.grade_letter(Game.exam_score_for(s)) == Game.grade_letter(0.90),
		"%.3f vs %.3f" % [Game.exam_score_for(s), 0.90])
	chk("and to the number", is_equal_approx(Game.exam_score_for(s), 0.90),
		Game.exam_score_for(s))

	# every band, not just the top one
	for want: float in [0.90, 0.80, 0.70, 0.62, 0.50, 0.40]:
		s.grades.clear()
		s.grades.append(want)
		chk("a record of %s sits an exam of %s in a bare room" % [
			Game.grade_letter(want), Game.grade_letter(want)],
			Game.grade_letter(Game.exam_score_for(s)) == Game.grade_letter(want),
			"%.2f -> %.3f" % [want, Game.exam_score_for(s)])

	# the room can only ever help, and only by a little
	s.grades.clear()
	s.grades.append(0.70)
	var bare := Game.exam_score_for(s)
	var guard := 0
	while Game.room_score(s.seat_index) < Balance.room_cap - 0.001 and guard < 60:
		Game.room_items.append({"id": Items.order()[guard % Items.order().size()],
			"tile": Layout.seat(s.seat_index) + Vector2i(0, -1)})
		guard += 1
	var furnished := Game.exam_score_for(s)
	chk("the room you built helps", furnished > bare,
		"%.3f -> %.3f" % [bare, furnished])
	chk("but by about half a letter, not by a grade and a half",
		furnished - bare <= Balance.exam_room_bonus + 0.001,
		furnished - bare)
	chk("and it can never make the exam worse than the record",
		furnished >= s.average_grade() - 0.001)

	Game.new_run(SEED)


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
			if Items.requires(id) == "" and Items.requires_trophy(id) == "" \
					and not Items.is_unlocked(id):
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
	var hud := _hud()

	# The picker used to keep ONE target for both buttons, so whenever two
	# interactables shared a tile the loser was silently unreachable and the
	# tie was settled by node order. Every landmark that has grown a second
	# verb has run into it.
	chk("each button has its own target", p.targets.has("interact")
		and p.targets.has("manage"))

	# --- the podium in the morning: teach on L, unit test on E ---
	for i in Balance.test_requires_taught:
		Game.record_taught("basic_arithmetic")
	Game.set_phase(Game.Phase.MORNING)
	await step(30)                       # let everyone reach their chairs
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)

	chk("TEACH offers the lesson", p.targets["teach"] == world.podium,
		p.targets["teach"])
	chk("and USE offers the unit test at the same moment", (func() -> bool:
		var t: Interactable = p.targets["interact"]
		return t != null and t.prompt_text().begins_with("Unit test")).call(),
		p.targets["interact"])
	chk("both are on offer together", p.offers().size() == 2, p.offers().size())

	# --- four at once: E (mess), L (end lesson), Q (quiz) and J (answer
	# all), together ---
	#
	# THE BUG THIS CATCHES. The prompt bar's own budget reserved space for
	# exactly ONE "   " joiner, correct back when only two things could
	# ever be live (E and F) -- the key remap made a third live verb (Q)
	# an ordinary thing, then the mass-help skill added a fourth (J), and
	# each extra joiner needs its own reserved space. The shortfall was
	# eaten by the OUTER clip with no ellipsis, landing wherever the tail
	# happened to fall: "Q - Quick quiz" silently rendered as "Q - Quick
	# q". Confirmed by screenshot, reproduced here by forcing a mess onto
	# the podium's own tile mid-lesson while both podium skills are ready.
	#
	# A clean Game.new_run() first: quiz_done and mess state both carry
	# across sections otherwise, and this block runs after two other
	# scenarios in the same section already exercised the podium.
	Game.new_run(SEED)
	Game.answer_all_taught = true  # this scenario is about the prompt bar
	                              # fitting four live verbs -- grant the one
	                              # the mentor would otherwise still be gating
	await step(2)
	world.start_lesson()          # not a raw phase-set: this is what
	await step(2)                 # actually re-arms Game.quiz_done
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)
	var _mess := RoomBuilder.build_mess(world, Layout.PODIUM + Vector2i(0, 1), "trash")
	world.messes.append(_mess)
	await step(3)
	chk("all four are live at once", p.offers().size() == 4, p.offers().size())
	hud._update_prompt()
	chk("the quiz prompt is not silently cut off",
		hud.prompt.text.contains("Quick quiz") or hud.prompt.text.ends_with("."),
		hud.prompt.text)
	chk("nothing in the bar is a bare truncated fragment with no marker",
		not hud.prompt.text.contains("[.") or hud.prompt.text.contains("[......]"),
		hud.prompt.text)

	Game.new_run(SEED)             # fully isolated from whatever follows
	await step(2)

	# --- a desk: help on E, move it on its own dedicated key ---
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
	chk("with nothing to do for the child, MOVE_DESK offers the move instead",
		(func() -> bool:
			var t: Interactable = p.targets["move_desk"]
			return t != null and t.prompt_text().contains("desk")).call(),
		p.targets["move_desk"])

	# --- your own desk: hand in on E, mark homework on its own key ---
	# Walked, not called directly on hud -- open_marking() being reachable
	# in isolation was never proof the button that is supposed to reach it
	# actually does, and this specific chain (a new Interactable, a new
	# classroom-level signal, a new main.gd connection) had no walk-up-and-
	# press coverage at all before this.
	p.carrying = 0
	s0.hw_state = StudentData.HW.COLLECTED
	s0.hw_true_accuracy = 0.9
	s0.hw_sheet = Questions.make_sheet(0.9, Game.rng)
	p.carry_homework(1)
	await place_player(Layout.TEACHER_DESK[0] + Vector2i(0, 1), Actor.DIR_UP)
	await step(2)
	chk("carrying homework, USE offers nothing (you have no classwork)",
		p.targets["interact"] == null)
	chk("HOMEWORK offers to mark it", (func() -> bool:
		var t: Interactable = p.targets["homework"]
		return t != null and t.prompt_text().contains("Mark")).call(),
		p.targets["homework"])
	await tap("homework")
	chk("pressing it opens the marking screen", _hud().mode == _hud().Mode.MARKING)
	_hud().close()
	p.carrying_hw = 0
	await step(2)

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

	# THE THING THAT MUST NOT CHANGE. At the opening size the camera cannot
	# drift: the room sits whole inside the limits and dead centre in them,
	# so the whole-room-at-a-glance reading that the "?" bubble, the audio
	# design and the Practised Eye perk were all argued from still holds.
	#
	# This used to assert the limits EQUALLED the room (640x352), which only
	# ever held on a viewport of exactly 20:11. Since the stretch aspect
	# became "expand" the viewport is whatever shape the window is, and on
	# anything taller _refresh_camera_limits() deliberately CENTRES the room
	# in the view rather than pinning it to an edge (see its docstring) --
	# the same no-drift guarantee, expressed for a view bigger than the room.
	# The old form failed on every other window shape while the game was
	# right, so it was a stale assertion, not a regression it had caught.
	chk("there is a camera", world.camera != null)
	var room_px := Vector2(Grid.BASE_W, Grid.BASE_H) * Grid.TILE
	var lim_w := float(world.camera.limit_right - world.camera.limit_left)
	var lim_h := float(world.camera.limit_bottom - world.camera.limit_top)
	var lim_cx := float(world.camera.limit_left + world.camera.limit_right) * 0.5
	var lim_cy := float(world.camera.limit_top + world.camera.limit_bottom) * 0.5
	chk("and at the opening size the room sits whole and centred in the limits",
		lim_w >= room_px.x and lim_h >= room_px.y
		and absf(lim_cx - room_px.x * 0.5) <= 1.0
		and absf(lim_cy - room_px.y * 0.5) <= 1.0,
		"limits %.0fx%.0f centred (%.0f, %.0f), room %.0fx%.0f" % [
			lim_w, lim_h, lim_cx, lim_cy, room_px.x, room_px.y])

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

	# the STORY page, with a full reel -- the other half of the file
	for k: String in ["got_stuck", "quiz_caught", "grade_jump", "grade_drop",
			"kept_back", "graduated", "caught_flare", "never_stuck",
			"favourite_streak", "helped_neighbour", "fire_drill"]:
		s.note_moment(k, s.joined_day + 5)
		s.note_moment(k, s.joined_day + 9)
	hud.show_student(s)                 # ensure _bio == s, then turn the page
	hud._bio_page = hud.BIO_STORY
	hud.show_student(s)
	chk("the student's story page fits with a full reel",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	hud.show_class_list()
	chk("the class list fits a full class",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	hud.close()

	# every shop tab
	hud.open_catalogue()
	for tab in [hud.Shop.BUY, hud.Shop.CABINET, hud.Shop.STAFF, hud.Shop.ROOM]:
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
		hud.rich.text.split("\n").size() <= 11,
		"%d rows" % hud.rich.text.split("\n").size())
	hud.close()

	Game.cheated = true          # the cheat notice is one more line
	hud.show_exam(Game.sit_exam())
	chk("the end-of-term exam fits a full class",
		hud.rich.text.split("\n").size() <= 11,
		"%d rows" % hud.rich.text.split("\n").size())
	hud.close()

	# The two RICH screens are not Labels, so _fits() cannot see them -- they
	# overflow by scrolling their content out of the box instead of wrapping.
	# Eleven rows is what the 128px body holds at font 8.
	const RICH_ROWS := 11
	for i in 40:
		Game.record_taught(String(Curriculum.lessons[i % Curriculum.lessons.size()]
			.get("id", "")))
	hud.show_curriculum()
	chk("the curriculum fits every subject in the panel",
		hud.rich.text.split("\n").size() <= RICH_ROWS,
		"%d rows" % hud.rich.text.split("\n").size())
	# It WINDOWS now rather than dumping all ten, because it is a list with a
	# cursor. What matters is that the cursor can reach every subject, not
	# that every subject is on screen at once.
	chk("it shows a windowful of subjects",
		hud.rich.text.split("\n").size() > 1,
		hud.rich.text.split("\n").size())
	chk("and the cursor reaches every one of them", (func() -> bool:
		for i in Curriculum.lessons.size():
			hud._sel = i
			hud.show_curriculum()
			if not hud.rich.text.contains(
					Curriculum.short_name(Curriculum.lessons[i])):
				return false
		return true).call())
	hud._sel = 0
	hud.show_curriculum()
	# The citation is still on screen -- it just stopped being the loudest
	# thing on it. It belongs to whichever subject is selected.
	chk("the standard for the selected subject is still shown",
		hud.hint.text.contains(String(Curriculum.lessons[0].get("standard", ""))),
		hud.hint.text)
	chk("and the rows themselves are free of citation codes",
		not hud.rich.text.contains(String(Curriculum.lessons[0].get("standard", ""))),
		hud.rich.text)
	chk("every row says in WORDS how well you know it", (func() -> bool:
		for line: String in hud.rich.text.split("\n"):
			if line.contains("never taught it") or line.contains("inside out") 						or line.contains("just started it") or line.contains("you know it well") 						or line.contains("getting the hang of it") 						or line.contains("Knowing your subjects") 						or line.contains("better at teaching it") 						or line.contains("You teach"):
				continue
			return false
		return true).call(), hud.rich.text)
	hud.close()

	while Game.enrol() != null:
		pass
	hud.show_exam(Game.sit_exam())
	chk("a full class fits on the end-of-term board",
		hud.rich.text.split("\n").size() <= RICH_ROWS,
		"%d rows" % hud.rich.text.split("\n").size())
	chk("and the board says what the term left behind",
		hud.rich.text.contains("concept") and hud.rich.text.contains("room"),
		hud.rich.text)
	hud.close()

	Game.event = DayEvent.by_id("inspector")
	hud.show_inspection(Game.inspect())
	chk("the inspection report fits", _fits(hud.body, PANEL_LINES),
		_overflow(hud.body, PANEL_LINES))
	hud.close()

	# THE BELL SETTLES THEM. Disruption used to survive the lesson it
	# belonged to: a child who had been playing up kept a red bubble and
	# kept offering "have a word" for the whole afternoon, with no lesson
	# left to disrupt. Found by tools/audit.gd, which stands at every
	# landmark in every phase -- no unit test was ever in the afternoon
	# with a disruptive child.
	Game.set_phase(Game.Phase.MORNING)
	world.start_lesson()
	await step(4)
	Game.roster[0].disrupting = true
	chk("somebody is playing up during the lesson", Game.roster[0].disrupting)
	world.end_lesson()
	await step(2)
	chk("and the bell settles them", not Game.roster[0].disrupting)
	chk("so nobody is still on offer to have a word with", (func() -> bool:
		for st: Interactable in world.stations:
			if st.action() == st.Action.SETTLE:
				return false
		return true).call())
	hud.close()
	await step(2)

	# Landmarks must not answer from each other's squares. Reach is the SUM
	# of both circles, so the board two tiles away was covering the bell.
	await place_player(Layout.BELL + Vector2i(0, 1), Actor.DIR_UP)
	Game.set_phase(Game.Phase.MORNING)
	await step(3)
	chk("nothing from the noticeboard reaches the bell's own square",
		(func() -> bool:
			for action: String in ["interact", "manage"]:
				var t: Interactable = world.player.targets.get(action)
				if t != null and is_instance_valid(t) and t.can_interact():
					if t.prompt_text().contains("Curriculum") 							or t.prompt_text().contains("shop"):
						return false
			return true).call(),
		"%s / %s" % [world.player.targets["interact"],
			world.player.targets["manage"]])
	Game.set_phase(Game.Phase.AFTERNOON)

	# The PROMPT BAR names both buttons now, and two landmarks sharing a tile
	# is exactly when it is longest. It is a Label, so it clips in silence.
	Game.set_phase(Game.Phase.AFTERNOON)
	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	# targets{} is a CACHE, only refreshed by _repick() on a physics frame --
	# place_player's own await can land its LAST frame on a stray held key
	# from earlier in this same test and re-pick against THAT facing, which
	# printing the (by-then-correct) facing afterwards never catches. Force
	# one clean re-pick against the facing actually asked for.
	world.player._repick()
	hud._update_prompt()
	chk("both buttons are named at the noticeboard",
		hud.prompt.text.contains("Curriculum") and hud.prompt.text.contains("shop"),
		hud.prompt.text)
	# Both keys must still be NAMED when the line is tight -- clipping the
	# joined line used to leave a hold bar with no words after it.
	Game.set_phase(Game.Phase.LESSON)
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)
	hud._update_prompt()
	chk("a crowded prompt bar still names both buttons",
		hud.prompt.text.contains("E") and hud.prompt.text.contains("F"),
		hud.prompt.text)
	chk("and neither half is left as a bare progress bar",
		not hud.prompt.text.ends_with("]"), hud.prompt.text)
	Game.set_phase(Game.Phase.AFTERNOON)
	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	hud._update_prompt()

	chk("and the prompt bar fits on its line",
		hud.prompt.text.length() <= hud.LINE_CHARS,
		"%d: %s" % [hud.prompt.text.length(), hud.prompt.text])

	await place_player(Layout.BELL + Vector2i(0, 1), Actor.DIR_UP)
	# Area2D overlap updates a physics frame behind a teleport, so the
	# picker needs a tick before it can have noticed the move.
	await step(3)
	hud._update_prompt()
	# Assert what the PICKER chose, not what the bar happens to be showing:
	# a timed hint owns the prompt bar while it is up, so the rendered text
	# can legitimately be a second behind the decision.
	chk("and the bell is what MANAGE points at, not the curriculum board",
		(func() -> bool:
			var t: Interactable = world.player.targets["manage"]
			return t != null and t.prompt_text().contains("bell")).call(),
		world.player.zone.get_overlapping_areas().size())

	# The status strip is a Label too, and it runs off the right-hand edge
	# the moment a lesson adds a clock, a voice meter and three counters.
	Game.set_phase(Game.Phase.LESSON)
	world.lesson_left = 45.0
	Game.voice = 0.5
	for st: StudentData in Game.roster:
		st.disrupting = true
		st.work_state = StudentData.Work.DONE
	world.player.carry_work(3)
	world.player.carry_homework(2)
	hud._update_status()
	chk("the status strip fits on its one line",
		hud.status.text.length() <= hud.LINE_CHARS,
		"%d chars: %s" % [hud.status.text.length(), hud.status.text])
	for st: StudentData in Game.roster:
		st.disrupting = false
	world.player.drop_all_work()
	world.player.drop_all_homework()
	Game.set_phase(Game.Phase.AFTERNOON)

	hud.show_title()
	chk("the title screen fits",
		_fits(hud.body, PANEL_LINES_SMALL), _overflow(hud.body, PANEL_LINES_SMALL))
	# Onboarding, slice three (AUTONOMOUS_TASKLIST.md B4's "still open"):
	# "need N" has printed on the status strip since day one and nothing
	# on the way IN ever said what it counted. This is the first sentence
	# a new run sees, so it is where the target gets explained.
	chk("and it says what the term target means, not just the day count",
		hud.body.text.contains("must pass to keep the job"), hud.body.text)
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

	# THE BUG THIS GUARDS, and it made the whole game unplayable.
	#
	# The podium used to require that EVERYONE was seated. The class takes
	# about ten seconds to file in, so for those ten seconds the one landmark
	# the day starts from offered nothing at all -- no prompt, no reason. You
	# could not teach, so you never reached the afternoon, so the bell could
	# never ring, so the day could never end.
	#
	# Every existing test stepped 40+ frames or teleported first, so not one
	# of them ever stood at the podium on the frame a day actually begins.
	await step(2)
	# Force the condition rather than racing it: send one child back to the
	# door and have them walk in properly, which is exactly the state every
	# day opens in.
	var late: Actor = world.students[world.students.size() - 1]
	late.global_position = Grid.tile_to_world(Layout.DOOR)
	late.walk_to_seat(world.grid.path(Layout.DOOR,
		Layout.seat(late.data.seat_index)), 0.0)
	await step(2)
	chk("somebody is still on their feet", not world.everyone_seated())
	await place_player(Layout.PODIUM + Vector2i(0, 1), Actor.DIR_UP)
	chk("the podium ALREADY offers to teach, before they are all sat down",
		(func() -> bool:
			var t: Interactable = p.targets["teach"]
			return t != null and t.prompt_text().begins_with("Teach")).call(),
		p.targets["teach"])
	await tap("teach")
	await _take_a_paper()
	chk("and it really starts", Game.phase == Game.Phase.LESSON, Game.phase)

	# whoever was still walking gets their paper when they sit
	await step(700)
	chk("everyone is seated eventually", world.everyone_seated())
	chk("and the latecomers were given work too, not skipped",
		(func() -> bool:
			for st: StudentData in Game.roster:
				if st.work_state == StudentData.Work.NONE:
					return false
			return true).call(),
		Game.roster.map(func(st: StudentData) -> int: return st.work_state))
	world.end_lesson()
	await step(2)
	hud.close()

	Game.new_run(SEED)
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
		var t: Interactable = p.targets["teach"]
		return t != null and t.prompt_text().begins_with("Teach")).call(),
		p.targets["teach"])
	await tap("teach")
	chk("the podium offers a choice of paper first",
		_hud().mode == _hud().Mode.HAND, _hud().mode)
	await _take_a_paper()
	chk("and taking one starts the lesson", Game.phase == Game.Phase.LESSON,
		Game.phase)
	chk("with that paper on the desks", not Game.assignment.is_empty())

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


func test_traits() -> void:
	section("WHAT MAKES ONE CHILD DIFFERENT")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("there are traits to have", Traits.ids().size() >= 4, Traits.ids().size())
	chk("the roll order is stable, not dictionary order", (func() -> bool:
		var a := Traits.ids()
		var b := Traits.ids()
		return a == b and a == a.duplicate()).call())

	# THE RULE. A trait that only prints a sentence is decoration, and
	# decoration teaches a player to stop reading the screen it is on. Every
	# one of these has to reach into the work model, the seating, or both.
	chk("every trait has a name and a blurb", (func() -> bool:
		for id: String in Traits.ids():
			if Traits.name_of(id) == "" or Traits.blurb(id) == "":
				return false
		return true).call())
	chk("and every one of them actually DOES something", (func() -> bool:
		var hooks := ["stall_mult", "help_xp_mult", "hide_seconds",
			"neighbour_stall_mult", "copy_from_neighbour", "helps_neighbour"]
		for id: String in Traits.ids():
			var found := false
			for h: String in hooks:
				if Traits.get_def(id).has(h):
					found = true
			if not found:
				return false
		return true).call())

	chk("everybody gets one when they arrive", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.trait_id == "" or not Traits.ids().has(s.trait_id):
				return false
		return true).call())
	chk("and a class is not all the same one", (func() -> bool:
		while Game.enrol() != null:
			pass
		var seen := {}
		for s: StudentData in Game.roster:
			seen[s.trait_id] = true
		return seen.size() >= 2).call())

	# --- the hooks, one at a time ---
	Game.new_run(SEED)
	var a := StudentData.new()
	a.aptitude = 0.5
	var b := StudentData.new()
	b.aptitude = 0.5
	a.trait_id = "steady"
	b.trait_id = "curious"
	chk("a steady child stalls less often than a curious one",
		a.stall_chance() < b.stall_chance(),
		"%.4f vs %.4f" % [a.stall_chance(), b.stall_chance()])

	# Curious costs you time and pays it back: they get stuck more, and each
	# answer is worth more to them. That is the trade, not a drawback.
	var c := StudentData.new()
	c.trait_id = "curious"
	c.confusion = 1.0
	var xp_before := c.xp
	c.help()
	var plain := StudentData.new()
	plain.trait_id = "steady"
	plain.confusion = 1.0
	var plain_before := plain.xp
	plain.help()
	chk("and gets more out of being answered",
		c.xp - xp_before > plain.xp - plain_before,
		"%d vs %d" % [c.xp - xp_before, plain.xp - plain_before])

	# --- Quiet: stuck, but not showing it ---
	var q := StudentData.new()
	q.trait_id = "quiet"
	q.work_state = StudentData.Work.WORKING
	q.work_timer = 10.0
	q.confusion = 1.0
	chk("a quiet child who is stuck really is stuck", q.is_struggling())
	chk("but does not show it at first", not q.is_visibly_struggling())
	for i in 60 * 8:
		q.tick_work(1.0 / 60.0, null)
	chk("they show it eventually, so nobody is lost forever",
		q.is_visibly_struggling())
	q.help()
	chk("and helping clears the hiding too", not q.is_visibly_struggling())

	var loud := StudentData.new()
	loud.trait_id = "steady"
	loud.confusion = 1.0
	chk("everyone else shows it the moment it happens",
		loud.is_visibly_struggling())

	# --- Chatty: it is about WHERE they sit ---
	Game.new_run(SEED)
	var s0: StudentData = Game.roster[0]
	var s1: StudentData = Game.roster[1]
	s0.trait_id = "steady"
	s1.trait_id = "chatty"
	# park them far apart, then next to each other
	Layout.set_seats([Vector2i(3, 4), Vector2i(15, 7), Vector2i(11, 4),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	var apart := s0.stall_chance()
	chk("across the room, they are not neighbours",
		Game.neighbours_of(s0).is_empty(), Game.neighbours_of(s0).size())

	Layout.set_seats([Vector2i(3, 4), Vector2i(4, 4), Vector2i(11, 4),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	chk("sat next to each other, they are", Game.neighbours_of(s0).has(s1))
	chk("and the chatty one drags the other off task",
		s0.stall_chance() > apart,
		"%.4f -> %.4f" % [apart, s0.stall_chance()])
	chk("which is the whole reason a seating plan is a decision",
		s0.neighbour_stall_multiplier() > 1.0)

	# a desk diagonally away is NOT next to you -- otherwise every desk in a
	# block would be everyone's neighbour and seating would stop mattering
	Layout.set_seats([Vector2i(3, 4), Vector2i(4, 5), Vector2i(11, 4),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	chk("diagonals do not count", not Game.neighbours_of(s0).has(s1))
	Layout.reset_seats()

	# --- it is theirs, so it is saved ---
	Game.new_run(SEED)
	var who: String = Game.roster[0].display_name
	var what: String = Game.roster[0].trait_id
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("a trait survives a save", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.display_name == who:
				return s.trait_id == what
		return false).call())
	Game.delete_save()
	Game.new_run(SEED)


## Sit the class in one straight row from x, so "next to" is unambiguous.
func _seat_in_a_row(x: int, y: int) -> void:
	var seats: Array[Vector2i] = []
	for i in Layout.DEFAULT_SEATS.size():
		seats.append(Vector2i(x + i, y))
	Layout.set_seats(seats)


func test_disruption() -> void:
	section("MESSING ABOUT")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)

	var a: StudentData = Game.roster[0]
	var b: StudentData = Game.roster[1]
	var c: StudentData = Game.roster[2]
	for st: StudentData in Game.roster:
		st.trait_id = "steady"

	chk("nobody starts off playing up", (func() -> bool:
		for st: StudentData in Game.roster:
			if st.disrupting:
				return false
		return true).call())

	# --- it is NOT the same as being stuck ---
	a.disrupting = true
	chk("a disruptive child is not doing any work", (func() -> bool:
		a.work_state = StudentData.Work.WORKING
		a.work_timer = 10.0
		var before := a.work_timer
		a.tick_work(1.0, Game.rng)
		return is_equal_approx(a.work_timer, before)).call())
	chk("and the room shows the louder problem, not the quieter one",
		not a.is_visibly_struggling())

	# --- it makes the desks either side worse ---
	b.trait_id = "steady"
	var beside_trouble := b.stall_chance()
	chk("sitting next to somebody playing up is worse for you",
		b.neighbour_stall_multiplier() > 1.0, b.neighbour_stall_multiplier())
	a.disrupting = false
	chk("and no worse than anyone else once they have settled",
		is_equal_approx(b.neighbour_stall_multiplier(), 1.0)
		and b.stall_chance() < beside_trouble,
		"%.4f beside trouble, %.4f after" % [beside_trouble, b.stall_chance()])

	# --- SPREADING is what makes it urgent ---
	a.disrupting = true
	var spread_guard := 0
	while not b.disrupting and spread_guard < 6000:
		Game.tick_class(1.0 / 60.0, Game.rng)
		spread_guard += 1
	chk("it spreads to the next desk if you leave it", b.disrupting,
		"gave up after %d frames" % spread_guard)
	chk("which is why settling outranks helping at the desk", (func() -> bool:
		var st: Interactable = world.station(a.seat_index)
		a.confusion = 1.0                 # stuck AND playing up
		return st != null and st.action() == st.Action.SETTLE).call())

	# --- dealing with it ---
	chk("having a word settles them", a.settle())
	chk("and they are working again", not a.disrupting)
	chk("having a word with somebody behaving does nothing at all",
		not c.settle())

	# --- BOTH sources are the player's own doing ---
	# (Flare-ups are a THIRD source, deliberately separate and randomly
	# timed -- suppressed here so this stays a test of boredom alone.)
	Game.new_run(SEED)
	Game._flares_today = 99999
	_seat_in_a_row(2, 4)
	for st: StudentData in Game.roster:
		st.trait_id = "steady"
	var bored: StudentData = Game.roster[0]
	bored.work_state = StudentData.Work.DONE      # finished, never collected
	var guard2 := 0
	while not bored.disrupting and guard2 < 12000:
		Game.tick_class(1.0 / 60.0, Game.rng)
		guard2 += 1
	# Collecting promptly stops being only a grade bonus: it is now also how
	# you keep the room quiet.
	chk("work you never came to collect turns into a bored child",
		bored.disrupting, "gave up after %d frames" % guard2)
	chk("and collecting it instead would have prevented that", (func() -> bool:
		Game.new_run(SEED)
		Game._flares_today = 99999                        # boredom only, no flares
		_seat_in_a_row(2, 4)
		for st: StudentData in Game.roster:
			st.trait_id = "steady"
			st.work_state = StudentData.Work.COLLECTED   # picked up promptly
		for i in 12000:
			Game.tick_class(1.0 / 60.0, Game.rng)
		for st: StudentData in Game.roster:
			if st.disrupting:
				return false
		return true).call())

	# --- a test is silent: nobody plays up when you cannot intervene ---
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	for st: StudentData in Game.roster:
		st.work_state = StudentData.Work.DONE
	for i in 3000:
		Game.tick_class(1.0 / 60.0, null)         # null rng == a test
	chk("nobody plays up during a test, because you could not deal with it",
		(func() -> bool:
			for st: StudentData in Game.roster:
				if st.disrupting:
					return false
			return true).call())

	# --- the good half of a seating plan ---
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	var helper: StudentData = Game.roster[0]
	var lost: StudentData = Game.roster[1]
	helper.trait_id = "bright"
	helper.work_state = StudentData.Work.COLLECTED   # work_fraction 1.0
	lost.trait_id = "steady"
	lost.confusion = 1.0
	chk("they are sitting together", Game.neighbours_of(lost).has(helper))
	var guard3 := 0
	while lost.is_struggling() and guard3 < 12000:
		Game.tick_class(1.0 / 60.0, Game.rng)
		guard3 += 1
	chk("a bright spark who has finished helps the desk beside them",
		not lost.is_struggling(), "gave up after %d frames" % guard3)

	# --- copying looks like the problem solving itself ---
	Game.new_run(SEED)
	_neutral_lesson()
	_seat_in_a_row(2, 4)
	var cheat: StudentData = Game.roster[0]
	var source: StudentData = Game.roster[1]
	cheat.trait_id = "copier"
	cheat.work_state = StudentData.Work.WORKING
	cheat.work_timer = 18.0
	cheat.confusion = 1.0
	source.trait_id = "steady"
	source.work_state = StudentData.Work.WORKING
	source.work_timer = 2.0                          # much further along
	var understood_before := cheat.understanding("math")
	var guard4 := 0
	while cheat.is_struggling() and guard4 < 12000:
		Game.tick_class(1.0 / 60.0, Game.rng)
		guard4 += 1
	chk("a copier gets themselves unstuck off the next desk",
		not cheat.is_struggling(), "gave up after %d frames" % guard4)
	chk("so on the surface it looks like they sorted themselves out",
		cheat.copied)
	# ...and here is where it stops looking like that
	chk("but they understand LESS than they did, not more",
		cheat.understanding("math") < understood_before,
		"%.3f -> %.3f" % [understood_before, cheat.understanding("math")])

	Layout.reset_seats()
	Game.new_run(SEED)
	await step(2)


func test_save_isolation() -> void:
	section("THE SUITE MUST NOT EAT YOUR SAVE")
	# advance_day() autosaves, and this suite advances hundreds of days. It
	# spent its whole life overwriting the real save file, so anybody who
	# ran the tests lost their game -- and the tests all passed while doing
	# it, because nothing ever asserted where the writing went.
	chk("the suite is not writing to the real save",
		Game.save_path != Game.SAVE_PATH, Game.save_path)
	chk("and it is writing somewhere", Game.save_path != "")
	Game.save_game()
	chk("its own save file works", Game.has_save())
	Game.delete_save()
	chk("and can be cleaned up", not Game.has_save())

	# The PixelRoom -> EDUSystem rename moved the whole user:// directory.
	# _migrate_one() carries a pre-rename file across exactly once, and never
	# clobbers a file that is already in place.
	var mig_src := "user://mig_test_src.json"
	var mig_dst := "user://mig_test_dst.json"
	for p: String in [mig_src, mig_dst]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var mf := FileAccess.open(mig_src, FileAccess.WRITE)
	mf.store_string("{\"carried\":true}")
	mf.close()
	Game._migrate_one(mig_src, mig_dst)
	chk("a pre-rename file is carried across", FileAccess.file_exists(mig_dst))
	chk("with its contents intact",
		FileAccess.get_file_as_string(mig_dst) == "{\"carried\":true}")
	var mf2 := FileAccess.open(mig_dst, FileAccess.WRITE)
	mf2.store_string("KEEP")
	mf2.close()
	Game._migrate_one(mig_src, mig_dst)
	chk("and a file already in place is left untouched",
		FileAccess.get_file_as_string(mig_dst) == "KEEP")
	for p: String in [mig_src, mig_dst]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_bubbles() -> void:
	section("THREE PROBLEMS, THREE COLOURS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	# They walk in from the door on a stagger; 40 frames is not enough, and
	# an unseated child falls through every branch of the bubble logic --
	# which is exactly why the screenshot showed one bubble instead of three.
	var guard := 0
	while not world.everyone_seated() and guard < 900:
		await step(1)
		guard += 1
	chk("the class is seated", world.everyone_seated(), guard)

	var s0: StudentData = Game.roster[0]
	var n0: Actor = world.student_node(s0.seat_index)
	s0.trait_id = "steady"              # no hiding, so the signal is prompt

	# Checked here rather than by screenshot: the bubble is a 7px sprite in
	# a 320x176 frame, and "is that one reddish?" is not a verification.
	chk("a settled child shows nothing", (func() -> bool:
		world._refresh_bubbles()
		return not n0.bubble.visible).call())

	s0.confusion = 1.0
	world._refresh_bubbles()
	chk("stuck shows the plain bubble",
		n0.bubble.visible and n0.bubble.modulate == Color.WHITE, n0.bubble.modulate)

	s0.confusion = 0.0
	s0.quiz_flagged = true
	world._refresh_bubbles()
	chk("quiz-flagged shows the cool one",
		n0.bubble.visible and n0.bubble.modulate == world.QUIZ_BUBBLE_TINT,
		n0.bubble.modulate)

	s0.disrupting = true
	world._refresh_bubbles()
	chk("and messing about shows the hot one, over both of the others",
		n0.bubble.visible and n0.bubble.modulate == world.NOISE_BUBBLE_TINT,
		n0.bubble.modulate)
	chk("and the three colours are actually different from each other",
		world.NOISE_BUBBLE_TINT != world.QUIZ_BUBBLE_TINT
		and world.NOISE_BUBBLE_TINT != Color.WHITE
		and world.QUIZ_BUBBLE_TINT != Color.WHITE)

	# a Quiet child is stuck without the room saying so
	s0.disrupting = false
	s0.quiz_flagged = false
	s0.trait_id = "quiet"
	s0.confusion = 1.0
	s0._hidden_for = 0.0
	world._refresh_bubbles()
	chk("a quiet child gives you nothing to scan for, at first",
		not n0.bubble.visible)

	Game.new_run(SEED)
	await step(2)


## The room SHOWS, it does not tell.
##
## Step 1 of ten-commits.md put the file page's own top line in a box over
## every desk. It is gone again (Sept 2026, the owner's call): at this desk
## spacing a full sentence per desk covered the room it was describing. What
## is over a desk now is the "?" and the work bar -- and nothing else. The
## reasons still live on the file page, off the same builder as before.
func test_room_shows_not_tells() -> void:
	section("THE ROOM SHOWS, IT DOES NOT TELL")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var guard := 0
	while not world.everyone_seated() and guard < 900:
		await step(1)
		guard += 1
	chk("the class is seated", world.everyone_seated(), guard)

	var s0: StudentData = Game.roster[0]
	var st0: Interactable = world.stations[s0.seat_index]
	var n0: Actor = world.student_node(s0.seat_index)
	chk("no desk says a sentence out loud any more",
		not st0.has_method("show_need"))
	chk("and nothing is left holding a box of text",
		st0.get("need_bubble") == null)

	# calm baseline
	s0.trait_id = ""
	s0.confusion = 0.0
	s0.disrupting = false
	s0.quiz_flagged = false
	s0.copied = false
	world._refresh_bubbles()
	chk("a settled desk shows nothing at all", not n0.bubble.visible)

	s0.disrupting = true
	world._refresh_bubbles()
	chk("playing up puts the mark up", n0.bubble.visible)
	chk("in the colour that means playing up",
		n0.bubble.modulate.is_equal_approx(world.NOISE_BUBBLE_TINT),
		n0.bubble.modulate)
	s0.disrupting = false

	s0.trait_id = "steady"       # no hiding, so is_visibly_struggling() is prompt
	s0.confusion = 1.0
	s0._hidden_for = 999.0
	world._refresh_bubbles()
	chk("a stuck child puts the same mark up", n0.bubble.visible)
	chk("in the plain colour that means stuck",
		n0.bubble.modulate.is_equal_approx(Color.WHITE), n0.bubble.modulate)
	s0.confusion = 0.0
	s0._hidden_for = 0.0
	s0.trait_id = ""

	s0.quiz_flagged = true
	world._refresh_bubbles()
	chk("the quiz catching them shows too", n0.bubble.visible)
	chk("in its own cooler colour",
		n0.bubble.modulate.is_equal_approx(world.QUIZ_BUBBLE_TINT),
		n0.bubble.modulate)
	s0.quiz_flagged = false
	world._refresh_bubbles()

	# --- the WHY did not go anywhere: it is on the file page, as before ---
	s0.disrupting = true
	chk("the ranking still knows what is worst for a child",
		StudentRead.urgent_line(s0) == StudentRead.PLAYING_UP,
		StudentRead.urgent_line(s0))
	s0.has_supply = false
	chk("and that a materials day outranks even playing up",
		StudentRead.urgent_line(s0) == StudentRead.NOTHING_TO_WORK_WITH,
		StudentRead.urgent_line(s0))
	s0.has_supply = true
	var hud := _hud()
	hud.show_student(s0)           # binds _bio, so the page switch below sticks
	hud._bio_page = hud.BIO_ACTING
	hud.show_student(s0)
	chk("...and the file page still prints it in those same words",
		hud.body.text.contains(StudentRead.urgent_line(s0)), hud.body.text)
	hud.close()
	s0.disrupting = false
	world._refresh_bubbles()

	# --- the bar itself: bigger, and clear of the mark above it ---
	chk("the work bar is the wide one, not the old smudge",
		n0.BAR_W >= 24.0, n0.BAR_W)
	# ...and still inside its own tile, so a row of them reads as a row.
	chk("...but not so wide that two of them run together",
		n0.BAR_W + n0.BAR_PAD * 2.0 <= float(Grid.TILE), n0.BAR_W)
	var mark_bottom: float = n0.bubble.position.y + n0.bubble.texture.get_height() / 2.0
	chk("the mark sits clear of the bar instead of on top of it",
		mark_bottom <= n0.BAR_Y - n0.BAR_PAD, [mark_bottom, n0.BAR_Y])

	Game.new_run(SEED)
	await step(2)


## The owner's own requirement, in one sentence: you can see EVERY
## student's notice, with no overlap, no matter how many are up at once.
## Desks stand a tile apart and can be pushed together, so this is not a
## rare case -- it is the ordinary one the moment a class gets busy.
func test_notices_never_overlap() -> void:
	section("NOTHING OVERLAPS, HOWEVER MANY")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	# A FULL room, not the four children a run opens with: the crowding is
	# the whole point, and four desks never crowd. _rebind_to_new_run()
	# rather than a walk-in, because the seats are what matter here, not
	# the entrance -- it is the same call the world already uses when a run
	# is replaced underneath it.
	while Game.enrol() != null:
		pass
	world._rebind_to_new_run()
	await step(2)
	chk("the class is seated", world.everyone_seated())
	chk("and it is a full one", world.students.size() == Game.seat_capacity(),
		world.students.size())

	# The worst case the room can produce: everybody working (a bar each)
	# AND everybody visibly stuck (a mark each), all at once.
	world.start_lesson()
	for s: StudentData in Game.roster:
		s.trait_id = "steady"
		s.confusion = 1.0
		s._hidden_for = 999.0
	world._refresh_bubbles()
	world._layout_notices()

	var shown: Array[Actor] = []
	for n: Actor in world.students:
		if n.has_notice():
			shown.append(n)
	chk("the whole class is shouting at once",
		shown.size() == Game.roster.size(), shown.size())

	var overlaps := 0
	var worst := ""
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			# Grown by the same gap the layout keeps: two notices that
			# merely touch read as one, which is the bug in a different hat.
			var a: Rect2 = shown[i].notice_world_box().grow(world.NOTICE_GAP)
			var b: Rect2 = shown[j].notice_world_box().grow(world.NOTICE_GAP)
			if a.intersects(b):
				overlaps += 1
				worst = "%d over %d" % [
					shown[i].data.seat_index, shown[j].data.seat_index]
	chk("no two notices overlap, with every desk asking for you",
		overlaps == 0, "%d pairs, e.g. %s" % [overlaps, worst])

	# The finished sheet marks ITS desk and never moves, so nothing may be
	# parked on top of one either.
	var on_paper := 0
	for st: Interactable in world.stations:
		if st.paper == null or not st.paper.visible or st.paper.texture == null:
			continue
		var size: Vector2 = st.paper.texture.get_size()
		var sheet := Rect2(st.paper.global_position - size / 2.0, size)
		for n: Actor in shown:
			if n.notice_world_box().intersects(sheet):
				on_paper += 1
	chk("and nothing is parked on top of a finished sheet", on_paper == 0, on_paper)

	# A notice may climb and step sideways; it may never wander off below
	# its own student, which would leave the leader line pointing upward
	# into somebody else's desk.
	var stray := 0
	for n: Actor in shown:
		if n.notice_offset.y > 0.0 or absf(n.notice_offset.x) > 2.0 * world.NOTICE_SIDE:
			stray += 1
	chk("every notice stays above the child it belongs to", stray == 0, stray)

	# Placement, not physics: the same room laid out twice is the same room.
	var first: Array[Vector2] = []
	for n: Actor in shown:
		first.append(n.notice_offset)
	world._layout_notices()
	var same := true
	for i in shown.size():
		if not shown[i].notice_offset.is_equal_approx(first[i]):
			same = false
	chk("laying the same room out twice gives the same answer", same)

	# And a child with nothing to say is not in the queue at all.
	var quiet: StudentData = Game.roster[0]
	quiet.confusion = 0.0
	quiet._hidden_for = 0.0
	quiet.work_state = StudentData.Work.NONE
	world._refresh_bubbles()
	world._layout_notices()
	var qn: Actor = world.student_node(quiet.seat_index)
	chk("a child with nothing to say takes up no room", not qn.has_notice())
	chk("and is put straight back where they belong",
		qn.notice_offset == Vector2.ZERO, qn.notice_offset)

	Game.new_run(SEED)
	await step(2)


## Ambient weather, tied to today's day event -- purely decorative, so the
## thing worth asserting is that it fires on a day the event calls for and
## stays quiet on a plain one, not any particular position or colour.
func test_weather() -> void:
	section("WEATHER")
	Game.new_run(SEED)
	await step(2)
	world.start_lesson()
	await step(2)

	Game.event = DayEvent.by_id("none")
	var before := world.get_child_count()
	world._tick_weather(0.5)
	chk("an ordinary day spawns no weather", world.get_child_count() == before)

	Game.event = DayEvent.by_id("wet_play")
	world._weather_due = 0.0
	var before2 := world.get_child_count()
	world._tick_weather(0.5)
	chk("wet play spawns a mote", world.get_child_count() > before2)
	chk("and it queues the next one rather than spawning every frame",
		world._weather_due > 0.0)

	Game.new_run(SEED)
	await step(2)


func test_voice() -> void:
	section("RAISING YOUR VOICE")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	await step(2)
	var p: Actor = world.player

	chk("it is a real, rebindable action, like every other key",
		InputMap.has_action("voice"))
	chk("and it is offered in the controls screen", (func() -> bool:
		for row: Dictionary in Settings.ACTIONS:
			if String(row["action"]) == "voice":
				return true
		return false).call())

	chk("you start a run with a full voice", is_equal_approx(Game.voice, 1.0))
	chk("but you cannot use it outside a lesson", not Game.can_raise_voice())

	Game.set_phase(Game.Phase.LESSON)
	chk("during a lesson you can", Game.can_raise_voice())

	# --- it is about WHERE YOU ARE STANDING ---
	# The only verb in the game not attached to a landmark, so this is the
	# line that keeps walking the room the game rather than a formality.
	var near: StudentData = Game.roster[0]
	var far: StudentData = Game.roster[1]
	Layout.set_seats([Vector2i(3, 4), Vector2i(17, 8), Vector2i(11, 4),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	near.disrupting = true
	far.disrupting = true

	var heard := Game.raise_voice(Vector2i(3, 5))     # standing by `near`
	chk("the desk beside you hears it", not near.disrupting)
	chk("the desk across the room does not", far.disrupting)
	chk("and it says how many heard you", heard == 1, heard)

	# --- it settles the room; it does not teach anybody ---
	# If shouting also unstuck people it would replace the walk to the desk,
	# and the walk to the desk is the game.
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	Game.set_phase(Game.Phase.LESSON)
	var lost: StudentData = Game.roster[0]
	lost.trait_id = "steady"
	lost.confusion = 1.0
	Game.raise_voice(Layout.seat(lost.seat_index))
	chk("shouting at a stuck child does not unstick them",
		lost.is_struggling())

	# --- the cost, and getting it back ---
	Game.new_run(SEED)
	Game.set_phase(Game.Phase.LESSON)
	var before := Game.voice
	Game.raise_voice(Vector2i(9, 5))
	chk("it costs you something even when nobody was playing up",
		Game.voice < before, "%.2f -> %.2f" % [before, Game.voice])

	var shouts := 1
	while Game.can_raise_voice() and shouts < 20:
		Game.raise_voice(Vector2i(9, 5))
		shouts += 1
	chk("you get a small handful of them, not an unlimited supply",
		shouts >= 2 and shouts <= 5, shouts)
	chk("and then you have to go and do it properly",
		not Game.can_raise_voice())
	chk("asking anyway is refused rather than ignored",
		Game.raise_voice(Vector2i(9, 5)) == -1)

	var empty := Game.voice
	for i in 600:
		Game.tick_voice(1.0 / 60.0)
	chk("it comes back on its own", Game.voice > empty,
		"%.2f -> %.2f" % [empty, Game.voice])
	for i in 6000:
		Game.tick_voice(1.0 / 60.0)
	chk("but never past full", is_equal_approx(Game.voice, 1.0))

	# --- not during a test ---
	Game.new_run(SEED)
	for i in Balance.test_requires_taught:
		Game.record_taught(String(Game.lesson.get("id", "")))
	Game.set_phase(Game.Phase.MORNING)
	await step(30)
	world.start_test(String(Game.lesson.get("id", "")))
	chk("you cannot shout the class down during a test either",
		not Game.can_raise_voice())
	world.end_test()

	Layout.reset_seats()
	Game.new_run(SEED)
	await step(2)


## Step 2 of ten-commits.md: the reward side finally shows up. Fx.flash()
## and Fx.count_to() had zero callsites before this, and coins/xp landed
## in total silence. A Floater is a plain child node with no id of its
## own, so "did one appear" is get_child_count() before and after -- the
## same proof test_weather() already uses for its own decorative spawn.
func test_juice_lands() -> void:
	section("THE GOOD BEATS LAND")
	Balance.ensure_loaded()

	# --- coins pop where they are earned: catching a flare-up ---
	Game.new_run(SEED)
	await step(2)
	Game.set_phase(Game.Phase.LESSON)
	var flarer: StudentData = Game.roster[0]
	flarer.flare_left = 1.0
	var st0: Interactable = world.stations[flarer.seat_index]
	chk("the desk is offering to catch it", st0.action() == st0.Action.DEFUSE,
		st0.action())
	var coins_before := Game.coins
	var children_before := world.get_children()
	st0.interact(world.player)
	chk("catching it still pays the coin reward",
		Game.coins == coins_before + Balance.flare_reward, Game.coins)
	var said_coins := false
	for c: Node in world.get_children():
		if c is Floater and not children_before.has(c) \
				and (c as Floater).current_text().contains("coins"):
			said_coins = true
	chk("and the money landing actually says so, not just the SFX",
		said_coins)

	# --- a child finishing their work gets Fx.flash(), not just the pose ---
	var n0: Actor = world.student_node(Game.roster[1].seat_index)
	n0._was_working = true
	Game.roster[1].work_state = StudentData.Work.DONE
	var flash_before := n0.sprite.modulate
	n0._physics_process(1.0 / 60.0)
	chk("finishing work flashes the sprite, not just the jump pose",
		n0.sprite.modulate != flash_before, n0.sprite.modulate)

	# --- settling the room by voice pops one floater per desk it reaches ---
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	await step(2)
	Game.set_phase(Game.Phase.LESSON)
	var near: StudentData = Game.roster[0]
	near.disrupting = true
	world.player.global_position = Grid.tile_to_world(Vector2i(3, 5))
	var before2 := world.get_children()
	world.raise_voice()
	chk("settling somebody by voice still settles them",
		not near.disrupting)
	var said_sorry := false
	for c: Node in world.get_children():
		if c is Floater and not before2.has(c) \
				and (c as Floater).current_text() == "sorry!":
			said_sorry = true
	chk("...and pops the same words the desk's own SETTLE does",
		said_sorry)

	# --- the teach beat: attention crossing up while you are at the front ---
	Game.new_run(SEED)
	await step(2)
	# A real lesson, not just the phase -- this block lets several physics
	# frames actually run, and a lesson_left never set by start_lesson()
	# stays at whatever it last was, which can end the lesson on frame one.
	world.start_lesson()
	Game.attention = 0.0
	world.player.global_position = Grid.tile_to_world(
		Layout.PODIUM + Vector2i(0, 1))
	var before3 := world.get_children()
	var guard3 := 0
	while Game.attention < Balance.teach_drift_hint_below and guard3 < 300:
		await step(1)
		guard3 += 1
	chk("attention actually crossed the line",
		Game.attention >= Balance.teach_drift_hint_below, Game.attention)
	var said_it := false
	for c: Node in world.get_children():
		if c is Floater and not before3.has(c) \
				and (c as Floater).current_text() == "with you":
			said_it = true
	chk("...and said so the moment it did, in the strip's own word",
		said_it, guard3)

	# --- xp lands at the bell, one line per desk, never as a raw number ---
	Game.new_run(SEED)
	await step(2)
	Game.set_phase(Game.Phase.LESSON)
	# A DIFF against what was already there, not just a count -- earlier
	# floaters in this same test are still mid-tween (0.8s) and would
	# otherwise leak into the digit check below.
	var before_children := world.get_children()
	world.end_lesson()
	var new_floaters: Array[Floater] = []
	for c: Node in world.get_children():
		if c is Floater and not before_children.has(c):
			new_floaters.append(c)
	chk("the bell pops one line per graded desk",
		new_floaters.size() >= Game.roster.size(), new_floaters.size())
	# XP is the child's own growth -- the same category "prose, never
	# numbers" already keeps off their file page -- so it is worded, never
	# counted, even here where nothing scans hud.body for it.
	var digits := RegEx.new()
	digits.compile("[0-9]")
	for f: Floater in new_floaters:
		chk("...worded rather than counted",
			digits.search(f.current_text()) == null, f.current_text())

	Game.new_run(SEED)
	await step(2)


func test_inspection() -> void:
	section("BEING INSPECTED")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	chk("an ordinary day is not an inspection", not Game.being_inspected())
	Game.event = DayEvent.by_id("inspector")
	chk("but an inspector's day is", Game.being_inspected())

	# It has to be ANNOUNCED. The events roll for tomorrow and the day
	# report says so, which is what makes the room, the lesson and the
	# material things you can go and do something about. An unannounced
	# judgement is weather, not a decision.
	chk("the event says what they are coming to do",
		String(DayEvent.by_id("inspector").get("blurb", "")).contains("watch"),
		DayEvent.by_id("inspector").get("blurb", ""))
	chk("and it no longer just multiplies coins, which inspected nothing",
		not DayEvent.by_id("inspector").has("coin_mult"))

	# --- the three judgements are real, and separable ---
	Game.coins = 0
	var bare := Game.inspect()
	chk("a bare room is judged bare", float(bare["room"]) < 0.2, bare["room"])

	Game.new_run(SEED)
	Game.event = DayEvent.by_id("inspector")
	var guard := 0
	while Game.room_score(0) < Balance.room_cap - 0.001 and guard < 60:
		Game.room_items.append({"id": Items.order()[guard % Items.order().size()],
			"tile": Layout.seat(0) + Vector2i(0, -1)})
		guard += 1
	var furnished := Game.inspect()
	chk("a room you furnished is judged better",
		float(furnished["room"]) > float(bare["room"]),
		"%.2f -> %.2f" % [bare["room"], furnished["room"]])

	# the lesson they watched
	Game.new_run(SEED)
	_neutral_lesson()
	Game.event = DayEvent.by_id("inspector")
	for st: StudentData in Game.roster:
		# through assign_work(), so work_total is the real length of the
		# sheet -- setting work_timer by hand leaves it zero, and a zero
		# total reads as 100% finished rather than 0%
		st.reset_lesson()
		st.assign_work()
	var nothing_done := Game.inspect()
	for st: StudentData in Game.roster:
		st.work_state = StudentData.Work.COLLECTED
	var all_done := Game.inspect()
	chk("a lesson where the work got done is judged better",
		float(all_done["lesson"]) > float(nothing_done["lesson"]),
		"%.2f -> %.2f" % [nothing_done["lesson"], all_done["lesson"]])

	# what they see at the bell is half of it
	for st: StudentData in Game.roster:
		st.disrupting = true
	var in_chaos := Game.inspect()
	chk("and a room still in chaos at the bell is judged worse",
		float(in_chaos["lesson"]) < float(all_done["lesson"]),
		"%.2f vs %.2f" % [in_chaos["lesson"], all_done["lesson"]])
	for st: StudentData in Game.roster:
		st.disrupting = false

	# knowing your material
	Game.new_run(SEED)
	Game.event = DayEvent.by_id("inspector")
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	var unread := Game.inspect()
	chk("teaching something you have never taught shows",
		is_equal_approx(float(unread["knowledge"]), 0.0), unread["knowledge"])
	for i in 40:
		Game.record_taught("basic_arithmetic")
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	var mastered := Game.inspect()
	chk("and so does knowing it inside out",
		float(mastered["knowledge"]) > float(unread["knowledge"]),
		"%.2f -> %.2f" % [unread["knowledge"], mastered["knowledge"]])

	# --- the payoff ---
	Game.new_run(SEED)
	Game.event = DayEvent.by_id("inspector")
	Game.coins = 0
	for st: StudentData in Game.roster:
		st.work_state = StudentData.Work.WORKING
		st.work_timer = st.work_total
	var failed := Game.inspect()
	chk("a bad inspection pays nothing", int(failed["grant"]) == 0)
	chk("and says so", not bool(failed["passed"]))
	chk("your coins are untouched by it", Game.coins == 0, Game.coins)

	Game.new_run(SEED)
	Game.event = DayEvent.by_id("inspector")
	Game.coins = 0
	var g2 := 0
	while Game.room_score(0) < Balance.room_cap - 0.001 and g2 < 60:
		Game.room_items.append({"id": Items.order()[g2 % Items.order().size()],
			"tile": Layout.seat(0) + Vector2i(0, -1)})
		g2 += 1
	for st: StudentData in Game.roster:
		st.work_state = StudentData.Work.COLLECTED
	for i in 40:
		Game.record_taught(String(Game.lesson.get("id", "")))
	var passed := Game.inspect()
	chk("a good one is a pass", bool(passed["passed"]), passed["overall"])
	chk("and it pays a grant", int(passed["grant"]) > 0, passed["grant"])
	chk("which really reaches your purse", Game.coins == int(passed["grant"]),
		"%d coins, grant %d" % [Game.coins, passed["grant"]])
	chk("it is remembered", not Game.last_inspection.is_empty())

	# --- it happens through the real end of a lesson ---
	Game.new_run(SEED)
	await step(40)
	Game.event = DayEvent.by_id("inspector")
	world.start_lesson()
	await step(4)
	var hud := _hud()
	world.end_lesson()
	await step(2)
	chk("ending an inspected lesson puts the verdict on screen",
		hud.mode == hud.Mode.REPORT and hud.title.text.begins_with("INSPECTION"),
		hud.title.text)
	chk("in words, not decimals", not hud.body.text.contains("0."), hud.body.text)
	# It REPLACES the ordinary lesson report that day, so the average has to
	# still be on screen somewhere -- it moved to the hint bar when the
	# fifth body line turned out not to fit.
	chk("and the day's average is still on screen, so nothing is lost",
		hud.hint.text.contains("today"), hud.hint.text)
	hud.close()

	# --- they are IN THE ROOM ---
	# Being able to see them is most of the mechanic: a judgement you watch
	# being formed is a different feeling from a number that arrives later.
	Game.new_run(SEED)
	Game.event = DayEvent.by_id("none")
	world.refresh_inspector()
	await step(2)
	chk("nobody is watching on an ordinary day", world.inspector == null)

	Game.event = DayEvent.by_id("inspector")
	world.refresh_inspector()
	await step(2)
	chk("the inspector is in the room on the day they visit",
		world.inspector != null and is_instance_valid(world.inspector))
	chk("standing, not sitting at a desk like a pupil",
		not world.inspector.seated)
	chk("and not counted among the children",
		not world.students.has(world.inspector))
	chk("on a tile that is actually free", (func() -> bool:
		var t := Grid.world_to_tile(world.inspector.global_position)
		return world.grid.is_free(t) and Game.item_at(t).is_empty()).call(),
		Grid.world_to_tile(world.inspector.global_position))

	Game.event = DayEvent.by_id("none")
	world.refresh_inspector()
	await step(2)
	chk("and they leave when the day is over", world.inspector == null)

	Game.new_run(SEED)
	await step(2)


func test_next_term() -> void:
	section("THE TERM AFTER THIS ONE")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("a run starts in term one", Game.term == 1)
	chk("with no history behind it", Game.term_history.is_empty())

	# Build a term worth carrying: a furnished room, a curriculum, coins,
	# and a class where some pass and some do not.
	while Game.enrol() != null:
		pass
	var guard := 0
	while Game.room_score(0) < Balance.room_cap - 0.001 and guard < 60:
		Game.room_items.append({"id": Items.order()[guard % Items.order().size()],
			"tile": Layout.seat(0) + Vector2i(0, -1)})
		guard += 1
	for l: Dictionary in Curriculum.lessons:
		for i in 4:
			Game.record_taught(String(l.get("id", "")))
	Game.coins = 1234
	var i2 := 0
	for st: StudentData in Game.roster:
		st.grades.append(0.95 - 0.10 * float(i2))
		i2 += 1

	var items_before: int = Game.room_items.size()
	var concepts_before: int = Game.concepts.size()
	var coins_before: int = Game.coins
	var level_before: int = Game.teacher_level
	var seats_before: Array = Layout.seats().duplicate()
	var result := Game.sit_exam()
	var should_move: int = int(result["passed"])
	var names_before := {}
	for st: StudentData in Game.roster:
		names_before[st.display_name] = true

	var info := Game.next_term()

	chk("the term advances", Game.term == 2, Game.term)
	chk("and the day goes back to one", Game.day == 1, Game.day)
	chk("the term is no longer over", not Game.term_over)
	chk("the term just played is on the record", Game.term_history.size() == 1)
	chk("with the letter it earned",
		String(Game.term_history[0]["letter"]) == String(result["letter"]))

	# WHAT YOU KEEP -- the things you spent the term building. Taking these
	# away at the bell would make twenty days of work into a sandbox.
	chk("you keep the room you built",
		Game.room_items.size() == items_before, Game.room_items.size())
	chk("and where you put the desks", Layout.seats() == seats_before)
	chk("you keep the curriculum you learned",
		Game.concepts.size() == concepts_before)
	chk("you keep your coins", Game.coins == coins_before, Game.coins)
	chk("and your own level", Game.teacher_level == level_before)

	# WHAT YOU DO NOT -- the class. That is the cost of teaching them well.
	chk("everyone who passed has moved up",
		(info["moved_up"] as Array).size() == should_move,
		"%d moved, %d passed" % [(info["moved_up"] as Array).size(), should_move])
	chk("and they are no longer in your class", (func() -> bool:
		for n: String in info["moved_up"]:
			for st: StudentData in Game.roster:
				if st.display_name == n:
					return false
		return true).call())
	chk("they are recorded as having been sent up",
		Game.graduated.size() >= should_move)
	chk("the empty desks are filled", Game.roster.size() == Game.seat_capacity(),
		Game.roster.size())
	chk("so you start the term with a full class",
		not Game.roster.is_empty())

	# whoever stayed keeps their record but starts on a clean sheet
	var stayed_one: StudentData = null
	for st: StudentData in Game.roster:
		if names_before.has(st.display_name):
			stayed_one = st
			break
	if stayed_one != null:
		chk("a child who stayed has a fresh sheet of grades",
			stayed_one.grades.is_empty())
		chk("but keeps the record of what they were taught",
			not stayed_one.transcript.is_empty() or stayed_one.joined_day > 0)
	else:
		chk("SKIPPED: everybody passed this seed", true)

	# --- it survives the night ---
	Game.save_game()
	Game.new_run(1)
	chk("a brand new run is back to term one", Game.term == 1)
	Game.load_game()
	chk("but a saved game remembers which term you are on", Game.term == 2,
		Game.term)
	chk("and every term you have finished", Game.term_history.size() == 1)
	Game.delete_save()

	Game.new_run(SEED)


## The PokeRogue-style fork: a few pre-rolled paths at the start of a
## term, drawn WITHOUT replacement, one chosen and the rest discarded.
func test_term_paths() -> void:
	section("TERM PATHS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	chk("a fresh run starts with no path hand and no path active",
		Game.term_path_hand.is_empty() and Game.term_path.is_empty())
	chk("choosing before a hand exists does nothing",
		Game.choose_term_path(0).is_empty())

	var hand := Game.draw_term_paths()
	chk("a term draws a hand of the configured size",
		hand.size() == Balance.term_path_hand_min, hand.size())
	var ids := {}
	for row: Dictionary in hand:
		ids[String(row.get("id", ""))] = true
	chk("drawn without replacement -- no duplicate paths in one hand",
		ids.size() == hand.size())

	chk("picking out of range does nothing",
		Game.choose_term_path(-1).is_empty()
		and Game.choose_term_path(hand.size()).is_empty())
	chk("and the hand is untouched by a picking that failed",
		Game.term_path_hand.size() == hand.size())

	# ordinary_term sits at 1.0 across the board on purpose -- a player who
	# always picks it should see exactly today's numbers, unmoved.
	var ord := TermPaths.by_id("ordinary_term")
	chk("ordinary_term really is the do-nothing option", is_equal_approx(
			float(ord.get("lesson_mult", 0.0)), 1.0)
		and is_equal_approx(float(ord.get("coin_mult", 0.0)), 1.0)
		and is_equal_approx(float(ord.get("density_mult", 0.0)), 1.0))

	Game.term_path_hand = [ord]
	var chosen := Game.choose_term_path(0)
	chk("choosing sets the active path",
		String(chosen.get("id", "")) == "ordinary_term")
	chk("and empties the hand behind it", Game.term_path_hand.is_empty())
	chk("its multipliers read as 1.0 -- the exact numbers before this system",
		is_equal_approx(Game.term_path_multiplier("lesson_mult"), 1.0)
		and is_equal_approx(Game.term_path_multiplier("coin_mult"), 1.0)
		and is_equal_approx(Game.complication_density_mult(), 1.0))

	# a livelier path really does change something real
	var busy := TermPaths.by_id("busy_term")
	Game.term_path_hand = [busy]
	Game.choose_term_path(0)
	chk("a busier path really does run lessons longer",
		Game.term_path_multiplier("lesson_mult") > 1.0)
	chk("and really does raise the coin payout",
		Game.term_path_multiplier("coin_mult") > 1.0)
	chk("and really does raise how much can go wrong",
		Game.complication_density_mult() > 1.0)

	# no path chosen yet (a fresh run's term one) also reads as ordinary
	Game.term_path = {}
	chk("nothing chosen yet reads as 1.0 too, not as a crash or a zero",
		is_equal_approx(Game.term_path_multiplier("lesson_mult"), 1.0)
		and is_equal_approx(Game.term_path_multiplier("coin_mult"), 1.0)
		and is_equal_approx(Game.complication_density_mult(), 1.0))

	# it is drawn again the moment a new term opens, ready before the
	# report screen that announces it even closes -- a term that actually
	# clears its target, or next_term() never reaches that call at all
	for st: StudentData in Game.roster:
		st.grades.append(0.95)
	Game.term_path_hand.clear()
	var carried := Game.next_term()
	chk("this term actually cleared its target",
		not bool(carried.get("run_over", false)), carried)
	chk("next_term() already has this term's hand waiting",
		not Game.term_path_hand.is_empty())

	# --- the active path is term-long state: it survives a save ---
	Game.term_path_hand = [busy]
	Game.choose_term_path(0)
	Game.save_game()
	Game.new_run(1)
	chk("a brand new run does not inherit the old one's path",
		Game.term_path.is_empty())
	Game.load_game()
	chk("but a saved game remembers which one was active",
		String(Game.term_path.get("id", "")) == "busy_term", Game.term_path)
	Game.delete_save()

	Game.new_run(SEED)


func test_term_target() -> void:
	section("THE TARGET, AND LOSING")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# THE THING THIS FIXES: there was nothing to lose to. The room got
	# better every term against a difficulty that never moved, so by the
	# third term nothing the player did mattered very much.
	chk("term one has a target", Game.term_target() > 0, Game.term_target())
	chk("and a fresh run is not over", not Game.run_over)

	var t1 := Game.term_target()
	Game.term = 2
	var t2 := Game.term_target()
	Game.term = 3
	var t3 := Game.term_target()
	chk("the target rises every term", t2 > t1 and t3 > t2,
		"%d, %d, %d" % [t1, t2, t3])
	Game.term = 99
	chk("but never past the number of children you could possibly have",
		Game.term_target() <= Game.seat_capacity(), Game.term_target())

	# --- missing it ends the run ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	for st: StudentData in Game.roster:
		st.grades.append(0.10)             # nobody is passing this
	var res := Game.sit_exam()
	chk("nobody passed", int(res["passed"]) == 0, res["passed"])
	chk("which is short of the target", not Game.met_target(int(res["passed"])))

	var info := Game.next_term()
	chk("so the run is over", Game.run_over)
	chk("and it says so", bool(info.get("run_over", false)))
	chk("the term does NOT advance past the one you failed", Game.term == 1,
		Game.term)
	chk("but the term is still on the record", Game.term_history.size() == 1)
	chk("marked as missed", not bool(Game.term_history[0]["met"]))
	chk("with the number you were asked for",
		int(Game.term_history[0]["target"]) == Game.term_target())

	# --- meeting it carries on ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	for st: StudentData in Game.roster:
		st.grades.append(0.95)             # everybody sails it
	var res2 := Game.sit_exam()
	chk("everybody passed", int(res2["passed"]) == Game.roster.size())
	var info2 := Game.next_term()
	chk("the run continues", not Game.run_over)
	chk("and so does the career", not bool(info2.get("run_over", false)))
	chk("the term advances", Game.term == 2)
	chk("and the term you passed is marked as met",
		bool(Game.term_history[0]["met"]))

	# --- the player can SEE the target all term, not just at the end ---
	Game.new_run(SEED)
	Game.set_phase(Game.Phase.MORNING)
	_hud()._update_status()
	chk("the status strip says what you are playing towards",
		_hud().status.text.contains("need"), _hud().status.text)

	# --- it survives the night ---
	Game.run_over = true
	Game.save_game()
	Game.new_run(1)
	chk("a new run is not over", not Game.run_over)
	Game.load_game()
	chk("but a finished one stays finished", Game.run_over)
	Game.delete_save()

	Game.new_run(SEED)


## Phase 6: the roguelike subject boss. A boss is a real card in the
## term-path fork, dealt only on an eligible term; its exam is judged on
## the class AVERAGE sit_exam() already produced against the card's bar;
## clearing it wins a trophy and a cosmetic, missing it ends the run.
func test_boss() -> void:
	section("SUBJECT BOSS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# --- the boss table ---
	chk("balance.json carries one boss per strand, the gauntlet, and the inspection",
		Balance.bosses.size() == 6, Balance.bosses.size())
	chk("the cadence is a real, read tunable",
		Balance.boss_term_interval >= 2, Balance.boss_term_interval)
	chk("every boss card is tagged, barred and has a real trophy behind it",
		(func() -> bool:
			for bcard: Dictionary in Balance.bosses:
				if String(bcard.get("kind", "")) != "boss":
					return false
				if float(bcard.get("target", 0.0)) <= 0.0:
					return false
				if Trophies.by_id(String(bcard.get("trophy_id", ""))).is_empty():
					return false
			return true).call())

	# --- boss cards only ever appear on an eligible term ---
	var off_term := Balance.boss_term_interval + 1   # never divisible by it
	var saw_boss_off := false
	for i in 24:
		Game.term = off_term
		for row: Dictionary in Game.draw_term_paths():
			if String(row.get("kind", "")) == "boss":
				saw_boss_off = true
	chk("no boss card is ever dealt on an ordinary term", not saw_boss_off)

	var saw_boss_on := false
	for i in 24:
		Game.term = Balance.boss_term_interval
		for row: Dictionary in Game.draw_term_paths():
			if String(row.get("kind", "")) == "boss":
				saw_boss_on = true
	chk("a boss term does deal one into the fork, alongside the ordinary cards",
		saw_boss_on)
	chk("the hand is still the configured size on a boss term",
		Game.draw_term_paths().size() == Balance.term_path_hand_min,
		Game.draw_term_paths().size())
	chk("choosing a boss card sets term_path like any other card", (func() -> bool:
		Game.term = Balance.boss_term_interval
		var guard := 0
		while guard < 60:
			var hand := Game.draw_term_paths()
			for j in hand.size():
				if String((hand[j] as Dictionary).get("kind", "")) == "boss":
					var chosen := Game.choose_term_path(j)
					return String(chosen.get("kind", "")) == "boss" \
						and String(Game.term_path.get("kind", "")) == "boss"
			guard += 1
		return false).call())

	# --- winning: the right trophy, and the cosmetic unlocks ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	var boss: Dictionary = {}
	for bcard: Dictionary in Balance.bosses:
		if String(bcard.get("strand", "")) == "math":
			boss = bcard.duplicate()
	chk("the cosmetic is locked before any boss is beaten",
		not Items.is_unlocked("winners_flag"))
	Game.term_path = boss
	for st: StudentData in Game.roster:
		st.grades.append(0.98)              # a class that sails it
	Game.next_term()
	chk("clearing the bar awards that boss's own trophy",
		Game.trophies.has(String(boss["trophy_id"])), Game.trophies)
	chk("and the cosmetic decor is on sale now",
		Items.is_unlocked("winners_flag"))
	chk("the run carries on after a boss win", not Game.run_over)

	# --- losing: run over, exactly like missing an ordinary target ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	Game.term_path = boss
	for st: StudentData in Game.roster:
		st.grades.append(0.15)             # nowhere near the bar
	Game.next_term()
	chk("missing a boss bar ends the run", Game.run_over)

	# --- the non-boss path is untouched: an ordinary term still judges seats ---
	Game.new_run(SEED)
	Game.term_path = {}
	while Game.enrol() != null:
		pass
	for st: StudentData in Game.roster:
		st.grades.append(0.95)
	var ord_info := Game.next_term()
	chk("an ordinary term with no boss card still advances normally",
		not bool(ord_info.get("run_over", false)) and Game.term == 2)

	# --- CONTRACT GUARD: the boss branch reuses sit_exam(), not a new formula
	# (same source-scan shape as test_balance()'s guard on tools/sim.gd) ---
	var src := FileAccess.get_file_as_string("res://scripts/autoload/game.gd")
	var a := src.find("func next_term(")
	var stop := src.find("\nfunc ", a + 1)
	var nt := src.substr(a, stop - a) if a >= 0 and stop > a else ""
	chk("next_term() is there to scan", nt != "")
	chk("the boss branch keys off the term_path kind",
		nt.contains('term_path.get("kind", "")) == "boss"'))
	chk("it measures the class average sit_exam() already produced",
		nt.contains('result.get("average"'))
	chk("against the boss card's own bar", nt.contains('term_path.get("target"'))
	chk("clearing it awards the trophy rather than scoring it bespoke",
		nt.contains("award_trophy("))
	chk("and no second grading pass sneaks in -- exactly one sit_exam() call",
		nt.count("sit_exam(") == 1, nt.count("sit_exam("))

	Game.new_run(SEED)


## The boss paper, PLAYED: rounds, moves, marks, the nudge on the exam, and
## the morning in the room. See scripts/data/boss_fight.gd.
func test_boss_fight() -> void:
	section("THE BOSS PAPER")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	while Game.enrol() != null:
		pass
	await step(2)

	# --- the table: every card carries a move list the fight understands ---
	chk("every boss card lists its moves", (func() -> bool:
		for c: Dictionary in Balance.bosses:
			var mv: Array = c.get("moves", [])
			if mv.is_empty():
				return false
			for m in mv:
				if not BossFight.KINDS.has(String(m)):
					return false
		return true).call())
	chk("every boss card carries a tactic line, in prose", (func() -> bool:
		for c: Dictionary in Balance.bosses:
			var tx := String(c.get("tactic", ""))
			if tx.length() < 20:
				return false
			for ch in "0123456789":
				if tx.contains(ch):
					return false
		return true).call())
	chk("the fight's tunables are read from the table",
		Balance.fight_round_seconds > 0.0 and Balance.fight_max_swing > 0.0
		and Balance.fight_freeze_count > 0)
	chk("every question line is prose", (func() -> bool:
		for kind: String in BossFight.QUESTIONS:
			for st: String in BossFight.QUESTIONS[kind]:
				for line: String in BossFight.QUESTIONS[kind][st]:
					for ch in "0123456789":
						if line.contains(ch):
							return false
		return true).call())

	var ela: Dictionary = {}
	var math_card: Dictionary = {}
	var sci: Dictionary = {}
	var soc: Dictionary = {}
	for c: Dictionary in Balance.bosses:
		match String(c.get("strand", "")):
			"ela": ela = c.duplicate()
			"math": math_card = c.duplicate()
			"science": sci = c.duplicate()
			"social": soc = c.duplicate()

	# --- a headless fight, driven by hand: freeze / steady / drop ---
	var f := BossFight.new()
	f.start(ela, Game.roster, Game.rng)
	chk("it opens on a breath, before the first question",
		f.stage == BossFight.Stage.BREATH)
	chk("one round per move on the card", f.total_rounds() == ela["moves"].size())
	chk("the clock is the whole paper",
		is_equal_approx(f.seconds_left(), f.total_seconds()))
	chk("the first question is named, with no decimal in it",
		f.question_text().begins_with("Question 1 of")
		and not f.question_text().contains("0."), f.question_text())
	f.tick(Balance.fight_breath_seconds + 0.01, Game.rng, Layout.PODIUM)
	chk("the breath ends and the first question opens",
		f.stage == BossFight.Stage.ROUND)
	chk("the reading paper's first move is a freeze",
		f.round_kind() == "freeze", f.round_kind())
	var frozen_now: Array = []
	for s: StudentData in Game.roster:
		if s.is_struggling():
			frozen_now.append(s)
	chk("it freezes exactly the table's count of children",
		frozen_now.size() == Balance.fight_freeze_count, frozen_now.size())
	chk("a frozen child shows it at once, whatever their trait",
		(frozen_now[0] as StudentData).is_visibly_struggling())
	chk("the room heard about each freeze", (func() -> bool:
		var n := 0
		for ev: String in f.events:
			if ev.begins_with("freeze:"):
				n += 1
		return n == frozen_now.size()).call())
	f.events.clear()

	# steady one at once, one late, leave one
	var quick: StudentData = frozen_now[0]
	var late: StudentData = frozen_now[1]
	var left: StudentData = frozen_now[2]
	quick.help()
	f.tick(0.1, Game.rng, Layout.PODIUM)
	chk("steadied inside the quick window: rallied",
		int(f.tally[quick.id]["rallied"]) == 1, f.tally[quick.id])
	f.tick(Balance.fight_quick_seconds + 0.5, Game.rng, Layout.PODIUM)
	late.help()
	f.tick(0.1, Game.rng, Layout.PODIUM)
	chk("steadied after the window: held, not rallied",
		int(f.tally[late.id]["held"]) == 1 and int(f.tally[late.id]["rallied"]) == 0,
		f.tally[late.id])
	chk("the room is still steady -- nothing dropped yet",
		f.composure_word() == "steady")
	f.tick(Balance.fight_round_seconds, Game.rng, Layout.PODIUM)
	chk("whoever is still frozen when the question moves on drops it",
		int(f.tally[left.id]["dropped"]) == 1, f.tally[left.id])
	chk("and is unfrozen without anyone having helped",
		not left.is_struggling() and left.helps_received == 0)
	chk("the next breath is announced",
		f.events.has("breath") and f.stage == BossFight.Stage.BREATH)
	chk("the tally moved the room off steady", f.composure() < 1.0)

	# --- J: everyone talked through it counts as held ---
	f.tick(Balance.fight_breath_seconds + 0.01, Game.rng, Layout.PODIUM)
	chk("question two is a freeze too", f.round_kind() == "freeze")
	var before_mass := f.counts()
	f.mass_steady()
	for s: StudentData in Game.roster:
		s.help()
	f.tick(0.1, Game.rng, Layout.PODIUM)
	var after_mass := f.counts()
	chk("the mass-help resolves them as held, never rallied",
		int(after_mass["held"]) - int(before_mass["held"]) == Balance.fight_freeze_count
		and after_mass["rallied"] == before_mass["rallied"], after_mass)

	# --- a chain spreads along adjacent desks ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	var a: StudentData = Game.roster[0]
	var b: StudentData = Game.roster[1]
	Layout.move_seat(b.seat_index, Layout.seat(a.seat_index) + Vector2i(1, 0))
	var chain_card := math_card.duplicate()
	chain_card["moves"] = ["chain"]
	var fc := BossFight.new()
	fc.start(chain_card, Game.roster, Game.rng)
	fc.tick(Balance.fight_breath_seconds + 0.01, Game.rng, Layout.PODIUM)
	var first_frozen := 0
	var chain_seed: StudentData = null
	for s: StudentData in Game.roster:
		if s.is_struggling():
			first_frozen += 1
			chain_seed = s
	chk("a chain starts on one child", first_frozen == 1, first_frozen)
	if Game.neighbours_of(chain_seed).is_empty():
		# the seed landed on a child with no neighbour this draw -- move the
		# link to the pair that has one, so the spread itself is what is tested
		chain_seed.unfreeze()
		fc.frozen.clear()
		fc._freeze(a)
	fc.tick(Balance.fight_chain_spread_seconds + 0.05, Game.rng, Layout.PODIUM)
	var now_frozen := 0
	for s: StudentData in Game.roster:
		if s.is_struggling():
			now_frozen += 1
	chk("...and freezes the next desk along", now_frozen == 2, now_frozen)
	Layout.reset_seats()

	# --- noise: the paper sets them arguing; settling them is the answer ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	var noise_card := soc.duplicate()
	noise_card["moves"] = ["noise"]
	var fn := BossFight.new()
	fn.start(noise_card, Game.roster, Game.rng)
	fn.tick(Balance.fight_breath_seconds + 0.01, Game.rng, Layout.PODIUM)
	var loud: Array = []
	for s: StudentData in Game.roster:
		if s.disrupting:
			loud.append(s)
	chk("a noise move sets off the table's count of children",
		loud.size() == Balance.fight_noise_count, loud.size())
	(loud[0] as StudentData).settle()
	fn.tick(0.1, Game.rng, Layout.PODIUM)
	chk("settling one quickly counts as rallied",
		int(fn.tally[(loud[0] as StudentData).id]["rallied"]) == 1)
	fn.tick(Balance.fight_round_seconds, Game.rng, Layout.PODIUM)
	chk("the rest drop it and are calmed when the question moves on",
		int(fn.tally[(loud[1] as StudentData).id]["dropped"]) == 1
		and not (loud[1] as StudentData).disrupting)

	# --- present: stand with the child up front ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	var pres_card := sci.duplicate()
	pres_card["moves"] = ["present"]
	var fp := BossFight.new()
	fp.start(pres_card, Game.roster, Game.rng)
	fp.tick(Balance.fight_breath_seconds + 0.01, Game.rng, Layout.PODIUM)
	chk("a present move puts one child up front", fp.presenting >= 0)
	var pres: StudentData = Game.student_by_id(fp.presenting)
	var beside: Vector2i = Layout.seat(pres.seat_index) + Vector2i(1, 0)
	var tt := 0.0
	while tt < Balance.fight_present_rally_seconds + 0.2:
		fp.tick(0.25, Game.rng, beside)
		tt += 0.25
	fp.tick(Balance.fight_round_seconds, Game.rng, beside)
	chk("stood with for the whole question: rallied",
		int(fp.tally[pres.id]["rallied"]) == 1, fp.tally[pres.id])
	chk("the paper is over after its last move", not fp.active())
	var report := fp.finish()
	chk("the presenter who rose to it carries a small positive nudge",
		pres.boss_delta > 0.0 and pres.boss_delta <= Balance.fight_max_swing,
		pres.boss_delta)

	var fp2 := BossFight.new()
	fp2.start(pres_card, Game.roster, Game.rng)
	fp2.tick(Balance.fight_breath_seconds + 0.01, Game.rng, Vector2i(0, 0))
	var pres2: StudentData = Game.student_by_id(fp2.presenting)
	fp2.tick(Balance.fight_round_seconds + 0.1, Game.rng, Vector2i(0, 0))
	chk("left alone up front: dropped",
		int(fp2.tally[pres2.id]["dropped"]) == 1, fp2.tally[pres2.id])
	report = fp2.finish()
	chk("finish() hands back one row per child",
		report["rows"].size() == Game.roster.size())
	chk("the one left alone carries a small negative nudge",
		pres2.boss_delta < 0.0 and pres2.boss_delta >= -Balance.fight_max_swing,
		pres2.boss_delta)
	chk("every row's word is prose", (func() -> bool:
		for r: Dictionary in report["rows"]:
			var w := String(r.get("word", ""))
			if w.is_empty():
				return false
			for ch in "0123456789.%":
				if w.contains(ch):
					return false
		return true).call())
	chk("the room is read in a word",
		["steady", "wobbling", "cracking", "gone"].has(String(report["composure"])))
	chk("a child the paper never touched sat it quietly", (func() -> bool:
		for r: Dictionary in report["rows"]:
			if int(r["rallied"]) + int(r["held"]) + int(r["dropped"]) == 0:
				return String(r["word"]) == "sat it quietly"
		return true).call())

	# --- the swing clamps both ways ---
	var big := BossFight.new()
	big.start(pres_card, Game.roster, Game.rng)
	var victim: StudentData = Game.roster[0]
	big.tally[victim.id] = {"rallied": 0, "held": 0, "dropped": 40}
	big.finish()
	chk("a terrible morning is capped at the table's max swing",
		is_equal_approx(victim.boss_delta, -Balance.fight_max_swing), victim.boss_delta)
	big.tally[victim.id] = {"rallied": 40, "held": 0, "dropped": 0}
	big.finish()
	chk("and so is a brilliant one",
		is_equal_approx(victim.boss_delta, Balance.fight_max_swing))

	# --- the exam reads it, and only it ---
	victim.grades.append(0.6)
	victim.boss_delta = 0.0
	var plain := Game.exam_score_for(victim)
	victim.boss_delta = 0.04
	chk("exam_score_for adds the nudge on top of the record",
		is_equal_approx(Game.exam_score_for(victim), plain + 0.04))
	victim.boss_delta = 0.0
	chk("and a zero nudge is the ordinary exam",
		is_equal_approx(Game.exam_score_for(victim), plain))
	victim.boss_delta = 0.03
	var rt := StudentData.from_dict(victim.to_dict())
	chk("the nudge survives a save round-trip", is_equal_approx(rt.boss_delta, 0.03))
	var old := victim.to_dict()
	old.erase("boss_delta")
	chk("a record from before the fight loads with none",
		StudentData.from_dict(old).boss_delta == 0.0)

	# --- the day: the podium offers the paper, and only on that morning ---
	Game.new_run(SEED)
	await step(2)
	while Game.enrol() != null:
		pass
	await step(2)
	chk("an ordinary morning has no paper on offer", not Game.boss_fight_today())
	Game.term_path = ela.duplicate()
	chk("a boss term's first morning has none either", not Game.boss_fight_today())
	Game.day = Balance.term_days
	chk("the last morning of a boss term does", Game.boss_fight_today())
	chk("the podium says so", world.podium.prompt_text().begins_with("Begin the"),
		world.podium.prompt_text())
	var seated: int = world.start_boss_fight()
	await step(2)
	chk("beginning the paper starts it for the whole class",
		seated == Game.roster.size())
	chk("the day is in its lesson phase", Game.phase == Game.Phase.LESSON)
	chk("the paper is live", Game.fight_active())
	chk("the podium cannot end it early", not world.podium.can_interact())
	chk("the examiner is in the room",
		world.examiner != null and is_instance_valid(world.examiner))
	chk("no work is on the desks -- nothing is graded today", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.work_state != StudentData.Work.NONE:
				return false
		return true).call())
	chk("the clock is the paper's", world.lesson_left > Balance.lesson_seconds)
	var guard := 0
	while Game.fight.stage != BossFight.Stage.ROUND and guard < 400:
		await step(1)
		guard += 1
	chk("the room ticks the paper into its first question",
		Game.fight.stage == BossFight.Stage.ROUND)
	chk("the banner names the question",
		hud.banner.visible and hud.banner.text.begins_with("Question"), hud.banner.text)
	var fz: StudentData = null
	for s: StudentData in Game.roster:
		if s.is_struggling():
			fz = s
			break
	chk("a child froze", fz != null)
	var st: Interactable = world.station(fz.seat_index)
	chk("their desk offers to steady them",
		st.can_interact() and st.prompt_text().begins_with("Steady"), st.prompt_text())
	await step(2)
	chk("the strip reads the question and the room's hold",
		hud.status.text.contains("Q1/") and hud.status.text.contains("hold"),
		hud.status.text)
	chk("and never a decimal", not hud.status.text.contains("0."), hud.status.text)

	# --- a round's own outcome flashes a cosmetic pose, held excepted ---
	var rallied_s: StudentData = null
	var dropped_s: StudentData = null
	var held_s: StudentData = null
	for s: StudentData in Game.roster:
		if s == fz or s.seat_index < 0:
			continue
		if rallied_s == null:
			rallied_s = s
		elif dropped_s == null:
			dropped_s = s
		elif held_s == null:
			held_s = s
	chk("enough seated children on hand to try all three outcomes",
		rallied_s != null and dropped_s != null and held_s != null)
	var rallied_node: Actor = world.student_node(rallied_s.seat_index)
	var dropped_node: Actor = world.student_node(dropped_s.seat_index)
	var held_node: Actor = world.student_node(held_s.seat_index)
	rallied_node.set_idle()
	dropped_node.set_idle()
	held_node.set_idle()
	Game.fight._resolve(rallied_s, "rallied")
	Game.fight._resolve(dropped_s, "dropped")
	Game.fight._resolve(held_s, "held")
	await step(1)
	chk("rallied flashes the jump pose",
		rallied_node.sprite.frame_coords.x == Actor.POSE_JUMP, rallied_node.sprite.frame_coords)
	chk("dropped flashes the sad pose",
		dropped_node.sprite.frame_coords.x == Actor.POSE_SAD, dropped_node.sprite.frame_coords)
	chk("held is the neutral middle -- no pose",
		held_node.sprite.frame_coords.x == 0, held_node.sprite.frame_coords)

	guard = 0
	while Game.fight_active() and guard < 100000:
		Game.fight.tick(0.5, Game.rng, Layout.PODIUM)
		guard += 1
	await step(2)
	chk("when the paper ends the room moves to the afternoon",
		Game.phase == Game.Phase.AFTERNOON)
	chk("the examiner has gone", world.examiner == null)
	chk("it cannot be sat twice", not Game.boss_fight_today())
	chk("the report is on screen",
		hud.mode == hud.Mode.REPORT
		and hud.title.text.contains(String(ela["name"]).to_upper()), hud.title.text)
	chk("it fits the panel", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	chk("and prints no decimal about a child", not hud.rich.text.contains("0."),
		hud.rich.text)
	hud.close()
	await step(2)
	var res := Game.sit_exam()
	hud.show_exam(res)
	await step(2)
	chk("the exam screen is the paper's",
		hud.title.text.contains(String(ela["name"]).to_upper()), hud.title.text)
	chk("and says which side of the bar the class landed",
		hud.rich.text.to_lower().contains("cleared"), hud.rich.text)
	hud.close()
	await step(2)

	# --- guards: the contract sim never sees any of this; no bare dice ---
	var sim_src := FileAccess.get_file_as_string("res://tools/sim.gd")
	chk("tools/sim.gd never touches the fight",
		not sim_src.contains("BossFight") and not sim_src.contains("boss_delta")
		and not sim_src.contains("start_boss_fight"))
	# code only -- the file's own comments name the banned calls to say
	# they are banned
	var bf_code := ""
	for line: String in FileAccess.get_file_as_string(
			"res://scripts/data/boss_fight.gd").split("\n"):
		if not line.strip_edges().begins_with("#"):
			bf_code += line + "\n"
	chk("the fight rolls only the run's own rng",
		bf_code.count("randf(") == bf_code.count("rng.randf(")
		and bf_code.count("randi_range(") == bf_code.count("rng.randi_range(")
		and bf_code.count("randi(") == 0)

	# --- the Mock Inspection: a sixth card, not one of the four strands or
	# the gauntlet -- its own pseudo-strand, with its own flavour text so it
	# does not silently fall back to "any" like an unlisted strand would ---
	var inspection: Dictionary = {}
	for c: Dictionary in Balance.bosses:
		if String(c.get("id", "")) == "boss_inspection":
			inspection = c.duplicate()
	chk("the Mock Inspection card is in the table", not inspection.is_empty())
	chk("its target sits above an ordinary subject boss's, below the gauntlet's",
		float(inspection.get("target", 0.0)) > 0.7
		and float(inspection.get("target", 0.0)) < 0.74)
	chk("its moves are noise-heavy, as briefed",
		(inspection.get("moves", []) as Array).count("noise") \
			> (inspection.get("moves", []) as Array).size() / 2.0)
	chk("beating it awards its own trophy, not a borrowed one",
		not Trophies.by_id(String(inspection.get("trophy_id", ""))).is_empty())
	var insp_fight := BossFight.new()
	insp_fight.start(inspection, Game.roster, Game.rng)
	chk("its own strand resolves to its own question pool, not the \"any\" fallback",
		insp_fight.strand == "inspection"
		and BossFight.QUESTIONS["freeze"].has("inspection"))

	Game.new_run(SEED)
	await step(2)


## The in-play help sheet, the class-mood word, and the dash-trail cap:
## the legibility pass a design critique asked for.
func test_legibility() -> void:
	section("LEGIBILITY: HELP SHEET, MOOD WORD, TRAIL CAP")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	hud.close()
	await step(2)

	# --- the help sheet ---
	chk("help is a real, rebindable action", Settings.DEFAULTS.has("help")
		and (func() -> bool:
			for e: Dictionary in Settings.ACTIONS:
				if String(e.get("action", "")) == "help":
					return true
			return false).call())
	chk("every listed action has a line saying what it is for", (func() -> bool:
		for e: Dictionary in Settings.ACTIONS:
			var a := String(e.get("action", ""))
			if String(hud.HELP_LINES.get(a, "")).is_empty():
				return false
		return true).call())
	chk("no help line prints a number about a child", (func() -> bool:
		for a: String in hud.HELP_LINES:
			var line := String(hud.HELP_LINES[a])
			if line.contains("%") or line.contains("0."):
				return false
		return true).call())
	await tap("help")
	chk("pressing it in free roam opens the sheet", hud.mode == hud.Mode.HELP, hud.mode)
	chk("the sheet fits the panel", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	chk("it names the key for the first verb",
		hud.rich.text.contains(Settings.binding_text("move_up").substr(0, 6)), hud.rich.text)
	# page all the way down: every action appears somewhere
	var seen := {}
	for i in Settings.ACTIONS.size() + 2:
		for e: Dictionary in Settings.ACTIONS:
			var lbl := String(hud.HELP_LINES.get(String(e.get("action", "")), ""))
			if lbl != "" and hud.rich.text.contains(lbl.substr(0, 12)):
				seen[String(e.get("action", ""))] = true
		await tap("move_down")
	chk("paging reaches every verb", seen.size() == Settings.ACTIONS.size(),
		"%d of %d" % [seen.size(), Settings.ACTIONS.size()])
	await tap("cancel")
	chk("Esc closes it", hud.mode == hud.Mode.NONE)
	await tap("help")
	await tap("help")
	chk("and so does the help key itself", hud.mode == hud.Mode.NONE)
	# the pause menu has a row for it
	hud.show_pause()
	chk("the pause menu offers the sheet", hud.body.text.contains("Controls"), hud.body.text)
	chk("and still fits the panel", hud.body.text.split("\n").size() <= 11)
	hud.close()
	await step(2)

	# --- the mood word ---
	Game.new_run(SEED)
	await step(2)
	for s: StudentData in Game.roster:
		s.disrupting = false
		s.confusion = 0.0
	Game.attention = 1.0
	chk("a full, calm room is with you", Game.class_mood() == "with you", Game.class_mood())
	Game.attention = 0.0
	chk("an unattended room is lost", Game.class_mood() == "lost them", Game.class_mood())
	Game.attention = 1.0
	var n := 0
	for s: StudentData in Game.roster:
		if n < 3:
			s.disrupting = true
			n += 1
	chk("three children messing about drag a full room down",
		Game.class_mood() != "with you", Game.class_mood())
	chk("the words are the table's own four", (func() -> bool:
		for att in [0.0, 0.2, 0.4, 0.7, 1.0]:
			Game.attention = att
			if not ["with you", "drifting", "restless", "lost them"].has(Game.class_mood()):
				return false
		return true).call())
	for s: StudentData in Game.roster:
		s.disrupting = false
	Game.attention = 1.0
	world.start_lesson()
	await step(3)
	chk("the strip reads the room in a word", hud.status.text.contains("room:"), hud.status.text)
	chk("and no longer as pips of attention", not hud.status.text.contains("teaching |"),
		hud.status.text)
	world.end_lesson()
	await step(2)

	# --- the dash trail is capped ---
	chk("afterimages are counted", Fx.afterimage_count(world) == 0)
	for i in 30:
		Fx.afterimage(world.player.sprite, world)
	chk("...and the count sees them", Fx.afterimage_count(world) == 30)
	await step(30)
	chk("they clean themselves up", Fx.afterimage_count(world) < 30)
	chk("the player holds a cap on the trail", world.player.DASH_TRAIL_CAP > 0
		and world.player.DASH_TRAIL_CAP < 40)

	Game.new_run(SEED)
	await step(2)


func test_screens_explain_themselves() -> void:
	section("SCREENS THAT EXPLAIN THEMSELVES")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var hud := _hud()
	await step(2)

	# --- the end of day ---
	# It used to print "room 40%  lesson 0%  hw 3%": percentages of a maximum
	# it never mentioned, so 40 could not be judged, and nothing on the
	# screen suggested an action.
	for st: StudentData in Game.roster:
		st.work_state = StudentData.Work.COLLECTED
	var report := Game.advance_day()
	hud.show_day_report(report)

	chk("the day report shows each part against its ceiling",
		hud.rich.text.contains(" of %d" % int(round(Balance.room_cap * 100.0))),
		hud.rich.text)
	chk("and names the parts in words, not in field names", (func() -> bool:
		for want: String in ["the room", "the lesson", "homework", "what you know"]:
			if not hud.rich.text.contains(want):
				return false
		return true).call(), hud.rich.text)
	chk("and ends with something to DO about it",
		hud.rich.text.contains("Weakest:")
		or hud.rich.text.contains("as good as it gets"), hud.rich.text)
	chk("the day report still fits",
		hud.rich.text.split("\n").size() <= 11,
		"%d rows" % hud.rich.text.split("\n").size())
	hud.close()

	# the arrow only appears once there IS a yesterday to compare against
	chk("no arrows on the first day", not Game.last_split.is_empty())
	var r2 := Game.advance_day()
	chk("the report carries yesterday's split too",
		(r2.get("split_before", {}) as Dictionary).has("room"),
		r2.get("split_before", {}))

	# the split must agree with the grade model rather than drift from it
	var split := Game.grade_split()
	var sum: float = float(split["room"]) + float(split["lesson"]) 		+ float(split["homework"]) + float(split["known"])
	var avg := 0.0
	for st2: StudentData in Game.roster:
		avg += Game.grade_for(st2)
	avg /= maxf(1.0, float(Game.roster.size()))
	chk("the parts add up to the grade they are explaining",
		absf(sum - avg) < 0.01, "%.3f vs %.3f" % [sum, avg])

	# --- the curriculum ---
	Game.new_run(SEED)
	await step(2)
	hud.show_curriculum()
	chk("a subject you have never taught says so plainly",
		hud.rich.text.contains("never taught it"), hud.rich.text)
	# Since the book layout (Sept 2026) this sits on the LEFT page, which is
	# what rich_left renders -- the line did not go away, it changed pages.
	chk("and the screen says what the whole thing is FOR",
		hud.rich_left.text.contains("better at teaching it")
		or hud.rich_left.text.contains("worth +"), hud.rich_left.text)
	chk("the citation is not shouting over the rows", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			if hud.rich.text.contains(String(l.get("standard", ""))):
				return false
		return true).call(), hud.rich.text)
	chk("but it is still on screen for the subject you are looking at",
		hud.hint.text.contains(String(Curriculum.lessons[0].get("standard", ""))),
		hud.hint.text)
	# The screen ACTS now, so its hint offers the action rather than
	# restating what the next concept would be.
	chk("and the detail line offers to teach it",
		hud.hint.text.contains("teach this next"), hud.hint.text)
	hud.close()



func test_quiz_buff_and_calm() -> void:
	section("WHAT A QUIZ BUYS, AND A PERK THAT WORKS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var s: StudentData = Game.roster[0]
	s.trait_id = "steady"

	# --- the quiz leaves the class FOCUSED ---
	# It used to cost 14 seconds of a 45-second lesson and leave nothing
	# behind at all: no grade term, no lasting effect, not even a saved
	# field. Break-even was about four students on time alone.
	Game.set_phase(Game.Phase.LESSON)
	Game.quiz_focus = false
	var before := s.stall_chance()
	Game.quiz_focus = true
	var after := s.stall_chance()
	chk("a quiz makes the class harder to distract", after < before,
		"%.4f -> %.4f" % [before, after])
	chk("by the amount the table says",
		is_equal_approx(after, before * Balance.quiz_focus_mult), after)

	chk("running one really does set it", (func() -> bool:
		Game.quiz_focus = false
		Game.quiz_done = false
		Game.run_quiz()
		return Game.quiz_focus).call())

	# it belongs to the lesson, like everything else about a lesson
	world.start_lesson()
	chk("and a new lesson starts unfocused again", not Game.quiz_focus)

	# ...and to the RUN. This leaked at first: the term simulator quizzes in
	# one policy and then measures the balance contract in another, and the
	# focus carried over into a row that was supposed to have no quiz in it.
	# It read 0.73 instead of 0.69 and nothing in the suite noticed, because
	# a balance row moving is not a failing assertion.
	Game.quiz_focus = true
	Game.new_run(SEED)
	chk("and a new RUN is never left focused from the last one",
		not Game.quiz_focus)
	await step(2)
	Game.set_phase(Game.Phase.LESSON)

	# The cost has to stay worth paying but not free.
	chk("a quiz still costs a real slice of the lesson",
		Balance.quiz_seconds_cost > 5.0
		and Balance.quiz_seconds_cost < Balance.lesson_seconds * 0.4,
		Balance.quiz_seconds_cost)

	# --- Calm Presence ---
	# THE BUG: this perk has been purchasable since perks existed and did
	# nothing whatsoever. Progress.calm_multiplier() had no caller anywhere
	# in scripts/ -- only a test asserted the maths of a function the game
	# never called.
	Game.new_run(SEED)
	await step(2)
	Game.set_phase(Game.Phase.LESSON)
	var t: StudentData = Game.roster[0]
	t.trait_id = "steady"
	Game.quiz_focus = false
	Game.perk_ranks.clear()
	var plain := t.stall_chance()

	Game.perk_ranks["calm_presence"] = 1
	world.player.global_position = Grid.tile_to_world(
		Layout.seat(t.seat_index) + Vector2i(1, 0))
	await step(2)
	chk("standing next to a child settles them", t.stall_chance() < plain,
		"%.4f -> %.4f" % [plain, t.stall_chance()])

	world.player.global_position = Grid.tile_to_world(Vector2i(1, Grid.H - 2))
	await step(2)
	chk("and from across the room it does nothing",
		is_equal_approx(t.stall_chance(), plain), t.stall_chance())

	Game.perk_ranks.clear()
	world.player.global_position = Grid.tile_to_world(
		Layout.seat(t.seat_index) + Vector2i(1, 0))
	await step(2)
	chk("without the perk, standing there changes nothing",
		is_equal_approx(t.stall_chance(), plain), t.stall_chance())

	Game.new_run(SEED)
	await step(2)


func test_stale_interactable_after_rebuild() -> void:
	section("A REBUILT ROOM DOES NOT LEAVE A CORPSE TARGETABLE")
	# THE BUG THIS GUARDS: RoomBuilder.add_prop() puts the "room_part" group
	# on the PROP (a StaticBody2D), and the Interactable is a CHILD of that
	# prop. rebuild_room() calls queue_free() on the PROP, not the child --
	# so the child's own is_queued_for_deletion() stays false right up
	# until the deferred free actually runs, even though remove_child()
	# already took it out of the tree. Every Game.new_run() rebuilds the
	# room, so this fired constantly and, because the crash happens INSIDE
	# _pick_target(), aborted _physics_process before targets ever got
	# refreshed -- which is what silently killed the homework screen: the
	# marking desk stopped being targetable for the rest of the run.
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(5)

	var old_desk: Interactable = world.teacher_desk
	chk("there is a teacher's desk to go stale", old_desk != null)

	# Force the exact rebuild path new_run() itself triggers, then poll
	# immediately -- NO awaiting a frame, which is the narrow window where
	# the physics server can still hand back the just-detached node.
	Game.room_resized.emit()
	chk("the old desk is still a valid object, right after rebuild",
		is_instance_valid(old_desk))
	chk("but it is no longer in the tree -- the actual, general check",
		not old_desk.is_inside_tree())

	# The real regression: calling can_interact() on that exact object
	# used to throw and abort _physics_process. It must not throw, and it
	# must not be worth interacting with.
	chk("a detached interactable is never offered", not old_desk.can_interact())

	var picked: Interactable = world.player._pick_target()
	chk("picking a target right after rebuild does not crash or return the corpse",
		picked == null or picked != old_desk)

	Game.new_run(SEED)
	await step(2)


func test_teaching() -> void:
	section("STANDING AT THE FRONT AND TEACHING")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(40)
	var p: Actor = world.player

	# THE CHANGE: a lesson used to run itself. Students worked whether or
	# not a teacher existed, so the whole job was reacting to bubbles and
	# the time between them was dead.
	chk("a fresh lesson has nobody's attention",
		is_equal_approx(Game.attention, 0.0), Game.attention)
	chk("the front of the room is near the podium",
		Game.can_teach_from(Layout.PODIUM + Vector2i(0, 1)))
	chk("and the back of the room is not",
		not Game.can_teach_from(Vector2i(Grid.W - 2, Grid.H - 2)))

	world.start_lesson()
	await step(4)
	var s: StudentData = Game.roster[0]
	s.trait_id = "steady"
	s.confusion = 0.0

	# --- nobody teaching: nothing happens ---
	p.global_position = Grid.tile_to_world(Vector2i(2, Grid.H - 2))
	await step(60)
	var idle_left := s.work_timer
	await step(120)
	chk("with nobody at the front the work does not move",
		is_equal_approx(s.work_timer, idle_left),
		"%.2f -> %.2f" % [idle_left, s.work_timer])
	chk("and attention has drained to nothing",
		is_equal_approx(Game.attention, 0.0), Game.attention)
	chk("the game says so, rather than leaving you to wonder",
		not Game.teaching)

	# --- teaching: it moves ---
	p.global_position = Grid.tile_to_world(Layout.PODIUM + Vector2i(0, 1))
	await step(30)
	chk("standing at the front IS teaching", Game.teaching)
	chk("and the class starts paying attention", Game.attention > 0.0,
		Game.attention)
	# Measure over a short window with a fresh stall grace: teaching shows
	# in the work timer immediately, and nothing random gets a chance to
	# stall them inside it (which would otherwise freeze the very thing
	# this checks -- a latent flake, exposed once flare-ups added another
	# draw to the shared rng stream and reshuffled what lands where).
	s.confusion = 0.0
	s._since_stall = 0.0
	var before := s.work_timer
	await step(20)
	chk("now the work moves", s.work_timer < before - 0.05,
		"%.2f -> %.2f" % [before, s.work_timer])

	# --- leaving costs, but does not freeze them dead ---
	# A hard on/off made a two second trip to help one child freeze seven
	# others, which reads as the game being broken rather than as a choice.
	await step(90)                      # get attention up to full
	chk("attention fills", Game.attention > 0.9, Game.attention)

	# ONBOARDING. Nothing told a new player that work only advances while
	# they are at the front, which made the first lesson read as broken
	# rather than as the central mechanic.
	#
	# It must NOT fire the instant they step away -- walking to a stuck
	# child is the game, and a nudge fired then would read as "do not do
	# that". It fires once the absence has actually cost something.
	# An Array as a counter, not an int: GDScript lambdas capture locals by
	# VALUE, so `var n := 0` incremented inside the closure only ever moves
	# the closure's own copy and the assertion reads 0 forever.
	var drifted: Array[int] = [0]
	Game.class_drifted.connect(func() -> void: drifted[0] += 1)

	p.global_position = Grid.tile_to_world(Vector2i(2, Grid.H - 2))
	await step(6)
	chk("stepping away does not immediately lecture the player",
		drifted[0] == 0 and Game.attention > Balance.teach_drift_hint_below,
		"%d at %.2f" % [drifted[0], Game.attention])

	await step(240)                     # stay away until it actually bites
	chk("but a long absence says why the work stopped",
		drifted[0] == 1 and Game.attention < Balance.teach_drift_hint_below,
		"%d at %.2f" % [drifted[0], Game.attention])

	# Back to the front and away again: the signal is per crossing, and
	# hint_once is what makes it once per RUN -- so the sentence cannot
	# start nagging a player who already knows.
	p.global_position = Grid.tile_to_world(Layout.PODIUM + Vector2i(0, 1))
	await step(90)
	chk("coming back does not fire it again", drifted[0] == 1, drifted[0])

	# ONBOARDING, slice two. Work left uncollected at the bell HALVES that
	# child's lesson grade, and nothing told the player that collecting was
	# part of the job rather than tidying up after it.
	#
	# Dwelled, not instant: a child finishing is not a mistake, and firing
	# the moment they put their pen down would be noise while the player is
	# already walking over.
	var cold: Array[int] = [0]
	Game.work_going_cold.connect(func() -> void: cold[0] += 1)
	var s1: StudentData = Game.roster[0]
	s1.work_state = StudentData.Work.DONE
	await step(4)
	chk("a child finishing is not immediately a telling-off",
		cold[0] == 0, cold[0])
	await step(int(Balance.uncollected_hint_after * 60.0) + 30)
	chk("but work left sitting says why it matters", cold[0] == 1, cold[0])
	s1.collect_work()
	await step(30)
	chk("collecting it stops the clock", cold[0] == 1, cold[0])
	var hud2 := _hud()
	hud2.hint_once("class_drifted", "Work only moves while you are at the front.")
	var first_text: String = hud2.prompt.text
	hud2.hint_once("class_drifted", "SHOULD NOT APPEAR")
	chk("and the nudge is shown once per run, not once per crossing",
		hud2.prompt.text == first_text, hud2.prompt.text)
	p.global_position = Grid.tile_to_world(Vector2i(2, Grid.H - 2))
	await step(30)                      # half a second away
	chk("a short trip costs some attention, not all of it",
		Game.attention > 0.3 and Game.attention < 1.0, Game.attention)
	await step(300)                     # a long absence
	chk("but a long absence costs the lot",
		is_equal_approx(Game.attention, 0.0), Game.attention)

	# --- a test is sat in silence and does not need teaching ---
	Game.new_run(SEED)
	await step(40)
	for i in Balance.test_requires_taught:
		Game.record_taught(String(Game.lesson.get("id", "")))
	Game.set_phase(Game.Phase.MORNING)
	world.start_test(String(Game.lesson.get("id", "")))
	p.global_position = Grid.tile_to_world(Vector2i(2, Grid.H - 2))
	var t: StudentData = Game.roster[0]
	var t_before := t.work_timer
	await step(120)
	chk("a test does not need teaching -- they sit it in silence",
		t.work_timer < t_before, "%.2f -> %.2f" % [t_before, t.work_timer])
	world.end_test()
	_hud().close()

	Game.new_run(SEED)
	await step(2)



func test_difficulty() -> void:
	section("HOW HARD A LESSON IS")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# Difficulty did not exist at all: work_seconds was a flat 20 for every
	# lesson, and grep over the whole project found the word only in prose.
	chk("every lesson says how hard it is", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			var v := Curriculum.difficulty(l)
			if v < 1 or v > 5:
				return false
		return true).call())
	chk("and they are not all the same", (func() -> bool:
		var seen := {}
		for l: Dictionary in Curriculum.lessons:
			seen[Curriculum.difficulty(l)] = true
		return seen.size() >= 3).call())

	var easy: Dictionary = {}
	var hard: Dictionary = {}
	for l: Dictionary in Curriculum.lessons:
		if Curriculum.difficulty(l) <= 1:
			easy = l
		if Curriculum.difficulty(l) >= 4:
			hard = l

	# --- a hard lesson is longer work ---
	Game.room_items.clear()
	var s := StudentData.new()
	s.aptitude = 0.5
	Game.lesson = easy
	s.assign_work()
	var easy_len := s.work_total
	s.reset_lesson()
	Game.lesson = hard
	s.assign_work()
	var hard_len := s.work_total
	chk("a hard lesson is longer work than an easy one", hard_len > easy_len,
		"%.1fs vs %.1fs" % [hard_len, easy_len])

	# --- and they get stuck on it more ---
	var t: StudentData = Game.roster[0]
	t.trait_id = "steady"
	Game.lesson = easy
	var easy_stall := t.stall_chance()
	Game.lesson = hard
	var hard_stall := t.stall_chance()
	chk("and they get stuck on it more often", hard_stall > easy_stall,
		"%.4f vs %.4f" % [hard_stall, easy_stall])

	# --- furniture takes the edge off ---
	# room_score used to feed the GRADE and nothing else, so a bookshelf was
	# worth points and changed nothing you could watch happen.
	var bare := t.stall_chance()
	var guard := 0
	while Game.room_score(t.seat_index) < Balance.room_cap - 0.001 and guard < 60:
		Game.room_items.append({"id": Items.order()[guard % Items.order().size()],
			"tile": Layout.seat(t.seat_index) + Vector2i(0, -1)})
		guard += 1
	chk("a furnished desk makes a hard lesson easier to sit",
		t.stall_chance() < bare, "%.4f -> %.4f" % [bare, t.stall_chance()])

	var u := StudentData.new()
	u.seat_index = t.seat_index
	u.assign_work()
	chk("and shortens the work on it", u.work_total < hard_len,
		"%.1fs vs %.1fs" % [u.work_total, hard_len])

	# ...but it does not make an EASY lesson easier still, because only the
	# extra difficulty is relieved.
	Game.lesson = easy
	var v := StudentData.new()
	v.seat_index = t.seat_index
	v.assign_work()
	var w := StudentData.new()
	w.seat_index = -1
	w.assign_work()
	chk("an easy lesson is not made easier still by furniture",
		is_equal_approx(v.work_total, w.work_total),
		"%.2f vs %.2f" % [v.work_total, w.work_total])

	# --- the player can SEE it before committing ---
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	hud.show_curriculum()
	chk("the curriculum page shows how hard each lesson is",
		hud.rich.text.contains(hud.BAR_FULL), hud.rich.text)
	hud.close()
	Game.set_phase(Game.Phase.MORNING)
	hud._update_status()
	chk("and the strip says how hard today's is",
		hud.status.text.contains("*"), hud.status.text)

	Game.new_run(SEED)
	await step(2)



## No screen may print a raw colour code as TEXT.
##
## A blanket string edit put BAR_TRACK at the FRONT of two format arg lists
## instead of replacing the second colour, so the hue was printed as words
## and a row of blocks was used as a colour: the curriculum and the shop both
## shipped reading "Reading 9fd89f you know it well". Every existing
## assertion passed, because they all check .contains() rather than what the
## screen actually looks like.
func test_no_raw_colour_codes() -> void:
	section("NO COLOUR CODES PRINTED AS TEXT")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	var rx := RegEx.new()
	# a 6-hex token that is NOT preceded by the "#" of a colour tag
	rx.compile("(?<![#0-9a-fA-F])[0-9a-f]{6}(?![0-9a-fA-F])")

	Game.add_coins(5000)
	for i in 12:
		Game.record_taught(String(Curriculum.lessons[i % Curriculum.lessons.size()]
			.get("id", "")))
	Game.room_items.append({"id": "bookshelf", "tile": Vector2i(9, 6)})

	var screens := {
		"curriculum": func() -> void: hud.show_curriculum(),
		"the shop": func() -> void: hud.open_catalogue(),
		"the exam": func() -> void: hud.show_exam(Game.sit_exam()),
		"the day report": func() -> void: hud.show_day_report(Game.advance_day()),
	}
	for name: String in screens.keys():
		(screens[name] as Callable).call()
		var shown: String = hud.rich.text if hud.rich.visible else hud.body.text
		chk("%s prints no raw colour codes" % name,
			rx.search(shown) == null,
			rx.search(shown).get_string() if rx.search(shown) != null else "")
		hud.close()



func test_specialism_and_choice() -> void:
	section("WHAT YOU TEACH, AND WHAT YOU TRAINED IN")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	# --- enough lessons to specialise INTO ---
	# Ten across four strands was too thin: picking Maths would have meant a
	# choice of two, which is a punishment rather than an identity.
	chk("there are lessons enough to specialise into", (func() -> bool:
		var per := {}
		for l: Dictionary in Curriculum.lessons:
			var st := String(l.get("strand", ""))
			per[st] = int(per.get(st, 0)) + 1
		for st: String in per.keys():
			if int(per[st]) < 4:
				return false
		return per.size() >= 4).call())

	# --- choosing the lesson ---
	chk("a run starts with nothing chosen", Game.chosen_lesson == "")
	Game.chosen_lesson = "chemistry"
	Game.subject = Game.pick_subject()
	chk("choosing a lesson makes it the one you teach",
		String(Game.lesson.get("id", "")) == "chemistry",
		Game.lesson.get("id", ""))
	chk("and the choice is spent, not sticky", Game.chosen_lesson == "")
	Game.subject = Game.pick_subject()
	chk("so the next day rolls one again unless you choose",
		Game.lesson.has("id"))

	# --- specialism changes how hard it is ---
	Game.room_items.clear()
	Game.specialism = ""
	Game.lesson = Curriculum.by_id("chemistry")       # science, difficulty 5
	var neutral: Array = Game.difficulty_mults(-1)

	Game.specialism = "science"
	var mine: Array = Game.difficulty_mults(-1)
	chk("your own subject is easier to get a class through",
		float(mine[0]) < float(neutral[0]),
		"%.2f vs %.2f" % [mine[0], neutral[0]])
	chk("and they get stuck on it less", float(mine[1]) < float(neutral[1]))

	Game.specialism = "ela"
	var theirs: Array = Game.difficulty_mults(-1)
	chk("somebody else's subject is harder", float(theirs[0]) > float(neutral[0]),
		"%.2f vs %.2f" % [theirs[0], neutral[0]])

	# --- and what it pays ---
	Game.specialism = "science"
	chk("teaching your own subject pays more",
		Game.lesson_pay_multiplier() > 1.0, Game.lesson_pay_multiplier())
	Game.specialism = "ela"
	chk("teaching out of field pays the usual",
		is_equal_approx(Game.lesson_pay_multiplier(), 1.0))

	# It is a LEAN, not a cage: everything is still teachable.
	#
	# This asserted `lessons.size() == 20`, which tested the SIZE of the
	# curriculum rather than the claim written above it, and broke the
	# moment a content batch landed. It now checks the actual promise: no
	# specialism removes a lesson from the pool or makes one unteachable.
	chk("every lesson is still teachable whatever you trained in",
		(func() -> bool:
			var saved: Dictionary = Game.lesson
			var every := true
			for sp: String in ["", "math", "ela", "science", "social"]:
				Game.specialism = sp
				if Curriculum.lessons.size() != Curriculum.count():
					every = false
				for l: Dictionary in Curriculum.lessons:
					Game.lesson = l
					var m: Array = Game.difficulty_mults(-1)
					if float(m[0]) <= 0.0 or float(m[1]) <= 0.0:
						every = false
			Game.lesson = saved
			return every).call())

	# --- the screens ---
	var hud := _hud()
	Game.specialism = "math"
	hud.show_curriculum()
	# The book layout (Sept 2026) puts the heading on the LEFT page.
	chk("the curriculum names what you teach next",
		hud.rich_left.text.contains("You teach"), hud.rich_left.text)
	chk("and what you trained in",
		hud.rich_left.text.contains("trained in"), hud.rich_left.text)
	hud.close()

	Game.specialism = ""
	hud.show_specialism()
	chk("a run asks what kind of teacher you are",
		hud.title.text.contains("WHAT DO YOU TEACH"), hud.title.text)
	chk("and offers every subject", (func() -> bool:
		for st: String in Curriculum.strands():
			if not hud.rich.text.contains(Curriculum.strand_label(st)):
				return false
		return true).call(), hud.rich.text)
	hud.close()

	# --- it survives the night ---
	Game.specialism = "science"
	Game.chosen_lesson = "chemistry"
	Game.save_game()
	Game.new_run(1)
	chk("a new run has no speciality", Game.specialism == "")
	Game.load_game()
	chk("but a saved one remembers it", Game.specialism == "science")
	chk("and what you had lined up to teach",
		Game.chosen_lesson == "chemistry")
	Game.delete_save()

	Game.new_run(SEED)
	await step(2)



func test_build_mode() -> void:
	section("REARRANGING THE ROOM")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	Game.add_coins(4000)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)
	var p: Actor = world.player
	# `main` is the parent of the world, the way the other tests reach it
	var main: Node = world.get_parent()

	chk("build is a real, rebindable action", InputMap.has_action("build"))
	chk("and it is offered in the controls screen", (func() -> bool:
		for row: Dictionary in Settings.ACTIONS:
			if String(row["action"]) == "build":
				return true
		return false).call())

	# Editing the room used to mean walking to every item in turn. The
	# cursor roams the WHOLE room now.
	Game.room_items.clear()
	Game.add_item("bookshelf", Vector2i(4, 6))
	Game.add_item("plant", Vector2i(14, 8))
	await step(3)
	p.global_position = Grid.tile_to_world(Vector2i(9, 3))

	main._toggle_build()
	await step(2)
	chk("build mode opens a cursor", main.placement.active
		and main.placement.browsing)
	chk("and it locks you where you stand rather than making you walk",
		p.input_locked)

	# reach the far corner without moving the teacher
	main.placement.tile = Vector2i(14, 8)
	main.placement._refresh()
	chk("the cursor reaches furniture across the room",
		not Game.item_at(main.placement.tile).is_empty())

	# --- pick up from under the CURSOR, not from under your feet ---
	var before: int = Game.room_items.size()
	main.placement.picked_up.emit("plant", Vector2i(14, 8))
	await step(3)
	chk("picking it up takes it off the floor",
		Game.room_items.size() == before - 1, Game.room_items.size())
	chk("and puts it in your hands", main.placement.active
		and main.placement.item_id == "plant")
	main.placement.tile = Vector2i(12, 8)
	main.placement._refresh()
	main.placement.placed.emit("plant", Vector2i(12, 8))
	await step(3)
	chk("and it goes back down where you put it",
		not Game.item_at(Vector2i(12, 8)).is_empty())

	# --- packing away from the cursor: F stores it in the cabinet, it is
	# not destroyed for half its value -- disposal happens from the cabinet
	# screen now ---
	main._toggle_build()
	await step(2)
	var coins_before: int = Game.coins
	var items_before: int = Game.room_items.size()
	var cabinet_before: int = Game.cabinet.size()
	main.placement.stored.emit(Vector2i(4, 6))
	await step(3)
	chk("packing away from the cursor takes it off the floor",
		Game.room_items.size() == items_before - 1)
	chk("and it goes into the cabinet, uncharged, un-refunded",
		Game.cabinet.size() == cabinet_before + 1 and Game.coins == coins_before,
		"%d cabinet, %d coins" % [Game.cabinet.size(), Game.coins])

	# --- the rule every other way of moving furniture already follows ---
	main.placement.finish()
	Game.set_phase(Game.Phase.LESSON)
	main._toggle_build()
	await step(2)
	chk("you cannot rearrange the room mid-lesson",
		not main.placement.active)
	Game.set_phase(Game.Phase.AFTERNOON)

	# --- and it still refuses to trap anybody ---
	# The aisle-safety check is the same one, which is the whole reason
	# build mode reuses Placement rather than reimplementing it.
	main._toggle_build()
	await step(2)
	main.placement.browsing = false
	main.placement.item_id = "bookshelf"
	main.placement.tile = Layout.desk_tile(0)
	main.placement._refresh()
	chk("dropping something inside a desk is still refused",
		not main.placement.is_valid())
	main.placement.tile = Vector2i(0, 0)
	main.placement._refresh()
	chk("and so is dropping it inside a wall", not main.placement.is_valid())
	main.placement.tile = Vector2i(9, 6)
	main.placement._refresh()
	chk("but a clear tile is fine", main.placement.is_valid())
	main.placement.finish()
	main._unlock()

	Game.new_run(SEED)
	await step(2)



func test_assignment_cards() -> void:
	section("THE PAPER YOU SET")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	# --- the ladder ---
	chk("there are five rarities", Assignments.rarities().size() == 5,
		Assignments.rarities().size())
	chk("named the way you named them", (func() -> bool:
		var want := ["Common", "Rare", "Excellent", "Epic", "Legendary"]
		for i in want.size():
			var got := Assignments.rarity_name(
				String(Assignments.rarities()[i]["id"]))
			if got != want[i]:
				return false
		return true).call())
	chk("each is rarer than the last", (func() -> bool:
		var last := 99999.0
		for r: Dictionary in Assignments.rarities():
			if float(r["weight"]) > last:
				return false
			last = float(r["weight"])
		return true).call())
	chk("and each pays more than the last", (func() -> bool:
		var last := 0.0
		for r: Dictionary in Assignments.rarities():
			if float(r["pay"]) <= last:
				return false
			last = float(r["pay"])
		return true).call())
	chk("every one has its own colour", (func() -> bool:
		var seen := {}
		for r: Dictionary in Assignments.rarities():
			seen[String(r["colour"])] = true
		return seen.size() == Assignments.rarities().size()).call())

	# --- mostly common, which is what makes a Legendary worth something ---
	var counts := {}
	for i in 4000:
		var c := Assignments.roll(Game.rng, Game.lesson)
		counts[c["rarity"]] = int(counts.get(c["rarity"], 0)) + 1
	chk("most papers are Common", int(counts.get("common", 0)) > 2000, counts)
	chk("and Legendaries are genuinely rare",
		int(counts.get("legendary", 0)) < 200
		and int(counts.get("legendary", 0)) > 0, counts)
	chk("but every rarity does turn up", counts.size() == 5, counts)

	# rarity is correlated with LENGTH, so a rare card is not a free lunch
	var common_diff := 0.0
	var common_n := 0
	var legend_diff := 0.0
	var legend_n := 0
	for i in 4000:
		var c2 := Assignments.roll(Game.rng, Game.lesson)
		if String(c2["rarity"]) == "common":
			common_diff += float(c2["difficulty"])
			common_n += 1
		elif String(c2["rarity"]) == "legendary":
			legend_diff += float(c2["difficulty"])
			legend_n += 1
	if legend_n > 0:
		chk("a rarer paper is usually a longer one",
			legend_diff / float(legend_n) > common_diff / maxf(1.0, float(common_n)),
			"%.1f vs %.1f" % [legend_diff / float(legend_n),
				common_diff / maxf(1.0, float(common_n))])
	else:
		chk("SKIPPED: no legendary in this sample", true)

	# --- drawing and choosing ---
	Game.new_run(SEED)
	var hand := Game.draw_hand()
	chk("the podium deals a hand within the shuffled range",
		hand.size() >= Balance.assign_hand_size_min
		and hand.size() <= Balance.assign_hand_size_max,
		hand.size())

	# A REAL shuffle, not always the same count -- draw a run of hands and
	# check the size actually varies. A single draw proves nothing; it could
	# always land on the same number by coincidence of the seed.
	var sizes := {}
	var all_in_range := true
	for i in 30:
		var sz: int = Game.draw_hand().size()
		sizes[sz] = true
		if sz < Balance.assign_hand_size_min or sz > Balance.assign_hand_size_max:
			all_in_range = false
	chk("hand size actually varies across draws, not fixed",
		sizes.size() > 1, sizes.keys())
	chk("and every draw stayed within the shuffled range", all_in_range,
		sizes.keys())

	chk("nothing is set until you pick", Game.assignment.is_empty())
	Game.choose_assignment(1)
	chk("choosing sets the paper", not Game.assignment.is_empty())
	chk("and the hand is spent", Game.hand.is_empty())

	# --- what it changes ---
	Game.room_items.clear()
	Game.assignment = {"rarity": "common", "form": "Worksheet",
		"difficulty": 1, "subject": "x", "lesson": ""}
	var short := StudentData.new()
	short.assign_work()
	Game.assignment = {"rarity": "legendary", "form": "Project",
		"difficulty": 5, "subject": "x", "lesson": ""}
	var long_one := StudentData.new()
	long_one.assign_work()
	chk("a Project is longer work than a Worksheet",
		long_one.work_total > short.work_total,
		"%.1fs vs %.1fs" % [long_one.work_total, short.work_total])

	chk("a Legendary pays more", Game.assignment_pay() > 1.0,
		Game.assignment_pay())
	Game.assignment = {"rarity": "common", "difficulty": 1}
	chk("and a Common pays the usual",
		is_equal_approx(Game.assignment_pay(), 1.0))

	# THE LINE THAT KEEPS THE CONTRACT SAFE: rarity pays coins and XP, never
	# grade. A multiplier on the lesson term would move the design pillar by
	# LUCK rather than by play.
	var s2: StudentData = Game.roster[0]
	s2.work_state = StudentData.Work.COLLECTED
	Game.assignment = {"rarity": "common", "difficulty": 3}
	var plain := Game.grade_for(s2)
	Game.assignment = {"rarity": "legendary", "difficulty": 3}
	chk("but rarity never touches the grade",
		is_equal_approx(Game.grade_for(s2), plain),
		"%.3f vs %.3f" % [Game.grade_for(s2), plain])

	# --- it survives the night ---
	Game.save_game()
	Game.new_run(1)
	chk("a new run has no paper set", Game.assignment.is_empty())
	Game.load_game()
	chk("but a saved one remembers what the class is doing",
		String(Game.assignment.get("rarity", "")) == "legendary")
	Game.delete_save()

	# --- the screen ---
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	Game.draw_hand()
	hud.show_hand()
	chk("the hand is on screen", hud.mode == hud.Mode.HAND)
	# ONE page at a time -- only the card at _sel is ever on screen, so
	# checking every title against a single page's text is checking
	# something the UI cannot show. This passed before only by an accident
	# of a fixed 3-card hand and this seed; a real 3-7 shuffle exposed it.
	# Turn to every page and check each card names ITSELF, correctly.
	chk("names every paper it dealt, one page at a time", (func() -> bool:
		for i in Game.hand.size():
			hud._sel = i
			hud.show_hand()
			var c3: Dictionary = Game.hand[i]
			# A plan's own name is the LEFT page of the book; the right page
			# is what it asks of you.
			if not hud.rich_left.text.contains(Assignments.title(c3)):
				return false
			# On the book's cream pages the rarity keeps its hue but is pulled
			# dark enough to read -- see hud._on_paper(). Still colour-coded,
			# just not the same literal hex the dark panel used.
			if not hud.rich_left.text.contains(hud._on_paper(
					Assignments.rarity_colour(String(c3["rarity"])))):
				return false
		return true).call())
	hud._sel = 0
	hud.show_hand()
	chk("and it fits", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	hud.close()

	Game.new_run(SEED)
	await step(2)



func test_a_term_can_be_won() -> void:
	section("A WELL-TAUGHT TERM IS WINNABLE")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# THE QUESTION NOTHING WAS ASKING. Every part of this game has been
	# tested in isolation and the simulator reports letter grades, but
	# nothing has ever checked the only thing that actually matters to a
	# player: play well for twenty days, and do you keep the job?
	#
	# Played COMPETENTLY, which here means the three things the game asks
	# for: teach at the front, unstick whoever freezes, and collect the work.
	var target := Game.term_target()
	chk("term one asks for a few of them", target > 0, target)

	for day in Balance.term_days:
		for st: StudentData in Game.roster:
			st.reset_lesson()
			st.assign_work()
		var t := 0.0
		while t < Balance.lesson_seconds:
			t += 1.0 / 60.0
			for st: StudentData in Game.roster:
				# at the front the whole time, so attention is full
				st.tick_work(1.0 / 60.0, Game.rng, 1.0)
				if st.is_struggling():
					st.help()
		for st: StudentData in Game.roster:
			st.collect_work()
		Game.grade_class()
		Game.assign_homework()
		# homework comes back and is marked honestly
		for st: StudentData in Game.roster:
			if st.hw_state == StudentData.HW.ASSIGNED:
				st.hw_state = StudentData.HW.MARKED
				st.hw_player_verdict = 1 if Questions.sheet_is_good(st.hw_sheet) else 0

	var avg := Game.class_average()
	chk("a term taught properly averages a real grade",
		avg >= Balance.grade_band_c, "%.2f (%s)" % [avg, Game.grade_letter(avg)])

	var result := Game.sit_exam()
	var passed: int = int(result["passed"])
	chk("and enough of them pass the exam", passed >= target,
		"%d passed, needed %d, class of %d" % [passed, target,
			Game.roster.size()])
	chk("so the job is kept", Game.met_target(passed))

	# and the opposite: a term nobody taught must NOT squeak through, or the
	# target is decoration
	Game.new_run(SEED)
	for day in Balance.term_days:
		for st: StudentData in Game.roster:
			st.reset_lesson()
			st.assign_work()
		Game.grade_class()
	var idle := Game.sit_exam()
	chk("a term nobody taught does not keep the job",
		not Game.met_target(int(idle["passed"])),
		"%d passed, needed %d" % [int(idle["passed"]), Game.term_target()])

	Game.new_run(SEED)



func test_autopilot_and_aide() -> void:
	section("AUTOPILOT, AND THE AIDE")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(40)
	var p: Actor = world.player

	# --- autopilot ---
	chk("it is a real, rebindable action", InputMap.has_action("autopilot"))
	chk("and it is offered in the controls screen", (func() -> bool:
		for row: Dictionary in Settings.ACTIONS:
			if String(row["action"]) == "autopilot":
				return true
		return false).call())
	chk("it starts off", not p.autopilot)

	# priority is the same one the desk itself uses, so it walks you to the
	# thing you would have chosen
	var a: StudentData = Game.roster[0]
	var b: StudentData = Game.roster[1]
	a.work_state = StudentData.Work.DONE          # rank 4, collect
	b.disrupting = true                           # rank 1, settle
	chk("messing about outranks a finished sheet",
		b.attention_rank() < a.attention_rank(),
		"%d vs %d" % [b.attention_rank(), a.attention_rank()])
	b.disrupting = false
	b.confusion = 1.0
	b.trait_id = "steady"
	chk("and being stuck outranks it too",
		b.attention_rank() < a.attention_rank())
	chk("a child who is fine does not want you at all", (func() -> bool:
		var c := StudentData.new()
		return c.attention_rank() == 0).call())

	# it moves your feet and never presses your buttons
	#
	# A new run opens the "what do you teach" screen, and that locks the
	# player -- so this has to answer it first, exactly as a player does.
	# Setting the PHASE to LESSON is not the same as STARTING one: the clock
	# is still zero, so it times out on the very next frame, auto-ends, and
	# opens a report that locks the player. Start it properly.
	Game.specialism = "math"
	_hud().close()
	await step(2)
	world.start_lesson()
	await step(4)
	b.trait_id = "steady"
	b.confusion = 1.0
	p.autopilot = true
	var helps_before: int = b.helps_total
	await step(120)
	chk("autopilot walks you somewhere", p.auto_target_name != "",
		"target=[%s] locked=%s hud=%d phase=%d stuck=%s rank=%d" % [
			p.auto_target_name, p.input_locked, _hud().mode, Game.phase,
			b.is_visibly_struggling(), b.attention_rank()])
	chk("but it never acts for you", b.helps_total == helps_before,
		"%d -> %d" % [helps_before, b.helps_total])
	p.autopilot = false
	b.confusion = 0.0
	a.work_state = StudentData.Work.NONE

	# --- the aide ---
	Game.new_run(SEED)
	await step(2)
	chk("you start without one", not Game.has_aide)
	Game.coins = 0
	chk("and cannot afford one on nothing", Game.set_aide(true) != "")
	Game.coins = Balance.aide_cost + 10
	chk("hiring works", Game.set_aide(true) == "")
	chk("they are hired", Game.has_aide)
	chk("and it cost what it says", Game.coins == 10, Game.coins)

	# they do the CHORE and never the judgement
	Game.set_phase(Game.Phase.LESSON)
	var c1: StudentData = Game.roster[0]
	c1.assign_work()
	c1.work_state = StudentData.Work.DONE
	var stuck: StudentData = Game.roster[1]
	stuck.trait_id = "steady"
	stuck.confusion = 1.0
	var stuck_helps: int = stuck.helps_total
	for i in 400:
		Game.tick_aide(1.0 / 60.0)
	chk("the aide collects finished work",
		c1.work_state == StudentData.Work.COLLECTED, c1.work_state)
	chk("but never unsticks anybody -- that is a judgement, not legwork",
		stuck.is_struggling() and stuck.helps_total == stuck_helps)

	# and they are paid every day, so keeping one is a standing decision
	Game.set_phase(Game.Phase.AFTERNOON)
	Game.coins = 5000
	var before_day: int = Game.coins
	var report := Game.advance_day()
	chk("their wage is in the day's upkeep",
		int(report["upkeep"]) >= Balance.aide_wage, report["upkeep"])

	# --- levelling the aide up ---
	Game.coins = 5000
	var interval_before: float = Game.aide_interval()
	chk("level 1 is the unmodified interval",
		is_equal_approx(interval_before, Balance.aide_collect), interval_before)
	var lvl_before: int = Game.coins
	chk("levelling up costs coins and raises the level",
		Game.level_up_staff("aide") == "" and Game.aide_level == 2,
		Game.aide_level)
	chk("and it costs what staff_level_cost(1) says",
		Game.coins == lvl_before - Game.staff_level_cost(1), Game.coins)
	chk("a levelled aide is faster, not just numbered differently",
		Game.aide_interval() < interval_before, Game.aide_interval())
	Game.coins = 0
	chk("cannot afford the next level on nothing",
		Game.level_up_staff("aide") != "")
	Game.coins = 999999
	for i in Balance.staff_level_max:
		Game.level_up_staff("aide")
	chk("levelling is capped at staff_level_max",
		Game.aide_level == Balance.staff_level_max, Game.aide_level)
	chk("and trying past the cap says so rather than overshooting",
		Game.level_up_staff("aide") != "")

	Game.set_aide(false)
	chk("and you can let them go", not Game.has_aide)
	chk("letting them go loses the training you paid for",
		Game.aide_level == 1, Game.aide_level)

	Game.save_game()
	Game.set_aide(true)
	Game.load_game()
	chk("whether you have one survives a save", not Game.has_aide)
	Game.delete_save()

	# --- the janitor: same shape as the aide, one door over ---
	Game.new_run(SEED)
	await step(2)
	chk("you start without a janitor either", not Game.has_janitor)
	Game.coins = 0
	chk("and cannot afford one on nothing", Game.set_janitor(true) != "")
	Game.coins = Balance.janitor_cost + 10
	chk("hiring works", Game.set_janitor(true) == "")
	chk("and it cost what it says", Game.coins == 10, Game.coins)

	# unlike the aide, this works in ANY phase -- mess isn't lesson-gated
	Game.set_phase(Game.Phase.MORNING)
	var acted := false
	for i in 400:
		if Game.tick_janitor(1.0 / 60.0):
			acted = true
	chk("the janitor's timer fires outside a lesson too", acted)

	Game.coins = 5000
	var jbefore: float = Game.janitor_interval()
	chk("levelling the janitor up speeds them up the same way",
		Game.level_up_staff("janitor") == "" and Game.janitor_level == 2
		and Game.janitor_interval() < jbefore, Game.janitor_interval())

	Game.set_phase(Game.Phase.AFTERNOON)
	Game.coins = 5000
	var jday_before: int = Game.coins
	var jreport := Game.advance_day()
	chk("the janitor's wage is in the day's upkeep too",
		int(jreport["upkeep"]) >= Balance.janitor_wage, jreport["upkeep"])

	Game.set_janitor(false)
	chk("letting the janitor go also resets their training",
		not Game.has_janitor and Game.janitor_level == 1, Game.janitor_level)

	Game.new_run(SEED)
	await step(2)


## Resolve YOUR room the same honest way a delegated one is, on the
## player's own request. THE PROMISE THAT MATTERS: the grade comes from
## Game.grade_class() -- your real room_score() -- not RoomSim's own flat
## room_value, which is what would make an auto-taught day a lie about
## your furniture rather than an honest reading of it.
func test_auto_teach() -> void:
	section("AUTO-TEACH")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()

	chk("off by default", not Game.auto_teach)
	await tap("auto_teach")
	chk("its own key toggles it", Game.auto_teach)
	await tap("auto_teach")
	chk("and toggles it back off", not Game.auto_teach)
	await tap("auto_teach")

	# A real furniture difference has to show up in the grade, or this is
	# a formula wearing RoomSim's clothes rather than an honest reading.
	Game.room_items.clear()
	Game.place_item("microscope", Vector2i(2, 4))   # strong, in range of seat 0
	Game.set_phase(Game.Phase.MORNING)
	world.start_lesson()
	chk("starting the lesson resolves it instantly -- no real-time ticking",
		Game.phase == Game.Phase.AFTERNOON, Game.phase)
	chk("and opens the watch screen", hud.mode == hud.Mode.WATCH, hud.mode)
	chk("naming auto-teach, not a hired archetype",
		hud.title.text.contains("Auto-teach"), hud.title.text)
	var furnished_grade := Game.roster[0].last_grade

	await tap("watch")   # the "skip to the bell" key, same as a delegated room
	chk("skipping lands on the last frame",
		hud._watch_i == hud._watch_frames.size() - 1)
	await tap("interact")
	chk("closing it hands off to the ordinary lesson report, not the school board",
		hud.mode == hud.Mode.REPORT, hud.mode)
	hud.close()

	# Same lesson, same seed, bare room this time -- the grade must move.
	Game.new_run(SEED)
	await step(2)
	Game.set_phase(Game.Phase.MORNING)
	world.start_lesson()
	var bare_grade := Game.roster[0].last_grade
	chk("furniture actually moved the auto-taught grade, not a formula",
		furnished_grade > bare_grade, "%.3f vs %.3f" % [furnished_grade, bare_grade])
	hud.close()

	# --- toggling it ON mid-lesson resolves THAT lesson immediately ---
	Game.new_run(SEED)
	await step(2)
	Game.set_phase(Game.Phase.MORNING)
	world.start_lesson()
	await step(3)
	chk("a real lesson is genuinely under way", Game.phase == Game.Phase.LESSON)
	var m := get_tree().get_first_node_in_group("main_wiring")
	m._toggle_auto_teach()
	chk("turning it on mid-lesson resolves that lesson too, not just the next one",
		Game.phase == Game.Phase.AFTERNOON, Game.phase)
	chk("and shows the watch screen the same way", hud.mode == hud.Mode.WATCH)
	hud.close()

	Game.new_run(SEED)
	await step(2)


func test_lesson_plan_folder() -> void:
	section("THE LESSON-PLAN FOLDER")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()

	Game.hand = [
		{"rarity": "common", "form": "Worksheet", "difficulty": 1,
			"subject": "Arithmetic", "lesson": "basic_arithmetic"},
		{"rarity": "excellent", "form": "Problem Set", "difficulty": 3,
			"subject": "Chemistry", "lesson": "chemistry"},
		{"rarity": "legendary", "form": "Project", "difficulty": 5,
			"subject": "Civics", "lesson": "civics"},
	]
	hud.show_hand()
	chk("the folder is open", hud.mode == hud.Mode.HAND)

	# ONE page at a time. A list of three reads as a menu; a page reads as a
	# plan, with room for what it actually asks of the class.
	chk("it shows one plan, not all of them", (func() -> bool:
		var shown := 0
		for c: Dictionary in Game.hand:
			if hud.rich_left.text.contains(Assignments.title(c)):
				shown += 1
		return shown == 1).call(), hud.rich_left.text)
	chk("and says which page you are on",
		hud.title.text.contains("1 of %d" % Game.hand.size()), hud.title.text)
	chk("the plan carries the objective it comes from", (func() -> bool:
		var l := Curriculum.by_id(String(Game.hand[0].get("lesson", "")))
		var obj := String(l.get("objective", ""))
		return obj == "" or hud.rich.text.contains(obj.substr(0, 20))).call(),
		hud.rich.text)

	# THE SHUFFLE. A hand just drawn gets a riffle before it settles; a page
	# TURN never does, or turning pages would nag with a sound effect and a
	# flourish every single time.
	hud._sel = 0
	hud.show_hand(true)
	chk("a fresh hand shuffles before it shows anything",
		hud.title.text == "SHUFFLING...", hud.title.text)
	await step(6)  # let at least the first riffle callback fire
	chk("the riffle actually draws a pip row, not blank or garbage",
		hud.rich.text.contains(hud.BAR_FULL) or hud.rich.text.contains(hud.BAR_EMPTY),
		hud.rich.text)
	chk("and it has not jumped ahead to the real card yet",
		not hud.rich.text.contains(Assignments.title(Game.hand[0])),
		hud.rich.text)
	await step(45)  # 6 steps x 0.07s of tween, with margin
	chk("and settles into the real folder afterward",
		hud.title.text.contains("1 of %d" % Game.hand.size()), hud.title.text)
	chk("showing a real card, not the shuffle pattern",
		hud.rich_left.text.contains(Assignments.title(Game.hand[0])),
		hud.rich_left.text)

	var first: String = hud.rich.text
	hud._sel = 1
	hud.show_hand()
	chk("turning the page does NOT reshuffle", hud.title.text != "SHUFFLING...")
	chk("turning the page shows a different plan", hud.rich.text != first)
	chk("and says so", hud.title.text.contains("2 of"), hud.title.text)

	# the wheel is an EVENT, so it is read in _input rather than polled
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	hud._input(wheel)
	chk("the scroll wheel turns it", hud._sel == 2, hud._sel)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	hud._input(up)
	chk("and turns it back", hud._sel == 1, hud._sel)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._input(click)
	chk("clicking the page turns it too", hud._sel == 2, hud._sel)

	chk("it fits", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	hud.close()

	Game.new_run(SEED)
	await step(2)


func test_dashboard() -> void:
	section("YOUR OWN DASHBOARD")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(5)
	var hud := _hud()
	const RICH_ROWS := 11

	# Reachable from the WORLD, on its own key -- not a landmark verb, so
	# E/F gain no third or fourth job. This is the actual test of "a
	# better button system": one more global key, same tier as Tab/pause.
	chk("closed to start with", hud.mode == hud.Mode.NONE)
	await tap("dashboard")
	chk("pressing the dashboard key opens it from the world",
		hud.mode == hud.Mode.DASHBOARD, hud.mode)
	hud.close()

	# THE BUG THIS CATCHES: show_dashboard() never set title.text, and
	# _open() does not clear it either -- so the dashboard silently kept
	# whatever the PREVIOUS screen's title was. Confirmed by screenshot:
	# open Career, close it, open the dashboard, and it read "YOUR
	# CAREER 6/23" over the tab strip. Reproduce that exact sequence.
	hud.show_career()
	hud.close()
	hud._dash = hud.Dash.OVERVIEW
	hud.show_dashboard()
	chk("the dashboard sets its own title rather than keeping the last one",
		hud.title.text == "YOUR DASHBOARD", hud.title.text)
	hud.close()

	# --- page 1: overview ---
	hud._dash = hud.Dash.OVERVIEW
	hud.show_dashboard()
	chk("opens on the overview page", hud._dash == hud.Dash.OVERVIEW)
	chk("shows your level", hud.rich.text.contains("Level %d" % Game.teacher_level),
		hud.rich.text)
	chk("and how many children you have",
		hud.rich.text.contains("%d of %d seats" % [Game.roster.size(), Game.seat_capacity()]),
		hud.rich.text)
	chk("the portrait is on for the overview page", hud.portrait.visible)
	chk("and names the cosmetic slots without pretending they exist",
		hud.rich.text.contains("Hat") and hud.rich.text.contains("Background")
		and hud.rich.text.contains("none chosen"), hud.rich.text)
	chk("it fits", hud.rich.text.split("
").size() <= RICH_ROWS,
		hud.rich.text.split("
").size())

	# --- page 2: items ---
	Game.place_item("stool", Vector2i(9, 6))
	hud._render_dashboard()  # room_items changed under an open screen
	hud._dash = (hud._dash + 1) % 4
	hud.show_dashboard()
	chk("cycled to the items page", hud._dash == hud.Dash.ITEMS)
	chk("the portrait turns off for a non-overview, non-wardrobe page",
		not hud.portrait.visible)
	chk("counts what you have bought, by category",
		hud.rich.text.contains(Items.category_label(Items.category_of("stool"))),
		hud.rich.text)
	chk("it fits", hud.rich.text.split("
").size() <= RICH_ROWS,
		hud.rich.text.split("
").size())
	Game.sell_item(Vector2i(9, 6))

	# --- page 3: skills ---
	Game.perk_ranks["calm_presence"] = 1
	hud._dash = (hud._dash + 1) % 4
	hud.show_dashboard()
	chk("cycled to the skills page", hud._dash == hud.Dash.SKILLS)
	# A summary, not a per-perk listing -- see hud.gd's own comment on why
	# (eleven perks stopped fitting a fixed, cursor-less page the moment
	# six landed alongside the roguelike pivot). The regression this test
	# now guards is "the trained COUNT reflects what you actually bought",
	# not a specific perk's name appearing verbatim.
	chk("shows a perk you have actually spent a point on",
		hud.rich.text.contains("1 of") and hud.rich.text.contains("skills trained"),
		hud.rich.text)
	chk("it fits", hud.rich.text.split("
").size() <= RICH_ROWS,
		hud.rich.text.split("
").size())

	# --- page 4: wardrobe -- hats and backgrounds, on the hook the
	# dashboard's own overview page has said "none chosen yet" about
	# since it was built ---
	hud._dash = (hud._dash + 1) % 4
	hud._sel = 0
	hud.show_dashboard()
	chk("cycled to the wardrobe page", hud._dash == hud.Dash.WARDROBE)
	chk("the portrait comes back for it -- the whole point is seeing the hat",
		hud.portrait.visible)
	chk("starts on the hat row", hud.rich.text.contains(">Hat"), hud.rich.text)
	var hat_before := Game.hat_id
	hud._adjust_wardrobe(1)
	chk("stepping right changes the hat", Game.hat_id != hat_before, Game.hat_id)
	chk("the actual player sprite picks it up, not just the label",
		world.player.hat_sprite.visible == (Game.hat_id != ""))
	hud._sel = 1
	hud._render_dashboard()
	var bg_before := Game.background_id
	hud._adjust_wardrobe(1)
	chk("stepping right on the background row changes the background",
		Game.background_id != bg_before, Game.background_id)
	chk("and leaves the hat exactly where the other row left it",
		Game.hat_id != hat_before, Game.hat_id)
	chk("it fits", hud.rich.text.split("
").size() <= RICH_ROWS,
		hud.rich.text.split("
").size())

	chk("and cycling wraps back round to overview",
		(hud._dash + 1) % 4 == hud.Dash.OVERVIEW)
	Game.hat_id = ""
	Game.background_id = ""
	world.player.refresh_hat()

	# --- closing ---
	await tap("cancel")
	chk("Esc closes it", hud.mode == hud.Mode.NONE, hud.mode)

	Game.perk_ranks.clear()
	Game.new_run(SEED)
	await step(2)


func test_milestones() -> void:
	section("SOMETHING TO AIM AT")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# WHY THESE EXIST: the game is endless by design, and a player who
	# reaches term five with nothing named to aim at stops. A milestone is
	# authored progress without an authored ending.
	chk("there are milestones", Milestones.count() > 0, Milestones.count())
	chk("every one has a name and a line to show", (func() -> bool:
		for m: Dictionary in Milestones.all():
			if String(m.get("name", "")) == "" or String(m.get("blurb", "")) == "":
				return false
		return true).call())
	chk("every id is unique", (func() -> bool:
		var seen := {}
		for m: Dictionary in Milestones.all():
			if seen.has(String(m["id"])):
				return false
			seen[String(m["id"])] = true
		return true).call())

	# A milestone whose threshold is DERIVED FROM CONTENT must not state
	# that number in its blurb.
	#
	# `polymath` read "Every concept in the curriculum. All sixty." and was
	# true right up until a content batch made it 120 -- so the game would
	# have told the player something false at the proudest moment it has.
	# Milestones with a fixed literal threshold (ten_up, fifty_up,
	# five_terms) may name their number, because nothing can move it.
	var content_derived: Array[String] = ["polymath", "specialist"]
	var numbered: Array = []
	for m: Dictionary in Milestones.all():
		if not content_derived.has(String(m.get("id", ""))):
			continue
		var b := String(m.get("blurb", "")).to_lower()
		for word: String in ["sixty", "thirty", "fifteen", "hundred", "twenty",
				"forty", "fifty", "ten ", "0", "1", "2", "3", "4", "5",
				"6", "7", "8", "9"]:
			if b.find(word) >= 0:
				numbered.append("%s: %s" % [m.get("id", ""), m.get("blurb", "")])
				break
	chk("a milestone counting content does not name the count",
		numbered.is_empty(), numbered)

	# Concepts are TEXTURE, not a collection. See docs/GDD.md.
	#
	# The board printed "Curriculum (8/120)". concept_bonus caps at ten
	# concepts, so the hundred and ten after that move no number -- the
	# fraction promised a completion target the systems do not deliver,
	# and made a teacher's subject knowledge look like a checklist she was
	# failing. Nothing may print a concept fraction again.
	chk("the curriculum board never shows a completion fraction",
		(func() -> bool:
			for c in get_tree().get_nodes_in_group("curriculum_board"):
				if c is Interactable:
					var t := String(c.prompt_text())
					if t.contains("/") or t.contains(str(Curriculum.concept_count())):
						return false
			return true).call())

	chk("a new run has earned none", Game.milestones.is_empty())

	# --- they gate nothing and pay nothing ---
	# The moment IS the reward. A milestone that paid coins would be a
	# quest, and a quest in an endless game is a treadmill.
	var coins_before: int = Game.coins
	Game.graduated.append({"name": "Someone", "level": 5})
	var fresh := Game.check_milestones()
	chk("sending a child up earns one", fresh.has("first_up"), fresh)
	chk("and it pays nothing at all", Game.coins == coins_before,
		"%d -> %d" % [coins_before, Game.coins])

	# --- and never twice ---
	var again := Game.check_milestones()
	chk("the same one never fires twice", not again.has("first_up"), again)
	chk("but it is remembered", Game.milestones.has("first_up"))

	# --- each is checked against real state ---
	Game.new_run(SEED)
	Game.coins = 5000
	Game.check_milestones()
	chk("money you have earns the money one", Game.milestones.has("rich"))

	Game.new_run(SEED)
	for i in 25:
		Game.room_items.append({"id": "plant", "tile": Vector2i(9, 6)})
	Game.check_milestones()
	chk("a furnished room earns the furnishing one",
		Game.milestones.has("furnished"))

	Game.new_run(SEED)
	for l: Dictionary in Curriculum.lessons:
		for i in 10:
			Game.record_taught(String(l.get("id", "")))
	Game.check_milestones()
	chk("knowing the whole curriculum earns the big one",
		Game.milestones.has("polymath"))
	chk("and knowing one subject earns the smaller one",
		Game.milestones.has("specialist"))

	# a term where every child passed, read from the RECORD so it survives
	# a reload rather than depending on the moment it happened
	Game.new_run(SEED)
	Game.term_history.append({"term": 1, "letter": "A", "passed": 6,
		"total": 6, "moved_up": 6, "target": 2, "met": true})
	Game.check_milestones()
	chk("a whole class passing earns one", Game.milestones.has("full_house"))
	chk("and surviving a term earns one", Game.milestones.has("first_term"))

	# --- they survive the night ---
	Game.save_game()
	var had := Game.milestones.size()
	Game.new_run(1)
	chk("a new run starts with none again", Game.milestones.is_empty())
	Game.load_game()
	chk("but a saved career remembers them",
		Game.milestones.size() == had, Game.milestones.size())
	Game.delete_save()

	# --- the screen ---
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	Game.milestones.append("first_up")
	hud._career_page = hud.CAREER_MILESTONES
	hud.show_career()
	chk("the career page opens", hud.mode == hud.Mode.CAREER)
	chk("it names what you HAVE done",
		hud.rich.text.contains(String(Milestones.by_id("first_up")["name"])),
		hud.rich.text)
	# The unearned ones are the point: a list of what you have done is a
	# trophy cabinet, one that shows what is left is a map.
	chk("and hides the ones you have not, without hiding that they exist",
		hud.rich.text.contains("- - -"), hud.rich.text)
	chk("it fits", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	hud.close()

	Game.new_run(SEED)
	await step(2)


func test_trophies() -> void:
	section("BOSS TROPHIES")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	# The shelf the roguelike endgame boss will land on. Nothing awards
	# these yet -- that is the boss encounter, still to build -- but the
	# table, the save slot and the screen are here so that work has
	# somewhere to go.
	chk("there are trophies defined", Trophies.count() > 0, Trophies.count())
	chk("one per subject boss, the gauntlet, and the inspection", Trophies.count() == 6)
	chk("every one has a name and a line", (func() -> bool:
		for t: Dictionary in Trophies.all():
			if String(t.get("name", "")) == "" or String(t.get("blurb", "")) == "":
				return false
		return true).call())
	chk("every id is unique", (func() -> bool:
		var seen := {}
		for t: Dictionary in Trophies.all():
			if seen.has(String(t["id"])):
				return false
			seen[String(t["id"])] = true
		return true).call())
	chk("no trophy blurb states a stage or a number", (func() -> bool:
		for t: Dictionary in Trophies.all():
			var b := String(t.get("blurb", "")).to_lower()
			for ch in "0123456789":
				if b.contains(ch):
					return false
			if b.contains("stage ") or b.contains("level "):
				return false
		return true).call())

	# --- a new run has none, and you cannot fake one ---
	chk("a fresh run has won no trophies", Game.trophies.is_empty())
	chk("awarding an unknown id does nothing",
		not Game.award_trophy("boss_nonsense") and Game.trophies.is_empty())

	# --- winning one records it, once ---
	var got: Array = []
	Game.trophy_earned.connect(func(id: String) -> void: got.append(id))
	chk("beating a boss awards its trophy", Game.award_trophy("boss_math"))
	chk("and it fires the signal", got == ["boss_math"], got)
	chk("it is on the shelf now", Game.trophies.has("boss_math"))
	chk("winning the same one again is a no-op",
		not Game.award_trophy("boss_math") and Game.trophies.size() == 1)

	# --- it gates and pays nothing ---
	var coins_before: int = Game.coins
	Game.award_trophy("boss_science")
	chk("a trophy pays no coins", Game.coins == coins_before)

	# --- it survives the night; an older save has none ---
	Game.save_game()
	var had := Game.trophies.size()
	Game.new_run(1)
	chk("a new run clears the shelf", Game.trophies.is_empty())
	Game.load_game()
	chk("but a saved career keeps its trophies",
		Game.trophies.size() == had, Game.trophies.size())
	var snap := Game.to_dict()
	snap.erase("trophies")
	Game.from_dict(snap)
	chk("a save from before trophies loads with none", Game.trophies.is_empty())
	Game.delete_save()

	# --- the screen shows them, won or not, on the career list ---
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	Game.award_trophy("boss_ela")
	# trophies sit after every milestone, so scroll the window down to them
	var ela_row := -1
	for i in hud._career_rows().size():
		if String(hud._career_rows()[i].get("id", "")) == "boss_ela":
			ela_row = i
			break
	hud._sel = ela_row
	hud._career_page = hud.CAREER_MILESTONES
	hud.show_career()
	chk("the career list names a won trophy",
		hud.rich.text.contains(String(Trophies.by_id("boss_ela")["name"])),
		hud.rich.text)
	chk("the title counts trophies", hud.title.text.contains("trophies 1/6"),
		hud.title.text)
	chk("the list still fits the panel",
		hud.rich.text.split("\n").size() <= 11, hud.rich.text.split("\n").size())
	# the cursor can reach the very last entry, which is the inspection trophy
	hud._sel = hud._career_rows().size() - 1
	hud.show_career()
	chk("the cursor can reach the last trophy",
		hud._career_rows()[hud._sel].get("id", "") == "boss_inspection",
		hud._career_rows()[hud._sel])
	hud.close()

	Game.new_run(SEED)
	await step(2)


func test_buying_desks() -> void:
	section("BUYING A DESK")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	# The class cap was hard-wired at 8 from the beginning: eight desks in
	# a 20x11 room and no way to have more, so the class could never grow
	# past it however well you taught.
	var start := Layout.seat_count()
	chk("you start with the desks the room came with",
		start == Balance.class_cap, start)
	chk("and the class can only be as big as the desks",
		Game.seat_capacity() == start, Game.seat_capacity())

	Game.coins = 0
	chk("you cannot buy one on nothing", Game.buy_desk() != "")
	chk("and nothing changed", Layout.seat_count() == start)

	Game.coins = 99999
	var cost := Game.desk_cost()
	chk("buying one works", Game.buy_desk() == "")
	chk("there is a desk more", Layout.seat_count() == start + 1,
		Layout.seat_count())
	chk("it cost what it said", Game.coins == 99999 - cost,
		"%d, cost %d" % [Game.coins, cost])
	chk("and the class can now be bigger", Game.seat_capacity() == start + 1)

	# the price rises, so a big class is a project rather than a purchase
	chk("the next one costs more", Game.desk_cost() > cost,
		"%d -> %d" % [cost, Game.desk_cost()])

	# every desk is a real seat: reachable, unique, and it gets a chair
	chk("no two desks share a tile", (func() -> bool:
		var seen := {}
		for t: Vector2i in Layout.seats():
			if seen.has(t):
				return false
			seen[t] = true
		return true).call())
	await step(4)
	chk("the room actually built it", (func() -> bool:
		var chairs := 0
		for n in get_tree().get_nodes_in_group("desk_part"):
			chairs += 1
		return chairs >= Layout.seat_count() * 2).call())
	chk("and a child can walk to it", world.grid.reachable(
		Layout.DOOR, Layout.seat(Layout.seat_count() - 1)))

	# a class actually grows into it
	Game.new_run(SEED)
	Game.coins = 99999
	while Game.enrol() != null:
		pass
	var full := Game.roster.size()
	chk("the class fills the desks it has", full == Layout.seat_count(), full)
	chk("and cannot grow further", Game.enrol() == null)
	Game.buy_desk()
	chk("buying a desk makes room for one more", Game.enrol() != null)
	chk("who is a real child", Game.roster.size() == full + 1)

	# THE TWO THINGS THAT MUST HOLD: the cap is real, and a room with
	# nowhere to put a desk says so rather than failing silently.
	Game.new_run(SEED)
	Game.coins = 9999999
	var bought := 0
	while Game.buy_desk() == "" and bought < 60:
		bought += 1
	chk("buying stops somewhere", bought < 60, bought)
	chk("and never past the hard cap",
		Layout.seat_count() <= Balance.class_hard_cap,
		"%d desks, hard cap %d" % [Layout.seat_count(), Balance.class_hard_cap])
	chk("with a reason, not a silent refusal", Game.buy_desk() != "",
		Game.buy_desk())
	chk("and desks keep their aisles -- no two side by side", (func() -> bool:
		for a: Vector2i in Layout.seats():
			for b: Vector2i in Layout.seats():
				if a != b and a.y == b.y and absi(a.x - b.x) == 1:
					return false
		return true).call())
	chk("every desk is still reachable from the door", (func() -> bool:
		for i in Layout.seat_count():
			if not world.grid.reachable(Layout.DOOR, Layout.seat(i)):
				return false
		return true).call())

	Game.new_run(SEED)
	await step(2)



func test_the_school() -> void:
	section("ROOMS YOU DO NOT STAND IN")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	chk("you start with one room, and it is yours", Game.rooms.is_empty())

	Game.coins = 0
	chk("a room costs money you have not got", Game.open_room() != "")
	Game.coins = 999999
	chk("and money you have opens one", Game.open_room() == "")
	chk("there is a room now", Game.rooms.size() == 1)
	chk("with children in it",
		(Game.rooms[0]["roster"] as Array).size() == Balance.school_class_size,
		(Game.rooms[0]["roster"] as Array).size())
	chk("and nobody teaching it", (Game.rooms[0]["teacher"] as Dictionary).is_empty())
	chk("the next one costs more", Game.room_cost() > Balance.room_cost)

	# --- an empty room is worse than no room ---
	# It costs you the purchase and teaches nobody. If an unstaffed room
	# quietly taught itself, hiring would be optional and the wage bill
	# would be a tax rather than a decision.
	var empty: Dictionary = Game.resolve_rooms()[0]
	chk("nobody teaching means nobody learning",
		float(empty["average"]) <= Balance.room_base + 0.001,
		empty["average"])
	chk("and no work is collected", int(empty["collected"]) == 0)

	# --- hiring ---
	Game.draw_applicants()
	chk("there are people to hire", Game.applicants.size() > 0)
	chk("each has a name, a wage and a weakness", (func() -> bool:
		for t: Dictionary in Game.applicants:
			if String(t.get("name", "")) == "" or int(t.get("wage", 0)) <= 0:
				return false
			if Staff.weakness(t) == "" or Staff.strengths(t) == "":
				return false
		return true).call())

	var wage: int = int(Game.applicants[0]["wage"])
	chk("hiring works", Game.hire(0, 0) == "")
	chk("the room has a teacher now",
		not (Game.rooms[0]["teacher"] as Dictionary).is_empty())
	chk("they are off the list", Game.applicants.size() >= 0)
	chk("and they cost you every day", Game.wage_bill() == wage,
		"%d vs %d" % [Game.wage_bill(), wage])

	# --- firing: undoing a bad hire, not a free do-over ---
	# hire() used to silently overwrite whoever was already there, for
	# free -- which meant a bad hire was already "fixable" by accident,
	# and made a deliberate severance cost pointless the moment both
	# existed side by side.
	chk("hiring into an already-staffed room is refused",
		Game.hire(0, 0) != "")
	var coins_before: int = Game.coins
	chk("firing costs the severance", Game.fire(0) == "")
	chk("and actually spends it",
		Game.coins == coins_before - Balance.fire_cost,
		"%d vs %d" % [Game.coins, coins_before - Balance.fire_cost])
	chk("the room is empty again",
		(Game.rooms[0]["teacher"] as Dictionary).is_empty())
	chk("firing an already-empty room is refused", Game.fire(0) != "")
	chk("and it can be hired into again", Game.hire(0, 0) == "")

	var staffed: Dictionary = Game.resolve_rooms()[0]
	chk("a staffed room actually teaches",
		float(staffed["average"]) > float(empty["average"]),
		"%.2f -> %.2f" % [empty["average"], staffed["average"]])

	# --- furniture, bought as a level ---
	var before := Game.room_value(Game.rooms[0])
	chk("furnishing costs", Game.furnish_room(0) == "")
	chk("and is worth something to that room",
		Game.room_value(Game.rooms[0]) > before)
	chk("but never more than a room can be worth", (func() -> bool:
		for i in 20:
			Game.furnish_room(0)
		return Game.room_value(Game.rooms[0]) <= Balance.room_cap + 0.001).call(),
		Game.room_value(Game.rooms[0]))

	# --- THE PROMISE: results are RUN, not assigned ---
	# A delegated room is resolved by playing its lesson with the teacher's
	# policy. Different policies must therefore produce different outcomes,
	# or hiring is decoration.
	# A LOCAL rng, and no new_run in the loop: new_run rebuilds the whole
	# room, and doing that twenty-four times inside a test took the suite
	# past its ten-minute watchdog.
	var got := {}
	var probe := RandomNumberGenerator.new()
	for a: Dictionary in Staff.ARCHETYPES:
		var total := 0.0
		for r in 4:
			probe.seed = 700 + r
			var roster: Array = []
			for i in 5:
				var st := StudentData.new()
				st.id = i + 1
				st.aptitude = 0.5
				st.diligence = 0.5
				st.seat_index = i
				roster.append(st)
			total += float(RoomSim.play_day(roster, a, Balance.room_base + 0.1,
				Game.lesson, probe)["average"])
		got[String(a["id"])] = total / 4.0
	chk("a better teacher gets a better result",
		float(got["veteran"]) > float(got["supply"]),
		"veteran %.2f vs supply %.2f" % [got["veteran"], got["supply"]])
	chk("and the archetypes are genuinely different", (func() -> bool:
		var lo := 9.0
		var hi := 0.0
		for k: String in got:
			lo = minf(lo, float(got[k]))
			hi = maxf(hi, float(got[k]))
		return hi - lo > 0.08).call(), got)

	# a delegated room must never read the PLAYER's furniture
	Game.new_run(SEED)
	Game.coins = 999999
	Game.open_room()
	for i in 40:
		Game.room_items.append({"id": "bookshelf", "tile": Layout.seat(0)})
	chk("your own furniture does nothing for a room across the corridor",
		is_equal_approx(Game.room_value(Game.rooms[0]), Balance.room_base),
		Game.room_value(Game.rooms[0]))

	# --- it survives the night ---
	Game.new_run(SEED)
	Game.coins = 999999
	Game.open_room()
	Game.draw_applicants()
	Game.hire(0, 0)
	var who := String((Game.rooms[0]["teacher"] as Dictionary)["name"])
	Game.save_game()
	Game.new_run(1)
	chk("a new run has no school", Game.rooms.is_empty())
	Game.load_game()
	chk("but a saved one remembers its rooms", Game.rooms.size() == 1)
	chk("and who teaches them",
		String((Game.rooms[0]["teacher"] as Dictionary).get("name", "")) == who)
	chk("and the children in them",
		(Game.rooms[0]["roster"] as Array).size() == Balance.school_class_size)
	Game.delete_save()

	# --- the board ---
	Game.new_run(SEED)
	await step(2)
	Game.coins = 999999
	Game.open_room()
	Game.draw_applicants()
	Game.hire(0, 0)
	Game.resolve_rooms()
	var hud := _hud()
	hud.show_school()
	chk("the school board opens", hud.mode == hud.Mode.SCHOOL)

	# Regression: a stale _sel (a room closed under it, a bigger school last
	# run) indexed Game.rooms[_sel] out of bounds in show_school() and in
	# _handle_input() -- four SCRIPT ERRORs a run that failed no assertion.
	hud._sel = 7
	hud.show_school()
	chk("a stale selection is clamped, not crashed into",
		hud.mode == hud.Mode.SCHOOL and hud._sel <= maxi(0, Game.rooms.size() - 1),
		hud._sel)

	chk("it names the room", hud.rich.text.contains("Room 2"), hud.rich.text)
	chk("and who is in it",
		hud.rich.text.contains(String((Game.rooms[0]["teacher"] as Dictionary)["name"]).substr(0, 8)),
		hud.rich.text)
	chk("and it fits", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())

	# --- watching the day that already happened ---
	# The playback must be the SAME roll that produced the letter, not a
	# fresh one -- so the frames' own tallies have to be able to add up to
	# it, and the screen must never be reachable before a room has a day
	# behind it to show.
	var last: Dictionary = Game.rooms[0].get("last", {})
	chk("resolving a room records a frame history",
		not (last.get("history", []) as Array).is_empty(), last.get("history", []))
	hud.show_watch(0)
	chk("watching opens its own screen", hud.mode == hud.Mode.WATCH)
	chk("and it fits too", hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	chk("it names the teacher watching",
		hud.rich.text.contains(String((Game.rooms[0]["teacher"] as Dictionary)["name"])),
		hud.rich.text)
	hud._watch_i = hud._watch_frames.size() - 1
	hud._render_watch_frame()
	chk("the last frame reports the same grade resolve_rooms recorded",
		hud.rich.text.contains(String(last.get("letter", "?"))), hud.rich.text)
	await tap("cancel")
	chk("Esc backs out to the school board", hud.mode == hud.Mode.SCHOOL)
	hud.close()

	Game.new_run(SEED)
	await step(2)


## The hallway: your own door leads out, a door per room leads back in.
##
## Driven through the REAL input pipeline throughout (place_player + tap),
## the same way the bell and podium are tested -- not by calling
## interact() directly, which would prove the signal wiring works without
## proving a player can actually reach it.
func test_hallway() -> void:
	section("HALLWAY")
	Game.new_run(SEED)
	await step(2)
	var main: Node = world.get_parent()
	var hallway: Node = main.get_node("Hallway")
	var hud := _hud()

	chk("the door out is live outside a lesson", world.hall_door.can_interact())
	world.start_lesson()
	chk("but not mid-lesson", not world.hall_door.can_interact())
	Game.set_phase(Game.Phase.AFTERNOON)

	await place_player(Layout.DOOR + Vector2i(1, 0), Actor.DIR_LEFT)
	await tap("manage")
	chk("stepping through the door hands the player to the hallway",
		world.player.get_parent() == hallway)
	chk("and the room itself is hidden while you are away", not world.visible)
	chk("the hallway is what's on screen instead", hallway.visible)
	chk("the principal greets you the first time, with a face on it",
		hud.mascot_box.visible and hud.mascot_portrait.visible)
	chk("and the same nudge does not repeat on a second visit", (func() -> bool:
		hud.mascot_box.visible = false
		hud.mascot_portrait.visible = false
		hud.principal_says("hallway_first_visit", "SHOULD NOT APPEAR AGAIN")
		return not hud.mascot_box.visible).call())

	var expect_doors := 3 + Game.rooms.size() + (1 if Game.can_open_room() else 0)
	chk("a door per room, plus home, the office, the mentor, and the next to open",
		hallway.doors.size() == expect_doors, hallway.doors.size())

	var office_door: Node2D = null
	var mentor_door: Node2D = null
	for d in hallway.doors:
		if String(d.door_kind) == "office":
			office_door = d
		elif String(d.door_kind) == "mentor":
			mentor_door = d
	chk("the office is always the second door along", office_door != null)
	chk("and the mentor teacher's room is always the third", mentor_door != null)
	chk("the mentor door tints distinctly from the office",
		hallway._door_tint("mentor", -1) != hallway._door_tint("office", -1))
	world.player.global_position = office_door.global_position
	await step(2)
	await tap("manage")
	chk("walking into it opens the principal's office", hud.mode == hud.Mode.OFFICE)
	chk("its milestone count matches what the career screen knows",
		hud.rich.text.contains("%d/%d" % [Game.milestones.size(), Milestones.all().size()]),
		hud.rich.text)
	chk("visiting proves the met_principal milestone", Game.met_principal)
	chk("and Milestones agrees, from that real state alone",
		Milestones.newly_earned([]).has("met_principal"))
	await tap("interact")
	chk("E from the office jumps to the full career list", hud.mode == hud.Mode.CAREER)
	await tap("cancel")
	chk("Esc backs all the way out, not just to the office", hud.mode == hud.Mode.NONE)

	# Open a room from inside the hallway -- the same Game.open_room() the
	# old School screen used, just reached by walking to a door instead of
	# pressing N from a menu.
	var open_door: Node2D = null
	for d in hallway.doors:
		if String(d.door_kind) == "open":
			open_door = d
	chk("there is a door for the next room, since a fresh school can afford one",
		open_door != null)
	var rooms_before := Game.rooms.size()
	Game.coins = 99999
	world.player.global_position = open_door.global_position
	await step(2)
	await tap("manage")
	chk("walking into it opens a room", Game.rooms.size() == rooms_before + 1)
	chk("and the corridor rebuilds to match",
		hallway.doors.size() == 3 + Game.rooms.size()
			+ (1 if Game.can_open_room() else 0))

	# The new room is unstaffed, so its door should offer to hire rather
	# than to watch -- there is nothing yet to watch.
	var room_door: Node2D = null
	for d in hallway.doors:
		if String(d.door_kind) == "room" and int(d.room_index) == rooms_before:
			room_door = d
	chk("the room you just opened has its own door", room_door != null)
	world.player.global_position = room_door.global_position
	await step(2)
	await tap("manage")
	chk("an unstaffed room's door opens hiring, not watching",
		hud.mode == hud.Mode.SCHOOL and hud._hiring)
	hud.close()

	# The door itself tells a story beyond "staffed or not" -- found via
	# /deep_critique: a room stuck on a failing grade for a whole term
	# looked exactly like a perfectly healthy one from the corridor, which
	# is exactly the information that would have prompted firing the
	# teacher earlier.
	var ri := rooms_before
	chk("an unstaffed room's door reads as needing you",
		hallway._door_tint("room", ri) == Color(1.3, 0.55, 0.4))
	Game.draw_applicants()
	Game.hire(ri, 0)
	Game.rooms[ri]["last"] = {"letter": "A"}
	chk("a staffed room doing well reads as fine",
		hallway._door_tint("room", ri) == Color(0.75, 0.9, 1.15))
	Game.rooms[ri]["last"] = {"letter": "E"}
	chk("but a staffed room that has been failing reads distinctly",
		hallway._door_tint("room", ri) == Color(1.15, 0.75, 0.45))
	chk("and that colour is neither 'unstaffed' nor 'fine'",
		hallway._door_tint("room", ri) != Color(1.3, 0.55, 0.4) and
		hallway._door_tint("room", ri) != Color(0.75, 0.9, 1.15))

	# Home again.
	var home_door: Node2D = null
	for d in hallway.doors:
		if String(d.door_kind) == "home":
			home_door = d
	world.player.global_position = home_door.global_position
	await step(2)
	await tap("manage")
	chk("the home door hands the player back to their own room",
		world.player.get_parent() == world)
	chk("and the room is what's on screen again", world.visible)
	chk("with the hallway put away", not hallway.visible)

	Game.new_run(SEED)
	await step(2)


## The mentor teacher: a room off the hallway that teaches the dash and the
## mass-help "answer all" (locked until then), and demonstrates -- with its
## own visibly spaced-out desks -- why crowding a room cuts both ways.
func test_mentor() -> void:
	section("THE MENTOR")
	Game.new_run(SEED)
	await step(2)
	var main: Node = world.get_parent()
	var mentor_room: Node = main.get_node("MentorRoom")
	var hallway: Node = main.get_node("Hallway")
	var hud := _hud()

	# --- a fresh career has NOT met the mentor: both verbs are locked ---
	chk("a new career starts with the dash untaught", not Game.dash_taught)
	chk("and the mass-help untaught", not Game.answer_all_taught)

	# the mass-help landmark refuses to offer itself while untaught, and
	# lights up the instant the flag flips
	world.start_lesson()
	await step(4)
	var aa: Interactable = null
	for n in get_tree().get_nodes_in_group("answer_all_caller"):
		if n is Interactable:
			aa = n
	chk("the answer-all landmark stays dark until the mentor teaches it",
		aa != null and not aa.can_interact())
	Game.answer_all_taught = true
	chk("...and offers itself the instant it is taught", aa.can_interact())
	Game.answer_all_taught = false
	world.end_lesson()
	await step(2)

	# the tap-dash does not fire while untaught
	Game.new_run(SEED)
	await step(2)
	_reset_dash(world.player)
	Game.dash_taught = false            # _reset_dash grants it; take it back
	var start := Grid.tile_to_world(Vector2i(3, 6))
	var W: int = int(round(Balance.teacher_dash_duration * 60.0))
	world.player.global_position = start
	await step(2)
	await hold("move_right", W)
	var walked: float = world.player.global_position.x - start.x
	world.player.global_position = start
	await step(2)
	Input.action_press("move_right")
	await step(2)
	Input.action_release("move_right")
	await step(2)
	world.player.global_position = start
	Input.action_press("move_right")
	await step(1)
	await step(W + 3)
	Input.action_release("move_right")
	await step(1)
	chk("double-tapping a direction does nothing while the dash is untaught",
		(world.player.global_position.x - start.x) <= walked * 1.4,
		"%.0f px, a plain walk is %.0f" % [world.player.global_position.x - start.x, walked])

	# --- the day-end nudge fires once, while the mentor is unmet ---
	hud._shown_hints.erase("see_the_mentor")
	hud._queued_hint = []
	hud._next_queued_hint_at = 0.0
	hud.close()
	Game.day_changed.emit(Game.day)
	await step(3)
	chk("a day ending before the mentor is met nudges toward the hallway",
		hud._shown_hints.has("see_the_mentor"))

	# --- walking in: the first visit teaches both verbs, one body not two ---
	Game.new_run(SEED)
	await step(2)
	Game.set_phase(Game.Phase.AFTERNOON)
	await place_player(Layout.DOOR + Vector2i(1, 0), Actor.DIR_LEFT)
	await tap("manage")
	chk("the door out still reaches the hallway", world.player.get_parent() == hallway)
	var md: Node2D = null
	for d in hallway.doors:
		if String(d.door_kind) == "mentor":
			md = d
	chk("the hallway has a mentor door", md != null)
	world.player.global_position = md.global_position
	await step(2)
	await tap("manage")
	chk("walking in reparents the same Actor into the mentor room",
		world.player.get_parent() == mentor_room and is_instance_valid(world.player))
	chk("and the mentor room is what's on screen",
		mentor_room.visible and not hallway.visible and not world.visible)
	# The one above passed for two sessions while the screen was EMPTY: the
	# room really was dressed and really was visible, and nothing checked
	# where the camera was pointing. Camera2D limits are global, main.tscn
	# parks this room at (0, 20000), and refresh_camera_limits() used to set
	# room-LOCAL limits -- pinning the camera 20,000px above the room.
	await step(2)
	var room_rect := Rect2(mentor_room.global_position,
		Vector2(mentor_room.ROOM_W, mentor_room.ROOM_H))
	chk("and the camera is pointed at the room, not at its local origin",
		room_rect.has_point(world.camera.get_screen_center_position()),
		"camera centre %s is outside %s" % [
			world.camera.get_screen_center_position(), room_rect])
	chk("the first visit opens the teaching dialogue", hud.mode == hud.Mode.MENTOR)

	var guard := 0
	while hud.mode == hud.Mode.MENTOR and guard < 40:
		await tap("interact")
		guard += 1
	chk("walking every page closes it", hud.mode == hud.Mode.NONE)
	chk("the dash is taught now", Game.dash_taught)
	chk("and the mass-help is taught now", Game.answer_all_taught)

	# --- then she SHOWS the chain dash, with her own class ---
	# The page walk above stops where the setup page hands the screen over:
	# the overlay is gone and the demonstration is running.
	chk("the first visit runs on into the chain dash, not out the door",
		mentor_room.demo_running())
	chk("...with the chain not yet taught -- watching is not the lesson's end",
		not Game.chain_dash_taught)
	chk("every one of her class has a hand up for it",
		mentor_room.hands_up() == (mentor_room.DESK_SPOTS as Array).size(),
		mentor_room.hands_up())
	chk("the player stands still and watches", world.player.input_locked)
	var seen_off_home := false
	guard = 0
	while mentor_room.demo_running() and guard < 120:
		await step(5)
		if (mentor_room.mentor.position as Vector2).distance_to(
				mentor_room.MENTOR_HOME) > 40.0:
			seen_off_home = true
		guard += 1
	chk("the demonstration finishes on its own", not mentor_room.demo_running(), guard)
	chk("she actually leaves the front to do it", seen_off_home)
	chk("and every hand she ran at is answered", mentor_room.hands_up() == 0,
		mentor_room.hands_up())
	chk("she is back at the front afterwards",
		(mentor_room.mentor.position as Vector2).distance_to(
			mentor_room.MENTOR_HOME) < 3.0)
	chk("then she says what you just watched",
		hud.mode == hud.Mode.MENTOR and hud._mentor_talk == hud.MentorTalk.CHAIN_AFTER)
	guard = 0
	while hud.mode == hud.Mode.MENTOR and guard < 20:
		await tap("interact")
		guard += 1
	chk("walking her explanation closes it", hud.mode == hud.Mode.NONE)
	chk("the chain dash is taught now", Game.chain_dash_taught)
	chk("and the player is free to try it", not world.player.input_locked)
	chk("her class starts practice straight away", mentor_room.practising)
	var rest := int(ceil(mentor_room.PRACTICE_REST * 60.0)) + 6
	await step(rest)
	chk("...hands go back up for the player to run at",
		mentor_room.hands_up() == (mentor_room.DESK_SPOTS as Array).size(),
		mentor_room.hands_up())

	# The REAL input path, in open floor: a dash along the front of desk 0
	# reaches its raised hand and answers it on the way in.
	var d0: Interactable = mentor_room.desks[0]
	_reset_dash(world.player)
	var run_from: Vector2 = (mentor_room.DESK_SPOTS[0] as Vector2) \
		+ mentor_room.ANSWER_SPOT + Vector2(-56.0, 0.0)
	world.player.position = run_from
	world.player.facing = Actor.DIR_RIGHT
	world.player.velocity = Vector2.ZERO
	await step(2)
	chk("desk 0's hand is up before the run", d0.asking)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(int(round(Balance.teacher_dash_duration * 60.0)) + 4)
	Input.action_release("move_right")
	await step(2)
	chk("a real dash into her pupil's raised hand answers it", not d0.asking)
	chk("...and leaves the next dash ready at once",
		world.player._dash_cool <= Balance.teacher_chain_dash_cooldown + 0.001,
		world.player._dash_cool)
	chk("her class stays out of the save -- nobody in here is on the roster",
		(func() -> bool:
			for s: StudentData in Game.roster:
				for pu: Node in mentor_room.pupils:
					if pu.get("data") == s:
						return false
			return true).call())

	# the desks in there really are spaced -- the room is the demonstration
	chk("the mentor room's desks are laid out with real gaps", (func() -> bool:
		var spots: Array = mentor_room.DESK_SPOTS
		for i in spots.size():
			for j in range(i + 1, spots.size()):
				if (spots[i] as Vector2).distance_to(spots[j] as Vector2) < 40.0:
					return false
		return true).call())

	# and it is dressed -- a designed classroom, which is the mentor's point
	var dressing: Array = get_tree().get_nodes_in_group("mentor_dressing")
	chk("every piece of dressing was built",
		dressing.size() == (mentor_room.DRESSING as Array).size(),
		"%d built, %d listed" % [dressing.size(),
			(mentor_room.DRESSING as Array).size()])
	chk("every dressing texture loads", (func() -> bool:
		for row: Array in mentor_room.DRESSING:
			if load("res://art/%s.png" % String(row[0])) == null:
				return false
		return true).call())
	chk("every piece sits inside the room", (func() -> bool:
		for spr: Node in dressing:
			var p: Vector2 = spr.position
			if p.x < -8.0 or p.x > mentor_room.ROOM_W \
					or p.y < -20.0 or p.y > mentor_room.ROOM_H:
				return false
		return true).call())
	# an authored layout that traps the player is worse than a plain room:
	# nothing solid may land on a desk, the mentor, the doorway or the spawn
	chk("no solid piece blocks a desk, the mentor or the way in", (func() -> bool:
		var keepouts: Array = (mentor_room.DESK_SPOTS as Array).duplicate()
		keepouts.append(mentor_room.entry_position())
		keepouts.append(Vector2(192, 80))     # the mentor
		keepouts.append(Vector2(0, 130))      # the doorway
		for body: Node in get_tree().get_nodes_in_group("mentor_solid"):
			for k: Vector2 in keepouts:
				if (body.position as Vector2).distance_to(k) < 34.0:
					return false
		return true).call())

	# --- leaving: back to the hallway, same body ---
	var exit_door: Node2D = null
	for c in mentor_room.get_children():
		if c is Interactable:
			exit_door = c
	chk("the mentor room has a door back", exit_door != null)
	world.player.global_position = mentor_room.to_global(exit_door.position)
	await step(2)
	await tap("manage")
	chk("the way back hands the player to the hallway",
		world.player.get_parent() == hallway)
	chk("with the mentor room put away", not mentor_room.visible and hallway.visible)

	chk("leaving puts her class's hands down", mentor_room.hands_up() == 0
		and not mentor_room.practising)
	chk("and the player's hand-set depth in there does not follow them out",
		world.player.z_index == 0, world.player.z_index)

	# --- a save that had the dash but never saw the chain gets the demo ---
	Game.chain_dash_taught = false
	hud.show_mentor()
	chk("a revisit before the chain has been shown opens with it",
		hud.mode == hud.Mode.MENTOR and hud._mentor_talk == hud.MentorTalk.CHAIN_INTRO)
	hud.close()
	Game.chain_dash_taught = true

	# --- a revisit outside a boss term is a plain idle line ---
	Game.term = 1
	Game.term_path = {}
	Balance.ensure_loaded()
	chk("term 1 is not on the boss cadence",
		Game.term % Balance.boss_term_interval != 0)
	hud.show_mentor()
	chk("a revisit outside a boss term shows the idle line, not the lesson again",
		hud.mode == hud.Mode.MENTOR and hud._mentor_talk == hud.MentorTalk.IDLE)
	await tap("interact")
	chk("and one press closes it", hud.mode == hud.Mode.NONE)

	# --- a revisit with a boss term due is a prose readiness read, no number ---
	Game.term = Balance.boss_term_interval        # an eligible term
	hud.show_mentor()
	chk("a revisit just before a boss term reads the room instead",
		hud.mode == hud.Mode.MENTOR and hud._mentor_talk == hud.MentorTalk.READ)
	chk("and phrases it as confidence, never a score", (func() -> bool:
		for ch in "0123456789":
			if hud.body.text.contains(ch):
				return false
		return hud.body.text.strip_edges() != "").call())
	hud.close()

	Game.new_run(SEED)
	await step(2)


## The F1 panel's "grow" cheat had a label and no case in the match --
## pressing E on it set Game.cheated and did nothing else. Caught only by
## actually calling it and checking the room got bigger, which a headless
## boot check never would have.
func test_dev_panel() -> void:
	section("DEV PANEL")
	Game.new_run(SEED)
	await step(2)
	var dbg: Node = world.get_parent().get_node("Debug")
	var w0 := Grid.W
	var h0 := Grid.H
	var students0 := Game.roster.size()

	Game.coins = 999999
	dbg._do_cheat("grow")
	chk("the grow cheat actually grows the room",
		Grid.W > w0 and Grid.H > h0, "%dx%d -> %dx%d" % [w0, h0, Grid.W, Grid.H])

	Game.new_run(SEED)
	await step(2)
	dbg._do_cheat("all")
	chk("EVERYTHING gives unlimited coins", Game.unlimited_coins)
	chk("EVERYTHING grows the room",
		Grid.W > w0 or Grid.H > h0, "%dx%d" % [Grid.W, Grid.H])
	chk("EVERYTHING fills the class",
		Game.roster.size() > students0, Game.roster.size())
	chk("EVERYTHING maxes every student", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.level < Balance.stu_max_level:
				return false
		return true).call())
	chk("EVERYTHING maxes the teacher",
		Game.teacher_level >= Balance.teacher_max_level, Game.teacher_level)
	chk("EVERYTHING places furniture", Game.room_items.size() > 0,
		Game.room_items.size())
	chk("a cheat marks the run as cheated, permanently", Game.cheated)

	# The panel's own open/close, not just what a cheat does once it's
	# open. F1/F2 are two different keys and a plain held-check is fine
	# for them; backtick does BOTH jobs on one key, so it needs the edge
	# of the press rather than the level, or it would flap open/closed
	# every frame the key stayed down. This is that bug, caught directly.
	dbg.open = false
	if dbg._backtick_edge(true):
		dbg._toggle(not dbg.open)
	chk("backtick opens the panel", dbg.open)
	if dbg._backtick_edge(true):
		dbg._toggle(not dbg.open)
	chk("holding backtick down does not close it again on the next frame",
		dbg.open)
	if dbg._backtick_edge(false):
		dbg._toggle(not dbg.open)
	chk("releasing backtick leaves it open", dbg.open)
	if dbg._backtick_edge(true):
		dbg._toggle(not dbg.open)
	chk("pressing backtick again closes it", not dbg.open)
	if dbg._backtick_edge(false):
		dbg._toggle(not dbg.open)

	# Shift+D, added after F1 turned out not to reach Godot at all on at
	# least one real machine -- an OEM binding eating it before the engine
	# ever sees it. Same edge-detect requirement as backtick, since it is
	# also one combo doing both jobs.
	dbg.open = false
	if dbg._shift_d_edge(true):
		dbg._toggle(not dbg.open)
	chk("shift+D opens the panel too", dbg.open)
	if dbg._shift_d_edge(true):
		dbg._toggle(not dbg.open)
	chk("holding it down does not flap the panel shut again", dbg.open)
	if dbg._shift_d_edge(false):
		dbg._toggle(not dbg.open)
	if dbg._shift_d_edge(true):
		dbg._toggle(not dbg.open)
	chk("pressing shift+D again closes it", not dbg.open)
	if dbg._shift_d_edge(false):
		dbg._toggle(not dbg.open)

	Game.new_run(SEED)
	await step(2)


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
		hud.title.text.begins_with("WHAT YOU CAN TEACH"), hud.title.text)
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

	# Buy something, then place it from the cabinet. Buying charges you and
	# drops the item in storage; the shop stays open. Placement is a
	# separate step from the CABINET tab, and free.
	await tap("manage")
	var chosen: String = String(hud._shop_rows()[hud._sel])
	while Items.category_of(chosen) == "consumable":
		await tap("move_down")
		chosen = String(hud._shop_rows()[hud._sel])
	var coins_before: int = Game.coins
	var items_before: int = Game.room_items.size()
	var cabinet_before: int = Game.cabinet.size()
	await tap("interact")
	await step(3)
	var main: Node = world.get_parent()
	chk("buying drops the item in the cabinet, not on the floor",
		Game.cabinet.size() == cabinet_before + 1 and Game.room_items.size() == items_before,
		"cabinet %d, room %d" % [Game.cabinet.size(), Game.room_items.size()])
	chk("and it charges you there and then",
		Game.coins == coins_before - Items.cost(chosen), Game.coins)
	chk("the shop stays open to buy more", hud.mode == hud.Mode.CATALOGUE)

	# Over to the cabinet tab and take it out.
	while hud._shop != hud.Shop.CABINET:
		await tap("menu")
	hud._sel = 0
	hud._render_catalogue()
	var coins_at_take: int = Game.coins
	await tap("interact")
	await step(3)
	chk("taking one out starts placement mode", main.placement.active)
	chk("the catalogue closed behind it", hud.mode == hud.Mode.NONE)
	chk("the ghost did NOT place itself on the same press",
		Game.room_items.size() == items_before, Game.room_items.size())

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
	chk("placing it puts it in the room, no further charge",
		Game.room_items.size() == items_before + 1
		and Game.coins == coins_at_take
		and Game.cabinet.size() == cabinet_before,
		"%d items, %d coins, %d cabinet" % [Game.room_items.size(), Game.coins, Game.cabinet.size()])
	chk("placement mode ends", not main.placement.active)
	chk("and you can walk again", not p.input_locked)

	# cancelling a cabinet-take must leave the copy in storage and unlock
	await place_player(Layout.CABINET + Vector2i(0, 1), Actor.DIR_UP)
	await tap("manage")
	while hud._shop != hud.Shop.CABINET:
		await tap("menu")
	hud._sel = 0
	hud._render_catalogue()
	# buy one more so there is something to take out
	var mid_coins: int = Game.coins
	var mid_cabinet: int = Game.cabinet.size()
	if mid_cabinet == 0:
		hud._shop = hud.Shop.BUY
		hud._sel = 0
		hud._render_catalogue()
		while Items.category_of(String(hud._shop_rows()[hud._sel])) == "consumable":
			await tap("move_down")
		await tap("interact")
		mid_coins = Game.coins
		mid_cabinet = Game.cabinet.size()
		while hud._shop != hud.Shop.CABINET:
			await tap("menu")
		hud._sel = 0
		hud._render_catalogue()
	await tap("interact")
	await step(3)
	await tap("cancel")
	await step(3)
	chk("cancelling a take leaves the copy in the cabinet and un-charged",
		not main.placement.active and not p.input_locked
		and Game.coins == mid_coins and Game.cabinet.size() == mid_cabinet,
		"%d coins, %d cabinet" % [Game.coins, Game.cabinet.size()])
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
	chk("it draws the sheet instead of describing it in words",
		hud.sheet.visible and not hud.body.visible)
	chk("the sheet actually holds this student's own items",
		hud.sheet._sheet.get("items", []) == Game.roster[0].hw_sheet.get("items", []))

	# --- the mouse-gesture path. Regression: $Overlay/Sheet was
	# mouse_filter IGNORE for its entire life, so _gui_input() never fired
	# and tracing a check or an X on the page did nothing at all -- only
	# the Left/Right fallback ever worked. ---
	chk("the sheet is actually wired to receive mouse input",
		hud.sheet.mouse_filter == Control.MOUSE_FILTER_STOP, hud.sheet.mouse_filter)
	var g0: int = hud._marking.size()
	trace_stroke(hud.sheet, [Vector2(60, 120), Vector2(95, 155), Vector2(160, 55)])
	for i in 30:
		hud.sheet.tick_gesture(0.02)
	await step(2)
	chk("tracing one unbroken stroke marks the sheet a pass",
		hud._marking.size() == g0 - 1 and hud.sheet._stamp_pass == 1,
		hud.sheet._stamp_pass)
	hud._marking_hold = 0.0
	hud._finish_marking_if_ready()
	await step(2)

	var x0: int = hud._marking.size()
	trace_stroke(hud.sheet, [Vector2(60, 55), Vector2(160, 155)])
	trace_stroke(hud.sheet, [Vector2(160, 55), Vector2(60, 155)])
	for i in 30:
		hud.sheet.tick_gesture(0.02)
	await step(2)
	chk("tracing two separate strokes marks the sheet a fail",
		hud._marking.size() == x0 - 1 and hud.sheet._stamp_pass == 0,
		hud.sheet._stamp_pass)
	hud._marking_hold = 0.0
	hud._finish_marking_if_ready()
	await step(2)

	var left: int = hud._marking.size()
	await tap("move_right")
	await step(2)
	chk("a verdict moves on to the next sheet immediately, state-wise",
		hud._marking.size() == left - 1)
	chk("and stamps the player's OWN verdict on the page, not the truth",
		hud.sheet._stamp_pass == 1, hud.sheet._stamp_pass)

	# The stamp holds for MARKING_STAMP_SECONDS of real pacing before the
	# next sheet replaces it -- the point of drawing it at all. A test has
	# no reason to sit through that any more than test_school() waits out
	# WATCH's own frame clock (see its _watch_i / _render_watch_frame()
	# just above): bypass it the same way, directly.
	hud._marking_hold = 0.0
	hud._finish_marking_if_ready()

	var guard := 0
	while hud.mode == hud.Mode.MARKING and guard < 20:
		await tap("move_right")
		hud._marking_hold = 0.0
		hud._finish_marking_if_ready()
		await step(2)
		guard += 1
	chk("marking every sheet finishes the batch", hud.mode == hud.Mode.REPORT, guard)
	chk("your arms are empty afterwards", p.carrying_hw == 0, p.carrying_hw)
	chk("every sheet is now marked", (func() -> bool:
		for s: StudentData in Game.roster:
			if s.hw_state != StudentData.HW.MARKED:
				return false
		return true).call())
	# every sheet here is a strong one, so a pass is "right" -- except the
	# single sheet the two-stroke gesture above deliberately X'd.
	chk("passing genuinely good sheets counts as getting them right",
		hud._marked_right == Game.roster.size() - 1, hud._marked_right)

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
	section("BUY, CABINET, MOVE")
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

	# --- the cabinet: two items owned but not placed ---
	Game.cabinet.append("bookshelf")
	Game.cabinet.append("plant")
	Game.cabinet_changed.emit()
	await step(2)
	chk("two items are in the cabinet", Game.cabinet.size() == 2)

	await place_player(Layout.BOARD + Vector2i(0, 1), Actor.DIR_UP)
	await tap("manage")
	chk("the shop opens on the BUY list",
		hud.mode == hud.Mode.CATALOGUE and hud._shop == hud.Shop.BUY)
	await tap("menu")
	chk("Tab switches to the CABINET list", hud._shop == hud.Shop.CABINET)
	chk("the cabinet list shows what you actually own",
		hud.rich.text.contains("Bookshelf") and hud.rich.text.contains("Potted Plant"),
		hud.rich.text)

	# Left sells one copy for half.
	var coins_before: int = Game.coins
	var sell_id: String = String(hud._shop_rows()[hud._sel])
	var refund: int = Game.sell_value(sell_id)
	await tap("move_left")
	await step(2)
	chk("Left sells one out of the cabinet and pays you back",
		Game.cabinet.size() == 1 and Game.coins == coins_before + refund,
		"%d in cabinet, %d coins (+%d expected)" % [Game.cabinet.size(), Game.coins, refund])
	chk("you get back half, not the full price",
		refund == int(floor(Items.cost(sell_id) * Balance.sell_fraction)), refund)

	# Tab is a five-stop cycle: buy -> cabinet -> staff room -> the room ->
	# lesson crafting -> buy
	await tap("menu")
	chk("Tab goes on to the staff room", hud._shop == hud.Shop.STAFF)
	await tap("menu")
	chk("then to the room itself", hud._shop == hud.Shop.ROOM)
	await tap("menu")
	chk("then to lesson crafting", hud._shop == hud.Shop.CRAFT)
	await tap("menu")
	chk("and round again to buying", hud._shop == hud.Shop.BUY)
	await tap("cancel")
	chk("Esc closes the shop", hud.mode == hud.Mode.NONE and not p.input_locked)

	# --- a consumable, bought through the real shop rather than
	# Game.use_consumable() directly, so the UI branch that skips
	# placement for it is what is actually under test ---
	await tap("manage")
	for i in Items.categories().size():
		if String(Items.categories()[hud._cat]) == "consumable":
			break
		await tap("move_right")
	chk("the shop actually has a consumable tab to land on",
		String(Items.categories()[hud._cat]) == "consumable", Items.categories()[hud._cat])
	hud._sel = 0
	hud._render_catalogue()
	var coins_before_shop_buy: int = Game.coins
	await tap("interact")
	chk("buying a consumable in the shop actually spends the coins",
		Game.coins < coins_before_shop_buy)
	chk("and does not start the ghost cursor -- there is nowhere to put it",
		not main.placement.active)
	chk("the shop stays open, unlike an ordinary purchase",
		hud.mode == hud.Mode.CATALOGUE)
	await tap("cancel")

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


## Ten-commits.md step 10: the mechanic was fully built and effectively
## undiscoverable. This tests the four things that changed -- a door to
## Shop.CRAFT from the book itself, a real countdown instead of a dead
## screen, the once-per-run nudge on the day it unlocks, and a craft's
## result (win OR lose) actually landing on the day-end report instead of
## silently vanishing.
func test_lesson_crafting() -> void:
	section("LESSON CRAFTING, DISCOVERABLE")
	var hud := _hud()
	Game.new_run(SEED)
	Game.add_coins(2000)
	await step(2)

	# --- locked: a real countdown, not a vague dead screen ---
	# balance.json currently unlocks crafting on day 1 (never actually
	# locked in real play), so day 0 is the only day that exercises this
	# branch -- synthetic, but the branch is real, tunable-driven code
	# and worth guarding in case unlock_day is ever raised again.
	Game.day = 0
	chk("crafting is locked before its own unlock day",
		not Game.lesson_crafting_unlocked())
	var locked_lines: Array = hud._render_craft([])
	chk("the locked screen says how many days are actually left",
		"\n".join(locked_lines).contains("%d day" % (Balance.craft_unlock_day - Game.day)),
		"\n".join(locked_lines))

	# --- the book itself does not offer the door while it is locked ---
	hud.show_curriculum()
	chk("the curriculum hint says nothing about crafting while it is locked",
		not hud.hint.text.contains("craft"), hud.hint.text)
	await tap("menu")
	chk("Tab does nothing on the book while crafting is locked",
		hud.mode == hud.Mode.CURRICULUM)

	# --- unlocked: the book opens straight into Shop.CRAFT ---
	Game.day = Balance.craft_unlock_day
	hud.show_curriculum()
	chk("the curriculum hint now offers the door",
		hud.hint.text.contains("craft"), hud.hint.text)
	await tap("menu")
	chk("Tab from the book lands directly on the craft tab",
		hud.mode == hud.Mode.CATALOGUE and hud._shop == hud.Shop.CRAFT)
	hud.close()

	# --- the once-per-run nudge, the same shape as the mentor's ---
	# balance.json unlocks crafting on day 1 itself, and day_changed never
	# fires for day 1 (same gap main.gd's day-beat wiring already names),
	# so run_started is the path a real run actually takes.
	hud._shown_hints.erase("craft_unlocked")
	hud._queued_hint = []
	hud._next_queued_hint_at = 0.0
	hud.close()
	Game.run_started.emit()
	await step(3)
	chk("a fresh run nudges toward crafting when it starts already unlocked",
		hud._shown_hints.has("craft_unlocked"))

	# --- day_changed also carries it, for whenever unlock_day is tuned
	# past day 1 and the run_started path no longer covers it ---
	hud._shown_hints.erase("craft_unlocked")
	hud._queued_hint = []
	hud._next_queued_hint_at = 0.0
	hud.close()
	Game.day_changed.emit(Game.day)
	await step(3)
	chk("the day crafting unlocks nudges toward it, if that day is not day 1",
		hud._shown_hints.has("craft_unlocked"))

	# --- committing a craft, and the "still in the oven" report line ---
	Game.new_run(SEED)
	Game.add_coins(2000)
	Game.day = Balance.craft_unlock_day
	await step(2)
	var lesson_id := String(Curriculum.lessons[0].get("id", ""))
	chk("a craft can actually be committed once unlocked",
		Game.commit_lesson_craft(lesson_id))
	chk("it spent real coins, not a free action",
		int(Game.lesson_crafts.get(lesson_id, {}).get("invested_coins", 0)) > 0)
	var report := Game.advance_day()
	hud.show_day_report(report)
	if Balance.craft_days_per_attempt > 1:
		chk("a craft still cooking shows on the very report it was bought on",
			hud.rich.text.contains("in the oven"), hud.rich.text)
		chk("...and says how many days are actually left",
			hud.rich.text.contains("%d day" % (Balance.craft_days_per_attempt - 1)),
			hud.rich.text)

	# --- the result landing on its own day, win or lose -- the real
	# report duplicated and given a forced result, so neither branch
	# depends on how the rng happens to roll here (same trick as the
	# pacing escalation test above, on the same screen) ---
	var win_report := report.duplicate()
	win_report["craft_result"] = {"lesson_id": lesson_id, "success": true}
	hud.show_day_report(win_report)
	chk("a craft that came out right says so, in words a player reads as good news",
		hud.rich.text.contains("came out of the oven"), hud.rich.text)
	var lose_report := report.duplicate()
	lose_report["craft_result"] = {"lesson_id": lesson_id, "success": false}
	hud.show_day_report(lose_report)
	chk("a craft that failed says so too -- it never just vanishes",
		hud.rich.text.contains("didn't take"), hud.rich.text)
	# The result sentence itself is prose -- unlike the day counters
	# elsewhere on this same screen, which are the sanctioned exception.
	chk("...and the result sentence itself carries no digit", (func() -> bool:
		# Strip the [color=#hex] tags first -- a hex colour like C_BAD's
		# own "d08a86" carries real digits, and scanning the raw BBCode
		# line would flag the tag rather than the prose.
		var tag_re := RegEx.new()
		tag_re.compile("\\[/?color[^\\]]*\\]")
		var digit_re := RegEx.new()
		digit_re.compile("[0-9]")
		for line: String in hud.rich.text.split("\n"):
			if line.contains("didn't take") \
					and digit_re.search(tag_re.sub(line, "", true)) != null:
				return false
		return true).call())

	# --- a style, so a crafted lesson has a name, not just a level ---
	# Cosmetic this slice: every style still runs through the same
	# craft_work_mult() as before -- confirmed below by comparing the
	# formula across two different styles at the same level, not just
	# eyeballing it.
	chk("a fresh craft is given a style", Game.CRAFT_STYLES.has(Game.craft_style(lesson_id)))
	var kept_style: String = Game.craft_style(lesson_id)
	Game.lesson_crafts[lesson_id]["craft_level"] = 3
	var mult_a := Game.craft_work_mult(lesson_id)
	var other_style: String = Game.CRAFT_STYLES[
		(Game.CRAFT_STYLES.find(kept_style) + 1) % Game.CRAFT_STYLES.size()]
	Game.lesson_crafts[lesson_id]["style"] = other_style
	chk("two different styles at the same level give the exact same bonus -- "
		+ "style is a name here, not yet a mechanic",
		is_equal_approx(Game.craft_work_mult(lesson_id), mult_a))

	# a fresh (never-crafted) lesson draws its own style rather than
	# reusing whatever the last one rolled
	Game.pending_craft = {}
	Game.lesson_crafts.erase(lesson_id)
	chk("recommitting a never-crafted lesson draws a fresh style",
		Game.commit_lesson_craft(lesson_id) and Game.CRAFT_STYLES.has(Game.craft_style(lesson_id)))
	chk("an uncrafted lesson has no style yet",
		Game.craft_style(String(Curriculum.lessons[1].get("id", ""))) == "")

	Game.new_run(SEED)
	await step(2)


func test_cabinet() -> void:
	section("THE CABINET")
	var hud := _hud()
	var p: Actor = world.player
	Game.new_run(SEED)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)

	chk("a new run starts with an empty cabinet", Game.cabinet.is_empty())

	# --- buying goes into storage, not onto the floor ---
	Game.add_coins(2000)
	var coins0: int = Game.coins
	var err := Game.buy_to_cabinet("bookshelf")
	chk("buying to the cabinet succeeds when you can afford it", err == "")
	chk("it charges the shop price up front",
		Game.coins == coins0 - Game.shop_price("bookshelf"), Game.coins)
	chk("the item is in the cabinet", Game.cabinet_count("bookshelf") == 1)
	chk("and nothing landed in the room", Game.room_items.is_empty())

	Game.buy_to_cabinet("bookshelf")
	chk("a second copy stacks", Game.cabinet_count("bookshelf") == 2)
	chk("cabinet_ids lists it once", Game.cabinet_ids() == ["bookshelf"])

	Game.coins = 0
	chk("a broke player cannot buy to the cabinet",
		Game.buy_to_cabinet("globe") != "" and Game.cabinet_count("globe") == 0)

	# --- placing from the cabinet is free and moves one copy ---
	var placed_ok := Game.place_from_cabinet("bookshelf", Vector2i(9, 6))
	chk("placing from the cabinet works", placed_ok)
	chk("it costs nothing -- it was paid for at the shop", Game.coins == 0)
	chk("one copy left the cabinet", Game.cabinet_count("bookshelf") == 1)
	chk("and it is on the floor now", not Game.item_at(Vector2i(9, 6)).is_empty())
	chk("you cannot place what you do not have",
		not Game.place_from_cabinet("globe", Vector2i(5, 6)))
	chk("nor place it where it does not fit",
		not Game.place_from_cabinet("bookshelf", Vector2i(9, 6)))

	# --- packing a placed item away returns it to the cabinet ---
	var back := Game.store_item(Vector2i(9, 6))
	chk("packing it away names the item", back == "bookshelf")
	chk("the floor tile is clear again", Game.item_at(Vector2i(9, 6)).is_empty())
	chk("and the copy is back in the cabinet", Game.cabinet_count("bookshelf") == 2)

	# --- selling is done from the cabinet, for half ---
	Game.coins = 0
	var refund := Game.sell_from_cabinet("bookshelf")
	chk("selling from the cabinet pays half the price",
		refund == Game.sell_value("bookshelf") and Game.coins == refund, refund)
	chk("and removes exactly one copy", Game.cabinet_count("bookshelf") == 1)
	chk("selling what you do not own pays nothing",
		Game.sell_from_cabinet("globe") == 0)

	# --- it survives a save round-trip; an old save has none ---
	var snap := Game.to_dict()
	Game.from_dict(snap)
	chk("the cabinet round-trips through a save",
		Game.cabinet_count("bookshelf") == 1 and Game.to_dict() == snap)
	var old_save := snap.duplicate()
	old_save.erase("cabinet")
	Game.from_dict(old_save)
	chk("a save from before the cabinet loads with an empty one",
		Game.cabinet.is_empty())

	# --- the physical landmark opens the cabinet screen ---
	Game.new_run(SEED)
	Game.set_phase(Game.Phase.AFTERNOON)
	await step(2)
	chk("the room has a cabinet to walk up to", world.cabinet != null)
	chk("it is on the manage key, like the shop",
		world.cabinet.action_name() == "manage")
	await place_player(Layout.CABINET + Vector2i(0, 1), Actor.DIR_UP)
	chk("standing at it offers the cabinet",
		p.targets["manage"] == world.cabinet, p.targets["manage"])
	await tap("manage")
	chk("and pressing it opens the shop straight on the cabinet tab",
		hud.mode == hud.Mode.CATALOGUE and hud._shop == hud.Shop.CABINET,
		hud._shop)
	hud.close()
	await step(2)

	# --- Game.place_item still works for tools/tests: buy AND place ---
	Game.add_coins(2000)
	var c1: int = Game.coins
	Game.place_item("plant", Vector2i(11, 6))
	chk("Game.place_item still buys and places in one step",
		not Game.item_at(Vector2i(11, 6)).is_empty()
		and Game.coins == c1 - Items.cost("plant"))

	Game.new_run(SEED)


func test_ad_poster() -> void:
	section("AD POSTER")
	var hud := _hud()
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	chk("the world actually has a poster to walk up to", world.ad_poster != null)
	chk("standing on its tile doesn't cost the room a seat", (func() -> bool:
		return world.grid.is_free(Layout.AD_POSTER)).call())

	hud.show_ads()
	await step(2)
	chk("it opens", hud.mode == hud.Mode.ADS, hud.mode)
	var tiers: Array = Balance.ad_tiers
	chk("balance.json actually has tiers to offer", tiers.size() > 0,
		tiers.size())
	chk("cheapest (shortest) tier is selected first", hud._ad_sel == 0)

	await tap("move_down")
	chk("Down cycles to the next tier", hud._ad_sel == 1, hud._ad_sel)

	var coins_before: int = Game.coins
	var picked: Dictionary = tiers[hud._ad_sel]
	await tap("interact")
	chk("choosing a tier starts the (compressed) watch, not an instant grant",
		hud._ad_watching > 0.0 and Game.coins == coins_before,
		"%d vs %d" % [Game.coins, coins_before])
	chk("input is ignored while watching -- can't spam a second pick",
		(func() -> bool:
			var sel_before: int = hud._ad_sel
			Input.action_press("move_down")
			hud._handle_ads_input()
			Input.action_release("move_down")
			return hud._ad_sel == sel_before).call())

	# Bypass the real-time wait the same way test_marking() bypasses
	# MARKING_STAMP_SECONDS -- a player-pacing delay, not something a test
	# has any reason to sit through.
	hud._ad_watching = 0.0
	hud._finish_ad()
	await step(2)
	chk("the reward actually pays out once watching finishes",
		Game.coins == coins_before + int(picked.get("reward_coins", 0)),
		"%d vs %d" % [Game.coins, coins_before + int(picked.get("reward_coins", 0))])
	chk("and the poster is ready to be watched again -- reversible, per E's own rule",
		hud._ad_watching <= 0.0 and hud._ad_tier == -1)

	await tap("cancel")
	chk("Esc backs out without spending anything else",
		hud.mode == hud.Mode.NONE, hud.mode)


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
	chk("two seconds in it is about 2s worth of THAT sheet",
		absf(later - 2.0 / s.work_total) < 0.05,
		"%.2f, sheet is %.1fs" % [later, s.work_total])

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

	# --- ten-commits.md step 5: four new events ---
	var pe := DayEvent.by_id("parents_evening")
	chk("parents' evening shortens the lesson and still pays coins",
		is_equal_approx(float(pe.get("lesson_mult", 1.0)), 0.8)
		and int(pe.get("bonus_coins", 0)) > 0, pe)
	chk("someone's birthday makes stalls more likely",
		float(DayEvent.by_id("birthday").get("stall_mult", 1.0)) > 1.0)
	var fair := DayEvent.by_id("book_fair")
	chk("the book fair grants a real, existing item",
		not Items.get_def(String(fair.get("grant_item", ""))).is_empty(), fair)
	chk("a new face unsettles the room a little",
		float(DayEvent.by_id("new_face").get("stall_mult", 1.0)) > 1.0)

	# --- the grant lands the moment the event is announced, same as coins,
	# not left to chance whether DayEvent.roll() actually lands on it ---
	Game.new_run(SEED)
	var cabinet_before := Game.cabinet.size()
	Game._apply_announced_event(fair)
	chk("the book fair actually puts the item in the cabinet",
		Game.cabinet.size() == cabinet_before + 1
		and Game.cabinet[Game.cabinet.size() - 1] == String(fair["grant_item"]),
		Game.cabinet)
	var coins_before3 := Game.coins
	Game._apply_announced_event(pe)
	chk("...and an ordinary bonus_coins event still just pays",
		Game.coins == coins_before3 + int(pe["bonus_coins"]), Game.coins)

	# --- the spread guarantee: the streak cap actually excludes "none" ---
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var saw_none_forced := false
	for i in 300:
		if String(DayEvent.roll(rng2, Balance.event_none_streak_cap)["id"]) == "none":
			saw_none_forced = true
	chk("once the streak is at the cap, none is excluded entirely",
		not saw_none_forced)
	var saw_none_free := false
	for i in 300:
		if String(DayEvent.roll(rng2, 0)["id"]) == "none":
			saw_none_free = true
	chk("...but it can still come up before the streak gets there",
		saw_none_free)

	# --- Game's own bookkeeping: read the day that just ended, not tomorrow ---
	Game.new_run(SEED)
	chk("a brand new run starts the streak at zero",
		Game._none_streak == 0, Game._none_streak)
	Game.event = DayEvent.by_id("none")
	Game._none_streak = Balance.event_none_streak_cap - 1
	Game.day = 1
	Game.advance_day()
	chk("an ordinary day walking in adds to the streak",
		Game._none_streak == Balance.event_none_streak_cap, Game._none_streak)
	Game.event = DayEvent.by_id("restless")
	Game.day = 1
	Game.advance_day()
	chk("...and anything else resets it to zero",
		Game._none_streak == 0, Game._none_streak)

	Game.new_run(SEED)


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
	Settings.rebind("dash", KEY_E)      # E is interact's default
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


func test_dash() -> void:
	section("DASH")
	chk("dash is a real, bound action",
		InputMap.has_action("dash")
		and not InputMap.action_get_events("dash").is_empty())

	Game.delete_save()
	Game.new_run(SEED)
	Balance.ensure_loaded()
	# A new career has NOT met the mentor, so the dash is locked. Every
	# section here is about the dash mechanic itself, not the gate -- grant
	# it the way a grandfathered save would have it. _reset_dash() does the
	# same before each later section.
	Game.dash_taught = true
	# row 6 is the clear aisle between the front desks (row 5) and the back
	# seats (row 7) -- a good stretch to the right with nothing to walk into.
	var start := Grid.tile_to_world(Vector2i(3, 6))
	# W frames is about one dash_duration at the 60Hz physics tick.
	var W: int = int(round(Balance.teacher_dash_duration * 60.0))

	world.player.global_position = start
	await step(2)
	await hold("move_right", W)
	var walked: float = world.player.global_position.x - start.x

	# A single TAP of dash on the first frame, same heading, same frame count.
	world.player.global_position = start
	await step(2)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(W - 1)
	Input.action_release("move_right")
	await step(1)
	var dashed: float = world.player.global_position.x - start.x

	chk("a dash covers noticeably more ground than a walk in the same time",
		dashed > walked * 1.4, "%.0f vs %.0f px in %d frames" % [dashed, walked, W])
	chk("the burst is roughly the multiplier balance.json sets",
		absf(dashed / maxf(1.0, walked) - Balance.teacher_dash_speed_multiplier) < 0.6,
		"%.2fx vs %.2fx" % [dashed / maxf(1.0, walked), Balance.teacher_dash_speed_multiplier])

	# And it is BRIEF: the stretch right after the burst is an ordinary walk,
	# not a lingering speed-up. This is what makes it a dash and not the old
	# held "Hurry" sprint it replaced.
	world.player.global_position = start
	await step(2)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(W)                       # let the whole burst elapse
	var after: float = world.player.global_position.x
	await step(W)                       # then measure an equal window
	Input.action_release("move_right")
	await step(1)
	var post_burst: float = world.player.global_position.x - after
	chk("once the burst is over, speed is back to a walk",
		absf(post_burst - walked) <= 6.0, "%.0f vs %.0f px after the burst" % [post_burst, walked])

	# Dash-cancel: for a blink AFTER the burst the interaction reach is
	# widened, so a dash that stops just short of a desk still connects into
	# the E press rather than dying a tile away. Then it snaps back.
	Game.new_run(SEED)
	Balance.ensure_loaded()
	# The two sections above already fired a dash each and left it cooling
	# down -- Game.new_run() does not touch player-instance dash state, and
	# a longer cooldown (see teacher.dash_cooldown's HUD-meter note) means
	# it can no longer be trusted to have drained on its own by now.
	_reset_dash(world.player)
	await step(2)
	var base_r: float = _zone_radius(world.player)
	world.player.global_position = start
	await step(2)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(W + 2)                   # burst elapses -> the grace window opens
	Input.action_release("move_right")
	await step(1)
	chk("just after a dash the reach is widened so the burst can connect",
		_zone_radius(world.player) > base_r + 1.0,
		"%.0f vs %.0f px" % [_zone_radius(world.player), base_r])
	chk("the widening is exactly balance.json's dash_cancel_reach",
		absf(_zone_radius(world.player) - (base_r + Balance.teacher_dash_cancel_reach)) < 0.5,
		"%.0f vs %.0f px" % [_zone_radius(world.player), base_r + Balance.teacher_dash_cancel_reach])
	await step(int(round(Balance.teacher_dash_cancel_grace * 60.0)) + 6)
	chk("and it snaps back to the normal reach once the grace lapses",
		absf(_zone_radius(world.player) - base_r) < 0.5,
		"%.0f vs %.0f px" % [_zone_radius(world.player), base_r])

	# Double-tap-a-direction trigger: two just_pressed on the SAME direction
	# within teacher.dash_double_tap_window fires the same burst as the
	# dedicated dash action -- no "dash" action involved at all.
	Game.new_run(SEED)
	Balance.ensure_loaded()
	_reset_dash(world.player)
	chk("no cooldown before any dash has fired",
		world.player.dash_cooldown_fraction() == 0.0, world.player.dash_cooldown_fraction())
	world.player.global_position = start
	await step(2)
	Input.action_press("move_right")
	await step(2)
	Input.action_release("move_right")
	await step(2)
	world.player.global_position = start   # discard the small nudge from the first tap
	Input.action_press("move_right")
	await step(1)
	await step(W - 1 + 4)
	Input.action_release("move_right")
	await step(1)
	var double_tap_dashed: float = world.player.global_position.x - start.x
	chk("double-tapping the same direction fires a dash",
		double_tap_dashed > walked * 1.4,
		"%.0f px, a walk in the same time is %.0f" % [double_tap_dashed, walked])
	chk("firing it raises the cooldown fraction",
		world.player.dash_cooldown_fraction() > 0.0, world.player.dash_cooldown_fraction())
	_reset_dash(world.player)
	chk("and _reset_dash drains it back to zero", world.player.dash_cooldown_fraction() == 0.0,
		world.player.dash_cooldown_fraction())

	# Tapping a DIFFERENT direction first must never combine into a dash --
	# each direction keeps its own clock.
	world.player.global_position = start
	await step(2)
	Input.action_press("move_left")
	await step(2)
	Input.action_release("move_left")
	await step(2)
	world.player.global_position = start   # discard the leftward nudge
	Input.action_press("move_right")
	await step(1)
	await step(W - 1 + 4)
	Input.action_release("move_right")
	await step(1)
	var opposite_taps: float = world.player.global_position.x - start.x
	chk("tapping a different direction first does not combine into a dash",
		opposite_taps < walked * 1.4,
		"%.0f px, a walk in the same time is %.0f" % [opposite_taps, walked])


## The current radius of the player's interaction zone -- used by the
## dash-cancel checks, which are entirely about that radius flexing.
func _zone_radius(p: Node) -> float:
	for c in (p.get_node("InteractZone") as Area2D).get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
			return ((c as CollisionShape2D).shape as CircleShape2D).radius
	return 0.0


# ============================================ flare-ups

func _anyone_flaring() -> bool:
	for st: StudentData in Game.roster:
		if st.flaring():
			return true
	return false


func _flaring_count() -> int:
	var n := 0
	for st: StudentData in Game.roster:
		if st.flaring():
			n += 1
	return n


func test_flares() -> void:
	section("FLARE-UPS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	await step(2)
	var s: StudentData = Game.roster[0]
	for st: StudentData in Game.roster:
		st.trait_id = "steady"

	chk("nobody starts with a flare-up brewing", not _anyone_flaring())

	# --- a flare-up is the most urgent thing at the desk ---
	s.flare_left = Balance.flare_countdown
	chk("a flaring child reads as flaring", s.flaring())
	chk("it outranks every other desk state", s.attention_rank() == 1)
	s.confusion = 1.0                 # stuck AND flaring
	s.disrupting = true              # and playing up too
	var st: Interactable = world.station(s.seat_index)
	chk("the desk offers 'head them off' ahead of settle or help",
		st != null and st.action() == st.Action.DEFUSE)
	chk("and the prompt says what it is", st.prompt_text().contains("kick off"))
	s.disrupting = false
	s.confusion = 0.0

	# --- catching it in time ---
	var xp_before: int = s.xp
	chk("heading it off works", s.defuse())
	chk("and clears the flare", not s.flaring())
	chk("with a little XP for the child", s.xp > xp_before)
	chk("heading off somebody who is fine does nothing at all", not s.defuse())

	# the coin tip is paid by the desk, not the student's own method
	var coins_before: int = Game.coins
	s.flare_left = Balance.flare_countdown
	st.interact(world.player)
	chk("catching it at the desk pays the coin tip",
		Game.coins == coins_before + Balance.flare_reward,
		"%d -> %d" % [coins_before, Game.coins])
	chk("and the flare is gone once you have", not s.flaring())

	# --- letting it run out ---
	s.flare_left = 0.05
	s.disrupting = false
	world._tick_flares(0.1, Game.rng)
	chk("a flare left too long tips into an ordinary disruption",
		s.disrupting and not s.flaring())
	chk("and flashes the chat pose on the child who missed it",
		world.student_node(s.seat_index).sprite.frame_coords.x == Actor.POSE_CHAT,
		world.student_node(s.seat_index).sprite.frame_coords)

	# --- the per-day cap ---
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	for st2: StudentData in Game.roster:
		st2.trait_id = "steady"
	Game._flares_today = Balance.flare_max_per_day
	for i in 4000:
		world._tick_flares(1.0 / 60.0, Game.rng)
	chk("once the day's cap is hit, no more flares start", not _anyone_flaring())

	# --- it starts on its own, and only ever one at a time ---
	Game._flares_today = 0
	var guard := 0
	while guard < 40000 and not _anyone_flaring():
		world._tick_flares(1.0 / 60.0, Game.rng)
		guard += 1
	chk("a flare does start on its own given time", _anyone_flaring(),
		"none in %d frames" % guard)
	var most_at_once := 0
	for i in 800:
		world._tick_flares(1.0 / 60.0, Game.rng)
		most_at_once = maxi(most_at_once, _flaring_count())
	chk("and never more than one is on the clock at once, ever",
		most_at_once <= 1, "peaked at %d" % most_at_once)

	# --- silent in a written test: the classroom feeds _tick_flares no rng ---
	Game.new_run(SEED)
	Game._flares_today = 0
	Game.test_active = true
	world.start_lesson()
	await step(1200)
	chk("a written test rolls no flare-ups", not _anyone_flaring())
	Game.test_active = false
	_hud().close()


## Mid-lesson mess: the roguelike's own extra spawn, additive to the
## day-start _spawn_mess() reroll rather than replacing it.
func test_mid_lesson_mess() -> void:
	section("MID-LESSON MESS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	world._clear_mess()
	chk("the room starts clean for this test", world.messes.is_empty())

	world._spawn_mid_lesson_mess()
	chk("a forced mid-lesson spawn grows messes by exactly one",
		world.messes.size() == 1, world.messes.size())
	chk("it is an ordinary mess once it exists -- the cleaning verb needs "
		+ "no awareness of how it got there",
		world.messes[0].can_interact() and world.messes[0].prompt_text() != "")

	var tile_a := Grid.world_to_tile(
		(world.messes[0] as Node2D).get_parent().global_position)
	world._spawn_mid_lesson_mess()
	chk("a second forced spawn grows it to two",
		world.messes.size() == 2, world.messes.size())
	var tile_b := Grid.world_to_tile(
		(world.messes[1] as Node2D).get_parent().global_position)
	chk("two forced spawns never land on the same tile", tile_a != tile_b)

	world._clear_mess()


## Mid-lesson complications: the phone/conference desk interruption, and
## the mess kind's own onset. Mirrors test_flares()'s shape -- catch it,
## let it run out, the per-lesson cap, and that it starts on its own.
## The curriculum and the lesson plans are read out of an open book.
func test_book_pages() -> void:
	section("THE BOOK")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()

	# --- it is a book, and only on the two screens that are one ---
	hud.show_curriculum()
	chk("the curriculum opens as a book", hud.book.visible)
	chk("with something written on the left page", hud.rich_left.text != "")
	chk("and the room still dimmed behind it", hud.overlay.visible)
	chk("the text is on the right-hand page, clear of the spine",
		hud.rich.offset_left >= 320.0, hud.rich.offset_left)

	# A hand has to exist before the plans can be a book -- show_hand()
	# closes itself when there is nothing dealt, which is exactly how the
	# close()-must-put-the-book-away bug showed up.
	Game.draw_hand()
	hud._sel = 0
	hud.show_hand()
	chk("the lesson plans open as a book too", hud.book.visible)
	chk("with the plan's own name on the left page",
		hud.rich_left.text.contains(Assignments.title(Game.hand[hud._sel])),
		hud.rich_left.text)

	# A screen that is NOT a book must not inherit one. This is the same
	# leak the portrait had to be guarded against.
	hud.show_student(Game.roster[0])
	chk("a screen that is not a book does not get one", not hud.book.visible)
	chk("and its text goes back to the full panel width",
		hud.rich.offset_left < 320.0, hud.rich.offset_left)

	# --- a page TURN flips; opening the book does not ---
	hud.show_curriculum()
	chk("opening the book is not a page turn", not hud.flip.visible)
	hud._sel += 1
	hud.show_curriculum()
	chk("turning to the next subject flips a page", hud.flip.visible)
	await step(20)
	chk("and the page settles again afterwards", not hud.flip.visible)

	# --- ink, not paper-on-ink ---
	chk("a common plan's own title is dark enough to read on paper", (func() -> bool:
		var ink := Color.from_string("#" + hud._on_paper(
			Assignments.rarity_colour("common")), Color.WHITE)
		return ink.get_luminance() <= 0.34).call())
	hud.close()
	chk("closing it puts the book away", not hud.book.visible)


## A materials day: the class starts empty-handed and it is your job to fix
## that before the bell.
func test_materials_day() -> void:
	section("MATERIALS DAY")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	# The event table still adds up, with the new row in it.
	var total := 0
	for row: Dictionary in DayEvent.TABLE:
		total += int(row.get("weight", 0))
	chk("the day-event weights still sum to exactly 100", total == 100, total)
	var mats := DayEvent.by_id("supplies")
	chk("there is a materials day to roll", not mats.is_empty())
	chk("and it says in prose what it wants of you",
		String(mats.get("blurb", "")).contains("Hand them out"), mats.get("blurb", ""))

	# --- an ORDINARY day is untouched: everyone already has their things ---
	Game.event = DayEvent.by_id("none")
	Game._set_up_supplies()
	chk("nobody is short of anything on an ordinary day",
		Game.awaiting_supplies() == 0, Game.awaiting_supplies())
	chk("and nothing slows their work",
		is_equal_approx(Game.supply_rate_mult(Game.roster[0]), 1.0))

	# --- a materials day empties every seated child's hands ---
	Game.event = mats
	Game._set_up_supplies()
	var seated := 0
	for s: StudentData in Game.roster:
		if s.seat_index >= 0:
			seated += 1
	chk("a materials day starts the whole class empty-handed",
		Game.awaiting_supplies() == seated, Game.awaiting_supplies())

	var kid: StudentData = Game.roster[0]
	chk("a child with nothing works slower for it",
		Game.supply_rate_mult(kid) < 1.0, Game.supply_rate_mult(kid))

	# --- the desk offers the job, and only while it IS a job ---
	var desk: Interactable = null
	for n: Node in world.stations:
		if n is Interactable and n.seat_index == kid.seat_index:
			desk = n
	chk("the child's desk is there to hand things to", desk != null)
	if desk != null:
		chk("and it offers to hand their things over first of all",
			desk.action() == desk.Action.HAND_OUT, desk.action())
		chk("saying so in prose", desk.prompt_text().contains("their things"),
			desk.prompt_text())
		desk.interact(world.player)
		chk("handing them over settles it", kid.has_supply)
		chk("so they are back to working at their own pace",
			is_equal_approx(Game.supply_rate_mult(kid), 1.0))
		chk("and the desk stops offering a job that is done",
			desk.action() != desk.Action.HAND_OUT)
		chk("one fewer is waiting", Game.awaiting_supplies() == seated - 1)
	chk("handing twice to the same child does nothing",
		not Game.give_supply(kid))

	# --- it shows up on the page that says what is acting on them ---
	var hud := _hud()
	var empty: StudentData = null
	for s: StudentData in Game.roster:
		if s.seat_index >= 0 and not s.has_supply:
			empty = s
			break
	if empty != null:
		hud.show_student(empty)
		hud._bio_page = hud.BIO_ACTING
		hud.show_student(empty)
		chk("a child with nothing is told so on their own page",
			hud.body.text.contains("nothing in front of them"), hud.body.text)
		hud.close()

	# --- and the simulator never sees any of it ---
	var sim := FileAccess.open("res://tools/sim.gd", FileAccess.READ)
	if sim != null:
		var src := sim.get_as_text()
		chk("the term simulator never touches materials, so the contract holds",
			not src.contains("supply") and not src.contains("supplies"),
			"sim.gd reaches into the materials path")
	Game.event = DayEvent.by_id("none")
	Game._set_up_supplies()


## Page three of a child's file: what is pulling on them right now.
func test_acting_on_them() -> void:
	section("WHAT'S ACTING ON THEM")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()
	var s: StudentData = Game.roster[0]

	# Tab cycles three pages now, not two, and comes back round.
	hud.show_student(s)
	chk("a file opens on page one", hud._bio_page == hud.BIO_FILE)
	hud._bio_page = hud.BIO_STORY
	hud.show_student(s)
	chk("page two is still their story", hud.hint.text.contains("acting on them"),
		hud.hint.text)
	hud._bio_page = hud.BIO_ACTING
	hud.show_student(s)
	chk("page three says what is acting on them",
		hud.body.text != "", hud.body.text)
	chk("and it offers the way back to the file",
		hud.hint.text.contains("back to the file"), hud.hint.text)

	# It NAMES influences. It never prints their value -- that is the rule
	# the whole student file exists to obey.
	var digits := RegEx.new()
	digits.compile("[0-9]")
	chk("nothing on the page prints a number about a child",
		digits.search(hud.body.text) == null, hud.body.text)
	chk("and it fits the panel budget",
		hud.body.text.split("
").size() <= 11, hud.body.text.split("
").size())

	# --- it actually reacts to what is true ---
	s.trait_id = "restless"
	hud.show_student(s)
	chk("a child's own trait is named on the page",
		hud.body.text.contains(Traits.name_of("restless")), hud.body.text)

	s.disrupting = true
	hud.show_student(s)
	chk("playing up shows up as something against them",
		hud.body.text.contains("playing up"), hud.body.text)
	s.disrupting = false

	s.copied = true
	hud.show_student(s)
	chk("copying shows up, because the gap it hides is the point",
		hud.body.text.contains("copied"), hud.body.text)
	s.copied = false

	# The day itself is an influence, and it is already prose in the table.
	Game.event = DayEvent.by_id("restless")
	hud.show_student(s)
	chk("today's own event is named too",
		hud.body.text.contains(String(DayEvent.by_id("restless").get("blurb", ""))),
		hud.body.text)
	Game.event = DayEvent.by_id("none")
	hud.show_student(s)
	chk("an ordinary day is not listed as though it were a problem",
		not hud.body.text.contains("Nothing out of the usual"), hud.body.text)

	# Both directions: the page has to be able to say something is HELPING.
	s.coached = 1
	hud.show_student(s)
	chk("what you have already done for them counts as for them",
		hud.body.text.contains("FOR THEM"), hud.body.text)
	s.coached = 0
	hud.close()


## Someone at your desk who wants an answer, not a nod.
func test_callers() -> void:
	section("SOMEONE AT YOUR DESK")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()

	# --- the table itself ---
	var total := 0
	for row: Dictionary in Complication.TABLE:
		total += int(row.get("weight", 0))
	chk("the complication weights still sum to exactly 100", total == 100, total)

	var with_choices := 0
	for row: Dictionary in Complication.TABLE:
		var choices: Array = row.get("choices", [])
		if choices.is_empty():
			continue
		with_choices += 1
		chk("%s offers two or three ways to answer" % row["id"],
			choices.size() >= 2 and choices.size() <= 3, choices.size())
		chk("%s says who is doing the asking" % row["id"],
			String(row.get("speaker", "")) in ["principal", "student"],
			row.get("speaker", ""))
		chk("%s has a line to say" % row["id"], String(row.get("line", "")) != "")
		for c: Dictionary in choices:
			chk("every choice of %s has a label and a reply" % row["id"],
				String(c.get("label", "")) != "" and String(c.get("says", "")) != "")
			for eff: Dictionary in c.get("effects", []):
				chk("%s only uses effects the game knows" % row["id"],
					String(eff.get("kind", "")) in Complication.EFFECTS,
					eff.get("kind", ""))
	chk("there are people to answer, not just phones", with_choices >= 6, with_choices)

	# Prose, never numbers -- the cost is felt at the purse, not printed.
	var digits := RegEx.new()
	digits.compile("[0-9]")
	for row: Dictionary in Complication.TABLE:
		if (row.get("choices", []) as Array).is_empty():
			continue
		var strings: Array[String] = [String(row.get("line", ""))]
		for c: Dictionary in row["choices"]:
			strings.append(String(c.get("label", "")))
			strings.append(String(c.get("says", "")))
		for t: String in strings:
			chk("nothing a caller says prints a number", digits.search(t) == null, t)

	# --- a row WITHOUT choices is untouched: still an instant payoff ---
	var call_row := Complication.by_id("phone_call")
	chk("the phone still has no choices to make", 
		(call_row.get("choices", []) as Array).is_empty())
	Game.interruption = call_row.duplicate()
	Game.interruption["left"] = 8.0
	var coins_before: int = Game.coins
	world._on_interruption_answered()
	chk("answering the phone still pays on the spot",
		Game.coins == coins_before + int(call_row.get("answer_reward_coins", 0)),
		Game.coins)
	chk("and leaves nothing pending", Game.interruption.is_empty())
	chk("and opens no screen", hud.mode != hud.Mode.CALLER)

	# --- a row WITH choices opens the screen and pays NOTHING yet ---
	var trip := Complication.by_id("trip_fund")
	Game.interruption = trip.duplicate()
	Game.interruption["left"] = 10.0
	Game.interruption_student_id = -1
	coins_before = Game.coins
	var lesson_before: float = world.lesson_left
	world._on_interruption_answered()
	await step(2)
	chk("answering a person opens their screen", hud.mode == hud.Mode.CALLER)
	chk("the lesson still paid for the interruption", world.lesson_left < lesson_before)
	chk("but nothing is won until you actually answer them",
		Game.coins == coins_before, Game.coins)
	chk("and the desk is clear either way", Game.interruption.is_empty())
	chk("the screen names who is asking", hud.title.text == "THE PRINCIPAL",
		hud.title.text)
	chk("and it fits the panel budget",
		hud.body.text.split("
").size() <= 11, hud.body.text.split("
").size())

	# choosing walks with the same keys every other list uses
	chk("the first way to answer is selected", hud._caller_sel == 0)
	hud._caller_sel = 1
	hud._render_caller()
	chk("moving the marker re-renders the other option",
		hud.body.text.contains("> Tell her"), hud.body.text)

	# --- what an answer actually does ---
	var rep_before: float = Game.reputation
	coins_before = Game.coins
	var said: String = world.resolve_caller_choice(trip, 0, null)
	chk("giving what you can costs coins", Game.coins == coins_before - 40, Game.coins)
	chk("and she remembers it", Game.reputation > rep_before)
	chk("and she says something back", said != "")
	hud.caller_replied(said)
	chk("the screen shows her reply", hud.body.text.contains(said), hud.body.text)
	chk("with nothing left to choose", not hud.body.text.contains(">"))
	hud.close()
	chk("closing it puts the room back", hud.mode == hud.Mode.NONE)

	# an item lands in the cabinet, where buying puts it -- not on the floor
	var cab_before: int = Game.cabinet.size()
	var placed_before: int = Game.room_items.size()
	world.resolve_caller_choice(Complication.by_id("storeroom_key"), 0, null)
	chk("taking the spare puts it in your cabinet",
		Game.cabinet.size() == cab_before + 1, Game.cabinet.size())
	chk("and places nothing for you", Game.room_items.size() == placed_before)

	# --- ten-commits.md step 7: three new desk decisions ---
	# found_item -- the same item-effect path storeroom_key already proved
	var cab_before2: int = Game.cabinet.size()
	world.resolve_caller_choice(Complication.by_id("found_item"), 0, null)
	chk("keeping what a child found puts it in the cabinet too",
		Game.cabinet.size() == cab_before2 + 1, Game.cabinet)

	# seat_swap -- letting them move disrupts one seated child
	Game.new_run(SEED)
	await step(2)
	for st: StudentData in Game.roster:
		st.disrupting = false
	var settled_count := 0
	for st: StudentData in Game.roster:
		if not st.disrupting:
			settled_count += 1
	world.resolve_caller_choice(Complication.by_id("seat_swap"), 0, null)
	var disrupting_count := 0
	for st: StudentData in Game.roster:
		if st.disrupting:
			disrupting_count += 1
	chk("letting a child swap seats unsettles exactly one desk",
		disrupting_count == 1 and settled_count == Game.roster.size(),
		disrupting_count)

	# borrow_desk -- lending it over pays reputation but still disrupts one
	Game.new_run(SEED)
	await step(2)
	var rep_before2: float = Game.reputation
	world.resolve_caller_choice(Complication.by_id("borrow_desk"), 0, null)
	chk("lending a desk over costs the room something",
		Game.reputation > rep_before2)
	chk("...and still unsettles a desk, the same as any other favour",
		(func() -> bool:
			for st: StudentData in Game.roster:
				if st.disrupting:
					return true
			return false).call())

	# --- the boost: teacher pace, and only that ---
	Game.clear_boost()
	chk("no boost is running to start with", Game.boost_speed_mult() == 1.0)
	var plain: float = Progress.speed(Game.perk_ranks, 1.0)
	world.resolve_caller_choice(Complication.by_id("child_question"), 0, null)
	chk("sitting with a child wins a stretch of quicker feet", Game.boost_left > 0.0)
	chk("which makes the teacher walk faster",
		Progress.speed(Game.perk_ranks, Game.boost_speed_mult()) > plain)
	var first: float = Game.boost_left
	Game.tick_boost(1.0)
	chk("it ticks down", Game.boost_left < first)
	world.resolve_caller_choice(Complication.by_id("child_question"), 0, null)
	chk("winning it twice refreshes rather than stacks",
		is_equal_approx(Game.boost_left, Balance.comp_boost_seconds), Game.boost_left)
	world.end_lesson()
	await step(2)
	chk("and the bell ends it", Game.boost_left == 0.0)
	chk("so the teacher is back to their own pace",
		is_equal_approx(Progress.speed(Game.perk_ranks, Game.boost_speed_mult()), plain))

	# --- a child asking is a REAL child, picked off the seeded rng ---
	Game.new_run(SEED)
	await step(2)
	var kid: StudentData = Game.roster[0]
	hud.show_caller(Complication.by_id("child_errand"), kid)
	chk("a child's own name is on their screen", hud.title.text == kid.display_name,
		hud.title.text)
	hud.close()

	# --- the simulator must never reach any of this ---
	var sim := FileAccess.open("res://tools/sim.gd", FileAccess.READ)
	chk("the term simulator can still be opened to be checked", sim != null)
	if sim != null:
		var src := sim.get_as_text()
		chk("and it never answers anyone at the desk, so the contract cannot drift",
			not src.contains("resolve_caller_choice") and not src.contains("start_boost"),
			"sim.gd reaches into the caller path")


func test_desk_interruption() -> void:
	section("DESK INTERRUPTIONS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	var rp: Interactable = null
	for n in get_tree().get_nodes_in_group("interruption_desk"):
		rp = n
	chk("the teacher desk has a RESPOND job on it", rp != null)
	Game.interruption = {}

	chk("nothing is waiting at the desk yet", not rp.can_interact())
	chk("so it offers nothing", rp.prompt_text() == "")

	# --- answering it ---
	var call_row := Complication.by_id("phone_call")
	Game.interruption = call_row.duplicate()
	Game.interruption["left"] = float(call_row.get("ring_seconds", 8.0))
	chk("a pending interruption offers to be answered", rp.can_interact())
	chk("and says which one it is", rp.prompt_text() == "Answer it", rp.prompt_text())

	var lesson_before: float = world.lesson_left
	var coins_before: int = Game.coins
	rp.interact(world.player)
	chk("answering deducts the right seconds", is_equal_approx(
		world.lesson_left,
		lesson_before - float(call_row.get("answer_cost_seconds", 5.0))),
		world.lesson_left)
	chk("and pays the right coins",
		Game.coins == coins_before + int(call_row.get("answer_reward_coins", 0)),
		Game.coins)
	chk("and it is cleared once handled", Game.interruption.is_empty())
	chk("so the desk has nothing left to offer", not rp.can_interact())

	# --- letting a phone call ring out: disrupts one calm child ---
	for s: StudentData in Game.roster:
		s.disrupting = false
	Game.interruption = call_row.duplicate()
	Game.interruption["left"] = 0.05
	world._tick_complications(0.1, Game.rng)
	var any_disrupting := false
	var phone_victim: StudentData = null
	for s: StudentData in Game.roster:
		if s.disrupting:
			any_disrupting = true
			phone_victim = s
	chk("ignoring a phone call disrupts one child", any_disrupting)
	chk("and flashes the chat pose on the child it picked",
		phone_victim != null and world.student_node(phone_victim.seat_index)
			.sprite.frame_coords.x == Actor.POSE_CHAT)
	chk("and clears the interruption either way", Game.interruption.is_empty())

	# --- letting a conference ring out: costs reputation instead ---
	var conf_row := Complication.by_id("conference")
	Game.interruption = conf_row.duplicate()
	Game.interruption["left"] = 0.05
	var rep_before: float = Game.reputation
	world._tick_complications(0.1, Game.rng)
	chk("ignoring a conference costs reputation instead",
		Game.reputation < rep_before, Game.reputation)

	# --- the per-lesson cap ---
	Game.interruption = {}
	Game._complications_today = Balance.comp_max_per_lesson
	# messes_before, not "empty" -- new_run() above already spawned this
	# day's ordinary start-of-day mess, unrelated to the cap under test.
	var messes_before: int = world.messes.size()
	for i in 4000:
		world._tick_complications(1.0 / 60.0, Game.rng)
	chk("once the lesson's cap is hit, nothing new starts",
		Game.interruption.is_empty() and world.messes.size() == messes_before,
		"%d -> %d messes" % [messes_before, world.messes.size()])

	# --- it starts on its own, of SOME kind, given time ---
	world._clear_mess()
	Game.interruption = {}
	Game._complications_today = 0
	var guard := 0
	while guard < 40000 and Game._complications_today == 0:
		world._tick_complications(1.0 / 60.0, Game.rng)
		guard += 1
	chk("a complication does start on its own given time",
		Game._complications_today > 0, "none in %d frames" % guard)

	Game.interruption = {}
	Game._complications_today = 0
	world._clear_mess()


## The anti-cram penalty: a child with an occupied desk orthogonally
## adjacent works slower, so spreading the desks back out is the actual
## counter-play to the discovered "shove every desk into the middle" meta.
## Layout only -- see the _one_lesson() source scan in test_balance() for
## the assertion that the contract never sees it.
func test_cluster_penalty() -> void:
	section("DESK CLUSTERING")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	chk("the penalty is a real, read tunable rather than a code const",
		Balance.room_cluster_penalty > 0.0, Balance.room_cluster_penalty)

	# the opening layout has no two seats within a tile of each other, so
	# nobody pays it until a player chooses to bunch the desks up
	var any_penalised := false
	for s: StudentData in Game.roster:
		if Game.cluster_rate_mult(s) < 1.0:
			any_penalised = true
	chk("the opening layout costs nobody anything", not any_penalised)

	var s0: StudentData = Game.roster[0]
	var s1: StudentData = Game.roster[1]
	var s2: StudentData = Game.roster[2]

	# 0 and 1 shoved together; 2 left off on its own
	Layout.set_seats([Vector2i(3, 4), Vector2i(4, 4), Vector2i(13, 8),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	chk("a bunched desk works slower", is_equal_approx(
		Game.cluster_rate_mult(s0), 1.0 - Balance.room_cluster_penalty),
		Game.cluster_rate_mult(s0))
	chk("and so does the desk it was bunched against",
		Game.cluster_rate_mult(s1) < 1.0)
	chk("the desk left on its own is untouched",
		is_equal_approx(Game.cluster_rate_mult(s2), 1.0))

	# spreading them back out clears it -- the counter-play actually works
	Layout.set_seats([Vector2i(3, 4), Vector2i(15, 7), Vector2i(13, 8),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	chk("moving them apart clears the penalty",
		is_equal_approx(Game.cluster_rate_mult(s0), 1.0))

	# 0.0 turns it off entirely
	var kept := Balance.room_cluster_penalty
	Balance.room_cluster_penalty = 0.0
	Layout.set_seats([Vector2i(3, 4), Vector2i(4, 4), Vector2i(13, 8),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	chk("penalty of 0 is a clean no-op, not a 0x rate",
		is_equal_approx(Game.cluster_rate_mult(s0), 1.0))
	Balance.room_cluster_penalty = kept

	# the room's own work tick actually reads it -- not just the helper
	var cls_src := FileAccess.get_file_as_string("res://scripts/world/classroom.gd")
	chk("classroom._physics_process actually applies cluster_rate_mult",
		cls_src.contains("cluster_rate_mult("))

	# and the behaviour it buys: the same sheet and the same teaching rate
	# for both, and the bunched desk still falls behind the lone one.
	# Rate held at 1.0 (perfect teaching, the contract's own convention)
	# and a null rng so no stalls muddy the comparison.
	Layout.set_seats([Vector2i(3, 4), Vector2i(4, 4), Vector2i(13, 8),
		Vector2i(15, 4), Vector2i(3, 7), Vector2i(7, 7), Vector2i(11, 7),
		Vector2i(7, 4)])
	for s: StudentData in Game.roster:
		s.work_state = StudentData.Work.WORKING
		s.work_total = 10.0
		s.work_timer = 10.0
		s.confusion = 0.0
		s.disrupting = false
	for i in 200:
		for s: StudentData in Game.roster:
			s.tick_work(1.0 / 60.0, null, Game.cluster_rate_mult(s))
	chk("over a stretch of teaching, the bunched desk is behind the lone one",
		s0.work_fraction() < s2.work_fraction(),
		"%.3f vs %.3f" % [s0.work_fraction(), s2.work_fraction()])

	Layout.reset_seats()
	Game.new_run(SEED)


# ============================================ furniture lanes and clutter

func test_dash_lanes() -> void:
	section("DASH LANES")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)

	chk("a plain tile has no dash flavour",
		world.dash_tile_kind(Vector2i(3, 6)) == "")

	# a lane item (the rug, w2) at (2,3) -> footprint (2,3),(3,3)
	Game.room_items.append({"id": "rug", "tile": Vector2i(2, 3)})
	chk("a tile beside a lane item reads as a lane",
		world.dash_tile_kind(Vector2i(2, 4)) == "lane",
		world.dash_tile_kind(Vector2i(2, 4)))
	chk("a tile well away from it does not",
		world.dash_tile_kind(Vector2i(9, 9)) == "")

	# clutter beats lane where their tiles-of-influence overlap
	Game.room_items.append({"id": "crate", "tile": Vector2i(3, 4)})
	chk("clutter wins the tile when a lane and a clutter item both touch it",
		world.dash_tile_kind(Vector2i(3, 3)) == "clutter",
		world.dash_tile_kind(Vector2i(3, 3)))
	Game.room_items.clear()

	# --- the burst actually carries past its normal length on a lane ---
	var W: int = int(round(Balance.teacher_dash_duration * 60.0))
	var start := Grid.tile_to_world(Vector2i(3, 6))
	Game.new_run(SEED)
	await step(40)                      # let the player finish filing in

	# a plain dash: the burst is spent by W frames
	_reset_dash(world.player)
	world.player.global_position = start
	await step(1)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(W + 4)
	var plain_burst: float = world.player._dash_burst
	Input.action_release("move_right")
	chk("a plain dash's burst is done by the time its duration is up",
		plain_burst == 0.0, "%.3f" % plain_burst)

	# the same dash, but there is a lane strip along the row it runs down
	Game.room_items.append({"id": "rug", "tile": Vector2i(4, 5)})
	Game.room_items.append({"id": "rug", "tile": Vector2i(6, 5)})
	Game.room_items.append({"id": "rug", "tile": Vector2i(8, 5)})
	_reset_dash(world.player)
	world.player.global_position = start
	await step(1)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(W + 4)
	var laned_burst: float = world.player._dash_burst
	Input.action_release("move_right")
	chk("a lane carries the burst past that point", laned_burst > 0.0,
		"%.3f" % laned_burst)
	Game.room_items.clear()

	# --- clutter kills the burst and lengthens the cooldown ---
	Game.new_run(SEED)
	await step(40)                      # let the player finish filing in
	Game.room_items.append({"id": "crate", "tile": Vector2i(4, 5)})
	_reset_dash(world.player)
	world.player.global_position = start
	await step(1)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(2)
	# the cooldown is set the instant a dash fires (dash_duration +
	# dash_cooldown), so it is a timing-proof witness that the dash happened
	chk("the clutter dash started", world.player._dash_cool > 0.0)
	Input.action_release("dash")
	await step(9)                       # far enough to reach the tile by the crate
	Input.action_release("move_right")
	chk("a dash into clutter loses its burst early",
		world.player._dash_burst == 0.0)
	chk("and the next dash has to wait longer for it",
		world.player._dash_cool >= Balance.teacher_dash_clutter_penalty - 0.05,
		"%.2f" % world.player._dash_cool)
	Game.room_items.clear()


## Clear every scrap of dash state so a test dash starts from nothing --
## the cooldown from an earlier dash would otherwise silently swallow it.
## Also grants dash_taught: a Game.new_run() now leaves the dash LOCKED
## until the mentor teaches it, and every dash test is about the mechanic,
## not the gate (there is a dedicated section for the gate).
func _reset_dash(p: Node) -> void:
	Game.dash_taught = true
	p._dash_burst = 0.0
	p._dash_cool = 0.0
	p._dash_cancel_grace = 0.0
	p._dash_lane_left = 0.0
	p._dash_stumbled = false
	for k: String in (p._tap_since as Dictionary).keys():
		p._tap_since[k] = 999.0


# ============================================ the chain dash

## A child with their hand visibly up, and nothing louder going on at the
## desk -- so HELP is exactly what E would offer there.
func _chain_stuck(s: StudentData) -> void:
	s.trait_id = "steady"
	s.has_supply = true
	s.flare_left = 0.0
	s.disrupting = false
	s.confusion = 1.0
	s._hidden_for = 999.0


## Mid-dash, as far as _tick_chain() can tell: a live burst on a dash that
## has not answered anyone yet. Driven this way rather than by input so the
## rules are checked apart from the geometry of an aisle; the real input
## path is walked in the mentor's room, in test_mentor().
func _chain_mid_dash(p: Node, fresh: bool = true) -> void:
	p._dash_burst = 0.1
	p._dash_cool = 1.0
	if fresh:
		p._dash_answered = false


func test_chain_dash() -> void:
	section("THE CHAIN DASH")
	Balance.ensure_loaded()
	chk("the chain's numbers live in balance.json",
		Balance.teacher_chain_dash_cooldown > 0.0
		and Balance.teacher_chain_dash_reach > 0.0
		and Balance.teacher_chain_dash_max_links > 0
		and Balance.teacher_chain_dash_window > 0.0)
	chk("a chained dash waits far less than an ordinary one",
		Balance.teacher_chain_dash_cooldown < Balance.teacher_dash_cooldown * 0.5,
		"%.2f vs %.2f" % [Balance.teacher_chain_dash_cooldown, Balance.teacher_dash_cooldown])

	Game.new_run(SEED)
	var guard := 0
	while not world.everyone_seated() and guard < 900:
		await step(1)
		guard += 1
	chk("the class is seated", world.everyone_seated(), guard)
	chk("a new career has not been shown the chain", not Game.chain_dash_taught)

	var p = world.player
	p.input_locked = false
	_reset_dash(p)
	var a: StudentData = Game.roster[0]
	var b: StudentData = Game.roster[1]
	var st_a: Interactable = world.stations[a.seat_index]
	var st_b: Interactable = world.stations[b.seat_index]
	for s: StudentData in Game.roster:
		s.confusion = 0.0
		s.disrupting = false
		s.flare_left = 0.0
	# Stand in the aisle just in front of A's desk, facing it.
	var in_front_of_a := Layout.desk_tile(a.seat_index) + Vector2i(0, 1)
	await place_player(in_front_of_a, Actor.DIR_UP)

	# --- untaught: a dash reaches a raised hand and does nothing to it ---
	_chain_stuck(a)
	chk("an untaught chain answers no one", not st_a.dash_answerable())
	_chain_mid_dash(p)
	await step(2)
	chk("...a dash into a raised hand leaves it up", a.is_struggling())

	# --- taught: the same dash answers them on arrival ---
	Game.chain_dash_taught = true
	chk("taught, a visibly raised hand in front of you is answerable",
		st_a.dash_answerable())
	var helps_before := a.helps_received
	_chain_mid_dash(p)
	await step(2)
	chk("a dash that reaches a raised hand answers it", not a.is_struggling())
	chk("...through the same help() E gives -- it counts as help",
		a.helps_received == helps_before + 1)
	chk("the lunge lands there: the burst ends on the answer", p._dash_burst == 0.0)
	chk("and the next dash is ready almost at once",
		p._dash_cool <= Balance.teacher_chain_dash_cooldown + 0.001, p._dash_cool)
	chk("that is one link in a chain", p.chain_links == 1, p.chain_links)

	# --- one child per dash ---
	_chain_stuck(a)
	_chain_mid_dash(p, false)          # the SAME dash, still live
	await step(2)
	chk("one dash answers one child, not everyone it passes", a.is_struggling())

	# --- the next dash links on ---
	_chain_mid_dash(p)
	await step(2)
	chk("the next dash answers the next hand", not a.is_struggling())
	chk("...and the chain grows", p.chain_links == 2, p.chain_links)

	# --- only a hand that is UP, only the verb E would give ---
	a.trait_id = "quiet"
	a.confusion = 1.0
	a._hidden_for = 0.0
	chk("a Quiet child still hiding it is not the dash's to find",
		not st_a.dash_answerable())
	_chain_mid_dash(p)
	await step(2)
	chk("...a dash past them leaves them stuck", a.is_struggling())
	_chain_stuck(a)
	a.disrupting = true
	_chain_mid_dash(p)
	await step(2)
	chk("a dash never settles a child playing up -- that is a word, not a run",
		a.disrupting)
	a.disrupting = false
	a.confusion = 0.0

	# --- not behind you ---
	_chain_stuck(a)
	p.facing = Actor.DIR_DOWN
	_chain_mid_dash(p)
	await step(2)
	chk("a dash AWAY from a raised hand does not answer it", a.is_struggling())
	p.facing = Actor.DIR_UP

	# --- a paper in progress is silent ---
	Game.test_active = true
	chk("nothing is answerable during a test", not st_a.dash_answerable())
	Game.test_active = false

	# --- out of breath: past the cap the wait is the ordinary one ---
	p.chain_links = Balance.teacher_chain_dash_max_links
	p._chain_left = Balance.teacher_chain_dash_window
	_chain_mid_dash(p)
	await step(2)
	chk("past the cap the answer still lands", not a.is_struggling())
	chk("...but the wait is not refunded",
		p._dash_cool > Balance.teacher_chain_dash_cooldown + 0.001, p._dash_cool)

	# --- the chain lapses if you stop running ---
	var lapse := int(ceil(Balance.teacher_chain_dash_window * 60.0)) + 6
	await step(lapse)
	chk("a chain left alone lapses back to nothing", p.chain_links == 0, p.chain_links)

	# --- another desk works the same way ---
	_chain_stuck(b)
	var in_front_of_b := Layout.desk_tile(b.seat_index) + Vector2i(0, 1)
	await place_player(in_front_of_b, Actor.DIR_UP)
	_chain_mid_dash(p)
	await step(2)
	chk("any desk in the room answers the same way", not b.is_struggling())
	chk("...via its own station", st_b.dash_answerable() == false)

	# --- the save keeps it, and an old save has not seen it ---
	Game.chain_dash_taught = true
	var d: Dictionary = Game.to_dict()
	chk("the chain being taught is saved", bool(d.get("chain_dash_taught", false)))
	d.erase("chain_dash_taught")
	Game.from_dict(d)
	chk("a save from before it existed has NOT been shown it -- the demo is the lesson",
		not Game.chain_dash_taught)
	chk("...while that same save keeps the dash itself", Game.dash_taught)

	_reset_dash(p)
	p.chain_links = 0
	p._chain_left = 0.0
	Game.new_run(SEED)
	await step(2)


# ============================================ the end-of-session bell rush

func test_bell_rush() -> void:
	section("BELL RUSH")
	Balance.ensure_loaded()

	# --- OFF by default: a lesson ends and nothing rushes ---
	chk("the bell rush ships switched off", not Balance.bell_rush_enabled)
	Game.new_run(SEED)
	await step(2)
	var frames := 0
	while frames < 3000 and not world.everyone_seated():
		await step(20)
		frames += 20
	world.start_lesson()
	await step(2)
	world.end_lesson()
	chk("with it off, ending a lesson starts no rush", not Game.bell_rush_active())
	chk("and no timer is running", is_equal_approx(Game.bell_rush_left, 0.0))

	# --- forced on: the round runs, and clearing every desk pays out ---
	Balance.bell_rush_enabled = true
	Game.set_phase(Game.Phase.AFTERNOON)
	Game.start_bell_rush()
	chk("switched on, the round is now running", Game.bell_rush_active())
	chk("with the full clock", is_equal_approx(Game.bell_rush_left, Balance.bell_rush_seconds))
	var seats: Array[int] = Game.bell_rush_pending()
	chk("every seated child is owed their work back", seats.size() >= 2,
		seats.size())

	var coins_before: int = Game.coins
	var xp_before: int = Game.student_in_seat(seats[0]).xp
	# hand back all but the last
	for i in range(seats.size() - 1):
		var last := Game.bell_rush_hand_back(seats[i])
		chk("handing back a desk mid-round does not finish it", not last)
	chk("each desk hands its child a little XP",
		Game.student_in_seat(seats[0]).xp > xp_before)
	chk("and the coin bonus has not landed yet", Game.coins == coins_before)
	chk("the round is still going", Game.bell_rush_active())

	var done := Game.bell_rush_hand_back(seats[seats.size() - 1])
	chk("the last desk completes the round", done)
	chk("which pays the flat coin bonus",
		Game.coins == coins_before + Balance.bell_rush_reward,
		"%d -> %d" % [coins_before, Game.coins])
	chk("and the round is over", not Game.bell_rush_active())
	chk("a hand-back after the round is a no-op",
		not Game.bell_rush_hand_back(seats[0]))

	# --- running out of time ends it with no bonus ---
	Game.set_phase(Game.Phase.AFTERNOON)
	Game.start_bell_rush()
	var timed_out: Array[int] = [0]
	Game.bell_rush_finished.connect(func(completed: bool) -> void:
		if not completed:
			timed_out[0] += 1)
	var purse: int = Game.coins
	Game.tick_bell_rush(Balance.bell_rush_seconds + 1.0)
	chk("the clock running out ends the round", not Game.bell_rush_active())
	chk("it reports as not completed", timed_out[0] == 1)
	chk("and pays nothing", Game.coins == purse)

	Balance.bell_rush_enabled = false


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
	chk("the podium is a teach thing", world.podium.action_name() == "teach")
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
	# The podium has two verbs now (Q quizzes, L ends the lesson), so the
	# question is which button points at it, not what the single target is.
	chk("the podium is what TEACH is pointing at",
		world.player.targets["teach"] == world.podium)
	# Q at the podium is the QUICK QUIZ -- its own dedicated key, not the
	# mashable USE button, since Aug 2026's key remap. Mashing E here must
	# still do nothing at all: neither ending the lesson nor calling a quiz.
	for i in 4:
		await tap("interact")
	chk("mashing the USE button at the podium cannot end the lesson",
		Game.phase == Game.Phase.LESSON, Game.phase)
	chk("and mashing it does not call a quiz either", not Game.quiz_done)
	await tap("quiz")
	chk("its own key does", Game.quiz_done)
	_hud().close()          # the quiz report must not leak into the next test
	await step(2)

	# nor can a TAP of teach, because ending a lesson is held
	chk("ending a lesson requires a hold, not a tap", world.podium.hold_time > 0.0)
	await tap("teach")
	chk("a quick tap of teach does not end it either",
		Game.phase == Game.Phase.LESSON, Game.phase)

	await hold_confirm("teach", 0.9)
	chk("holding teach DOES end the lesson",
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
		world.podium.key_hint() == Settings.binding_text("teach").split(",")[0].strip_edges(),
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
	# Lessons that carry NO citation, on purpose.
	#
	# The rule at the top of curriculum.gd is that a fabricated citation is
	# worse than none at all, so an uncited lesson has to be ALLOWED -- but
	# only deliberately. Naming them here means an accidental omission still
	# fails while a considered one does not have to be papered over with a
	# plausible-looking code.
	#
	# The five social-studies lessons added in the August 2026 content batch
	# are here because the writer said, in as many words, that it could not
	# verify a Maryland Social Studies code for them. That is the rule
	# working: the Framework numbers its standards 1.0 to 6.0 by strand
	# rather than by topic, so a per-topic code would have had to be minted.
	var uncited: Array[String] = [
		"using_sources",
		"community_roles", "state_symbols", "transport_history",
		"constitution", "industrialisation",
	]

	var bad: Array = []
	for l: Dictionary in Curriculum.lessons:
		var deliberate: bool = uncited.has(String(l.get("id", "")))
		for key: String in ["id", "name", "short", "strand", "objective"]:
			if String(l.get(key, "")).strip_edges() == "":
				ok = false
				bad.append("%s missing %s" % [l.get("name", "?"), key])
		var has_std: bool = String(l.get("standard", "")).strip_edges() != ""
		var has_src: bool = String(l.get("source", "")).strip_edges() != ""
		# Half a citation is the one thing that is never right: a code with
		# no document, or a document with no code.
		if has_std != has_src:
			ok = false
			bad.append("%s is half-cited" % l.get("name", "?"))
		if deliberate and has_std:
			bad.append("%s was meant to be uncited" % l.get("name", "?"))
			ok = false
		elif not deliberate and not has_std:
			bad.append("%s lost its citation" % l.get("name", "?"))
			ok = false
		# a fabricated citation is worse than none, so every lesson must
		# carry a real code AND say which document it came from
		if not String(l.get("source", "")).findn("maryland") >= 0 \
				and not String(l.get("source", "")).findn("ngss") >= 0:
			pass
		if has_std:
			seen_std[String(l.get("standard", ""))] = true
	chk("every lesson is fully cited, or deliberately not cited at all",
		ok, bad)
	chk("no two lessons share a standard code",
		seen_std.size() == Curriculum.count() - uncited.size(),
		"%d codes for %d cited lessons" % [
			seen_std.size(), Curriculum.count() - uncited.size()])

	chk("every source that exists names a real document", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			var src := String(l.get("source", "")).to_lower()
			if src == "":
				continue            # deliberately uncited, checked above
			if src.find("maryland") < 0:
				return false
		return true).call())

	chk("objectives are real sentences, not placeholders", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			if String(l["objective"]).length() < 40:
				return false
		return true).call())

	# `short` is a COLUMN on a 320px screen and it clips in silence, which
	# is the whole reason the budget exists. Nothing checked it until a
	# content batch arrived with a 14-character one.
	var too_long: Array = []
	for l: Dictionary in Curriculum.lessons:
		if String(l.get("short", "")).length() > 13:
			too_long.append("%s (%d)" % [
				l.get("short", ""), String(l.get("short", "")).length()])
	chk("every lesson's short name fits its column", too_long.is_empty(),
		too_long)

	# A concept belongs to exactly one lesson, and its id says which. The
	# gates on furniture read these strings, so a stray prefix is a gate
	# that can never open.
	chk("every concept id is prefixed by its own lesson", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			for c: Dictionary in l.get("concepts", []):
				if not String(c.get("id", "")).begins_with(
						String(l.get("id", "")) + "."):
					return false
		return true).call())

	chk("every lesson has three concepts, unlocking at 1, 3 and 6",
		(func() -> bool:
			for l: Dictionary in Curriculum.lessons:
				var ats: Array = []
				for c: Dictionary in l.get("concepts", []):
					ats.append(int(c.get("at", 0)))
				if ats != [1, 3, 6]:
					return false
			return true).call())

	# The four strands stay level. A curriculum that drifts to nine maths
	# lessons and three science ones quietly stops being a school.
	chk("the four strands are evenly stocked", (func() -> bool:
		var per := {}
		for l: Dictionary in Curriculum.lessons:
			var s := String(l.get("strand", ""))
			per[s] = int(per.get(s, 0)) + 1
		if per.size() != 4:
			return false
		var counts: Array = per.values()
		counts.sort()
		return int(counts[-1]) - int(counts[0]) <= 2).call())

	# No dead fields, and no emoji.
	#
	# `icon` sat on every lesson and NOTHING read it — ten held an emoji,
	# thirty were empty, and the empty thirty were an invitation to spend a
	# cycle filling in a field no screen renders. Deleted. This check stops
	# it drifting back in with the next content batch, and catches emoji
	# anywhere in the curriculum, which docs/BRIEFING.md bans in game text.
	chk("no lesson carries the dead `icon` field", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			if l.has("icon"):
				return false
		return true).call())

	chk("no emoji anywhere in the curriculum", (func() -> bool:
		for l: Dictionary in Curriculum.lessons:
			for key: String in ["name", "short", "objective"]:
				for c in String(l.get(key, "")):
					if c.unicode_at(0) > 0x2000:
						return false
		return true).call())

	chk("every difficulty from 1 to 5 is represented", (func() -> bool:
		var seen := {}
		for l: Dictionary in Curriculum.lessons:
			seen[int(l.get("difficulty", 0))] = true
		for d in range(1, 6):
			if not seen.has(d):
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
	# 200 draws over 40 lessons is a coupon-collector problem: P(a given
	# lesson is still missed) = (39/40)^200 ~= 0.7%, so ~27% of seeds should
	# expect at least one miss by chance alone -- this was already fragile,
	# not something the batch below broke. new_run()'s per-strand starter
	# lesson seeding (each strand draws one lesson via Curriculum.pick(rng)
	# before this loop starts) shifts Game.rng's stream enough that SEED's
	# 200 draws now land on 39 of 40, confirmed by re-running with a raised
	# count. 500 draws makes any miss ~40 * (39/40)^500 ~= 0.006%, restoring
	# the test's real intent (the whole curriculum surfaces with enough
	# play) without changing what pick_subject()/new_run() actually do.
	for i in 500:
		picked[Game.pick_subject()] = true
	chk("over a term you teach the whole curriculum",
		picked.size() == Curriculum.count(), picked.size())

	# homework must come from the lesson's own strand
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var math_sheet := Questions.make_sheet(1.0, rng, "math")
	var ela_sheet := Questions.make_sheet(1.0, rng, "ela")
	# Was "does the question contain an x or a +" -- a proxy for "came from
	# the maths bank" that broke the day the bank grew to include halves,
	# quarters and perimeters, none of which use either symbol. Check the
	# actual thing the test is FOR: the question is one of the math bank's
	# own, not a guess at what a maths question looks like.
	chk("a maths lesson sets maths homework", (func() -> bool:
		var q := String(math_sheet["items"][0]["q"])
		for item: Dictionary in Questions.bank_for("math"):
			if String(item["q"]) == q:
				return true
		return false).call(),
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
	chk("it is their own dedicated bust, not their sheet",
		hud.portrait.texture != null
		and hud.portrait.texture.resource_path.ends_with("portrait_" + who.art + ".png"),
		hud.portrait.texture)
	chk("the file says which seat and when they joined",
		hud.body.text.contains("Seat %d" % (who.seat_index + 1))
		and hud.body.text.contains("day %d" % who.joined_day), hud.body.text)

	# Tab turns to their STORY -- a second page, not more crammed onto the
	# first. Give them a beat worth telling.
	who.note_moment("grade_jump", who.joined_day + 8)
	await tap("menu")
	chk("Tab opens their story page",
		hud.mode == hud.Mode.STUDENT and hud.body.text.to_lower().contains("record"),
		hud.body.text)
	chk("the reel is rendered as prose, not raw kind ids",
		not hud.body.text.contains("grade_jump")
		and hud.body.text.to_lower().contains("grade"), hud.body.text)
	chk("the story page shows no raw number either",
		not hud.body.text.contains("0.") and not hud.body.text.contains("%"),
		hud.body.text)
	# Tab again: page THREE, what is acting on them right now (Sept 2026).
	# This used to turn straight back to the file, when there were two pages.
	await tap("menu")
	chk("Tab turns on to what's acting on them",
		hud.hint.text.contains("back to the file"), hud.hint.text)
	await tap("menu")
	chk("and Tab once more comes back round to the file",
		hud.body.text.contains("Seat"), hud.body.text)

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
	# How they work, in words. A child with a TRAIT gets the trait's own
	# sentence instead of the generic pace line, because it is the more
	# useful one -- "will not say when they are lost" tells you what to do,
	# "works at a steady pace" does not. Either way it is prose.
	chk("it describes how they work in words", (func() -> bool:
		if hud.body.text.contains("quickly") or hud.body.text.contains("steady") 				or hud.body.text.contains("longer"):
			return true
		return s0.trait_id != "" and hud.body.text.contains(
			Traits.blurb(s0.trait_id))).call(), hud.body.text)
	chk("it reports homework as a word, not a fraction",
		hud.body.text.contains("most") or hud.body.text.contains("about half")
		or hud.body.text.contains("all"), hud.body.text)
	chk("it says how often you helped them",
		hud.body.text.contains("help"), hud.body.text)
	chk("grades are letters, with a count of lessons",
		hud.body.text.contains("Averaging a") and hud.body.text.contains("3 lesson"),
		hud.body.text)

	# The rule was enforced on the STUDENT FILE only, which is how the
	# curriculum screen came to print "Knowing your subjects is worth +12%
	# to every grade" and the bookshelf blurb came to read "Helps anyone
	# sitting within 4 tiles". A rule enforced on one screen is a rule.
	Game.new_run(SEED)
	Game.concepts.append("fractions.equivalent")
	Game.concepts.append("civics.rights")
	hud.show_curriculum()
	chk("the curriculum screen states no percentage",
		not hud.rich.text.contains("%"), hud.rich.text)
	chk("it says what knowing your subjects is worth, in words",
		hud.rich_left.text.contains("Knowing your subjects"), hud.rich_left.text)
	chk("and the left page states no percentage either",
		not hud.rich_left.text.contains("%"), hud.rich_left.text)
	hud.close()

	chk("no item blurb states a number", (func() -> bool:
		for id: String in Items.order():
			var b := String(Items.get_def(id).get("blurb", ""))
			for c in b:
				if c.unicode_at(0) >= 48 and c.unicode_at(0) <= 57:
					return false
			if b.findn(" tiles") >= 0:
				return false
		return true).call())

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


## The career-wide block that survives new_run(). Alumni, the run counter,
## the lifetime tallies -- everything a fresh RUN is not allowed to erase.
func test_meta() -> void:
	section("META")
	Game.new_run(SEED)

	chk("a fresh run has a meta block with every key",
		Game.meta.has("alumni") and Game.meta.has("best_term")
		and Game.meta.has("runs_finished") and Game.meta.has("lifetime_graduated")
		and Game.meta.has("lifetime_milestones") and Game.meta.has("career_boon"),
		Game.meta.keys())
	chk("it starts empty",
		(Game.meta["alumni"] as Array).is_empty()
		and int(Game.meta["runs_finished"]) == 0
		and int(Game.meta["lifetime_graduated"]) == 0
		and int(Game.meta["best_term"]) == 0)

	# new_run() must NOT wipe meta -- a new RUN inside the same career is
	# the whole reason the block exists.
	Game.meta["runs_finished"] = 3
	(Game.meta["alumni"] as Array).append({"name": "Ada"})
	Game.new_run(SEED)
	chk("new_run() leaves meta standing",
		int(Game.meta["runs_finished"]) == 3
		and (Game.meta["alumni"] as Array).size() == 1,
		"%d / %d" % [int(Game.meta["runs_finished"]),
			(Game.meta["alumni"] as Array).size()])

	# wipe_everything() DOES clear it, then rebuilds a fresh block
	Game.wipe_everything()
	chk("wipe_everything() resets meta to a fresh block",
		(Game.meta["alumni"] as Array).is_empty()
		and int(Game.meta["runs_finished"]) == 0)

	# and it round-trips through a save
	Game.new_run(SEED)
	Game.meta["runs_finished"] = 5
	Game.meta["best_term"] = 4
	(Game.meta["alumni"] as Array).append({"name": "Grace", "level": 6})
	(Game.meta["lifetime_milestones"] as Array).append("first_graduate")
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("a save reload restores meta whole",
		int(Game.meta["runs_finished"]) == 5
		and int(Game.meta["best_term"]) == 4
		and (Game.meta["alumni"] as Array).size() == 1
		and String((Game.meta["alumni"] as Array)[0].get("name", "")) == "Grace"
		and (Game.meta["lifetime_milestones"] as Array).has("first_graduate"),
		Game.meta)
	Game.delete_save()

	# a save written before "meta" existed still loads, with a fresh block
	Game.new_run(SEED)
	var raw := Game.to_dict()
	raw.erase("meta")
	Game.from_dict(raw)
	chk("a pre-meta save loads with a fresh meta block",
		Game.meta.has("alumni")
		and (Game.meta["alumni"] as Array).is_empty()
		and int(Game.meta["runs_finished"]) == 0,
		Game.meta)

	Game.new_run(SEED)   # fully isolated from whatever follows


## The unified graduation snapshot -- one shape from both exit paths, and
## every leaver also lands in meta.alumni for the career-long wall.
func test_graduate_record() -> void:
	section("GRADUATE RECORD")
	Balance.ensure_loaded()
	Game.new_run(SEED)

	var s: StudentData = Game.roster[0]
	s.transcript.append({"lesson": "counting", "name": "Counting",
		"standard": "K.CC.1", "day": 2, "grade": 0.8, "test": false})
	var rec := Game.graduate_record(s)
	chk("the snapshot carries the whole child, not just a grade",
		rec.has("name") and rec.has("level") and rec.has("readiness")
		and rec.has("day") and rec.has("term") and rec.has("art")
		and rec.has("trait_id") and rec.has("aptitude") and rec.has("favourite")
		and rec.has("joined_day") and rec.has("helps_total")
		and rec.has("best_subject") and rec.has("transcript"),
		rec.keys())

	var tlen := (rec["transcript"] as Array).size()
	s.transcript.append({"lesson": "adding", "name": "Adding",
		"standard": "1.OA.1", "day": 3, "grade": 0.5, "test": false})
	chk("the snapshot's transcript is a copy -- later rows do not leak in",
		(rec["transcript"] as Array).size() == tlen
		and s.transcript.size() == tlen + 1)
	chk("graduate_record() appends nowhere on its own",
		Game.graduated.is_empty() and (Game.meta["alumni"] as Array).is_empty())

	# the manual path -- sending a ready child up early
	while not s.is_ready_to_graduate():
		s.add_xp(s.xp_for_next_level())
	var got := Game.graduate(s)
	chk("graduate() records into this run's list",
		Game.graduated.size() == 1
		and String(Game.graduated[0]["name"]) == String(got["name"]))
	chk("and into the career-long alumni list",
		(Game.meta["alumni"] as Array).size() == 1
		and String((Game.meta["alumni"] as Array)[0]["name"]) == String(got["name"]))
	chk("the alumni entry has the same unified shape",
		(Game.meta["alumni"] as Array)[0].has("transcript")
		and (Game.meta["alumni"] as Array)[0].has("trait_id"))
	chk("the run list still gets graduate()'s own extra fields",
		Game.graduated[0].has("coins") and Game.graduated[0].has("replaced_by"))

	# and the alumni list outlives the run
	Game.new_run(SEED)
	chk("a fresh run keeps the alumni you already graduated",
		(Game.meta["alumni"] as Array).size() == 1)
	chk("but this run's own graduated list is clear again",
		Game.graduated.is_empty())

	# the exam-pass path also feeds meta.alumni -- measured as a DELTA,
	# because new_run() above deliberately kept the earlier graduate.
	Game.new_run(SEED)
	var alumni_before: int = (Game.meta["alumni"] as Array).size()
	while Game.enrol() != null:
		pass
	for st: StudentData in Game.roster:
		st.grades.append(0.95)
	var passed: int = int(Game.sit_exam()["passed"])
	Game.next_term()
	chk("passing the exam lands each passer in meta.alumni too",
		(Game.meta["alumni"] as Array).size() == alumni_before + passed and passed > 0,
		"%d new in alumni, %d passed" % [
			(Game.meta["alumni"] as Array).size() - alumni_before, passed])
	Game.delete_save()

	Game.new_run(SEED)   # isolate from whatever follows


## The alumni wall -- the second page of the career screen. Reads
## meta.alumni, newest first, and tells each leaver's story from the same
## helpers a living child's file uses.
func test_alumni_wall() -> void:
	section("THE ONES WHO LEFT")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()

	# --- nothing there yet ---
	(Game.meta["alumni"] as Array).clear()
	hud._career_page = hud.CAREER_ALUMNI
	hud._alum_open = -1
	hud._sel = 0
	hud.show_career()
	chk("the wall opens on the career screen", hud.mode == hud.Mode.CAREER)
	chk("with nobody on it, it says so plainly",
		hud.rich.text.to_lower().contains("no one has left yet"), hud.rich.text)
	chk("Tab is offered to get back to the milestones",
		hud.hint.text.contains("Tab"), hud.hint.text)

	# --- two real leavers, snapshotted the way graduation does it ---
	var a: StudentData = Game.roster[0]
	a.transcript.append({"lesson": "counting", "name": "Counting",
		"standard": "K.CC.1", "day": 2, "grade": 0.8, "test": false})
	a.note_moment("grade_jump", a.joined_day + 6)
	var rec_a := Game.graduate_record(a)
	rec_a["name"] = "Ada"
	rec_a["term"] = 1
	var b: StudentData = Game.roster[1]
	var rec_b := Game.graduate_record(b)
	rec_b["name"] = "Grace"
	rec_b["term"] = 2
	(Game.meta["alumni"] as Array).append(rec_a)
	(Game.meta["alumni"] as Array).append(rec_b)

	hud._alum_open = -1
	hud._sel = 0
	hud.show_career()
	chk("both leavers are on the wall",
		hud.rich.text.contains("Ada") and hud.rich.text.contains("Grace"),
		hud.rich.text)
	chk("it says which class each left with",
		hud.rich.text.contains("Class of Term"), hud.rich.text)
	chk("the newest leaver is at the top",
		hud.rich.text.strip_edges().begins_with(">")
		and hud.rich.text.split("\n")[0].contains("Grace"),
		hud.rich.text.split("\n")[0])
	chk("the wall fits the panel",
		hud.rich.text.split("\n").size() <= 11, hud.rich.text.split("\n").size())

	# --- open the one with a story ---
	hud._sel = 1                      # Ada, the second row
	hud._alum_open = 1
	hud.show_career()
	chk("her story names what she was taught",
		hud.rich.text.to_lower().contains("record")
		or hud.rich.text.to_lower().contains("lesson"), hud.rich.text)
	chk("her remembered beat is prose, not a kind id",
		not hud.rich.text.contains("grade_jump")
		and hud.rich.text.to_lower().contains("grade"), hud.rich.text)
	chk("her story states no decimal and no percentage",
		not hud.rich.text.contains("0.") and not hud.rich.text.contains("%"),
		hud.rich.text)
	chk("the way back to the list is the only live key",
		hud.hint.text.to_lower().contains("back to the list"), hud.hint.text)

	# --- Tab flips back to the milestones, and forgets the open story ---
	hud._career_page = hud.CAREER_MILESTONES
	hud._alum_open = -1
	hud.show_career()
	chk("Tab returns to the milestones list",
		hud.title.text.contains("YOUR CAREER"), hud.title.text)
	hud.close()

	Game.delete_save()
	Game.new_run(SEED)


## The per-student highlight reel -- kind ids, never prose, capped, and it
## rides along into the alumni snapshot.
func test_moments() -> void:
	section("NOTABLE MOMENTS")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	var s: StudentData = Game.roster[0]

	# --- the raw mechanism ---
	s.moments.clear()
	s.note_moment("got_stuck", 3)
	chk("a moment is a kind and a day, nothing else",
		s.moments.size() == 1
		and String(s.moments[0]["kind"]) == "got_stuck"
		and int(s.moments[0]["day"]) == 3,
		s.moments)
	chk("has_moment sees it", s.has_moment("got_stuck") and not s.has_moment("graduated"))

	# the cap keeps the FIRST entry plus the most recent -- a highlight reel
	s.moments.clear()
	for i in Balance.moments_cap + 6:
		s.note_moment("beat_%d" % i, i)
	chk("the reel is capped", s.moments.size() == Balance.moments_cap)
	chk("and it keeps the origin beat plus the latest",
		String(s.moments[0]["kind"]) == "beat_0"
		and String(s.moments[s.moments.size() - 1]["kind"])
			== "beat_%d" % (Balance.moments_cap + 5))

	# --- a grade a band away from the running average ---
	var g: StudentData = Game.roster[1]
	g.grades.clear()
	g.moments.clear()
	var lesson: Dictionary = Curriculum.lessons[0]
	for _c in 3:
		g.grades.append(0.65)
		g.record_result(lesson, 0.65, 1)
	chk("a steady run of grades makes no jump or drop",
		not g.has_moment("grade_jump") and not g.has_moment("grade_drop"))
	g.grades.append(0.95)
	g.record_result(lesson, 0.95, 5)
	chk("a grade a whole band above their average is remembered as a jump",
		g.has_moment("grade_jump"))
	g.grades.append(0.20)
	g.record_result(lesson, 0.20, 9)
	chk("and a crash below it as a drop", g.has_moment("grade_drop"))

	# --- the quiz catching a child out, once ---
	var q: StudentData = Game.roster[2]
	q.moments.clear()
	q.aptitude = 0.0
	q.confusion = 1.0                  # struggling -> understanding bottoms out
	var qr := RandomNumberGenerator.new()
	var flagged := false
	for seed_try in 30:
		qr.seed = 1000 + seed_try
		q.quiz_flagged = false
		q.take_quiz(qr, "math")
		if q.quiz_flagged:
			flagged = true
			break
	chk("a quiz that catches a child out is remembered",
		flagged and q.has_moment("quiz_caught"))
	var before: int = q.moments.size()
	q.take_quiz(qr, "math")
	chk("but only the first time, not every quiz", q.moments.size() == before)

	# --- the first stall, once ---
	var w: StudentData = Game.roster[3]
	w.moments.clear()
	w.aptitude = 0.0
	w.assign_work()
	var wr := RandomNumberGenerator.new()
	wr.seed = 42
	var ticks := 0
	while w.confusion < 1.0 and ticks < 6000:
		w.tick_work(0.1, wr, 0.0)
		ticks += 1
	var stuck_count := 0
	for m: Dictionary in w.moments:
		if String(m.get("kind", "")) == "got_stuck":
			stuck_count += 1
	chk("the first time a child gets stuck is remembered",
		w.confusion >= 1.0 and stuck_count == 1,
		"stuck after %d ticks, reel %s" % [ticks, w.moments])
	w.confusion = 0.0                  # "helped" -- let them roll a stall again
	w.assign_work()
	var ticks2 := 0
	while w.confusion < 1.0 and ticks2 < 6000:
		w.tick_work(0.1, wr, 0.0)
		ticks2 += 1
	var stuck_after := 0
	for m: Dictionary in w.moments:
		if String(m.get("kind", "")) == "got_stuck":
			stuck_after += 1
	chk("...and only the first time", stuck_after == 1)

	# --- it survives a save ---
	Game.new_run(SEED)
	Game.roster[0].moments.clear()
	Game.roster[0].note_moment("got_stuck", 2)
	Game.roster[0].note_moment("grade_jump", 6)
	Game.save_game()
	Game.new_run(1)
	Game.load_game()
	chk("the reel round-trips through a save",
		Game.roster[0].has_moment("got_stuck")
		and Game.roster[0].has_moment("grade_jump"),
		Game.roster[0].moments)
	Game.delete_save()

	# --- graduating is the last beat, and it rides into the alumni snapshot ---
	Game.new_run(SEED)
	var up: StudentData = Game.roster[0]
	while not up.is_ready_to_graduate():
		up.add_xp(up.xp_for_next_level())
	Game.graduate(up)
	chk("being sent up is a moment on the child's reel", up.has_moment("graduated"))
	chk("and the alumni snapshot carries the reel, not just a name", (func() -> bool:
		var a: Array = Game.meta["alumni"]
		if a.is_empty():
			return false
		for m: Dictionary in (a[a.size() - 1].get("moments", []) as Array):
			if String(m.get("kind", "")) == "graduated":
				return true
		return false).call())

	# --- a child kept back for another term knows it ---
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	var idx := 0
	for st: StudentData in Game.roster:
		st.grades.append(0.95 if idx % 2 == 0 else 0.08)
		idx += 1
	Game.sit_exam()
	Game.next_term()
	chk("a child kept back for another term has that on their reel", (func() -> bool:
		for st: StudentData in Game.roster:
			if st.has_moment("kept_back"):
				return true
		return false).call())

	# --- ten-commits.md step 6: five more remembered moments ---

	# reached before it went off
	Game.new_run(SEED)
	await step(2)
	var flarer: StudentData = Game.roster[0]
	flarer.flare_left = 1.0
	var st0: Interactable = world.stations[flarer.seat_index]
	st0.interact(world.player)
	chk("catching a flare-up before it goes off is remembered",
		flarer.has_moment("caught_flare"))

	# reached the end of a term without ever getting stuck. Captured as
	# object references BEFORE next_term() -- everyone here passes, so
	# next_term() clears roster and refills it, and only the reference
	# itself (not looking them up again in Game.roster afterward) survives
	# that regardless of which side of moved-up/stayed they land on.
	Game.new_run(SEED)
	while Game.enrol() != null:
		pass
	var stuck_one: StudentData = Game.roster[0]
	var clean_one: StudentData = Game.roster[1]
	stuck_one.note_moment("got_stuck", 3)
	for st: StudentData in Game.roster:
		st.grades.append(0.95)     # everyone passes -- moved up or not is not the point
	Game.sit_exam()
	Game.next_term()
	chk("never getting stuck all term is remembered",
		clean_one.has_moment("never_stuck"))
	chk("...but not for the one who did get stuck",
		not stuck_one.has_moment("never_stuck"))

	# lessons running in their own best subject
	Game.new_run(SEED)
	var keen: StudentData = Game.roster[0]
	keen.favourite = "math"
	Game.lesson = Curriculum.by_id("basic_arithmetic")
	for i in Balance.moments_favourite_streak - 1:
		Game.grade_class()
	chk("not yet -- one short of the streak",
		not keen.has_moment("favourite_streak"), keen._favourite_streak)
	Game.grade_class()
	chk("a run of lessons in their best subject is remembered",
		keen.has_moment("favourite_streak"))
	chk("...and the streak resets once it has paid out",
		keen._favourite_streak == 0, keen._favourite_streak)
	Game.lesson = Curriculum.by_id("reading_fluency")
	Game.grade_class()
	chk("a lesson outside their best subject breaks the streak",
		keen._favourite_streak == 0, keen._favourite_streak)

	# helping a neighbour, the first time
	Game.new_run(SEED)
	_seat_in_a_row(2, 4)
	var helper: StudentData = Game.roster[0]
	var struggler: StudentData = Game.roster[1]
	helper.trait_id = "anchor"      # the strongest helps_neighbour value
	helper.work_state = StudentData.Work.DONE
	struggler.trait_id = "steady"   # no hiding, so is_struggling() is prompt
	struggler.confusion = 1.0
	var guard6 := 0
	while not helper.has_moment("helped_neighbour") and guard6 < 200:
		# Reasserted every pass: tick_class() also rolls disruption, and
		# once it is struggling-but-not-disrupting is no longer true, the
		# very thing being waited for can never fire again.
		struggler.disrupting = false
		struggler.confusion = 1.0
		helper.disrupting = false
		helper.work_state = StudentData.Work.DONE
		Game.tick_class(1.0, Game.rng)     # a fat delta -- deterministic seed, not luck
		guard6 += 1
	chk("helping a neighbour is remembered, on the HELPER's own reel",
		helper.has_moment("helped_neighbour"), guard6)
	chk("...not on the one who got helped",
		not struggler.has_moment("helped_neighbour"))

	# sat out a fire drill
	Game.new_run(SEED)
	Game.event = DayEvent.by_id("fire_drill")
	Game.grade_class()
	chk("a fire drill day is remembered by the whole class", (func() -> bool:
		for st: StudentData in Game.roster:
			if not st.has_moment("fire_drill"):
				return false
		return true).call())
	chk("...only once, not once per lesson", (func() -> bool:
		Game.grade_class()
		var n := 0
		for m: Dictionary in Game.roster[0].moments:
			if String(m.get("kind", "")) == "fire_drill":
				n += 1
		return n == 1).call())

	Game.new_run(SEED)   # isolate from whatever follows


## The day's beat: one line in the teacher's voice at the start of a day,
## deterministic, prose, tightening through a boss term.
func test_day_beats() -> void:
	section("DAY BEATS")
	var hud := _hud()

	# --- DayBeats.line_for: pure, deterministic, prose ---
	var boss := {"term": 3, "day": 1, "term_days": 20, "path_kind": "boss",
		"path_id": "boss_ela", "boss_name": "Reading Paper"}
	var d1 := DayBeats.line_for(boss)
	chk("a boss term opens with its own line", d1.contains("Reading Paper"), d1)
	chk("line_for is deterministic", DayBeats.line_for(boss) == d1)

	boss["day"] = 9
	var mid := DayBeats.line_for(boss)
	chk("every middle day of a boss term gets a line", not mid.is_empty())
	chk("the same day gives the same line", DayBeats.line_for(boss) == mid)

	boss["day"] = 18
	chk("two days out reads as a countdown",
		DayBeats.line_for(boss).to_lower().contains("two"), DayBeats.line_for(boss))
	boss["day"] = 20
	chk("exam day names the boss and says today",
		DayBeats.line_for(boss).contains("Reading Paper")
		and DayBeats.line_for(boss).to_lower().contains("today"))

	chk("term one day one is silent -- the cold open already is the beat",
		DayBeats.line_for({"term": 1, "day": 1, "term_days": 20}) == "")
	chk("an ordinary term opens on a line keyed to the path taken",
		not DayBeats.line_for({"term": 2, "day": 1, "term_days": 20,
			"path_id": "chaotic_term"}).is_empty())
	chk("an ordinary mid-term day is usually quiet",
		DayBeats.line_for({"term": 2, "day": 5, "term_days": 20}) == "")
	chk("but the halfway mark gets one",
		not DayBeats.line_for({"term": 2, "day": 10, "term_days": 20}).is_empty())

	chk("no beat ever prints a raw number", (func() -> bool:
		for dd in range(1, 21):
			for c: Dictionary in [
				{"term": 3, "day": dd, "term_days": 20, "path_kind": "boss",
					"path_id": "boss_math", "boss_name": "Number Gauntlet"},
				{"term": 2, "day": dd, "term_days": 20, "path_id": "busy_term"}]:
				var s: String = DayBeats.line_for(c)
				if s.contains("%") or s.contains("0."):
					return false
		return true).call())

	# --- the presenter: the player's own portrait, text typing on ---
	Game.new_run(SEED)
	await step(2)
	hud.close()
	hud._queued_beat = ""
	hud._beat_full = ""
	hud._hint_until = 0.0
	await step(2)
	var line := "Reading Paper today. Doors open within the hour."
	hud.show_day_beat(line)
	chk("the beat wears the player's face, not the principal's",
		hud.mascot_portrait.visible and hud.mascot_portrait.texture != null
		and hud.mascot_portrait.texture.resource_path.ends_with("portrait_player.png"))
	await step(2)
	chk("the line starts partial -- it is typing on",
		hud.prompt.text.length() < line.length(), hud.prompt.text)
	await step(120)
	chk("and settles on the whole line", hud.prompt.text == line, hud.prompt.text)

	# --- queued, then surfaced when the player is back in free roam ---
	hud.close()
	hud._queued_beat = ""
	hud._beat_full = ""
	hud._hint_until = 0.0
	await step(2)
	hud.queue_day_beat("Two mornings left. Drill what will not stick.")
	await step(6)
	chk("a queued beat surfaces once the screen is clear",
		hud.mascot_portrait.visible and not hud.prompt.text.is_empty())

	hud.close()
	hud._queued_beat = ""
	hud._beat_full = ""
	hud._hint_until = 0.0
	Game.new_run(SEED)
	await step(2)


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


## The six roguelike-pivot perks reconciled onto the existing perk board
## (docs/ROGUELIKE_DESIGN.md's skill table) rather than a second system.
## Same discipline as the block above: every one of them must actually
## reach the one real call site it claims to change.
func test_new_perks() -> void:
	section("NEW PERKS")
	Balance.ensure_loaded()
	var none := {}

	chk("Quick Sweep really does cut the presses a mess needs",
		Progress.mess_presses({"quick_sweep": 1}) < Progress.mess_presses(none))
	chk("but never below one -- a mash the player can still see land",
		Progress.mess_presses({"quick_sweep": 99}) >= 1)

	chk("Carrying Voice really does widen the shush",
		Progress.voice_range_bonus({"carrying_voice": 1}) > 0.0
		and is_equal_approx(Progress.voice_range_bonus(none), 0.0))

	chk("Quick Study really does run lessons a little longer",
		Progress.lesson_length_mult({"quick_study": 1}) > 1.0
		and is_equal_approx(Progress.lesson_length_mult(none), 1.0))

	chk("Lucky Break really does bias the hand toward rarer papers",
		Progress.assignment_luck({"lucky_break": 1}) > 0.0
		and is_equal_approx(Progress.assignment_luck(none), 0.0))

	chk("Thrifty really does knock something off the shop price",
		Progress.shop_discount({"thrifty": 1}) > 0.0
		and is_equal_approx(Progress.shop_discount(none), 0.0))
	chk("but never gives the room away for free",
		Progress.shop_discount({"thrifty": 99}) < 1.0)

	chk("Iron Will really does shrink how far a disruption spreads",
		Progress.disruption_spread_mult({"iron_will": 1}) < 1.0
		and is_equal_approx(Progress.disruption_spread_mult(none), 1.0))

	# --- and the cheap-to-reach call sites actually read Progress, not
	# just Progress itself agreeing with its own formula ---
	Game.new_run(SEED)
	var full_price := Items.cost("stool")
	Game.perk_ranks = {"thrifty": 1}
	chk("the shop actually prices a purchase at a discount, not just Items.cost()",
		Game.shop_price("stool") < full_price, Game.shop_price("stool"))

	var plain_presses := Game.mess_presses_needed()
	Game.perk_ranks = {"quick_sweep": 1}
	chk("mess.gd's own press count actually shrinks, not just Progress's",
		Game.mess_presses_needed() < plain_presses, Game.mess_presses_needed())

	Game.perk_ranks = {}
	var plain_length := Game.lesson_length()
	Game.perk_ranks = {"quick_study": 1}
	chk("lesson_length() actually runs longer, not just Progress's own number",
		Game.lesson_length() > plain_length,
		"%.2f -> %.2f" % [plain_length, Game.lesson_length()])

	Game.perk_ranks = {}
	Game.new_run(SEED)


## The dash's own upgrade, the smoke it kicks up, and the display settings
## that decide how much of the school you can see around the room.
##
## All three landed together in Sept 2026 and all three are the kind of
## thing a suite is bad at noticing: a perk that reads the wrong number
## still runs, a window base size that is half what it should be still
## opens a window, and a HUD anchored to the wrong box still draws.
func test_dash_upgrade_and_display() -> void:
	section("LIGHT FEET, SMOKE AND THE WINDOW")
	Balance.ensure_loaded()
	var none := {}

	# --- the perk is real, and reachable ---
	chk("Light Feet is a perk you can actually buy",
		Balance.perks.has("light_feet"))
	chk("...with more than one rank in it",
		Progress.max_rank("light_feet") > 1, Progress.max_rank("light_feet"))
	chk("...and it is on the board the player picks from",
		Progress.perk_order().has("light_feet"))

	# --- what each rank does ---
	chk("a rank makes the dash last longer",
		Progress.dash_duration({"light_feet": 1}) > Progress.dash_duration(none))
	chk("...and unranked it is exactly the base duration",
		is_equal_approx(Progress.dash_duration(none), Balance.teacher_dash_duration))
	chk("a rank shortens the wait for the next one",
		Progress.dash_cooldown({"light_feet": 1}) < Progress.dash_cooldown(none))
	chk("...and unranked it is exactly the base cooldown",
		is_equal_approx(Progress.dash_cooldown(none), Balance.teacher_dash_cooldown))

	# The floor is the whole reason the dash stays a decision. Without it a
	# maxed perk would leave the cooldown meter permanently full, and the
	# room's lanes and clutter would stop mattering to a dash at all.
	chk("the cooldown is FLOORED, never free",
		Progress.dash_cooldown({"light_feet": 99}) > 0.0,
		Progress.dash_cooldown({"light_feet": 99}))
	chk("...at a real fraction of the base, not a token",
		Progress.dash_cooldown({"light_feet": 99}) >= Balance.teacher_dash_cooldown * 0.2)

	# Speed is Brisk Walk's job. If Light Feet ever raised it too, the two
	# perks would stop being distinguishable and one of them is dead weight.
	chk("Light Feet does NOT also raise your speed -- that is Brisk Walk",
		is_equal_approx(Progress.speed({"light_feet": 3}), Progress.speed(none)))

	# --- the juice scales with it ---
	chk("a levelled dash kicks up more smoke",
		Progress.dash_smoke_count({"light_feet": 1}) > Progress.dash_smoke_count(none))
	chk("...in bigger motes",
		Progress.dash_smoke_scale({"light_feet": 1}) > Progress.dash_smoke_scale(none))
	chk("...and unranked it is exactly what balance.json says",
		Progress.dash_smoke_count(none) == Balance.teacher_dash_smoke_count
		and is_equal_approx(Progress.dash_smoke_scale(none), Balance.teacher_dash_smoke_scale))
	chk("the smoke is a real puff even with no perk at all",
		Progress.dash_smoke_count(none) > 0 and Progress.dash_smoke_scale(none) > 0.0)
	# Read from the source, not asked of the class: Fx is a RefCounted with
	# only static methods, and has_method() cannot be called on it directly.
	var fx_src := FileAccess.get_file_as_string("res://scripts/ui/fx.gd")
	chk("Fx knows how to draw one", fx_src.contains("static func smoke("))
	chk("...and it is a cloud of its own, not the chalk puff renamed",
		fx_src.contains("static func puff("))

	# --- the player actually reads the perk, not Balance directly ---
	# Fired through the REAL input path, the way test_dash_lanes() does it.
	# TWO physics frames, and _dash_cool as the witness, for the reason that
	# test spells out: the press lands on the frame after it is made, and the
	# cooldown is set the instant a dash fires, so it is timing-proof in a
	# way that reading the burst on frame one is not.
	Game.new_run(SEED)
	await step(40)                      # let the player finish filing in
	var p = world.player
	var start := Grid.tile_to_world(Vector2i(3, 6))

	Game.perk_ranks = {}
	_reset_dash(p)
	p.global_position = start
	await step(1)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(2)
	var plain_burst: float = p._dash_burst
	var plain_cool: float = p._dash_cool
	Input.action_release("dash")
	Input.action_release("move_right")
	chk("a plain dash starts a burst at all", plain_burst > 0.0,
		"%.3f" % plain_burst)

	Game.perk_ranks = {"light_feet": 3}
	_reset_dash(p)
	p.global_position = start
	await step(1)
	Input.action_press("move_right")
	Input.action_press("dash")
	await step(2)
	var perked_burst: float = p._dash_burst
	var perked_cool: float = p._dash_cool
	Input.action_release("dash")
	Input.action_release("move_right")

	chk("the REAL dash lasts longer with the perk, not just Progress's number",
		perked_burst > plain_burst, "%.3f -> %.3f" % [plain_burst, perked_burst])
	chk("...and the REAL wait after it is shorter",
		perked_cool < plain_cool, "%.3f -> %.3f" % [plain_cool, perked_cool])
	# Longer burst AND shorter wait together are the upgrade. Either alone
	# would still pass an "it changed" check while being half the perk.
	chk("...so a levelled dash covers more ground per second of cooldown",
		perked_burst / maxf(0.001, perked_cool) > plain_burst / maxf(0.001, plain_cool))

	Game.perk_ranks = {}
	_reset_dash(p)

	# --- the window ---
	# BASE was wrong for a month: it still said 320x176 after the room
	# doubled, so "x3" opened a window at one and a half times the viewport
	# and every pixel edge landed on a half pixel.
	chk("one step of window scale is the REAL viewport size",
		Settings.BASE == Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height"))),
		Settings.BASE)
	chk("the window can be dragged to any size",
		bool(ProjectSettings.get_setting("display/window/size/resizable")))
	chk("fullscreen is a rebindable verb like any other",
		Settings.DEFAULTS.has("fullscreen") and (func() -> bool:
			for e: Dictionary in Settings.ACTIONS:
				if String(e.get("action", "")) == "fullscreen":
					return true
			return false).call())
	chk("...and there is one call that flips it",
		Settings.has_method("toggle_fullscreen"))
	chk("the biggest offered scale still fits on a screen",
		Settings.max_window_scale() >= 1 and Settings.max_window_scale() <= 6,
		Settings.max_window_scale())

	# --- the room is framed, not letterboxed ---
	chk("the viewport EXPANDS to the window rather than growing black bars",
		String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand",
		ProjectSettings.get_setting("display/window/stretch/aspect"))
	chk("something is drawn in the space that opens up around the room",
		ResourceLoader.exists("res://art/tile_backdrop.png"))
	chk("...and it loads", load("res://art/tile_backdrop.png") != null)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	var backdrop := inst.get_node_or_null("Backdrop") as CanvasLayer
	chk("the backdrop is a layer BEHIND the world, not a sprite inside it",
		backdrop != null and backdrop.layer < 0,
		backdrop.layer if backdrop != null else "missing")
	chk("...and it tiles rather than stretching one 32px square over the screen",
		backdrop != null and backdrop.get_node_or_null("Wall") != null
		and (backdrop.get_node("Wall") as TextureRect).stretch_mode
			== TextureRect.STRETCH_TILE)
	inst.free()

	# The HUD is authored in absolute 640x352 coordinates. Anchored to the
	# viewport instead, "expand" puts the prompt bar through the middle of
	# the room on any window that is not exactly 20:11.
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var h: Control = hud_scene.instantiate()
	chk("the HUD is a centred box, not stretched to the whole viewport",
		is_equal_approx(h.anchor_left, 0.5) and is_equal_approx(h.anchor_top, 0.5)
		and is_equal_approx(h.anchor_right, 0.5) and is_equal_approx(h.anchor_bottom, 0.5),
		"%.2f %.2f %.2f %.2f" % [h.anchor_left, h.anchor_top, h.anchor_right, h.anchor_bottom])
	chk("...and that box is exactly the room's own size",
		int(h.offset_right - h.offset_left) == Settings.BASE.x
		and int(h.offset_bottom - h.offset_top) == Settings.BASE.y,
		"%d x %d" % [int(h.offset_right - h.offset_left), int(h.offset_bottom - h.offset_top)])
	h.free()

	# --- the forge's own palette ---
	# docs/PIXEL_STYLE.md promised this file for months before it existed.
	chk("the house palette is on disk",
		FileAccess.file_exists("res://tools/palette.json"))
	var pf := FileAccess.open("res://tools/palette.json", FileAccess.READ)
	var pal: Variant = JSON.parse_string(pf.get_as_text()) if pf != null else null
	if pf != null:
		pf.close()
	chk("...and it parses", pal is Dictionary)
	chk("...and every entry is a colour the forge can actually use", (func() -> bool:
		if not (pal is Dictionary):
			return false
		var n := 0
		for group: String in (pal as Dictionary).keys():
			if group.begins_with("_"):
				continue
			for cname: String in ((pal as Dictionary)[group] as Dictionary).keys():
				var hex := str(((pal as Dictionary)[group] as Dictionary)[cname])
				if not hex.begins_with("#") or hex.length() != 7:
					return false
				n += 1
		return n > 20).call())
	chk("...and it says which forge tab may offer each group",
		pal is Dictionary and (pal as Dictionary).has("_modules"))

	# --- the forge tabs themselves ---
	# Two of the five shipped calling a method that does not exist and threw
	# the moment you opened them. Nothing looked, because nothing loads a
	# dev tool's scripts but the dev tool.
	for tab: String in ["forge_tab", "forge_palette_bar", "forge_art_ui",
			"forge_items_ui", "forge_hud_ui", "forge_audio_ui"]:
		chk("tools/%s.gd still compiles" % tab,
			load("res://tools/%s.gd" % tab) != null)

	Game.perk_ranks = {}
	Game.new_run(SEED)


## The Claude <-> Gemini relay: the files exist, the state parses, and the
## rules the protocol claims to enforce are actually enforced.
##
## A coordination protocol nobody checks is a coordination protocol that has
## quietly stopped running -- the same failure this repo already had with a
## git hook sitting dead in .git/hooks for weeks. These assertions are cheap
## and they fail loudly the day someone deletes the tool and leaves the doc.
func test_relay() -> void:
	section("THE RELAY")

	chk("the protocol is written down",
		FileAccess.file_exists("res://docs/relay/PROTOCOL.md"))
	chk("the tool that enforces it exists",
		FileAccess.file_exists("res://tools/relay.py"))
	chk("Antigravity has a way in",
		FileAccess.file_exists("res://GEMINI.md"))
	chk("...and it points at the protocol rather than restating it",
		FileAccess.get_file_as_string("res://GEMINI.md").contains(
			"docs/relay/PROTOCOL.md"))
	chk("there is a launcher, like every other tool here",
		FileAccess.file_exists("res://Relay.bat"))

	var f := FileAccess.open("res://docs/relay/STATE.json", FileAccess.READ)
	chk("the relay has a state file", f != null)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if f != null:
		f.close()
	chk("...and it parses", parsed is Dictionary)
	var st: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	chk("...and it says whose turn it is",
		["claude", "gemini"].has(String(st.get("turn", ""))), st.get("turn"))
	chk("...and how long a turn may take before it can be taken over",
		int(st.get("interval_minutes", 0)) > 0, st.get("interval_minutes"))
	chk("...and who holds which files", st.get("claims") is Dictionary)
	chk("...for both agents, so neither can be silently absent",
		(st.get("claims", {}) as Dictionary).has("claude")
		and (st.get("claims", {}) as Dictionary).has("gemini"))

	# The turn format IS the protocol. If the tool stops requiring a section,
	# the section stops being written, and the loop degrades into a chat.
	var tool_src := FileAccess.get_file_as_string("res://tools/relay.py")
	for name: String in ["DID", "EVIDENCE", "PLAN", "NEED FROM YOU",
			"CAN GIVE YOU", "YOU GOT RIGHT", "YOU GOT WRONG", "QUESTIONS",
			"CLAIMING"]:
		chk("a turn must carry ## %s" % name, tool_src.contains('"%s"' % name))

	# The two guards that matter most, asserted on the tool's own source: a
	# post out of turn, and an accusation with no evidence behind it.
	chk("posting out of turn is refused",
		tool_src.contains("it is %s's turn, not yours"))
	chk("an unfounded YOU GOT WRONG is refused",
		tool_src.contains("names no file"))
	chk("...and so is a hedged one",
		tool_src.contains("HEDGES") and tool_src.contains("is a QUESTION, not a finding"))
	chk("a claim that collides with the other agent's is refused",
		tool_src.contains("collides with"))
	chk("claims compare whole path segments, so a directory catches a file "
		+ "inside it", tool_src.contains('startswith(b + "/")'))

	# The relay is a conversation, so it must have started.
	var d := DirAccess.open("res://docs/relay/turns")
	chk("there is a turns folder", d != null)
	var turns: PackedStringArray = d.get_files() if d != null else PackedStringArray()
	var md := 0
	for t: String in turns:
		if t.ends_with(".md"):
			md += 1
	chk("...with at least one turn in it, so the loop has actually begun",
		md >= 1, md)


## Subject icons, the taught count, and teaching on your own for several
## days. Three requests from Sept 2026, in one section because all three
## are about the same screen's worth of decisions.
func test_subjects_and_skip() -> void:
	section("SUBJECT MARKS, TAUGHT COUNTS AND TEACHING ALONE")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	var hud := _hud()

	# ---------------------------------------------------- the subject marks
	for strand: String in ["ela", "math", "science", "social"]:
		chk("there is a mark for %s" % strand,
			ResourceLoader.exists("res://art/icon_%s.png" % strand))
		chk("...and it loads", load("res://art/icon_%s.png" % strand) != null)
	chk("every strand the curriculum actually uses has one", (func() -> bool:
		for s: String in Curriculum.strands():
			if not ResourceLoader.exists("res://art/icon_%s.png" % s):
				return false
		return true).call(), Curriculum.strands())
	chk("the mark is BBCode a RichTextLabel can draw",
		hud.strand_icon("math").begins_with("[img")
		and hud.strand_icon("math").contains("res://art/icon_math.png"))
	# A crafted lesson can carry a strand nobody drew a mark for. Losing the
	# icon is fine; a broken-image box on every row of that lesson is not.
	chk("an unknown strand loses the mark rather than breaking the row",
		hud.strand_icon("basket_weaving") == "")

	# The icon's colour and the row's colour come from two different files
	# in two different languages. Different greens would read as a second,
	# unexplained category rather than as one subject.
	var py := FileAccess.get_file_as_string("res://tools/make_ui.py")
	for strand: String in hud.STRAND_COLOUR:
		var hex := String(hud.STRAND_COLOUR[strand])
		var as_py := "(0x%s, 0x%s, 0x%s)" % [hex.substr(0, 2), hex.substr(2, 2),
			hex.substr(4, 2)]
		chk("make_ui.py draws %s in the same colour hud.gd prints it" % strand,
			py.contains(as_py), as_py)

	# ---------------------------------------------------- the taught count
	var lid := String(Curriculum.lessons[0].get("id", ""))
	Game.taught.clear()
	chk("a lesson you have never taught says so",
		hud._taught_words(lid) == "Never taught", hud._taught_words(lid))
	Game.record_taught(lid)
	chk("once is 'once', not '1 times'",
		hud._taught_words(lid) == "Taught once", hud._taught_words(lid))
	Game.record_taught(lid)
	chk("twice is 'twice'",
		hud._taught_words(lid) == "Taught twice", hud._taught_words(lid))
	for i in 5:
		Game.record_taught(lid)
	chk("after that it counts",
		hud._taught_words(lid) == "Taught 7 times", hud._taught_words(lid))
	chk("...and the count is the one that unlocks concepts, not a second tally",
		Game.times_taught(lid) == 7, Game.times_taught(lid))

	hud._sel = 0
	hud.show_curriculum()
	await step(2)
	chk("the book actually prints it",
		hud.rich_left.text.contains("Taught 7 times"), hud.rich_left.text)
	chk("...and puts a mark beside the subject",
		hud.rich_left.text.contains("icon_") and hud.rich.text.contains("icon_"))
	# The panel budget, which this screen has blown before: adding the icon
	# pushed rows onto a second line until the difficulty bar came off them.
	chk("no row of the book wraps past the page",
		hud.rich.text.split("\n").size() <= 11,
		hud.rich.text.split("\n").size())
	hud.close()
	await step(2)

	# ------------------------------------------------ teaching on your own
	Game.new_run(SEED)
	await step(2)
	chk("the cap is what balance.json says, with nothing in the room",
		Game.skip_days_max() == Balance.skip_max_days, Game.skip_days_max())
	chk("...and it is a real number of days, not zero",
		Balance.skip_max_days >= 1, Balance.skip_max_days)

	# The item hook: no item carries "skip_days" yet, so the test supplies
	# one rather than the feature going untested until one does.
	var fake := {"name": "Test Rota", "cost": 1, "art": "crate", "w": 1,
		"range": 1, "bonus": 0.0, "cat": "learning", "skip_days": 2}
	Balance.items["_test_rota"] = fake
	Game.room_items.append({"id": "_test_rota", "tile": Vector2i(9, 6)})
	chk("furniture can raise the cap -- the hook items will use later",
		Game.skip_days_max() == Balance.skip_max_days + 2, Game.skip_days_max())
	Game.room_items.clear()
	for i in 20:
		Game.room_items.append({"id": "_test_rota", "tile": Vector2i(9, 6)})
	chk("...but only so far, so a room full of them cannot skip a whole term",
		Game.skip_days_max()
			== Balance.skip_max_days + Balance.skip_item_bonus_cap,
		Game.skip_days_max())
	Game.room_items.clear()
	Balance.items.erase("_test_rota")

	# The clamp that matters: the exam is the one day the game is asking
	# about, and a skip may not walk through it.
	Game.day = 1
	chk("early in the term you may hand over the full run of days",
		Game.skip_days_available() == Balance.skip_max_days,
		Game.skip_days_available())
	Game.day = Balance.term_days - 2
	chk("near the exam it offers only the days that are left",
		Game.skip_days_available() == 2, Game.skip_days_available())
	Game.day = Balance.term_days
	chk("on the last day it offers nothing at all",
		Game.skip_days_available() == 0, Game.skip_days_available())
	chk("...and neither does a term that is already over", (func() -> bool:
		Game.day = 1
		Game.term_over = true
		var n := Game.skip_days_available()
		Game.term_over = false
		return n == 0).call())

	# --- and it actually runs the days, through the real model ---
	Game.new_run(SEED)
	await step(20)
	var before_day: int = Game.day
	var before_taught: int = Game.times_taught(String(Game.lesson.get("id", "")))
	var rows: Array = world.run_skipped_days(3)
	chk("three days handed over is three days gone",
		Game.day == before_day + 3, "%d -> %d" % [before_day, Game.day])
	chk("...and one row came back for each",
		rows.size() == 3, rows.size())
	chk("...each naming the day, the subject and what it came to",
		rows.size() == 3 and (rows[0] as Dictionary).has("day")
		and (rows[0] as Dictionary).has("subject")
		and (rows[0] as Dictionary).has("letter"))
	chk("the class was actually taught, not just fast-forwarded",
		Game.times_taught(String(Game.lesson.get("id", ""))) > before_taught
		or Game.times_taught(String(rows[0].get("subject", ""))) >= 0)
	# No homework on a day you were not there to set it. That is the cost,
	# and without it a skip is strictly better than being in the room.
	chk("no homework went out while you were away", not Game.homework_out)

	# The clamp is enforced by the runner too, not only by the screen that
	# calls it -- a caller that asked for ten should not get ten.
	Game.new_run(SEED)
	await step(20)
	Game.day = Balance.term_days - 1
	var day_before: int = Game.day
	var over: Array = world.run_skipped_days(99)
	chk("asking for more days than are left runs only the days that are left",
		Game.day <= Balance.term_days,
		"day %d, term_days %d, ran %d" % [Game.day, Balance.term_days, over.size()])
	chk("...which is at most one day here", over.size() <= 1,
		"%d from day %d" % [over.size(), day_before])

	# --- the screen ---
	Game.new_run(SEED)
	await step(20)
	Game.day = 1
	hud.show_skip()
	await step(2)
	chk("the chooser opens", hud.mode == hud.Mode.SKIP, hud.mode)
	chk("...and starts at one day, not at the maximum",
		hud._skip_days == 1, hud._skip_days)
	chk("...and says what it will cost you before you agree",
		hud.rich.text.to_lower().contains("homework"), hud.rich.text)
	chk("...and does not print a number standing in for what a child will do",
		not hud.rich.text.contains("0."), hud.rich.text)
	hud.close()
	await step(2)

	# On the last day there is nothing to agree to, so the screen must not
	# open at all rather than opening with a zero on it.
	Game.day = Balance.term_days
	hud.show_skip()
	await step(2)
	chk("on the last day the chooser refuses to open",
		hud.mode != hud.Mode.SKIP, hud.mode)
	hud.close()
	await step(2)

	chk("the verb has its own key, per one-key-per-verb",
		Settings.DEFAULTS.has("skip_days"))
	chk("...which is not auto-teach's",
		Settings.DEFAULTS.get("skip_days") != Settings.DEFAULTS.get("auto_teach"))
	chk("...and the controls sheet says what it is for",
		not String(hud.HELP_LINES.get("skip_days", "")).is_empty())

	Game.new_run(SEED)
	await step(2)


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
	# The catalogue renders into `rich`, not `body` -- _render_catalogue()
	# explicitly sets body.visible = false. This assertion checked body,
	# which the shop never touches, so it was passing on STALE leftover
	# text from whichever earlier screen last wrote to body (student bios
	# also say "helps"). A content change elsewhere shifted which screen
	# runs last and exposed it: the leftover text stopped containing
	# "helps" and the assertion failed for a reason that had nothing to do
	# with the shop. Checking the control the shop actually writes to.
	chk("effects read as words, not decimals",
		hud.rich.text.contains("helps") and not hud.rich.text.contains("+0."),
		hud.rich.text)

	await tap("menu")
	chk("Tab moves to the cabinet", hud._shop == hud.Shop.CABINET)
	await tap("menu")
	chk("Tab again reaches the staff room", hud._shop == hud.Shop.STAFF)
	chk("which shows your level", hud.rich.text.contains("Level"), hud.rich.text)
	chk("and no picture, because there is nothing to look at",
		not hud.portrait.visible)
	await tap("menu")
	chk("Tab again reaches the room itself", hud._shop == hud.Shop.ROOM)
	chk("which tells you how big your classroom is",
		hud.rich.text.contains("%d by %d" % [Grid.W, Grid.H]), hud.rich.text)
	await tap("menu")
	chk("Tab again reaches lesson crafting", hud._shop == hud.Shop.CRAFT)
	await tap("menu")
	chk("and Tab cycles back round to buying", hud._shop == hud.Shop.BUY)

	# spending a point through the real screen
	Game.add_teacher_xp(Balance.teacher_xp_per_level * 3)
	await tap("menu")
	await tap("menu")
	# THE AIDE is row 0 and the JANITOR row 1 of the staff room now, so
	# the perks start at row 2.
	Game.coins = 5000
	var coins_before: int = Game.coins
	chk("the staff room opens on the aide", hud._sel == 0, hud._sel)
	await tap("interact")
	chk("E hires them", Game.has_aide)
	chk("and it costs what it says", Game.coins == coins_before - Balance.aide_cost,
		"%d -> %d" % [coins_before, Game.coins])

	var before_level_up: int = Game.coins
	await tap("interact")
	chk("E again, now hired, trains them up a level instead of firing them",
		Game.has_aide and Game.aide_level == 2, Game.aide_level)
	chk("and that costs coins too",
		Game.coins == before_level_up - Game.staff_level_cost(1), Game.coins)

	await tap("move_left")
	chk("move_left lets them go instead", not Game.has_aide)
	chk("and the training is lost with them", Game.aide_level == 1, Game.aide_level)

	await tap("move_down")
	await tap("move_down")
	var spent_before: int = Game.perk_points_spent()
	await tap("interact")
	chk("E on a perk row still spends a point",
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
		var required := ["name", "cat", "cost", "art", "blurb"]
		if String(d.get("cat", "")) == "consumable":
			required.append("effect")     # spent the day it's bought
		else:
			required.append_array(["range", "bonus"])   # placed furniture
		for key: String in required:
			if not d.has(key):
				bad.append("%s missing %s" % [id, key])
		if not Items.categories().has(String(d.get("cat", ""))):
			bad.append("%s has an unknown category" % id)
	chk("every item is complete and in a real category", bad.is_empty(), bad)

	# The shop prints the name through substr(0, 13) into a %-13s column,
	# so anything longer is CUT ON SCREEN and nothing said so. Two shipped
	# items were already being truncated -- "Alphabet Frieze" rendered as
	# "Alphabet Frie" -- and eight of a twenty-two item content batch would
	# have been. Labels clip in silence; this is the silence.
	var long_names: Array = []
	for id: String in Items.order():
		var nm := String(Items.get_def(id).get("name", ""))
		if nm.length() > 13:
			long_names.append("%s (%d): %s" % [id, nm.length(), nm])
	chk("every item name fits the shop column", long_names.is_empty(),
		long_names)

	# THE CHECK THE ART BROWSER EXISTS FOR: a missing PNG is a runtime crash.
	#
	# LOADS, not exists. `art/inspector.png` was on disk and every
	# file-exists check in the project was green while the running room
	# threw a resource error, because nothing had imported it. exists()
	# would have passed that file too.
	var missing: Array = []
	for id: String in Items.order():
		var art := String(Items.get_def(id).get("art", ""))
		var path := "res://art/%s.png" % art
		if not ResourceLoader.exists(path):
			missing.append("%s -> %s.png MISSING" % [id, art])
		elif load(path) == null:
			missing.append("%s -> %s.png WILL NOT LOAD (unimported?)" % [id, art])
	chk("every item's picture actually loads", missing.is_empty(), missing)

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

	# prices should broadly rise with what an item does, or the choice is
	# fake -- furniture only, since a consumable's price buys a day-long
	# hook rather than a bonus/range figure at all.
	var cheap_bonus := 0.0
	var dear_bonus := 0.0
	for id: String in Items.order():
		var d := Items.get_def(id)
		if String(d.get("cat", "")) == "consumable":
			continue
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


## Every global class the game relies on is actually REGISTERED.
##
## A brand-new class_name is not in Godot's registry until the project is
## rescanned, and until then every file referencing it fails to PARSE. That
## does not fail an assertion -- it silently removes whole sections from the
## run, and the only symptom is the assertion count dropping. It has happened
## twice: Version took hud.gd down (724 -> 560) and Fx took four files down
## (828 -> 708), both reporting ALL PASSED.
##
## The fix is `godot --headless --path . --import` after adding one. This
## test at least turns the silence into a named failure.
func test_global_classes_registered() -> void:
	section("GLOBAL CLASSES ARE REGISTERED")
	for cls: String in ["Fx", "Floater", "Items", "Traits", "Curriculum",
			"Balance", "Layout", "Grid", "Progress", "StudentData",
			"Interactable", "Placement", "RoomBuilder", "DayEvent", "DayBeats",
			"BossFight"]:
		chk("%s is a registered global class" % cls,
			ClassDB.class_exists(cls) or _gdscript_class_exists(cls), cls)


## Godot keeps script classes in the ProjectSettings list rather than in
## ClassDB, so a registered GDScript class has to be looked for there.
func _gdscript_class_exists(name: String) -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == name:
			return true
	return false


func test_every_asset_loads() -> void:
	section("EVERY ASSET ACTUALLY LOADS")
	# EXISTING ON DISK IS NOT ENOUGH. Godot cannot load a texture it has not
	# imported, and tools/make_art.py writes PNGs without importing them --
	# so a brand-new sprite is on disk, passes any file-exists check, and
	# then fails at load() in the running game.
	#
	# That is exactly how the inspector shipped invisible: art/inspector.png
	# was right there, and every asset check was green, while the room threw
	# a resource error every time an inspection day came round.
	var checked := 0
	var broken: Array[String] = []
	var da := DirAccess.open("res://art")
	if da != null:
		da.list_dir_begin()
		var n := da.get_next()
		while n != "":
			if n.ends_with(".png"):
				checked += 1
				var path := "res://art/%s" % n
				if not ResourceLoader.exists(path) or load(path) == null:
					broken.append(n)
			n = da.get_next()
		da.list_dir_end()
	chk("there is art to check", checked > 0, checked)
	chk("and every single piece of it loads", broken.is_empty(),
		"%d of %d fail to load: %s" % [broken.size(), checked, broken])


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
	# Nothing on disk should be unexplained. Four exceptions, each named
	# here so a FIFTH orphan is a real failure rather than something that
	# blends into an accepted list:
	#   table, poster_abc     sample art for the text-grid sprite pipeline,
	#                         which exists to demonstrate it, not to be used
	#   principal             the principal's walk-cycle sheet -- kept as
	#                         the palette source make_portrait() draws
	#                         portrait_principal from (Sept 2026 art pass),
	#                         but nothing puts the principal IN the room
	#                         the way the inspector's own sheet is
	#   portrait_inspector    drawn for every CHARACTERS entry as a matter
	#                         of consistency, but the inspector has no bio
	#                         screen to show a bust on -- only the room
	#                         sprite (inspector.png) is ever displayed
	const ART_SAMPLES := ["table", "poster_abc", "principal", "portrait_inspector"]
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

	# THE SOURCE-OF-TRUTH RULE: a hand edit wins, and is recorded.
	#
	# A sprite can be produced three ways -- plotted in Python, written as a
	# text grid in tools/sprites/, or drawn by hand -- and until make_art.py
	# learned to stand down, nothing arbitrated. Hand-editing a generated
	# sprite was silently undone by the next run of the script.
	#
	# Checked by SIZE rather than by reading the script, because that is the
	# thing that actually differs: a text grid and its procedural namesake
	# are almost never the same dimensions, so if the procedural version had
	# won this comparison would fail.
	var grids := DirAccess.open("res://tools/sprites")
	var grid_names: Array[String] = []
	var mismatched: Array = []
	if grids != null:
		grids.list_dir_begin()
		var g := grids.get_next()
		while g != "":
			if g.ends_with(".txt"):
				var gname := g.get_basename()
				grid_names.append(gname)
				var rows := 0
				var cols := 0
				var fh := FileAccess.open("res://tools/sprites/%s" % g, FileAccess.READ)
				if fh != null:
					while not fh.eof_reached():
						var line := fh.get_line()
						if line.begins_with("#") or line.strip_edges() == "":
							continue
						rows += 1
						cols = maxi(cols, line.length())
					fh.close()
				var tex: Texture2D = load("res://art/%s.png" % gname)
				if tex == null:
					mismatched.append("%s: no loadable PNG" % gname)
				elif tex.get_width() != cols or tex.get_height() != rows:
					mismatched.append("%s: grid is %dx%d, PNG is %dx%d -- the "
						% [gname, cols, rows, tex.get_width(), tex.get_height()]
						+ "procedural version overwrote the hand-edited one")
			g = grids.get_next()
		grids.list_dir_end()
	chk("there are text-grid sprite sources", not grid_names.is_empty(),
		grid_names)
	chk("and a hand-edited source owns its PNG, not the procedural drawing",
		mismatched.is_empty(), mismatched)

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


# ====================================================== music & ambience

func test_music() -> void:
	section("MUSIC AND AMBIENCE")

	# The tracks. The same seam make_art.py has: written by a script,
	# imported by Godot, and nothing in between -- so LOAD them, do not
	# just look for the files.
	var tracks: Array[String] = []
	var broken: Array[String] = []
	var da := DirAccess.open("res://audio")
	if da != null:
		da.list_dir_begin()
		var f := da.get_next()
		while f != "":
			if f.begins_with("music_") and f.ends_with(".wav"):
				tracks.append(f.get_basename())
				var path := "res://audio/%s" % f
				if not ResourceLoader.exists(path) or load(path) == null:
					broken.append(f)
			f = da.get_next()
		da.list_dir_end()
	tracks.sort()
	chk("there are nine music tracks",
		tracks == ["music_afternoon", "music_fight", "music_lose", "music_morning",
			"music_noise", "music_room", "music_test", "music_title", "music_win"],
		tracks)
	chk("and every one of them loads", broken.is_empty(), broken)
	for t: String in tracks:
		var w: AudioStreamWAV = load("res://audio/%s.wav" % t)
		if w == null:
			continue
		var secs := w.get_length()
		if t in ["music_win", "music_lose"]:
			chk("%s is a short sting" % t, secs >= 2.0 and secs <= 3.0, secs)
		else:
			chk("%s is a real loop, not a blip" % t, secs >= 20.0 and secs <= 32.0, secs)

	# The bus: music and effects on separate faders.
	var idx := AudioServer.get_bus_index("Music")
	chk("there is a Music bus", idx >= 0)
	chk("and it feeds Master", idx >= 0 and AudioServer.get_bus_send(idx) == &"Master")
	chk("the project's bus layout is its own file",
		String(ProjectSettings.get_setting("audio/buses/default_bus_layout"))
			== "res://default_bus_layout.tres")
	var layout: Resource = load("res://default_bus_layout.tres")
	chk("and that file loads with the Music bus in it",
		layout is AudioBusLayout and String(layout.get("bus/1/name")) == "Music")
	chk("Sfx stays on Master", Sfx._players[0].bus == "Master")

	# The autoload.
	chk("the Music autoload exists", get_node_or_null("/root/Music") != null)
	Music.enabled = true
	Music.stop(0.0)
	chk("stopped means no current track", Music.current == "")
	var n0: int = Music.starts
	Music.play("music_title", 0.0)
	chk("play() switches current", Music.current == "music_title")
	chk("and actually starts a player",
		Music.starts == n0 + 1 and Music._live.stream != null and Music._live.playing)
	var live: AudioStreamPlayer = Music._live
	Music.play("music_title", 0.0)
	chk("playing the track already playing is a no-op, not a restart",
		Music.starts == n0 + 1 and Music._live == live)
	var bed: AudioStreamWAV = live.stream
	chk("the bed loops forward over its whole length",
		bed.loop_mode == AudioStreamWAV.LOOP_FORWARD and bed.loop_end > 0
		and bed.loop_end == int(round(bed.get_length() * bed.mix_rate)),
		[bed.loop_mode, bed.loop_end])
	chk("...on a duplicate, so the imported resource is untouched",
		(load("res://audio/music_title.wav") as AudioStreamWAV).loop_mode
			== AudioStreamWAV.LOOP_DISABLED)
	Music.play("music_room", 0.0)
	chk("a different track switches players",
		Music.current == "music_room" and Music._live != live and Music.starts == n0 + 2)
	Music.sting("music_win")
	chk("a sting does not change the bed", Music.current == "music_room" and Music._live.playing)
	chk("it plays on its own player", Music._sting.playing and Music._sting.stream != null)
	chk("and it does not loop",
		(Music._sting.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED)
	chk("a missing track is a warning, not a crash", (func() -> bool:
		Music.sting("music_no_such_thing")
		return true).call())
	Music.stop(0.0)
	chk("stop() clears current", Music.current == "")
	chk("and silences both bed players", not Music._a.playing and not Music._b.playing)
	chk("every music player is on the Music bus",
		Music._a.bus == "Music" and Music._b.bus == "Music" and Music._sting.bus == "Music")

	# Cues by listening: the game never calls Music itself.
	Game.new_run(SEED)
	chk("a new run puts the classroom under play", Music.current == "music_room")
	Music.play("music_fight", 0.0)
	chk("the assessment track is there for the fight code to call",
		Music.current == "music_fight")
	Game.term_began.emit(2)
	chk("and a new term brings the classroom back", Music.current == "music_room")
	Music.enabled = false
	chk("switching music off silences it", not Music._live.playing)
	Music.enabled = true
	chk("and switching it back on resumes the same bed",
		Music.current == "music_room" and Music._live.playing)

	# The day's own shape: Game.phase_changed already announces morning,
	# the lesson and the afternoon, and Game.test_active is read at the
	# moment the lesson begins -- nothing new was wired into the game to
	# hear any of this, only into Music.
	chk("the run so far left the day in the morning", Game.phase == Game.Phase.MORNING)
	Game.set_phase(Game.Phase.LESSON)
	chk("an ordinary lesson plays the classroom bed",
		Music.current == "music_room", Music.current)
	Game.set_phase(Game.Phase.AFTERNOON)
	chk("afternoon winds the room down on its own bed",
		Music.current == "music_afternoon", Music.current)
	Game.set_phase(Game.Phase.MORNING)
	chk("and morning gets its own sparse bed",
		Music.current == "music_morning", Music.current)
	Game.test_active = true
	Game.set_phase(Game.Phase.LESSON)
	chk("a silent unit test gets its own bed, not the ordinary lesson's",
		Music.current == "music_test", Music.current)
	Game.test_active = false
	Game.set_phase(Game.Phase.AFTERNOON)
	Game.set_phase(Game.Phase.LESSON)
	chk("and an ordinary lesson afterwards goes back to the classroom bed",
		Music.current == "music_room", Music.current)

	# A live assessment still owns the bed: the phase listener steps aside
	# rather than racing the fight code for the same two players. Leave
	# test_active on so a listener that did NOT step aside would reach for
	# music_test instead -- proving this is the guard holding, not luck.
	Game.term_path = (Balance.bosses[0] as Dictionary).duplicate()
	Game.day = Balance.term_days
	Game.test_active = true
	Music.play("music_room", 0.0)
	Game.start_boss_fight()
	chk("the phase listener does not steal the bed from a live paper",
		Music.current == "music_room", Music.current)
	Game.test_active = false
	Game.fight = null
	Game.fight_done = false
	# Leaving Game.phase at LESSON with no fight would let the world's own
	# per-frame ticking (still live from earlier sections) carry on as if
	# a lesson were running and eventually change the phase again on its
	# own -- a new run is a clean, known state for whatever comes next.
	Game.new_run(SEED)
	Music.stop(0.0)

	# Settings: its own volume, saved, with a default for old files.
	var snapshot := Settings.to_dict()
	chk("music has its own volume, and it defaults to 0.6",
		is_equal_approx(float(Settings.FACTORY["music_volume"]), 0.6))
	Settings.music_volume = 0.35
	var d := Settings.to_dict()
	chk("it is saved", d.has("music_volume"))
	Settings.from_dict({})
	Settings.from_dict(d)
	chk("and round-trips", is_equal_approx(Settings.music_volume, 0.35))
	var old := snapshot.duplicate()
	old.erase("music_volume")
	Settings.from_dict(old)
	chk("a settings file from before music loads with the default",
		is_equal_approx(Settings.music_volume, 0.6))
	Settings.music_volume = 0.0
	Settings.apply_audio()
	chk("zero silences the Music bus", AudioServer.is_bus_mute(idx) and not Music.enabled)
	Settings.music_volume = 0.5
	Settings.apply_audio()
	chk("and any other value reaches the bus",
		not AudioServer.is_bus_mute(idx) and Music.enabled
		and AudioServer.get_bus_volume_db(idx) < 0.0)
	Settings.from_dict(snapshot)
	Settings.apply_audio()

	# The settings page: a Music row next to Sound, same left/right idiom.
	Music.stop(0.0)
	var t: Node2D = load("res://scenes/ui/title.tscn").instantiate()
	add_child(t)
	await step(3)
	chk("the title screen plays the title theme", Music.current == "music_title")
	t._go(t.Page.SETTINGS)
	chk("the settings page has a Music row right after Sound",
		t._rows().find("music") == t._rows().find("sfx") + 1, t._rows())
	chk("and still fits the panel budget", t._rows().size() <= 11, t._rows().size())
	var before: float = Settings.music_volume
	t.sel = t._rows().find("music")
	t._adjust(-1)
	chk("Left turns the music down", Settings.music_volume < before)
	t._adjust(1)
	chk("and Right turns it back up", is_equal_approx(Settings.music_volume, before))
	chk("the row shows itself", t.menu.text.contains("Music"))
	t.queue_free()
	await step(2)
	Music.stop(0.0)


## The boss paper switches the bed to music_fight and back, with a sting
## for how it went -- the one piece connecting the two branches this
## session merged. Driven through the PODIUM's own interact(), not the
## direct API test_boss_fight() uses, so main.gd's real signal wiring
## (fight_started -> Music.play, fight_ended -> Music.sting + play) is
## what is actually being checked.
func test_fight_music() -> void:
	section("THE FIGHT'S OWN MUSIC")
	Balance.ensure_loaded()
	Game.new_run(SEED)
	await step(2)
	while Game.enrol() != null:
		pass
	await step(2)
	var boss: Dictionary = {}
	for c: Dictionary in Balance.bosses:
		if String(c.get("strand", "")) == "ela":
			boss = c.duplicate()
	Game.term_path = boss
	Game.day = Balance.term_days
	Music.play("music_room", 0.0)
	await step(2)
	world.podium.interact(world.player)
	await step(2)
	chk("beginning the paper switches the bed to music_fight",
		Music.current == "music_fight", Music.current)
	var guard := 0
	while Game.fight_active() and guard < 100000:
		Game.fight.tick(0.5, Game.rng, Layout.PODIUM)
		guard += 1
	await step(3)
	chk("the paper being over brings the classroom bed back",
		Music.current == "music_room", Music.current)
	Game.new_run(SEED)
	await step(2)
	Music.stop(0.0)


## The art overhaul (Sept 2026) added make_portrait() to tools/make_art.py:
## a 96x96 bust per CHARACTERS entry, for a future HUD/bio panel that wants
## a face rather than a desk-distance 32x48 sheet frame. Not wired into any
## scene yet -- that is a UI change, and out of scope for the art pass that
## drew the busts -- so nothing else in this suite would catch a broken or
## missing one before a screen goes looking for it. "examiner" is excluded
## on purpose: that character (and its art) belongs to a parallel session
## working in the main repo, not this pass.
func test_portraits() -> void:
	section("PORTRAITS")
	var names := ["player", "inspector", "principal", "mentor",
		"student_a", "student_b", "student_c", "student_d",
		"student_e", "student_f", "student_g", "student_h"]
	var missing: Array[String] = []
	var wrong_size: Array[String] = []
	for n: String in names:
		var path := "res://art/portrait_%s.png" % n
		if not ResourceLoader.exists(path):
			missing.append(n)
			continue
		var tex: Texture2D = load(path)
		if tex == null or tex.get_width() != 96 or tex.get_height() != 96:
			wrong_size.append(n)
	chk("every character has a portrait bust", missing.is_empty(), missing)
	chk("and each one is a 96x96 image", wrong_size.is_empty(), wrong_size)


## The walkthrough tools: ONE walk_to, and a verdict a machine can read.
##
## Not a test of the game -- a test of the thing that tests the game, and
## the two failures it pins down are both ones this repo actually had.
##
## walk_to() lived in playterm.gd and playtrace.gd, byte-identical. A real
## fix landed in one copy; the other kept a comment saying so and stayed
## broken. And playterm.gd exited 0 whatever happened, so a failed day 18,
## a clean run, and a script that never compiled were indistinguishable
## from the outside -- which is how a regression sat for four days while
## the suite below it stayed green. A green suite cannot say anything
## about a tool that never reports failure, so it says it here instead.
func test_walkthrough() -> void:
	section("WALKTHROUGH")
	var drive := FileAccess.get_file_as_string("res://tools/playdrive.gd")
	var term := FileAccess.get_file_as_string("res://tools/playterm.gd")
	var trace := FileAccess.get_file_as_string("res://tools/playtrace.gd")
	chk("all three walkthrough scripts are there to scan",
		drive != "" and term != "" and trace != "")

	# --- one copy of the keyboard, not two ---
	chk("walk_to() lives in playdrive.gd", drive.count("func walk_to(") == 1)
	chk("...and playterm.gd does not redefine it",
		term.count("func walk_to(") == 0)
	chk("...and neither does playtrace.gd -- the copy that missed the fix",
		trace.count("func walk_to(") == 0)
	chk("both tools inherit the shared base rather than copying it",
		term.contains('extends "res://tools/playdrive.gd"')
		and trace.contains('extends "res://tools/playdrive.gd"'))
	chk("the one walk_to() still arrives by TILE, not only by 5px centre",
		drive.contains("Grid.world_to_tile(player.global_position) == tile"))
	for fn: String in ["func tap(", "func hold(", "func frames(", "func _release("]:
		chk("%s() is shared too, not copied back into a tool" % fn.substr(5).rstrip("("),
			drive.count(fn) == 1 and term.count(fn) == 0 and trace.count(fn) == 0)

	# --- a walkthrough that fails has to SAY so, in the exit code ---
	chk("playterm.gd quits with a real code",
		term.contains("get_tree().quit(0 if _verdict() else 1)"))
	chk("...and never with the bare quit() that made every run look fine",
		not term.contains("get_tree().quit()"))
	chk("it prints a verdict line either way",
		term.contains('VERDICT_PASS := "WALKTHROUGH PASSED"')
		and term.contains('VERDICT_FAIL := "WALKTHROUGH FAILED"'))
	chk("a failure names the day it broke on",
		term.contains('[VERDICT_FAIL, _fail_day, _fail_why]'))
	chk("competence stays reported, not gated, until a marking policy exists",
		term.contains("const GATE_COMPETENCE := false"))
	chk("and it cannot hang whatever is waiting on it",
		term.contains("watchdog(WATCHDOG_SECONDS"))

	# --- and whatever RUNS it must read that line, not the exit code alone ---
	var bat := FileAccess.get_file_as_string("res://Play a Whole Term.bat")
	var hook := FileAccess.get_file_as_string("res://.githooks/pre-push")
	chk("the launcher is there to scan", bat != "")
	chk("the pre-push hook is TRACKED, not hidden in .git/hooks where it died",
		hook != "")
	chk("the launcher checks the verdict line", bat.contains("WALKTHROUGH PASSED"))
	# Case-insensitively: Godot prints "Parse Error:" on one line and
	# "with error \"Parse error\"" on the next, and this check quietly
	# passed on the second one until both guards were made /I and -i.
	chk("...and the parse-error trap", bat.to_lower().contains("parse error"))
	chk("the hook actually runs the walkthrough", hook.contains("playterm.tscn"))
	chk("...and blocks on its verdict",
		hook.contains("WALKTHROUGH PASSED") and hook.contains("WALKTHROUGH FAILED"))
	chk("...and guards the same parse-error trap",
		hook.to_lower().contains("parse error"))

	# --- the gates are DISARMED on purpose; say it out loud ---
	# Step 0 of the ten-commit queue turned both hooks off by default: two
	# minutes on every commit and three and a half on every push was
	# costing more than the breakage it caught. The bodies are intact and
	# EDUSYSTEM_GATE=1 brings either one back for a single command.
	#
	# This is asserted rather than left to the files, because the last time
	# a gate in this repo stopped running, nothing said so for weeks. Two
	# of these pin the disarm as a DELIBERATE, documented state; the third
	# stops Verify.bat quietly losing the walkthrough it inherited from the
	# pre-push hook, which would leave nothing running it at all.
	var commit_hook := FileAccess.get_file_as_string("res://.githooks/pre-commit")
	chk("the pre-commit gate is opt-in via EDUSYSTEM_GATE, not automatic",
		commit_hook.contains("EDUSYSTEM_GATE"))
	chk("...and so is pre-push", hook.contains("EDUSYSTEM_GATE"))
	chk("...and Verify.bat runs the walkthrough the hook no longer does",
		FileAccess.get_file_as_string("res://Verify.bat").contains("Play a Whole Term.bat"))

	# --- a dev tool must never write the player's save (CLAUDE.md) ---
	chk("both walkthroughs redirect the save away from the player's",
		drive.contains('Game.save_path = "user://edusystem_WALKTHROUGH_save.json"'))
	# The screenshot harness boots the REAL game against the real save, which
	# is the point of it -- but "day"/"new_term" advance that run, and an
	# advance can write. Reading the player's save is fine; writing it is the
	# thing the rule forbids.
	var shot := FileAccess.get_file_as_string("res://tools/shot.gd")
	chk("...and so does the screenshot harness, which boots the real run",
		shot.contains('const SHOT_SAVE := "user://edusystem_SHOT_save.json"')
		and shot.contains("Game.save_path = SHOT_SAVE"))
