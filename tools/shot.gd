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
## The player's save is never written by this tool -- see _ready().
const SHOT_SAVE := "user://edusystem_SHOT_save.json"


func _ready() -> void:
	# A dev tool must never write the player's save (CLAUDE.md), and this one
	# boots the REAL game -- "day", "new_term" and the rest advance the run,
	# and an advance can save. So it works on a COPY: the player's file is
	# duplicated to the shot path, and save_path points at the duplicate
	# before classroom.gd's ensure_run() ever reads one. Shots still show
	# the room as it actually stands; nothing they do can reach it.
	Game.save_path = SHOT_SAVE
	if FileAccess.file_exists(Game.SAVE_PATH):
		var real := FileAccess.get_file_as_string(Game.SAVE_PATH)
		var copy := FileAccess.open(SHOT_SAVE, FileAccess.WRITE)
		if copy != null:
			copy.store_string(real)
			copy.close()
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
	var screen: String = args[5] if args.size() > 5 else ""

	# The actual boot scene (scenes/ui/title.tscn) is structurally nothing
	# like main.tscn -- no World, no UI/HUD -- so it gets its own short
	# path rather than being forced through _open_screen(), which assumes
	# both exist.
	if screen == "boot_title":
		var title: Node = load("res://scenes/ui/title.tscn").instantiate()
		get_tree().root.add_child.call_deferred(title)
		await get_tree().process_frame
		for i in frames:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2 := get_viewport().get_texture().get_image()
		var err2 := img2.save_png(out)
		print("shot: %s  %dx%d  err=%d  (%d frames)" % [
			out, img2.get_width(), img2.get_height(), err2, frames])
		get_tree().quit(0 if err2 == OK else 1)
		return

	var main: Node = load(MAIN).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	# Optional: open a named screen before shooting. Every overlay in this
	# project has needed two or three passes to stop running off the bottom
	# of a 288x128 panel, and no assertion catches text that merely overflows.
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
		"dashboard":
			Game.new_run(0)
			Game.place_item("stool", Vector2i(9, 6))
			Game.perk_ranks["calm_presence"] = 1
			hud._dash = hud.Dash.OVERVIEW
			hud.show_dashboard()
		"dashboard_wardrobe":
			Game.new_run(0)
			Game.hat_id = "cap"
			Game.background_id = "dusk"
			hud._dash = hud.Dash.WARDROBE
			hud._sel = 0
			hud.show_dashboard()
		"dashboard_items":
			Game.new_run(0)
			Game.place_item("stool", Vector2i(9, 6))
			hud._dash = hud.Dash.ITEMS
			hud.show_dashboard()
		"dashboard_skills":
			Game.new_run(0)
			Game.teacher_level = 5   # 4 points earned, so 3 spent reads sanely
			Game.perk_ranks["calm_presence"] = 1
			Game.perk_ranks["long_reach"] = 2
			hud._dash = hud.Dash.SKILLS
			hud.show_dashboard()
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
		"ads":
			Game.new_run(0)
			hud.show_ads()
		"marking_stamp":
			# The player's own verdict, stamped -- checked separately from
			# the plain sheet since the stamp only ever appears for the
			# instant MARKING_STAMP_SECONDS holds it up.
			Game.new_run(0)
			for s: StudentData in Game.roster:
				s.hw_state = StudentData.HW.COLLECTED
				s.hw_true_accuracy = 0.7
				s.hw_sheet = Questions.make_sheet(s.hw_true_accuracy, Game.rng, "math")
			hud.open_marking()
			hud.sheet.stamp(true)
		"boss_fight":
			# The paper, mid-question: the examiner up front, three children
			# frozen, the banner across the top, the strip reading the room.
			Game.new_run(0)
			Game.term_path = (Balance.bosses[0] as Dictionary).duplicate()
			Game.day = Balance.term_days
			world.start_boss_fight()
			Game.fight.tick(Balance.fight_breath_seconds + 0.05, Game.rng, Layout.PODIUM)
			world._drain_fight_events()
			hud.show_banner(Game.fight.question_text(), 30.0)
		"fight_report":
			Game.new_run(0)
			Game.term_path = (Balance.bosses[0] as Dictionary).duplicate()
			Game.day = Balance.term_days
			world.start_boss_fight()
			var fguard := 0
			while Game.fight_active() and fguard < 100000:
				Game.fight.tick(0.5, Game.rng, Layout.PODIUM)
				fguard += 1
			hud.show_fight_report(world.end_boss_fight())
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
		"door":
			world.player.global_position = Grid.tile_to_world(Layout.DOOR + Vector2i(1, 0))
			world.player.facing = Actor.DIR_LEFT
		"hallway":
			Game.coins = 999999
			Game.open_room()
			Game.open_room()
			Game.open_room()
			Game.applicants = [Staff.archetype("veteran").duplicate(),
				Staff.archetype("supply").duplicate()]
			Game.applicants[0]["name"] = "Dr Okafor"
			Game.applicants[1]["name"] = "Mr Petrov"
			Game.hire(0, 0)
			Game.hire(1, 0)
			Game.resolve_rooms()
			# Forced rather than left to whatever the sim actually rolled --
			# this shot exists to show all three door states side by side
			# (fine / failing / unstaffed), not to prove what a veteran or
			# a supply teacher usually scores.
			Game.rooms[0]["last"]["letter"] = "A"
			Game.rooms[1]["last"]["letter"] = "E"
			var hallway: Node = main.get_node("Hallway")
			hallway.rebuild()
			world.player.get_parent().remove_child(world.player)
			hallway.add_child(world.player)
			world.player.position = hallway.entry_position()
			hallway.refresh_camera_limits(world.camera)
			if world.camera != null:
				world.camera.make_current()
				world.camera.reset_smoothing()
			world.visible = false
			hallway.visible = true
		"acting":
			# Page three of a child's file, with plenty acting on them --
			# a trait, a bad day, and something they are doing to
			# themselves -- so the shot shows a full page rather than a
			# nearly-empty one.
			Game.intro_seen = true
			hud.close()
			Game.event = DayEvent.by_id("restless")
			var kid: StudentData = Game.roster[0]
			kid.trait_id = "ghost"
			kid.copied = true
			kid.coached = 1
			# show_student() resets to page one whenever the CHILD changes,
			# so the page has to be set after the first call, not before it.
			hud.show_student(kid)
			hud._bio_page = hud.BIO_ACTING
			hud.show_student(kid)
		"caller":
			# Someone at your desk, mid-decision. The principal rather than a
			# child, because her portrait is a fixed asset and a child's is
			# whichever the roll picked -- a screenshot wants the stable one.
			# Two options showing, marker on the first: the worst case for
			# panel fit is the longest line plus every choice under it.
			Game.intro_seen = true
			hud.close()
			hud.show_caller(Complication.by_id("trip_fund"), null)
		"mentor", "mentor_demo", "mentor_chain":
			# The mentor's room, dressed. Reparent the same body in, park it
			# by the door looking in, pin the camera -- the layout is what
			# this shot is for.
			# The intro slate is still up on a fresh run and it is a full
			# CanvasLayer, so without closing it this photographs MONDAY's
			# wall of text with the room dimly behind it. Every other case
			# here happens to drive the HUD to a screen of its own, which is
			# why only this one needed saying out loud.
			Game.intro_seen = true
			hud.close()
			var mroom: Node2D = main.get_node("MentorRoom")
			mroom.visible = true
			world.player.get_parent().remove_child(world.player)
			mroom.add_child(world.player)
			world.player.position = mroom.entry_position()
			world.player.facing = Actor.DIR_RIGHT
			mroom.refresh_camera_limits(world.camera)
			if world.camera != null:
				world.camera.make_current()
				world.camera.reset_smoothing()
			world.visible = false
			main.get_node("Hallway").visible = false
			# mentor_demo: the chain-dash demonstration part-way through --
			# every hand up, and her mid-run between desks.
			if screen == "mentor_demo":
				mroom.play_chain_demo()
			# mentor_chain: what she says after it -- the longest page, which
			# is the one that has to fit the panel.
			if screen == "mentor_chain":
				hud.show_mentor_after_demo()
				hud._sel = 1
				hud._render_mentor()
		"intro":
			# The title slate. new_run(0) then force intro_seen back off:
			# new_run() already resets it, but a case run right after another
			# one in the same process (this harness reuses one Game autoload
			# across every match branch it's ever handed) must not inherit a
			# stale true.
			Game.new_run(0)
			Game.intro_seen = false
			hud.show_intro()
		"intro_walk":
			# The cutscene itself, mid-stride: the slate is gone, the room is
			# visible, and the teacher is partway across it -- the harness's
			# own post-open wait (see _ready() below) advances REAL frames
			# afterward, same as any other running gameplay, so this is a
			# genuine walk in progress by the time the shot is taken, not a
			# frozen pose.
			Game.new_run(0)
			Game.intro_seen = false
			hud.show_intro()
			world.player.global_position = Grid.tile_to_world(
				Layout.DOOR + Vector2i(1, 0))
			world.player.start_scripted_walk(world.teacher_start_world())
			hud._sel = 0
			hud._render_intro()
		"intro_line":
			# Arrived, and on the longest bubble line in the script -- the
			# worst case for panel fit, checked by eye rather than trusting
			# the suite's own line-count assertion alone.
			Game.new_run(0)
			Game.intro_seen = false
			hud.show_intro()
			world.player.global_position = world.teacher_start_world()
			hud._sel = hud.INTRO_PAGES.size() - 1
			hud._render_intro()
		"office":
			for m: Dictionary in Milestones.all():
				if Game.milestones.size() >= 6:
					break
				Game.milestones.append(String(m["id"]))
			hud._sel = 0
			hud.show_office()
		"principal":
			hud.principal_says("shot_demo",
				"Work only moves while you are at the front.")
		"watch":
			Game.coins = 999999
			Game.open_room()
			Game.applicants = [Staff.archetype("veteran").duplicate()]
			Game.applicants[0]["name"] = "Dr Okafor"
			Game.hire(0, 0)
			Game.resolve_rooms()
			hud.show_watch(0)
			# Land mid-lesson rather than on frame zero or the final tally,
			# so the shot shows the thing this screen actually adds: a
			# room mid-day, not its bookends.
			hud._watch_i = mini(10, hud._watch_frames.size() - 1)
			hud._render_watch_frame()
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
		"alumni":
			# a few leavers with real records, then open the wall on them
			for i in mini(3, Game.roster.size()):
				var g: StudentData = Game.roster[i]
				g.transcript.append({"lesson": "counting", "name": "Counting",
					"standard": "K.CC.1", "day": 2, "grade": 0.8, "test": false})
				g.transcript.append({"lesson": "adding", "name": "Adding",
					"standard": "1.OA.1", "day": 5, "grade": 0.6, "test": false})
				g.note_moment("grade_jump" if i == 0 else "never_stuck", g.joined_day + 5)
				var rec := Game.graduate_record(g)
				rec["term"] = i + 1
				(Game.meta["alumni"] as Array).append(rec)
			hud._career_page = hud.CAREER_ALUMNI
			hud._alum_open = -1
			hud.show_career()
		"skip":
			hud.show_skip()
		"skip_report":
			# Three real days, run through the real model, so the report is
			# of something that actually happened rather than a mock-up.
			hud.show_skip_report(main.world.run_skipped_days(3))
		"curriculum":
			for l: Dictionary in Curriculum.lessons:
				for i in 4:
					Game.record_taught(String(l.get("id", "")))
			hud.show_curriculum()
		"dev_room":
			var dbg: Node = main.get_node("Debug")
			dbg._do_cheat("all")
			dbg._toggle(true)
			dbg.page = dbg.Page.CHEATS
		"dev_room_bare":
			# Same cheat, panel closed -- to actually see the room it made.
			var dbg2: Node = main.get_node("Debug")
			dbg2._do_cheat("all")
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
		"consumables":
			Game.add_coins(3000)
			hud.open_catalogue()
			hud._cat = Items.categories().find("consumable")
			hud._render_catalogue()
		"staff":
			Game.add_teacher_xp(4000)
			hud.open_catalogue()
			hud._shop = hud.Shop.STAFF
			hud._render_catalogue()
		"staff_scrolled":
			# Worst case for the perk-list windowing: a middle selection
			# shows BOTH ellipses at once -- the exact row count that has
			# to fit the panel budget, not just the top-of-list case.
			Game.add_teacher_xp(4000)
			hud.open_catalogue()
			hud._shop = hud.Shop.STAFF
			hud._sel = 6
			hud._render_catalogue()
		"craft":
			# One lesson per Game.CRAFT_STYLES entry, forced to a real
			# craft_level so every style's colour shows in the same shot --
			# see docs/CRAFT_STYLES.md.
			Game.add_coins(3000)
			Game.day = Balance.craft_unlock_day
			for i in Game.CRAFT_STYLES.size():
				var lid: String = String(Curriculum.lessons[i].get("id", ""))
				Game.lesson_crafts[lid] = {"craft_level": 3, "invested_coins": 500,
					"invested_days": 4, "style": Game.CRAFT_STYLES[i]}
			hud.open_catalogue()
			hud._shop = hud.Shop.CRAFT
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
		"hat":
			# refresh_hat() again on purpose: the player's own _ready()
			# already ran, with hat_id still "", by the time this case
			# gets to set it.
			Game.hat_id = "cap"
			world.player.refresh_hat()
			world.player.global_position = Grid.tile_to_world(
				Layout.PODIUM + Vector2i(0, 1))
		"auto_teach":
			Game.auto_teach = true
			Game.set_phase(Game.Phase.MORNING)
			world.start_lesson()
			hud._watch_i = mini(10, hud._watch_frames.size() - 1)
			hud._render_watch_frame()
		"weather":
			Game.event = DayEvent.by_id("wet_play")
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
		"notices":
			# The crowded case the notice layout exists for: a full class,
			# every one of them working AND visibly stuck, so a bar and a
			# mark are up over every desk at once. If any two of them sit on
			# top of each other, it shows here and nowhere else.
			while Game.enrol() != null:
				pass
			world._rebind_to_new_run()
			world.start_lesson()     # a real lesson: it sets the clock too, and
			                         # a LESSON phase with no clock ends instantly
			for st: StudentData in Game.roster:
				# Fresh work each, at a different point through it, so the
				# bars in the shot are bars and not eight identical blocks.
				st.work_state = StudentData.Work.NONE
				st.assign_work()
				st.work_timer = st.work_total * (0.15 + 0.1 * float(st.seat_index % 8))
				st.trait_id = "steady"       # no hiding: the mark is prompt
				st.confusion = 1.0
				st._hidden_for = 999.0
			world._refresh_bubbles()
			world._layout_notices()
		"mess":
			# The room-mess/janitor systems shipped with zero screenshot
			# coverage -- headless proves _spawn_mess() does not crash,
			# never that the props are actually on screen. MESS_MIN is 1,
			# so a forced re-seed always gives at least one to look at.
			# No janitor here on purpose: tick_janitor()'s first tick fires
			# on the very next physics frame (its timer starts at 0.0), so
			# hiring one before the reveal wait swept the mess before this
			# shot could ever see it -- found by looking, not assumed.
			world._spawn_mess()
		"mess_janitor":
			# The other half: a janitor already on staff, working the room
			# with nobody stood at the podium -- confirms tick_janitor()
			# really does run outside the LESSON-only block.
			Game.add_coins(500)
			Game.set_janitor(true)
			world._spawn_mess()
		"day":
			while Game.enrol() != null:
				pass
			var rep := Game.advance_day()
			rep["joined"] = "Someone New"
			rep["event"] = "A wasp in the room"
			rep["event_blurb"] = "Nobody is going to concentrate today."
			hud.show_day_report(rep)
		"consumables_report":
			Game.add_coins(1000)
			Game.use_consumable("coffee")
			Game.use_consumable("bake_sale")
			var rep2 := Game.advance_day()
			hud.show_day_report(rep2)
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
		"term_paths":
			# The PokeRogue-style fork: a REAL drawn hand (TermPaths.draw(),
			# not a hand-crafted fixture) through the real shuffle -- same
			# reasoning as "hand_shuffle" above, and the same 90-frame wait
			# comfortably outlasts the ~0.42s reveal.
			Game.new_run(0)
			Game.draw_term_paths()
			hud.show_term_paths(true)
		"desk_interruption":
			# The RESPOND badge, in situ. Game.interruption built the exact
			# way _tick_complications() actually builds it (a duplicated
			# table row plus a "left" countdown), not a hand-rolled dict --
			# and world.player parked on the same tile tests/run.gd already
			# proved reaches this desk (Layout.TEACHER_DESK[0] + (0,1)).
			world.start_lesson()
			world.player.global_position = Grid.tile_to_world(
				Layout.TEACHER_DESK[0] + Vector2i(0, 1))
			var call_row := Complication.by_id("phone_call")
			Game.interruption = call_row.duplicate()
			Game.interruption["left"] = float(call_row.get("ring_seconds", 8.0))
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
