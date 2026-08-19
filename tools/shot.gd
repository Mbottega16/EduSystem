extends Node

## Screenshot harness.
##
##   godot --path . res://tools/shot.tscn -- out.png [frames] [width] [height]
##
## Runs the REAL game scene for a few frames and saves what it drew. Not
## headless — headless has no renderer, so it can only ever prove that code
## does not crash, never that anything is on screen.
##
## That distinction has already cost this project once: a broken hud.gd
## survived a headless boot check because the game opens on the title screen
## and never instantiates the HUD. Every UI panel so far has also needed two
## or three passes to stop overflowing 288x128, and no assertion catches a
## panel that merely looks wrong.

const MAIN := "res://scenes/main.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 30

	# An explicit size lets a grown room be shot whole rather than cropped to
	# whatever the project's viewport happens to be.
	if args.size() > 3:
		var w := int(args[2])
		var h := int(args[3])
		get_window().content_scale_size = Vector2i(w, h)
		get_window().size = Vector2i(w * 3, h * 3)

	# Deferred: the root is still setting up its own children while _ready()
	# runs here, and a direct add_child() is refused outright.
	# Optional: grow the room first, so a screenshot can show a size the
	# opening classroom never reaches.
	var grow: int = int(args[4]) if args.size() > 4 else 0

	var main: Node = load(MAIN).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	# Optional: open a named screen before shooting. Every overlay in this
	# project has needed two or three passes to stop running off the bottom
	# of a 288x128 panel, and no assertion catches text that merely overflows.
	var screen: String = args[5] if args.size() > 5 else ""

	if grow > 0:
		Game.coins = 99999999
		for i in grow:
			Game.expand_room("wide")
			Game.expand_room("tall")
		await get_tree().physics_frame

	# Physics frames, not a timer: the whole game runs on the physics tick,
	# and students walk to their chairs on a stagger.
	for i in frames:
		await get_tree().physics_frame

	if screen != "":
		_open_screen(main, screen)
		# Long enough for the reveal to FINISH. Two frames caught the result
		# screens mid-wipe, which photographs an animation rather than a
		# layout -- and layout is the only thing these shots are for.
		for i in 70:
			await get_tree().physics_frame

	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("shot: %s  %dx%d  err=%d  (%d frames)" % [
		out, img.get_width(), img.get_height(), err, frames])
	get_tree().quit(0 if err == OK else 1)


