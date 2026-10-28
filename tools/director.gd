extends "res://tools/playterm.gd"

## The director: plays the real game like a person who wants a good classroom.
##
## playterm.gd only teaches, marks what it happens to carry, and rings the bell. This
## one also sweeps up messes, collects and marks homework, settles and quizzes, shops,
## hires staff, spends skill points and places furniture. It drives the REAL buttons
## (walking, E, F, Tab, arrows) and reads the same state a player can see.
##
## Everything is bounded: every step has a guard, a failed step is logged and skipped,
## and the day always ends at the bell. A video bot that gets stuck is worse than one
## that is clumsy.
##
##   godot --path . [--write-movie out.avi ...] res://tools/director.tscn -- \
##     <seed> <id> <teacher name> <game seconds> [speed]
##
## It prints one `DIRECTOR` line per thing it does, so a recording can be cut from the log.

var _limit_frames := 0
var _frames := 0
var _bought: Dictionary = {}          # item id -> times bought by this bot
var _events := 0
var _mentor_done := false
var _mentor_tries := 0
var _bad_spots: Dictionary = {}        # tiles the bot gave up on (a mess it cannot clear)
var _stuck_days := 0
var persona: Dictionary = {}
var _persona_id: String = "pedagogy_master"


func _load_persona(p_id: String) -> void:
	_persona_id = p_id
	var path := "res://tools/personas/%s.json" % p_id
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var json := JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			persona = json.data
			_log("persona", "loaded %s (Tier %d - %s): %s" % [
				p_id, int(persona.get("tier", 3)), persona.get("category", "proficient"), persona.get("title", "")])
			return
	_log("persona", "using default steady_teacher config")
	persona = {
		"tier": 3,
		"skill_rating": 80,
		"category": "proficient",
		"reaction_delay": 0.8,
		"chores_first": false,
		"use_voice": true,
		"idle_circulate": true,
		"chain_nearby": true,
		"chain_radius": 3.0,
		"max_chain_count": 1,
		"zpd_seating": true,
		"desk_rearrange_mode": "zpd",
		"quiz_frequency_days": 2,
		"perk_priorities": ["quick_sweep", "brisk_walk", "calm_presence", "practised_marker", "steady_hands"],
		"furniture_priorities": ["floor_cushion", "pot_of_pens", "paper_mobile", "stool", "backpack", "crate"],
		"min_coins_buffer": 30
	}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed: int = int(args[0]) if args.size() > 0 else 777
	var id: String = args[1] if args.size() > 1 else "director"
	var teacher: String = args[2] if args.size() > 2 else ""
	var seconds: float = float(args[3]) if args.size() > 3 else 300.0
	var speed: float = float(args[4]) if args.size() > 4 else 1.0
	var persona_arg: String = args[5] if args.size() > 5 else "pedagogy_master"
	var continue_save: bool = (int(args[6]) != 0) if args.size() > 6 else false
	var max_terms: int = int(args[7]) if args.size() > 7 else 0

	_limit_frames = int(seconds * 60.0) if seconds > 0.0 else 0
	var wd: float = (seconds * 6.0 / maxf(speed, 1.0) + 600.0) if seconds > 0.0 else (maxf(float(max_terms), 3.0) * 3600.0)
	watchdog(wd, "DIRECTOR FAILED")
	await boot(run_seed, speed, id, continue_save)
	_load_persona(persona_arg)
	if teacher != "":
		Game.teacher_name = teacher
	if continue_save and Game.has_save() and not Game.run_over:
		_log("resume", "resumed career: day %d, term %d, coins %d" % [Game.day, Game.term, Game.coins])
	await frames(secs(1.0))
	await _run(max_terms)
	_finish()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _limit_frames > 0 and _frames >= _limit_frames:
		_finish()


func _calculate_scorecard() -> Dictionary:
	var avg: float = Game.class_average()
	var gpa_letter: String = Game.grade_letter(avg)
	var gpa_pts: float = clampf(avg * 40.0, 0.0, 40.0)
	var total_frames: int = _lesson_front_frames + _lesson_walk_frames
	var front_ratio: float = 0.5 if total_frames == 0 else clampf(float(_lesson_front_frames) / float(total_frames), 0.0, 1.0)
	var teach_pts: float = front_ratio * 30.0
	var milestone_pts: float = clampf(float(Game.milestones.size()) * 3.0, 0.0, 15.0)
	var coins_pts: float = clampf(float(Game.coins) * 0.1, 0.0, 15.0)
	var total_score: int = int(round(gpa_pts + teach_pts + milestone_pts + coins_pts))
	var tier: int = int(persona.get("tier", 3))
	var rating: int = int(persona.get("skill_rating", 75))
	return {
		"teacher": Game.teacher_name,
		"persona": _persona_id,
		"title": persona.get("title", ""),
		"tier": tier,
		"category": persona.get("category", "proficient"),
		"baseline_rating": rating,
		"evaluated_score": total_score,
		"gpa_letter": gpa_letter,
		"class_average": avg,
		"coins": Game.coins,
		"day": Game.day,
		"term": Game.term,
		"events": _events
	}


