extends Node2D

## Wires the world to the UI.
##
## Neither half should have to know how the other is built, and neither
## _ready() can assume it runs first — so the connecting happens here, in the
## parent of both, once.

@onready var world: Node2D = $World
@onready var hud: Control = $UI/HUD
@onready var hallway: Node2D = $Hallway
@onready var mentor_room: Node2D = $MentorRoom

var placement: Placement = null


func _ready() -> void:
	placement = Placement.new()
	placement.visible = false
	world.add_child(placement)

	# Signals that belong to the WORLD itself survive a rebuild, so they are
	# connected once.
	world.quiz_requested.connect(_run_quiz)
	world.caller_requested.connect(_show_caller)
	hud.caller_answered.connect(_answer_caller)
	world.answer_all_requested.connect(_run_answer_all)
	world.curriculum_requested.connect(hud.show_curriculum)
	world.marking_requested.connect(hud.open_marking)
	world.test_requested.connect(func(lid: String) -> void: world.start_test(lid))
	world.lesson_auto_ended.connect(_on_lesson_ended)
	world.auto_lesson_resolved.connect(_on_auto_lesson_resolved)
	world.inspected.connect(func(r: Dictionary) -> void:
		_bump(3.0 if not bool(r.get("passed", false)) else 1.5)
		hud.show_inspection(r))
	world.test_auto_ended.connect(hud.show_test_report)
	# The boss paper: each question across the top as it opens, the report
	# when it is over. Both belong to the world, so connected once.
	world.fight_banner.connect(func(t: String) -> void: hud.show_banner(t))
	world.fight_ended.connect(_on_fight_ended)
	world.room_rebuilt.connect(_wire_room)
	_wire_room()

	# Onboarding, in one sentence at the moment it explains something the
	# player has just watched happen, from the principal rather than a
	# disembodied prompt. Game owns the threshold; principal_says() owns
	# the "only say it once" and respects Settings.show_hints.
	Game.class_drifted.connect(func() -> void:
		hud.principal_says("class_drifted",
			"Work only moves while you are at the front."))

	Game.work_going_cold.connect(func() -> void:
		hud.principal_says("uncollected",
			"Finished work only counts once you collect it."))

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
	placement.stored.connect(func(tile: Vector2i) -> void:
		Game.store_item(tile))       # packed away, not sold -- dispose from the cabinet

	# The hallway persists for the whole run, unlike the room's own
	# landmarks -- it never gets torn down and rebuilt, so this connection
	# is made once here rather than re-made in _wire_room().
	hallway.door_chosen.connect(_on_hallway_door)
	# The mentor room, likewise, is a permanent scene -- its exit door hands
	# the player back to the hallway.
	mentor_room.exit_chosen.connect(_leave_mentor)

	# A one-line nudge toward the mentor, the first time a day ends before
	# the player has been down the hall to meet them. Non-blocking: it rides
	# the same once-per-run corner popup every other tutorial line uses, and
	# never forces a walk. A grandfathered save loads with dash_taught true,
	# so it never sees this.
	Game.day_changed.connect(func(_d: int) -> void:
		if not Game.dash_taught:
			hud.queue_hint("see_the_mentor",
				"There is a mentor teacher down the hall now.")
		hud.queue_day_beat(_day_beat_line()))

	# The day's beat also needs the FIRST morning of a term, which
	# day_changed never fires for -- term_began covers term 2 onward, and a
	# brand new career comes in on run_started.
	Game.term_began.connect(func(_t: int) -> void:
		hud.queue_day_beat(_day_beat_line()))
	Game.run_started.connect(func() -> void:
		hud.queue_day_beat(_day_beat_line()))

	# The storyline cutscene. hud.gd owns the WORDS and their paging; this is
	# the wiring that turns "the slate was dismissed" into an actual teacher
	# walking across an actual room, and "a page turned" into a line above
	# their own head instead of hud reaching into world.player directly.
	hud.intro_walk_requested.connect(_start_intro_cutscene)
	hud.intro_desk_pull_requested.connect(_intro_pull_desk)
	hud.intro_line_changed.connect(func(t: String) -> void:
		world.player.say(t))
	hud.intro_finished.connect(func() -> void:
		Game.desks_in_store = 0
		world.player.input_locked = false
		world.player.hide_bubble())

	# Both conditions on purpose: intro_seen alone would replay it for
	# anyone who had an existing save from before this shipped, the day it
	# shipped -- day 1 with no term behind you yet is what actually means
	# "this is a new career", not just an unset flag.
	if not Game.intro_seen and Game.day <= 1 and Game.term_history.is_empty():
		# Locked here rather than left to hud._open()'s own best-effort
		# lock: that one goes through a _player reference hud only
		# discovers lazily in _process(), so it can still be null on the
		# very first frame -- harmless while a full slate covers the
		# screen, but this cutscene shows the room FROM that first frame.
		world.player.input_locked = true
		hud.show_intro()
	Music.play("music_room")