## Drive the HUD straight to a screen, rather than trying to walk the teacher
## across the room and press the right buttons in the right phase.
func _open_screen(main: Node, screen: String) -> void:
	var hud: Node = main.get_node("UI/HUD")
	var world: Node = main.get_node("World")
	match screen:
		"quiz":
			world.start_lesson()
			hud.show_quiz_report(world.run_quiz())
		"specialism":
			Game.specialism = ""
			hud.show_specialism()
		"hand":
			# a hand with one of each of the top rarities, so the colours
			# can be compared side by side
			Game.hand = [
				{"rarity": "common", "form": "Worksheet", "difficulty": 1,
					"subject": "Arithmetic", "lesson": "basic_arithmetic"},
				{"rarity": "excellent", "form": "Problem Set", "difficulty": 3,
					"subject": "Arithmetic", "lesson": "basic_arithmetic"},
				{"rarity": "legendary", "form": "Project", "difficulty": 5,
					"subject": "Arithmetic", "lesson": "basic_arithmetic"},
			]
			hud.show_hand()
		"hand_shuffle":
			# A REAL draw, not the hand-crafted one-of-each-rarity fixture
			# "hand" uses -- this exercises the actual 3-7 shuffle and
			# settles on whatever size and rarities the seed produced. The
			# shuffle ANIMATION itself is not what this captures: every
			# screen shot here waits 70 frames after opening for the same
			# reason results screens do not photograph mid-wipe -- layout
			# is what these shots are for, not catching an animation. The
			# shuffle's mechanics are asserted directly in tests/run.gd
			# instead (title reads SHUFFLING..., then settles).
			Game.new_run(0)
			Game.draw_hand()
			hud.show_hand(true)
		"marking":
			# The real bug this verifies: a rebuilt room used to leave a
			# stale marking desk that silently killed the homework screen
			# for the rest of the run. new_run() rebuilds the room, so
			# opening straight after it is exactly the scenario that broke.
			Game.new_run(0)
			for s: StudentData in Game.roster:
				s.hw_state = StudentData.HW.COLLECTED
				s.hw_true_accuracy = 0.7
				s.hw_sheet = Questions.make_sheet(s.hw_true_accuracy, Game.rng, "math")
			hud.open_marking()
		"school":
			Game.coins = 999999
			for ri in 3:
				Game.open_room()
			Game.applicants = [Staff.archetype("veteran").duplicate(),
				Staff.archetype("supply").duplicate()]
			Game.applicants[0]["name"] = "Dr Okafor"
			Game.applicants[1]["name"] = "Mr Petrov"
			Game.hire(0, 0)
			Game.hire(1, 0)
			Game.furnish_room(0)
			Game.furnish_room(0)
			Game.resolve_rooms()
			hud.show_school()
		"hiring":
			Game.coins = 999999
			Game.open_room()
			Game.draw_applicants()
			hud._hiring_for = 0
			hud.show_hiring()
		"career":
			for m: Dictionary in Milestones.all():
				if Game.milestones.size() >= 5:
					break
				Game.milestones.append(String(m["id"]))
			hud.show_career()
		"curriculum":
			for l: Dictionary in Curriculum.lessons:
				for i in 4:
					Game.record_taught(String(l.get("id", "")))
			hud.show_curriculum()
		"unit_test":
			for i in 5:
				Game.record_taught("basic_arithmetic")
			world.start_test("basic_arithmetic")
			hud.show_test_report(world.end_test())
		"student":
			var s: StudentData = Game.roster[0]
			Game.lesson = Curriculum.by_id("basic_arithmetic")
			Game.grade_class()
			Game.lesson = Curriculum.by_id("reading_fluency")
			Game.grade_class()
			hud.show_student(s)
		"shop":
			Game.add_coins(3000)
			hud.open_catalogue()
		"room":
			Game.add_coins(50000)
			hud.open_catalogue()
			hud._shop = hud.Shop.ROOM
			hud._render_catalogue()
		"staff":
			Game.add_teacher_xp(4000)
			hud.open_catalogue()
			hud._shop = hud.Shop.STAFF
			hud._render_catalogue()
		"class_list":
			hud.show_class_list()
		# "curriculum" is handled earlier in this match -- GDScript's match
		# takes the FIRST arm, so a second "curriculum" case here was dead
		# code. It taught basic_arithmetic x7, reading_fluency x4 and
		# science_basics once; the surviving arm teaches all lessons x4,
		# which is what every "curriculum" screenshot has actually shown.
		"at_board":
			# standing at the noticeboard: BOTH buttons must be named
			Game.set_phase(Game.Phase.AFTERNOON)
			world.player.global_position = Grid.tile_to_world(
				Layout.BOARD + Vector2i(0, 1))
		"at_bell":
			Game.set_phase(Game.Phase.AFTERNOON)
			world.player.global_position = Grid.tile_to_world(
				Layout.BELL + Vector2i(0, 1))
		"title":
			hud.show_title()
		"inspection":
			Game.event = DayEvent.by_id("inspector")
			var g := 0
			while Game.room_score(0) < Balance.room_cap - 0.001 and g < 60:
				Game.room_items.append({"id": Items.order()[g % Items.order().size()],
					"tile": Layout.seat(0) + Vector2i(0, -1)})
				g += 1
			for st: StudentData in Game.roster:
				st.work_state = StudentData.Work.COLLECTED
			for i in 20:
				Game.record_taught(String(Game.lesson.get("id", "")))
			hud.show_inspection(Game.inspect())
		"inspector_here":
			Game.event = DayEvent.by_id("inspector")
			world.refresh_inspector()
			world.start_lesson()
		"teaching":
			world.start_lesson()
			world.player.global_position = Grid.tile_to_world(
				Layout.PODIUM + Vector2i(0, 1))
			Game.attention = 0.8
		"noise":
			# one of each problem, side by side, to check the three bubble
			# colours read apart at a glance
			world.start_lesson()
			Game.roster[0].disrupting = true
			Game.roster[1].confusion = 1.0
			Game.roster[1].trait_id = "steady"
			Game.roster[2].quiz_flagged = true
		"day":
			while Game.enrol() != null:
				pass
			var rep := Game.advance_day()
			rep["joined"] = "Someone New"
			rep["event"] = "A wasp in the room"
			rep["event_blurb"] = "Nobody is going to concentrate today."
			hud.show_day_report(rep)
		"run_over":
			# a career: two terms taught, the second one missed. Cleared
			# first -- the harness has already played real days by now, and
			# their terms would stack under the ones being demonstrated.
			Game.term_history.clear()
			Game.graduated.clear()
			Game.term_history.append({"term": 1, "letter": "C", "passed": 3,
				"total": 6, "moved_up": 3, "target": 2, "met": true})
			Game.term_history.append({"term": 2, "letter": "D", "passed": 1,
				"total": 8, "moved_up": 1, "target": 3, "met": false})
			Game.term = 2
			for ll: Dictionary in Curriculum.lessons:
				for ii in 3:
					Game.record_taught(String(ll.get("id", "")))
			for ii in 4:
				Game.graduated.append({"name": "Someone", "level": 5})
			hud.show_run_over({"run_over": true, "target": 3})
		"new_term":
			while Game.enrol() != null:
				pass
			var gg := 0
			while Game.room_score(0) < Balance.room_cap - 0.001 and gg < 40:
				Game.room_items.append({"id": Items.order()[gg % Items.order().size()],
					"tile": Layout.seat(0) + Vector2i(0, -1)})
				gg += 1
			for ll: Dictionary in Curriculum.lessons:
				for ii in 4:
					Game.record_taught(String(ll.get("id", "")))
			var kk := 0
			for st: StudentData in Game.roster:
				st.grades.append(0.95 - 0.09 * float(kk))
				kk += 1
			Game.sit_exam()
			hud.show_new_term(Game.next_term())
		"exam":
			# A term somebody actually played: a furnished room, a full
			# curriculum, one child sent up, and a spread of results rather
			# than a column of identical failures.
			while Game.enrol() != null:
				pass
			var g := 0
			while Game.room_score(0) < Balance.room_cap - 0.001 and g < 40:
				Game.room_items.append({"id": Items.order()[g % Items.order().size()],
					"tile": Layout.seat(0) + Vector2i(0, -1)})
				g += 1
			for l: Dictionary in Curriculum.lessons:
				for i in 4:
					Game.record_taught(String(l.get("id", "")))
			# Graduate FIRST: sending a child up enrols a replacement, and a
			# replacement has no grades at all -- so grades handed out before
			# this went to a student who is no longer in the room.
			var up: StudentData = Game.roster[0]
			while not up.is_ready_to_graduate():
				up.add_xp(1)
			Game.graduate(up)
			var k := 0
			for st: StudentData in Game.roster:
				st.grades.append(0.94 - 0.075 * float(k))
				st.grades.append(0.90 - 0.070 * float(k))
				k += 1
			hud.show_exam(Game.sit_exam())
		_:
			push_error("unknown screen: " + screen)