func _save_scorecard(card: Dictionary) -> void:
	var path := "D:/EduSystemClips/leaderboard.json"
	var dir_access := DirAccess.open("D:/EduSystemClips")
	if dir_access == null:
		path = "user://leaderboard.json"
	var existing: Dictionary = {}
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var json := JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			existing = json.data
	existing[Game.teacher_name] = card
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(existing, "  "))
		file.close()


func _finish() -> void:
	if _limit_frames < 0:
		return
	_limit_frames = -1
	var card := _calculate_scorecard()
	_save_scorecard(card)
	_log("scorecard", "teacher=%s tier=%d rating=%d score=%d/100 gpa=%s" % [
		Game.teacher_name, card["tier"], card["baseline_rating"], card["evaluated_score"], card["gpa_letter"]])
	_log("end", "frames=%d events=%d coins=%d day=%d term=%d" % [_frames, _events, Game.coins, Game.day, Game.term])
	print("DIRECTOR DONE teacher=%s day=%d term=%d frames=%d events=%d score=%d tier=%d" % [
		Game.teacher_name, Game.day, Game.term, _frames, _events, card["evaluated_score"], card["tier"]])
	get_tree().quit()


func _log(kind: String, msg: String) -> void:
	_events += 1
	print("DIRECTOR d%d.%d | %-8s | %s" % [Game.day, Game.phase, kind, msg])


# ---------------------------------------------------------------- the days

func _run(max_terms: int = 0) -> void:
	var last_day := Game.day
	var last_term := Game.term
	for attempt in Balance.term_days * 8:
		if _limit_frames < 0 or Game.run_over:
			break
		if max_terms > 0 and Game.term > max_terms:
			_log("target_terms", "completed target terms: %d" % max_terms)
			break
		if max_terms == 0 and _limit_frames <= 0 and Game.term > 3:
			break
		var day: int = Game.day
		await clear_screens()

		# If a loaded save starts in the afternoon, resolve it by ringing the bell:
		if Game.phase == Game.Phase.AFTERNOON:
			var bell_tile: Vector2i = Layout.BELL + Vector2i(0, 1)
			await _go(bell_tile, 400)
			await hold("manage", 1.0)
			var picks := 0
			while hud.mode == hud.Mode.EXAM_PICK and picks < 8:
				picks += 1
				await tap("interact")
			await clear_screens()
			await frames(secs(0.5))
			continue

		# MORNING: the room first, then the lesson.
		if Game.phase == Game.Phase.MORNING:
			await _clean_messes()
			await _maybe_mentor()
			await _go_podium()
			await tap("teach")
			if hud.mode == hud.Mode.HAND:
				await tap("interact")
				await frames(4)
		if Game.phase != Game.Phase.LESSON:
			_stuck_days += 1
			var here: Vector2i = Grid.world_to_tile(player.global_position)
			_log("stuck", "the lesson would not start (phase %d, L=[%s], at %s, podium reachable %s, hud %d, locked %s)" % [
				Game.phase, _offer("teach"), here,
				world.grid.reachable(here, Layout.PODIUM + Vector2i(0, 1)), hud.mode, player.input_locked])
			await clear_screens()
			if _stuck_days >= 3:
				# Last resort, said out loud: put the teacher back at the podium.
				_log("recover", "moved the teacher back to the podium")
				player.global_position = Grid.tile_to_world(Layout.PODIUM + Vector2i(0, 1))
				_stuck_days = 0
				await frames(secs(0.5))
			continue
		_stuck_days = 0

		await _play_lesson()
		await clear_screens()

		# AFTERNOON: hand in the homework, mark it, spend what was earned, ring the bell.
		if Game.phase == Game.Phase.AFTERNOON:
			await _go_over_quizzes()
			await _collect_homework()
			await _mark_homework()
			await _clean_messes()
			await _spend()
			await _rearrange_desks()
			var bell_tile: Vector2i = Layout.BELL + Vector2i(0, 1)
			await _go(bell_tile, 400)
			for b_try in 3:
				if Game.phase != Game.Phase.AFTERNOON:
					break
				await hold("manage", 1.0)
				var picks := 0
				while hud.mode == hud.Mode.EXAM_PICK and picks < 8:
					picks += 1
					await tap("interact")
				await frames(secs(0.5))
		if Game.day != last_day:
			last_day = Game.day
			_log("day", "now day %d, coins %d, class %s" % [
				Game.day, Game.coins, Game.grade_letter(Game.class_average())])
		if Game.term != last_term:
			_log("term_complete", "term %d completed! Class avg: %s, coins: %d -> Now term %d" % [
				last_term, Game.grade_letter(Game.class_average()), Game.coins, Game.term])
			last_term = Game.term
			if max_terms > 0 and Game.term > max_terms:
				_log("target_terms", "completed target terms: %d" % max_terms)
				break
		await clear_screens()
		await frames(secs(0.5))