## The storyline cutscene's second beat: the slate is gone, the room is
## visible -- and empty. Every desk is stashed in the cabinet, the four
## children build() had already seated are cleared, and the teacher walks
## from the door to the cabinet to start pulling desks out. Triggered by
## hud's intro_walk_requested, fired once the slate is dismissed.
func _start_intro_cutscene() -> void:
	world.player.global_position = Grid.tile_to_world(Layout.DOOR + Vector2i(1, 0))
	Game.intro_begin_desks()
	world.clear_students()
	world.player.start_scripted_walk(
		Grid.tile_to_world(Layout.CABINET + Vector2i(0, 1)))


## One press of E at the cabinet: pull a desk out, kick up a little dust,
## and once the last one is out, bring the class in from the door and
## send the teacher to the front where every ordinary day begins.
func _intro_pull_desk() -> void:
	# Let them actually reach the cabinet before anything comes out of it.
	if world.player != null and world.player.is_walking_scripted():
		return
	var left := Game.intro_pull_desk()
	Sfx.play("blip")
	# The desk that just came out of the cabinet. rebuild_desks_only() has
	# already run (Game.intro_pull_desk -> intro_desks_changed), so ask the
	# world which body is newest and settle it in -- squash-and-land plus a
	# little dust, the same visual language Fx.land() gives placed shop
	# furniture, so a desk ARRIVES rather than snapping into place.
	var desk_node: StaticBody2D = world.newest_desk()
	if desk_node != null and is_instance_valid(desk_node):
		Fx.land(desk_node)
		Fx.puff(world, desk_node.global_position, Color(0.82, 0.77, 0.7, 0.75), 4)
	if world.player != null and is_instance_valid(world.player):
		Fx.puff(world, world.player.global_position + Vector2(0, -3),
			Color(0.82, 0.77, 0.7, 0.75), 3)
	if left <= 0:
		world.intro_bring_students_in()
		world.player.start_scripted_walk(world.teacher_start_world())


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


## The paper has begun. The one line of instruction it gets, once per run,
## from the principal -- the day's beat and the mentor's tactic line have
## already said the rest.
func _on_fight_started(_seated: int) -> void:
	hud.principal_says("boss_fight",
		"Steady whoever freezes. Settle whoever kicks off. Stay near whoever is up front.")
	Music.play("music_fight", 1.5)


## The paper is over. The same bump the exam gets: this is the morning
## that decides it. The room word IS the verdict -- steady/wobbling read
## as a win worth a sting, cracking/gone as a loss -- and either way the
## bed comes back for the ordinary afternoon that follows.
func _on_fight_ended(report: Dictionary) -> void:
	_bump(3.0)
	var composure := String(report.get("composure", ""))
	Music.sting("music_win" if composure in ["steady", "wobbling"] else "music_lose")
	Music.play("music_room", 2.0)
	hud.show_fight_report(report)