## Close whatever is open like a player: E for reports, Esc for the ad offer.
func clear_screens(limit: int = 6) -> void:
	for i in limit:
		if hud.mode == hud.Mode.NONE or Game.run_over:
			return
		await tap("cancel" if hud.mode == hud.Mode.ADS else "interact")
	if hud.mode != hud.Mode.NONE:
		hud.close()
		await frames(2)


# ---------------------------------------------------------------- walking

## Walk to a tile along the room's own path, so desks and furniture do not block it.
func _go(tile: Vector2i, limit: int = 400) -> bool:
	var here: Vector2i = Grid.world_to_tile(player.global_position)
	if here == tile:
		return true
	var g = world.grid
	if g != null and g.reachable(here, tile):
		var route: Array = g.path(here, tile)
		for t: Vector2i in route:
			if t == here:
				continue
			if not await walk_to(t, 120):
				break
	return await walk_to(tile, limit)


func _go_podium(limit: int = 300) -> bool:
	var preferred := Layout.PODIUM + Vector2i(0, 1)
	if await _go(preferred, limit):
		return true
	for off: Vector2i in [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 2), Vector2i(1, 2)]:
		var alt: Vector2i = Layout.PODIUM + off
		if world.grid != null and world.grid.is_free(alt) and await _go(alt, limit / 2):
			return true
	return false


func _nearby_desk_needing_me(max_dist: float) -> int:
	var here: Vector2 = Vector2(Grid.world_to_tile(player.global_position))
	var best := -1
	var best_dist := max_dist
	for s: StudentData in Game.roster:
		if s.seat_index < 0:
			continue
		var r: int = s.attention_rank()
		if r > 0:
			var desk_pos := Vector2(Layout.seat(s.seat_index) + Layout.DESK_OFFSET + Vector2i(0, 1))
			var d: float = here.distance_to(desk_pos)
			if d <= best_dist:
				best_dist = d
				best = s.seat_index
	return best


# ---------------------------------------------------------------- messes

func _pos_of(n: Node) -> Vector2:
	if n is Node2D:
		return (n as Node2D).global_position
	var p := n.get_parent()
	return (p as Node2D).global_position if p is Node2D else player.global_position


## Sweep up every mess in the room: walk beside it, press E until it is gone.
func _clean_messes() -> void:
	var guard := 0
	while guard < 12 and not world.messes.is_empty():
		guard += 1
		var m: Interactable = null
		var best := 1e9
		for c: Interactable in world.messes:
			if not is_instance_valid(c) or _bad_spots.has(Grid.world_to_tile(_pos_of(c))):
				continue
			if Grid.world_to_tile(_pos_of(c)).x <= 0:      # on the door tile: not a floor mess
				continue
			var d: float = player.global_position.distance_to(_pos_of(c))
			if d < best:
				best = d
				m = c
		if m == null:
			break
		var at: Vector2i = Grid.world_to_tile(_pos_of(m))
		var reached := false
		for off: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i.ZERO]:
			var t: Vector2i = at + off
			if world.grid != null and world.grid.is_free(t) and await _go(t, 120):
				await frames(3)
				# Only press E when the thing E would act on IS this mess (not the ad poster,
				# a desk or anything else standing near it).
				if player.targets.get("interact") == m:
					reached = true
					break
		if not reached:
			_log("mess", "could not reach the mess at %s" % [at])
			_bad_spots[at] = true
			continue
		var before: int = world.messes.size()
		for i in Game.mess_presses_needed() + 2:
			if not is_instance_valid(m) or not world.messes.has(m):
				break
			await tap("interact")
		if world.messes.size() < before:
			_log("mess", "swept the mess at %s (%d left)" % [at, world.messes.size()])
		else:
			_log("mess", "the mess at %s would not clear (stood at %s, E=[%s])" % [
				at, Grid.world_to_tile(player.global_position), _offer("interact")])
			_bad_spots[at] = true
			continue


# ---------------------------------------------------------------- lesson

## Teach from the front; go to whoever needs me; sweep a mess when nobody does;
## settle a noisy room with the voice; run a quick quiz once the class has settled.
func _play_lesson() -> void:
	var guard := 0
	var quizzed := false
	_reset_lesson_tally()
	while Game.phase == Game.Phase.LESSON and guard < 4000 and _limit_frames >= 0:
		guard += 1
		# Voice settlement: only teachers equipped with classroom presence use voice
		var noisy := 0
		for s: StudentData in Game.roster:
			if s.seat_index >= 0 and s.disrupting:
				noisy += 1
		if noisy >= 2 and Game.voice > 0.0 and bool(persona.get("use_voice", true)):
			await tap("voice")
			_log("voice", "settled %d noisy students" % noisy)

		# Answer all (mentor skill)
		var stuck := 0
		for s2: StudentData in Game.roster:
			if s2.seat_index >= 0 and s2.is_struggling():
				stuck += 1
		if stuck >= 2 and Game.answer_all_taught and _offer("answer_all") != "-":
			await tap("answer_all")
			_log("help", "answered %d stuck students at once" % stuck)

		# Chore fixated (Tier 1 distracted_sweeper): sweeps crumbs even while desks wait
		if bool(persona.get("chores_first", false)) and not world.messes.is_empty():
			await _clean_messes()
			await _go_podium(300)
			continue

		var seat := _desk_needing_me()
		if seat < 0:
			if not world.messes.is_empty():
				await _clean_messes()
				await _go_podium(300)
				continue
			var quiz_freq: int = int(persona.get("quiz_frequency_days", 2))
			var allow_quiz := (Game.day % quiz_freq == 0)
			if not quizzed and allow_quiz and guard > 6 and _offer("quiz") != "-":
				await tap("quiz")
				quizzed = true
				_log("quiz", "ran a quick quiz")
			_lesson_front_frames += secs(0.5)
			# Natural human idle circulation: casually pace along the front board
			if bool(persona.get("idle_circulate", true)) and guard % 12 == 0:
				var off_x: int = -2 if (guard % 24 == 0) else 2
				var patrol_tile: Vector2i = Layout.PODIUM + Vector2i(off_x, 1)
				if world.grid != null and world.grid.is_free(patrol_tile):
					await _go(patrol_tile, 100)
					await frames(secs(0.6))
					await _go_podium(100)
			else:
				await frames(secs(0.5))
			continue

		# Human reaction delay (perception lag before heading out)
		var delay: float = float(persona.get("reaction_delay", 0.0))
		if delay > 0.0:
			await frames(secs(delay))
			if Game.phase != Game.Phase.LESSON:
				break
			seat = _desk_needing_me()
			if seat < 0:
				continue

		var stand: Vector2i = Layout.seat(seat) + Layout.DESK_OFFSET + Vector2i(0, 1)
		_lesson_trips += 1
		var before: int = Engine.get_physics_frames()
		if not await _go(stand, 160):
			_lesson_walk_frames += Engine.get_physics_frames() - before
			await frames(4)
			continue
		await tap("interact")
		_lesson_helped += 1

		# Chain nearby students needing help before commuting back to the podium
		if bool(persona.get("chain_nearby", true)):
			var chains := 0
			var max_chains: int = int(persona.get("max_chain_count", 2))
			var rad: float = float(persona.get("chain_radius", 4.0))
			while chains < max_chains:
				var next_seat := _nearby_desk_needing_me(rad)
				if next_seat < 0 or next_seat == seat:
					break
				var next_stand: Vector2i = Layout.seat(next_seat) + Layout.DESK_OFFSET + Vector2i(0, 1)
				if not await _go(next_stand, 120):
					break
				await tap("interact")
				_lesson_helped += 1
				chains += 1
				seat = next_seat

		await _go_podium(300)
		_lesson_walk_frames += Engine.get_physics_frames() - before
	if Game.phase == Game.Phase.LESSON:
		await hold("teach", 0.8)


# ---------------------------------------------------------------- quizzes