func _wire_room() -> void:
	var pairs := [
		[world.podium, "hand_requested", _offer_hand],
		[world.podium, "lesson_ended", _on_lesson_ended],
		[world.podium, "test_ended", hud.show_test_report],
		[world.podium, "fight_started", _on_fight_started],
		[world.bell, "day_ended", _on_day_ended],
		[world.bell, "term_ended", _on_term_ended],
		[world.noticeboard, "catalogue_opened", hud.open_catalogue],
		[world.cabinet, "cabinet_opened", func() -> void: hud.open_catalogue(hud.Shop.CABINET)],
		[world.ad_poster, "ad_poster_opened", hud.show_ads],
		[world.hall_door, "chosen", _enter_hallway],
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
		Game.place_from_cabinet(id, tile)  # taken from storage; already paid for
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
## Turning it ON while a real lesson is already running resolves THAT
## lesson instantly rather than making the player wait for the next one --
## the toggle is meant to be usable the moment you decide you are done
## walking today's floor, not just at the podium beforehand.
func _toggle_auto_teach() -> void:
	Game.auto_teach = not Game.auto_teach
	Sfx.play("blip")
	if Game.auto_teach and Game.phase == Game.Phase.LESSON and not Game.test_active:
		_on_auto_lesson_resolved(world.run_auto_lesson())


## Show the day RoomSim just resolved, the same way a delegated room's is
## shown -- watchable, at your own pace, or skippable with the "watch" key.
## Closing it hands off to the ordinary lesson report, exactly where a
## manually-played lesson's own end would have landed.
func _on_auto_lesson_resolved(data: Dictionary) -> void:
	# On an inspection day, run_auto_lesson()'s own end_lesson() call has
	# already fired world.inspected -> hud.show_inspection() by the time
	# this runs -- that verdict outranks the watch replay, so leave it on
	# screen rather than paving over it.
	if hud.mode == hud.Mode.REPORT:
		return
	hud.show_own_watch(data.get("history", []), data.get("results", []))


func _toggle_build() -> void:
	if placement.active:
		placement.finish()
		_unlock()
		return
	if Game.phase == Game.Phase.LESSON:
		hud.principal_says("build_lesson", "Not while the class is working.")
		return
	world.player.input_locked = true
	placement.begin_browse(world.grid,
		Grid.world_to_tile(world.player.global_position))


## Draw a hand (3-7, a fresh shuffle every morning) and let the player pick
## one; the lesson starts with whichever they took.
func _offer_hand() -> void:
	Game.draw_hand()
	hud.show_hand(true)


func _start_chosen_lesson(i: int) -> void:
	Game.choose_assignment(i)
	world.podium.lesson_started.emit(world.start_lesson())


## Someone at your desk who wants an answer. The room raised it, the HUD
## shows it, and the answer comes back through here -- the same round trip
## quiz and marking already make, so neither half reaches into the other.
func _show_caller(row: Dictionary, who: StudentData) -> void:
	hud.show_caller(row, who)


func _answer_caller(row: Dictionary, index: int, who: StudentData) -> void:
	hud.caller_replied(world.resolve_caller_choice(row, index, who))


func _run_quiz() -> void:
	hud.show_quiz_report(world.run_quiz())


## The mass-help skill (J). No result screen -- the room shows it: stuck
## and quiz bubbles clear on the spot, and the lesson clock takes the
## hit. The principal explains it once, the first time.
func _run_answer_all() -> void:
	world.run_answer_all()
	Sfx.play("blip")
	hud.principal_says("answer_all",
		"You went round the whole room at once. That is most of the lesson's "
		+ "time gone, and it is a while before you can do it again.")


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


## Walked through your own door. Reparents the SAME player node into the
## hallway rather than spawning a second one -- world.player stays the one
## true teacher throughout, which is what every test and every other system
## already assumes it is.
func _enter_hallway(_kind: String, _room_index: int) -> void:
	if world.hall_door == null or not world.hall_door.can_interact():
		return
	hallway.rebuild()
	var p: Actor = world.player
	world.remove_child(p)
	hallway.add_child(p)
	p.position = hallway.entry_position()
	p.facing = p.DIR_DOWN
	# The camera is a CHILD of the player (classroom._attach_camera()), so
	# it came along in the reparent above -- world.camera is still the
	# right reference to it, just relocated.
	hallway.refresh_camera_limits(world.camera)
	if world.camera != null:
		world.camera.make_current()
		world.camera.reset_smoothing()
	world.visible = false
	hallway.visible = true
	hud.principal_says("hallway_first_visit",
		"Every room you hold has a door here now.")


## The reverse: back through the home door, into the room you left exactly
## as it was -- nothing in it was ticking while you were away, because
## nothing in classroom._physics_process runs outside Phase.LESSON, and
## you can only leave in the first place when you are not mid-lesson.
func _return_home() -> void:
	var p: Actor = world.player
	hallway.remove_child(p)
	world.add_child(p)
	p.global_position = Grid.tile_to_world(Layout.DOOR + Vector2i(1, 0))
	p.facing = p.DIR_DOWN
	world._refresh_camera_limits()
	if world.camera != null:
		world.camera.make_current()
		world.camera.reset_smoothing()
	hallway.visible = false
	world.visible = true


## The morning's narration line, or "" for a day that gets none. Built
## here, from live Game/Balance state, so DayBeats stays a pure text
## function with a trivial test and no autoload dependency.
func _day_beat_line() -> String:
	var tp: Dictionary = Game.term_path
	return DayBeats.line_for({
		"term": Game.term,
		"day": Game.day,
		"term_days": Balance.term_days,
		"path_kind": String(tp.get("kind", "")),
		"path_id": String(tp.get("id", "")),
		"boss_name": String(tp.get("name", "")),
	})


## Into the mentor teacher's room, off the hallway. Reparents the SAME
## Actor -- never a second body -- exactly as the hallway/room transitions
## already do. The first visit runs the teaching dialogue; a revisit shows
## an idle line, or a prose readiness read if a boss term is due.
func _enter_mentor() -> void:
	mentor_room.visible = true
	var p: Actor = world.player
	hallway.remove_child(p)
	mentor_room.add_child(p)
	p.position = mentor_room.entry_position()
	p.facing = p.DIR_RIGHT
	mentor_room.refresh_camera_limits(world.camera)
	if world.camera != null:
		world.camera.make_current()
		world.camera.reset_smoothing()
	hallway.visible = false
	world.visible = false
	# Locked here rather than left to hud._open()'s own best-effort lock,
	# which goes through a _player reference hud only discovers lazily in
	# _process() -- the same reason the intro locks the player in _ready().
	p.input_locked = true
	hud.show_mentor()


## Back out through the mentor room's door, into the hallway.
func _leave_mentor() -> void:
	hallway.rebuild()
	var p: Actor = world.player
	mentor_room.remove_child(p)
	hallway.add_child(p)
	p.position = hallway.entry_position()
	p.facing = p.DIR_DOWN
	hallway.refresh_camera_limits(world.camera)
	if world.camera != null:
		world.camera.make_current()
		world.camera.reset_smoothing()
	mentor_room.visible = false
	world.visible = false
	hallway.visible = true


func _on_hallway_door(kind: String, room_index: int) -> void:
	match kind:
		"home":
			_return_home()
		"office":
			Game.met_principal = true
			hud._sel = 0
			hud.show_office()
		"mentor":
			_enter_mentor()
		"open":
			var err := Game.open_room()
			if err != "":
				hud.hint_once("hallway_open_room_failed", err)
				return
			hallway.rebuild()
		"room":
			if room_index < 0 or room_index >= Game.rooms.size():
				return
			var r: Dictionary = Game.rooms[room_index]
			var teacher: Dictionary = r.get("teacher", {})
			if teacher.is_empty():
				hud._hiring_for = room_index
				hud.show_hiring()
			elif hud._can_watch(room_index):
				hud.show_watch(room_index)
			else:
				# Staffed, but the bell has not rung on it yet -- there is
				# nothing to watch, but there is still something to show:
				# the same room overview the old School screen gave, on
				# this room, rather than silently doing nothing.
				hud._sel = room_index
				hud.show_school()