## After a quick quiz, go to each flagged child's desk and go over what they got wrong.
func _go_over_quizzes() -> void:
	var done := 0
	for s: StudentData in Game.roster:
		if s.seat_index < 0 or not s.quiz_flagged:
			continue
		var stand: Vector2i = Layout.seat(s.seat_index) + Layout.DESK_OFFSET + Vector2i(0, 1)
		if not await _go(stand, 160):
			continue
		var guard := 0
		while guard < 6 and _offer("interact").begins_with("Go over"):
			guard += 1
			await tap("interact")
			await frames(secs(0.4))
		if guard > 0:
			done += 1
	if done > 0:
		_log("quiz", "went over the quiz with %d students" % done)


# ---------------------------------------------------------------- homework

## After the lesson: walk to every desk with finished homework and collect it.
func _collect_homework() -> void:
	var got := 0
	for s: StudentData in Game.roster:
		if s.seat_index < 0 or s.hw_state != StudentData.HW.DONE:
			continue
		var stand: Vector2i = Layout.seat(s.seat_index) + Layout.DESK_OFFSET + Vector2i(0, 1)
		if not await _go(stand, 160):
			continue
		var before: int = player.carrying_hw
		await tap("interact")
		await frames(4)
		if player.carrying_hw > before or s.hw_state == StudentData.HW.COLLECTED:
			got += 1
	if got > 0:
		_log("homework", "collected %d sheets" % got)


## The base marker, plus a log line for what it did.
func _mark_homework() -> void:
	var carrying: int = player.carrying_hw
	if carrying <= 0:
		return
	await super._mark_homework()
	_log("marking", "marked the homework (was carrying %d, now %d)" % [carrying, player.carrying_hw])


# ---------------------------------------------------------------- spending

## Staff first, then skills, then one piece of furniture, placed.
func _spend() -> void:
	await _go(Layout.BOARD + Vector2i(0, 1))
	await tap("manage")
	if hud.mode != hud.Mode.CATALOGUE:
		_log("shop", "the shop would not open (F=[%s])" % _offer("manage"))
		return
	await _shop_staff()
	await _shop_perks()
	var max_buys: int = int(persona.get("max_furniture_per_day", 1))
	for b in max_buys:
		var bought_id := await _shop_furniture()
		await clear_screens()
		if bought_id != "":
			await _place_from_cabinet(bought_id)
		else:
			break


func _shop_tab(tab: int) -> bool:
	var guard := 0
	while hud._shop != tab and guard < 8:
		guard += 1
		await tap("menu")
	return hud._shop == tab


## Move the shop cursor onto a row by its id. Returns false when it is not listed.
func _shop_pick(id: String) -> bool:
	var rows: Array = hud._shop_rows()
	var at := rows.find(id)
	if at < 0:
		return false
	var guard := 0
	while hud._sel != at and guard < rows.size() + 2:
		guard += 1
		await tap("move_down")
	return hud._sel == at


func _shop_staff() -> void:
	if not await _shop_tab(hud.Shop.STAFF):
		return
	# The janitor first when the room keeps getting messy, then the aide.
	for which: String in ["janitor", "aide"]:
		var has: bool = Game.has_janitor if which == "janitor" else Game.has_aide
		if has:
			continue
		var cost: int = Balance.janitor_cost if which == "janitor" else Balance.aide_cost
		if Game.coins < cost + 40:
			continue
		var before: int = Game.coins
		if await _shop_pick(which):
			await tap("interact")
		if Game.coins < before:
			_log("hire", "hired the %s for %d coins" % [which, before - Game.coins])


func _shop_perks() -> void:
	if not await _shop_tab(hud.Shop.STAFF):
		return
	var guard := 0
	var order: Array = persona.get("perk_priorities", [
		"brisk_walk", "practised_marker", "calm_presence", "quick_sweep", "steady_hands"
	])
	while Game.perk_points_free() > 0 and guard < 6:
		guard += 1
		var bought := false
		for id: String in order:
			var points: int = Game.perk_points_free()
			if await _shop_pick(id):
				await tap("interact")
			if Game.perk_points_free() < points:
				_log("skill", "learned %s (rank %d)" % [id, int(Game.perk_ranks.get(id, 0))])
				bought = true
				break
		if not bought:
			break


## Buy furniture prioritizing high-impact aura items from persona, falling back to cheapest affordable.
func _shop_furniture() -> String:
	if not await _shop_tab(hud.Shop.BUY):
		return ""
	var preferred: Array = persona.get("furniture_priorities", [
		"bookshelf", "study_folder", "globe", "rug", "whiteboard", "clock"
	])
	var min_buffer: int = int(persona.get("min_coins_buffer", 25))
	var cats: Array = Items.categories()

	# First pass: look for preferred high-impact items (Tier 2+ only; Tier 1 novice buys cheapest)
	var is_novice: bool = int(persona.get("tier", 3)) <= 1
	if not is_novice:
		for pref_id: String in preferred:
			if _bought.has(pref_id):
				continue
			for c in cats.size():
				var rows: Array = hud._shop_rows()
				if rows.has(pref_id):
					var p: int = Game.shop_price(pref_id)
					if Game.coins >= p + min_buffer:
						var before: int = Game.coins
						if await _shop_pick(pref_id):
							await tap("interact")
						if Game.coins < before:
							_bought[pref_id] = int(_bought.get(pref_id, 0)) + 1
							_log("buy", "bought %s for %d coins (preferred)" % [pref_id, before - Game.coins])
							return pref_id
				await tap("move_right")

	# Fallback: cheapest affordable item
	for c in cats.size():
		var rows: Array = hud._shop_rows()
		var pick := ""
		var price := 1 << 30
		for id: String in rows:
			if Items.category_of(id) == "consumable" or _bought.has(id):
				continue
			var p: int = Game.shop_price(id)
			if p < price and Game.coins >= p + min_buffer:
				price = p
				pick = id
		if pick != "":
			var before: int = Game.coins
			if await _shop_pick(pick):
				await tap("interact")
			if Game.coins < before:
				_bought[pick] = int(_bought.get(pick, 0)) + 1
				_log("buy", "bought %s for %d coins" % [pick, before - Game.coins])
				return pick
		await tap("move_right")     # next category
	return ""


# ---------------------------------------------------------------- placing

## Take the bought piece out of the cabinet and put it somewhere valid.
func _place_from_cabinet(id: String) -> void:
	await _go(Layout.BOARD + Vector2i(0, 1))
	await tap("manage")
	if hud.mode != hud.Mode.CATALOGUE:
		return
	if not await _shop_tab(hud.Shop.CABINET) or not await _shop_pick(id):
		await clear_screens()
		return
	await tap("interact")                # closes the shop and starts placing
	await frames(4)
	var pl = main.placement
	if pl == null or not pl.active:
		_log("place", "placement did not start for %s" % id)
		return
	# Floor pieces cross the room toward a free tile near a wall. Wall pieces slide along the
	# wall; desk-top pieces hop from desk to desk. So after the walk, sweep sideways until the
	# ghost turns valid, the way a player nudges it.
	var spot := _pick_spot(pl) if not Items.is_wall(id) and not Items.is_desk_top(id) else Vector2i(-1, -1)
	var guard := 0
	while spot != Vector2i(-1, -1) and pl.tile != spot and guard < 80:
		guard += 1
		var d: Vector2i = spot - pl.tile
		var before: Vector2i = pl.tile
		await tap(("move_right" if d.x > 0 else "move_left") if absi(d.x) >= absi(d.y) else ("move_down" if d.y > 0 else "move_up"))
		if pl.tile == before:
			break
	var dir := "move_right"
	var sweeps := 0
	while not pl.is_valid() and sweeps < 40:
		sweeps += 1
		var before2: Vector2i = pl.tile
		await tap(dir)
		if pl.tile == before2:
			dir = "move_left" if dir == "move_right" else "move_right"
	if pl.is_valid():
		var at: Vector2i = pl.tile
		await tap("interact")
		await frames(4)
		_log("place", "placed %s at %s" % [id, at])
	else:
		_log("place", "%s found no valid tile (ghost at %s, wanted %s)" % [id, pl.tile, spot])
		await tap("cancel")


## Walk the room's tiles from the back wall forward and take the first the ghost accepts.
func _pick_spot(pl) -> Vector2i:
	var keep: Vector2i = pl.tile
	var found := Vector2i(-1, -1)
	var tiles: Array[Vector2i] = []
	for y in range(3, 11):
		for x in range(3, 17):
			# Keep doorway corridor (x <= 2), right corkboard (x >= 17), and podium front clear
			if (x >= 8 and x <= 10) and (y == 3 or y == 4):
				continue
			tiles.append(Vector2i(x, y))
	# the outside of the room first: furniture along walls leaves the middle for the class
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _wall_gap(a) < _wall_gap(b))
	for t: Vector2i in tiles:
		pl.tile = t
		if pl.is_valid():
			if world.grid != null:
				var pod := Layout.PODIUM + Vector2i(0, 1)
				if not world.grid.reachable(pod, Layout.BELL + Vector2i(0, 1)):
					continue
			found = t
			break
	pl.tile = keep
	return found


func _wall_gap(t: Vector2i) -> int:
	return mini(mini(t.x - 1, 18 - t.x), mini(t.y - 3, 10 - t.y))


# ---------------------------------------------------------------- the desks

## Every third day, rearrange desks. With ZPD seating, pairs struggling students with peer tutors;
## otherwise moves the struggling student closer to the front.
func _rearrange_desks() -> void:
	if Game.day < 3 or Game.day % 3 != 0:
		return
	var mode: String = String(persona.get("desk_rearrange_mode", "zpd"))
	if mode == "none":
		_log("desks", "desk rearrangement skipped (mode=none)")
		return
	var use_zpd: bool = (mode == "zpd" or mode == "pods") and bool(persona.get("zpd_seating", true))
	var pick: StudentData = null
	var tutor: StudentData = null

	if use_zpd:
		# Find a struggling student (competence < 0.6) and a suitable tutor (delta in [0.08, 0.45])
		for s: StudentData in Game.roster:
			if s.seat_index >= 0 and s.competence < 0.6:
				for t: StudentData in Game.roster:
					if t != s and t.seat_index >= 0:
						var delta: float = t.competence - s.competence
						if delta >= 0.08 and delta <= 0.45:
							var dist := Vector2(Layout.seat(s.seat_index)).distance_to(Vector2(Layout.seat(t.seat_index)))
							if dist > 2.2:
								pick = s
								tutor = t
								break
				if pick != null:
					break

	if pick == null and mode == "random":
		var seated: Array[StudentData] = []
		for s_rand: StudentData in Game.roster:
			if s_rand.seat_index >= 0:
				seated.append(s_rand)
		if not seated.is_empty():
			pick = seated[randi() % seated.size()]

	if pick == null:
		# Fallback: candidate farthest from the podium
		var cands: Array[StudentData] = []
		for s: StudentData in Game.roster:
			if s.seat_index >= 0:
				cands.append(s)
		cands.sort_custom(func(a: StudentData, b: StudentData) -> bool:
			return Vector2(Layout.seat(a.seat_index)).distance_to(Vector2(Layout.PODIUM)) > Vector2(Layout.seat(b.seat_index)).distance_to(Vector2(Layout.PODIUM)))
		for c: StudentData in cands.slice(0, 5):
			var stand: Vector2i = Layout.seat(c.seat_index) + Layout.DESK_OFFSET + Vector2i(0, 1)
			if not await _go(stand, 160):
				continue
			await frames(3)
			if _offer("move_desk") != "-":
				pick = c
				break
			_log("desks", "%s's desk is busy: E=[%s]" % [c.first_name(), _offer("interact")])

	if pick == null:
		_log("desks", "no desk could be picked up today")
		return

	var pick_stand: Vector2i = Layout.seat(pick.seat_index) + Layout.DESK_OFFSET + Vector2i(0, 1)
	if not await _go(pick_stand, 160):
		_log("desks", "could not reach %s's desk" % pick.first_name())
		return
	await frames(3)
	if _offer("move_desk") == "-":
		_log("desks", "%s's desk is busy: E=[%s]" % [pick.first_name(), _offer("interact")])
		return

	await tap("move_desk")
	await frames(4)
	var pl = main.placement
	if pl == null or not pl.active or pl.desk_index < 0:
		_log("desks", "could not pick up %s's desk (M=[%s])" % [pick.display_name, _offer("move_desk")])
		if pl != null and pl.active:
			await tap("cancel")
		return

	var start: Vector2i = pl.tile
	var target_anchor := Vector2(Layout.seat(tutor.seat_index)) if tutor != null else Vector2(Layout.PODIUM + Vector2i(0, 2))
	var spots: Array[Vector2i] = []
	for y in range(3, 8):
		for x in range(3, 17):
			var t2 := Vector2i(x, y)
			pl.tile = t2
			if pl.is_valid():
				if tutor != null:
					var td: float = Vector2(t2).distance_to(target_anchor)
					if td >= 1.0 and td <= 2.2:
						spots.append(t2)
				else:
					if Vector2(t2).distance_to(target_anchor) < Vector2(start).distance_to(target_anchor):
						spots.append(t2)
	pl.tile = start
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_to(target_anchor) < Vector2(b).distance_to(target_anchor))

	for spot: Vector2i in spots.slice(0, 4):
		var guard := 0
		while pl.tile != spot and guard < 80:
			guard += 1
			var d2: Vector2i = spot - pl.tile
			var before: Vector2i = pl.tile
			await tap(("move_right" if d2.x > 0 else "move_left") if absi(d2.x) >= absi(d2.y) else ("move_down" if d2.y > 0 else "move_up"))
			if pl.tile == before:
				break
		if pl.tile == spot and pl.is_valid():
			await tap("interact")
			await frames(4)
			_log("desks", "moved %s's desk from %s to %s (target=%s)" % [
				pick.display_name, start, spot, tutor.first_name() if tutor != null else "podium"])
			return
	_log("desks", "no better place for %s's desk" % pick.display_name)
	await tap("cancel")


# ---------------------------------------------------------------- the mentor

## Walk the player to a point in the CURRENT room's own coordinates. The hallway and the
## mentor's room are not tile grids, so this presses directions from pixel positions instead.
func _walk_local(target: Vector2, tol: float = 5.0, limit: int = 600) -> bool:
	var actual_tol := maxf(tol, 4.0 * maxf(speed, 1.0))
	for i in limit:
		var d: Vector2 = target - player.position
		if d.length() <= actual_tol:
			_release()
			await frames(3)
			return true
		_release()
		if absf(d.x) > actual_tol:
			Input.action_press("move_right" if d.x > 0.0 else "move_left")
		if absf(d.y) > actual_tol:
			Input.action_press("move_down" if d.y > 0.0 else "move_up")
		await get_tree().physics_frame
	_release()
	return false


## Go to the mentor's room and learn what the mentor teaches (the dash, answering everyone at
## once, then the chain and the call), the way a new teacher would. Once per run.
func _maybe_mentor() -> void:
	if _mentor_done or _mentor_tries >= 3 or Game.day < 2:
		return
	_mentor_tries += 1
	if not await _go(Layout.DOOR + Vector2i(1, 0)):
		_log("mentor", "could not reach the hallway door")
		return
	await tap("manage")
	await frames(secs(1.5))
	if not main.hallway.visible:
		_log("mentor", "the hallway door did not open (F=[%s])" % _offer("manage"))
		return
	_log("mentor", "in the hallway at %s" % [player.position])
	# door 2 is the mentor's: doors sit at x = 64 + 96 * index along the hallway
	var door_x := 64.0 + 96.0 * 2.0
	var entered := false
	for y in [68.0, 72.0, 76.0, 64.0]:
		if await _walk_local(Vector2(door_x, y), 4.0, 500) and _offer("manage") != "-":
			await tap("manage")
			await frames(secs(1.5))
			entered = main.mentor_room.visible
			if entered:
				break
	if not entered:
		_log("mentor", "could not enter the mentor's room (at %s, F=[%s])" % [player.position, _offer("manage")])
		await _leave_hallway()
		return
	_log("mentor", "met the mentor")
	var guard := 0
	while guard < 80 and main.mentor_room.visible:
		guard += 1
		if hud.mode != hud.Mode.NONE:
			await tap("interact")
		else:
			await frames(secs(0.5))
			if not player.input_locked and guard > 6:
				break
	_log("mentor", "learned: dash=%s answer_all=%s chain=%s" % [
		Game.dash_taught, Game.answer_all_taught, Game.chain_dash_taught])
	# out through the mentor room's door, back to the hallway, then home
	var left := false
	for pt: Vector2 in [Vector2(-4, 134), Vector2(0, 138), Vector2(8, 134), Vector2(8, 130), Vector2(20, 138)]:
		if await _walk_local(pt, 4.0, 400) and _offer("manage") != "-":
			await tap("manage")
			await frames(secs(1.5))
			left = main.hallway.visible
			if left:
				break
	if not left:
		_log("mentor", "could not leave the mentor's room (at %s, F=[%s])" % [player.position, _offer("manage")])
		return
	await _leave_hallway()
	_mentor_done = Game.dash_taught


## Back through the home door (door 0) to the classroom.
func _leave_hallway() -> void:
	for y in [68.0, 72.0, 76.0, 64.0]:
		if await _walk_local(Vector2(64.0, y), 4.0, 500) and _offer("manage") != "-":
			await tap("manage")
			await frames(secs(1.5))
			if not main.hallway.visible:
				_log("mentor", "back in the classroom")
				return
	_log("mentor", "could not find the way home from the hallway (at %s, F=[%s])" % [player.position, _offer("manage")])
