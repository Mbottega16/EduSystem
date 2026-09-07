extends Actor

## The teacher. You.
##
## Movement is read through INPUT ACTIONS, never Input.is_physical_key_pressed.
## That distinction is load-bearing: Input.action_press() can drive an action
## from a test, but nothing can fake a physical key press, so the old WASD
## handling was untestable by construction.

signal target_changed(target: Interactable)
signal carrying_changed(count: int)

@onready var zone: Area2D = $InteractZone
@onready var carry_icon: Sprite2D = $CarryIcon
@onready var hat_sprite: Sprite2D = $HatSprite
@onready var bubble: SpeechBubble = $SpeechBubble

## What each BUTTON is pointing at. Two interactables may share a tile so
## long as they use different keys -- the podium offers "teach today's
## lesson" on L and "unit test" on E at the same moment, and a desk offers
## "help" on E and "move this desk" on F.
##
## This used to be a single target for both buttons, which meant that
## whenever two things overlapped one of them was silently unreachable and
## the tie was broken by node order. Every landmark that has grown a second
## verb since has run into it.
## One slot per action an Interactable can be bound to -- see
## Interactable.KEY_ACTIONS, the single source for this list.
var targets: Dictionary = {
	"interact": null, "manage": null,
	"quiz": null, "homework": null, "move_desk": null, "teach": null,
	"respond": null, "answer_all": null,
}

## The one to describe in the prompt. USE wins when both are live: it is the
## button you are already holding a finger over.
var target: Interactable = null
var carrying: int = 0        ## classwork sheets in your arms
var carrying_hw: int = 0     ## homework collected, waiting to be marked
## Set while a full-screen overlay owns the input, so you don't wander off
## behind the catalogue.
var input_locked: bool = false

## Walk me to whoever needs me next, and back to the front when nobody does.
##
## It moves your FEET and never presses your buttons. What to do once you
## arrive is still a judgement, and so is the decision to leave the front at
## all -- which is the trade the whole lesson is built on. Crossing a room
## you can already see is simply not the interesting part.
var autopilot: bool = false
signal autopilot_changed(on: bool)


## Where autopilot is currently heading, for the HUD. Empty when idle.
var auto_target_name: String = ""

## Cutscene-only movement: walk toward a fixed point under SCRIPT control
## rather than input, for the storyline intro's walk-in. Deliberately its
## own thing rather than a mode of autopilot -- autopilot chases whoever
## currently needs you and re-aims every frame; this walks toward one fixed
## point once and is done, a stage direction rather than a standing policy.
var _walk_target: Vector2 = Vector2.ZERO
var _walking_scripted: bool = false


func start_scripted_walk(target: Vector2) -> void:
	_walk_target = target
	_walking_scripted = true


func is_walking_scripted() -> bool:
	return _walking_scripted


func _scripted_walk_direction() -> Vector2:
	var to: Vector2 = _walk_target - global_position
	if to.length() <= 3.0:
		_walking_scripted = false
		return Vector2.ZERO
	return to.normalized()


## The player's own voice, above their own head -- see SpeechBubble.
func say(text: String) -> void:
	if bubble != null:
		bubble.say(text)


func hide_bubble() -> void:
	if bubble != null:
		bubble.hide_bubble()


## Built entirely in code (no new scene/art), the same way the yearbook
## screen was: a badge per key currently on offer, floating above the
## teacher's head so a new player can SEE what pressing E, H, L etc. does
## without opening a menu first. One row, positioned above SpeechBubble
## (which sits at y -28) so the two never overlap.
const _KEY_PROMPT_Y := -46.0
const _KEY_PROMPT_COLORS := {
	"interact": Color(0.55, 0.85, 1.0), "manage": Color(1.0, 0.75, 0.4),
	"teach": Color(1.0, 0.55, 0.75), "quiz": Color(0.7, 0.6, 1.0),
	"homework": Color(0.6, 1.0, 0.65), "move_desk": Color(0.85, 0.85, 0.6),
	"respond": Color(1.0, 0.55, 0.4), "answer_all": Color(0.55, 0.8, 0.85),
}
var _key_prompts_root: Node2D = null
var _key_prompt_badges: Dictionary = {}   ## action -> {"box": ColorRect, "label": Label, "tween": Tween}


func _build_key_prompts_root() -> void:
	_key_prompts_root = Node2D.new()
	_key_prompts_root.position = Vector2(0, _KEY_PROMPT_Y)
	_key_prompts_root.z_index = 5
	add_child(_key_prompts_root)


## Rebuilds the badge row from player.offers() every physics frame. Cheap:
## at most a handful of Interactables are ever in range at once, and this
## only touches nodes when the SET of offered actions actually changed --
## an existing badge just has its text/afford-state refreshed in place, so
## the glow tween underneath it is never restarted needlessly.
func _update_key_prompts() -> void:
	if _key_prompts_root == null:
		return
	var live: Array[Interactable] = offers()
	var wanted: Dictionary = {}
	for t: Interactable in live:
		if not t.can_interact():
			continue
		wanted[t.action_name()] = t

	# drop badges whose action is no longer on offer
	for action: String in _key_prompt_badges.keys().duplicate():
		if not wanted.has(action):
			var gone: Dictionary = _key_prompt_badges[action]
			(gone["tween"] as Tween).kill()
			(gone["box"] as ColorRect).queue_free()
			_key_prompt_badges.erase(action)

	var x := 0.0
	# KEY_ACTIONS order, so the row reads in a stable left-to-right order
	# instead of jumping around as targets are picked up and dropped.
	for action: String in Interactable.KEY_ACTIONS:
		if not wanted.has(action):
			continue
		var t: Interactable = wanted[action]
		if not _key_prompt_badges.has(action):
			_key_prompt_badges[action] = _spawn_key_badge(action)
		var badge: Dictionary = _key_prompt_badges[action]
		var box := badge["box"] as ColorRect
		var label := badge["label"] as Label
		label.text = "%s  %s" % [t.key_hint(), t.prompt_text()]
		box.size = label.get_minimum_size() + Vector2(10, 6)
		box.position = Vector2(x, 0)
		x += box.size.x + 6.0

	# Keep the row on screen. It grows rightward from above the player's
	# head, so standing near the right wall it used to run clean off the
	# edge -- the last badge's key was unreadable. Shift the whole row back
	# on by however much it overhangs (either side). Badges are 1:1 with
	# screen pixels here, so the canvas transform is all this needs.
	if x > 0.0 and _key_prompts_root != null:
		var vp_w := get_viewport_rect().size.x
		var screen_x := (get_viewport().get_canvas_transform() * global_position).x
		var margin := 6.0
		var shift := 0.0
		if screen_x + x > vp_w - margin:
			shift = (vp_w - margin) - (screen_x + x)
		if screen_x + shift < margin:
			shift = margin - screen_x
		_key_prompts_root.position.x = shift
	elif _key_prompts_root != null:
		_key_prompts_root.position.x = 0.0


func _spawn_key_badge(action: String) -> Dictionary:
	var box := ColorRect.new()
	box.color = _KEY_PROMPT_COLORS.get(action, Color(0.8, 0.8, 0.8))
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.position = Vector2(5, 3)
	box.add_child(label)
	_key_prompts_root.add_child(box)

	# The "glow": a slow, looping pulse on the badge's own alpha, so it
	# reads as lit up rather than as flat, static HUD chrome. Cheap --
	# one Tween per badge, killed the moment the badge is dropped.
	var tw := create_tween().set_loops()
	tw.tween_property(box, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(box, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

	return {"box": box, "label": label, "tween": tw}


## The desk that most needs the teacher, by the same priority the desk
## itself uses. Null when the room is calm.
func _who_needs_me() -> StudentData:
	var best: StudentData = null
	var best_rank := 99
	var best_dist := 99999.0
	for s: StudentData in Game.roster:
		var rank := s.attention_rank()
		if rank == 0 or s.seat_index < 0:
			continue
		var d: float = global_position.distance_to(
			Grid.tile_to_world(Layout.seat(s.seat_index)))
		# more urgent first; among equals, whoever is nearest
		if rank < best_rank or (rank == best_rank and d < best_dist):
			best = s
			best_rank = rank
			best_dist = d
	return best


## The direction autopilot wants to walk, or ZERO to stand still.
func _auto_direction() -> Vector2:
	Balance.ensure_loaded()
	auto_target_name = ""
	if Game.phase != Game.Phase.LESSON or Game.test_active:
		return Vector2.ZERO

	var who := _who_needs_me()
	var goal: Vector2
	if who != null:
		auto_target_name = who.first_name()
		goal = Grid.tile_to_world(Layout.seat(who.seat_index) + Vector2i(0, 1))
	else:
		# nobody needs you, so go and do the job: back to the front
		if Game.can_teach_from(Grid.world_to_tile(global_position)):
			return Vector2.ZERO
		auto_target_name = "the front"
		goal = Grid.tile_to_world(Layout.PODIUM + Vector2i(0, 1))

	var to: Vector2 = goal - global_position
	if to.length() <= float(Balance.auto_arrive) * Grid.TILE:
		return Vector2.ZERO
	return to.normalized()


func _ready() -> void:
	_apply_reach()
	# teacher_desk.gd finds the carrier through this group rather than
	# needing a wired reference, so its prompt is answerable before anyone
	# has interacted with anything.
	add_to_group("carrier")
	_refresh_carry_icon()
	refresh_hat()
	_build_key_prompts_root()


func _physics_process(delta: float) -> void:
	tick_pose(delta)
	var dir := Vector2.ZERO
	if _walking_scripted:
		dir = _scripted_walk_direction()
	elif not input_locked:
		dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		if Game.claim_action("autopilot"):
			autopilot = not autopilot
			Sfx.play("blip")
			autopilot_changed.emit(autopilot)
		# Steering by hand always wins. Autopilot is a chauffeur, not a lock:
		# the instant you touch a movement key it stands aside for that frame,
		# so it can never fight you for the wheel.
		if autopilot and dir == Vector2.ZERO:
			dir = _auto_direction()
	_tick_dash(delta, dir)
	walk(dir, delta)

	# The thing you were standing at can be destroyed under you — sell a
	# bookshelf and its node is freed while this still points at it. Drop a
	# dead target before anything reads it.
	for action: String in targets.keys():
		_live(action)      # drops it if the node has been freed under us

	# AFTER move_and_slide, always: Area2D overlap state updates one physics
	# frame behind transform changes, so picking before moving would select
	# against where you were last frame.
	_repick()
	_update_key_prompts()

	_teach_anim(delta)
	if not input_locked:
		_tick_hold(delta)
		# The one verb that is not a landmark. It is still about where you
		# are standing -- only the desks within earshot hear it.
		if Game.claim_action("build"):
			var m := get_tree().get_first_node_in_group("main_wiring")
			if m != null and m.has_method("_toggle_build"):
				m._toggle_build()
		if Game.claim_action("voice"):
			var room := get_tree().get_first_node_in_group("classroom")
			if room != null and room.has_method("raise_voice"):
				room.raise_voice()
		if Game.claim_action("auto_teach"):
			var m2 := get_tree().get_first_node_in_group("main_wiring")
			if m2 != null and m2.has_method("_toggle_auto_teach"):
				m2._toggle_auto_teach()


## Nearest interactable, but strongly preferring whatever you are facing.
## Pure-nearest is ambiguous the moment two desks are in range, and a
## raycast fired from between two desks misses both.
func _pick_target(action: String = "") -> Interactable:
	var best: Interactable = null
	var best_score := -INF
	var f := facing_vector()
	for a in zone.get_overlapping_areas():
		if not (a is Interactable):
			continue
		# Bought furniture is torn down and rebuilt whenever the room
		# changes, and the physics server still hands back the old node for
		# a frame afterwards. Targeting one means the next press lands on a
		# corpse and silently does nothing.
		#
		# is_queued_for_deletion() is NOT enough. A landmark's Interactable
		# is a CHILD of the prop that carries the "room_part" group (see
		# RoomBuilder.add_prop) -- rebuild_room() calls queue_free() on the
		# PARENT, and that flag does not propagate to the child early, only
		# the eventual free() does. The child is detached from the tree the
		# instant remove_child() runs on its parent, well before that. This
		# is the actual, general check: is it in the tree RIGHT NOW.
		if not is_instance_valid(a) or not a.is_inside_tree():
			continue
		var it := a as Interactable
		if not it.can_interact():
			continue
		# Only ever compete with things on the SAME button.
		if action != "" and it.action_name() != action:
			continue
		var to: Vector2 = it.global_position - global_position
		var dist := to.length()
		var aligned := 1.0 if dist < 0.01 else f.dot(to / dist)
		var score := (100.0 if aligned > 0.2 else 0.0) - dist
		if score > best_score:
			best_score = score
			best = it
	return best


## A target that is still actually there.
##
## Reading a freed node into a TYPED variable throws "Trying to assign
## invalid previously freed instance", and that error aborts the rest of
## _physics_process -- every frame, forever, so targets stopped refreshing
## and every button went dead. It has to be checked as a Variant first.
##
## Same reason as the is_inside_tree() check in _pick_target(): a landmark
## detached by its parent's rebuild is still "valid" right up until the
## deferred free actually runs, and calling anything tree-dependent on it
## (can_interact(), interact(), even reading hold_time off some scripts)
## throws. This is what let one stale marking desk kill the homework
## screen for the rest of a run -- the crash happened here, inside
## _pick_target(), which aborts _physics_process before it ever reaches
## the line that would have refreshed targets and replaced it.
func _live(action: String) -> Interactable:
	var v: Variant = targets.get(action)
	if v == null or not is_instance_valid(v) or not (v as Node).is_inside_tree():
		targets[action] = null
		return null
	return v as Interactable


## Re-pick every button, and announce the one the prompt should describe.
func _repick() -> void:
	var before: Interactable = target
	for action: String in targets.keys():
		targets[action] = _pick_target(action)
	target = null
	for action: String in Interactable.KEY_ACTIONS:
		target = _live(action)
		if target != null:
			break
	if target != before:
		target_changed.emit(target)


## Everything currently on offer, so the prompt can list both buttons rather
## than only mentioning whichever one happened to win.
func offers() -> Array[Interactable]:
	var out: Array[Interactable] = []
	for action: String in Interactable.KEY_ACTIONS:
		var t := _live(action)
		if t != null:
			out.append(t)
	return out


## How far through a hold-to-confirm we are, 0..1. The HUD draws this.
var hold_progress: float = 0.0
var _held: float = 0.0
## Which button the in-progress hold belongs to, so releasing one does not
## wipe the other's progress.
var _holding: String = ""


## Route the press to the right BUTTON, and make anything irreversible
## require a HOLD.
##
## Before this, one key did everything: help, collect, hand in, start the
## lesson, end the lesson, ring the bell. Reaching to help a student who
## happened to be standing near the podium ended the whole lesson, which is
## about the worst possible thing a stray keypress can do in this game.
##
##   interact (E) - help, collect, hand in. Mashable, never destructive.
##   manage   (F) - lesson, bell, shop. Separate finger, separate intent.
##
## and on top of that, the two that cannot be undone need the key held.
func _tick_hold(delta: float) -> void:
	hold_progress = 0.0
	for action: String in Interactable.KEY_ACTIONS:
		_tick_one(action, delta)


## Each button is ticked independently. `_held` is shared because only one
## hold can be in progress at a time in practice -- you have two fingers, but
## a hold you abandon halfway resets anyway.
func _tick_one(action: String, delta: float) -> void:
	var t := _live(action)
	if t == null:
		if _holding == action:
			_held = 0.0
			_holding = ""
		return

	var need: float = t.hold_time

	if need <= 0.0:
		if Game.claim_action(action):
			t.interact(self)
			_repick()          # what you just did changes what is on offer
		return

	if Input.is_action_pressed(action):
		if _holding != action:
			_holding = action
			_held = 0.0
		_held += delta
		hold_progress = clampf(_held / need, 0.0, 1.0)
		if _held >= need:
			_held = -999.0            # fire once per hold, not once per frame
			hold_progress = 0.0
			t.interact(self)
			_repick()
	elif _holding == action:
		_held = 0.0
		_holding = ""
		hold_progress = 0.0


## Perks raise the teacher's base speed, so this is expressed as a ratio
## against the Actor constant rather than as a flat multiplier.
## Standing at the front, gesturing at the class -- POSE_CHAT (the sheet's
## Aug 2026 pose columns) held for most of a beat and released for one
## walk-step frame in between, so it reads as talking rather than a frozen
## photo. Before the pose columns existed this cycled the two STEP frames
## instead; that fallback is gone now that there is a real pose for it.
var _teach_t: float = 0.0

func _teach_anim(delta: float) -> void:
	if not Game.teaching:
		_teach_t = 0.0
		return
	facing = DIR_DOWN                 # turn and face the room
	_teach_t += delta
	if fmod(_teach_t, 0.7) < 0.35:
		_set_frame(POSE_CHAT, true)
	else:
		_set_frame(1)


func speed_scale() -> float:
	var base: float = Progress.speed(Game.perk_ranks, Game.boost_speed_mult()) / SPEED
	if autopilot and auto_target_name != "":
		base *= Balance.auto_speed
	if _dash_burst > 0.0:
		base *= Balance.teacher_dash_speed_multiplier
	return base


## The tap-dash. A short burst in whatever direction you are already
## heading, then a cooldown before the next one -- see teacher.dash_* in
## balance.json. It replaced the old held "Hurry" sprint: same key, but you
## tap it for a lunge instead of holding it to glide across the whole room.
## No stamina -- the cooldown is the entire limiter.
var _dash_burst: float = 0.0   ## seconds of burst still active
var _dash_cool: float = 0.0    ## seconds until the next dash is allowed
## Dash-cancel: seconds of widened reach left after a burst ended. See
## teacher.dash_cancel_* in balance.json -- a dash that stops just short of
## a desk still reaches it for this blink, so the burst connects into the
## action instead of dying a tile away.
var _dash_cancel_grace: float = 0.0
var _dash_reach_boosted: bool = false
## Furniture lanes -- see teacher.dash_lane_* in balance.json. How much
## lane-carry is left on the current dash, and whether the clutter "stumble"
## sound has already played for it (once per dash, not once per frame).
var _dash_lane_left: float = 0.0
var _dash_stumbled: bool = false
## Decoration only -- a dust kick on the launch and a fading trail through
## the burst, so a dash reads as a lunge instead of a brief speed-up. The
## room node the effect sprites hang on, and a timer so the trail is a
## handful of ghosts rather than one per frame. Neither touches Game.rng.
var _dash_fx_room: Node = null
## The most ghosts a trail may hold at once. Decoration, not a tunable.
const DASH_TRAIL_CAP := 12
## How far below the sprite's origin the smoke starts. The teacher's
## origin is their middle, and dust kicked from someone's waist reads as
## smoke coming off them rather than off the floor. Decoration, not a
## tunable -- it is a fact about where this sprite's feet are.
const SMOKE_FOOT_DROP := 10.0
var _dash_ghost_t: float = 0.0

## Double-tap-a-direction trigger. Seconds since the last just_pressed on
## each move_* action; a second press on the SAME direction within
## teacher.dash_double_tap_window fires a dash. Opposite/different
## directions never combine -- each has its own clock, so tap-left-then-
## tap-right cannot read as a dash. The dedicated `dash` action (Shift,
## see settings.gd) still fires the same burst; this is a second trigger
## for the same code below, not a replacement.
var _tap_since: Dictionary = {
	"move_left": 999.0, "move_right": 999.0, "move_up": 999.0, "move_down": 999.0,
}


## Returns true the one frame a double-tap fires. Always ticks the clocks,
## even when a dash could not fire right now (mid-burst, on cooldown,
## input locked), so a tap during that window still counts toward the
## next legal one.
func _tick_double_tap_dash(delta: float) -> bool:
	Balance.ensure_loaded()
	var fired := false
	for action: String in _tap_since.keys():
		_tap_since[action] = float(_tap_since[action]) + delta
		if Input.is_action_just_pressed(action):
			if float(_tap_since[action]) <= Balance.teacher_dash_double_tap_window:
				fired = true
			_tap_since[action] = 0.0
	# The tap clocks still tick above (so a tap during the window still
	# counts toward the next legal dash), but the dash itself does not
	# exist until the mentor teaches it -- see Game.dash_taught.
	return fired and Game.dash_taught


func _tick_dash(delta: float, dir: Vector2) -> void:
	var double_tapped := _tick_double_tap_dash(delta)
	var was_bursting := _dash_burst > 0.0
	_dash_burst = maxf(0.0, _dash_burst - delta)
	_dash_cool = maxf(0.0, _dash_cool - delta)

	# Furniture underfoot while the burst is live: a clear lane carries it,
	# a bit of clutter kills it dead. Layout only -- see dash_tile_kind().
	var crashed := false
	if _dash_burst > 0.0:
		match _dash_room_kind():
			"clutter":
				_dash_burst = 0.0
				_dash_cancel_grace = 0.0
				_dash_cool = maxf(_dash_cool, Balance.teacher_dash_clutter_penalty)
				crashed = true
				if not _dash_stumbled:
					_dash_stumbled = true
					Sfx.play("deny")
					var rm := get_tree().get_first_node_in_group("classroom")
					if rm != null:
						Fx.puff(rm, global_position + Vector2(0, -3),
							Color(0.82, 0.77, 0.7, 0.75), 3)
			"lane":
				if _dash_lane_left > 0.0:
					var carry: float = minf(delta, _dash_lane_left)
					# Capped at the LEVELLED duration, not the base one: with Light
					# Feet the base is shorter than the dash you actually fired, so
					# capping there would have a clear lane SHORTEN a levelled dash.
					_dash_burst = minf(Progress.dash_duration(Game.perk_ranks),
						_dash_burst + carry)
					_dash_lane_left -= carry

	# A few fading ghosts while the burst is live -- the trail draws itself
	# as we move on. Decoration: throttled, and never off Game.rng.
	# Gated on actually being in play (a cutscene or a locked screen spawns
	# none) and capped, so a trail can never outlive the moment it
	# decorates or pile up in a state nobody is watching.
	if _dash_burst > 0.0 and sprite != null and not input_locked \
			and not _walking_scripted:
		_dash_ghost_t += delta
		if _dash_ghost_t >= 0.03:
			_dash_ghost_t = 0.0
			if _dash_fx_room == null or not is_instance_valid(_dash_fx_room):
				_dash_fx_room = get_tree().get_first_node_in_group("classroom")
			if _dash_fx_room != null and Fx.afterimage_count(_dash_fx_room) < DASH_TRAIL_CAP:
				Fx.afterimage(sprite, _dash_fx_room)

	# The frame the burst runs out is the frame the grace window opens --
	# unless you ran it into a crate, which earns no "connect".
	if was_bursting and _dash_burst == 0.0 and not crashed:
		Balance.ensure_loaded()
		_dash_cancel_grace = Balance.teacher_dash_cancel_grace
	_dash_cancel_grace = maxf(0.0, _dash_cancel_grace - delta)
	_apply_dash_reach()
	if input_locked or _walking_scripted:
		return
	if dir == Vector2.ZERO or _dash_burst > 0.0 or _dash_cool > 0.0:
		return
	# Always consume the claim, but only act on it once the mentor has
	# taught the dash. double_tapped is already gated in _tick_double_tap_dash().
	var wants_dash := Game.claim_action("dash") or double_tapped
	if wants_dash and Game.dash_taught:
		Balance.ensure_loaded()
		# Through Progress, not straight off Balance: the Light Feet perk
		# lengthens the burst and shortens the wait, and every perk effect in
		# this game funnels through Progress so there is one place to look
		# when one does not seem to be doing anything.
		_dash_burst = Progress.dash_duration(Game.perk_ranks)
		_dash_cool = _dash_burst + Progress.dash_cooldown(Game.perk_ranks)
		_dash_lane_left = Balance.teacher_dash_lane_extend
		_dash_stumbled = false
		Sfx.play("blip")
		_kick_up_smoke(dir)


## The launch cloud. Decoration only -- gated on actually being in play, the
## same way the trail is, so a scripted walk or a locked screen kicks up
## nothing, and skipped entirely when there is no room to hang it on (a
## headless sim has no classroom node).
func _kick_up_smoke(dir: Vector2) -> void:
	if input_locked or _walking_scripted:
		return
	var room := get_tree().get_first_node_in_group("classroom")
	if room == null:
		return
	Balance.ensure_loaded()
	Fx.smoke(room, global_position + Vector2(0, SMOKE_FOOT_DROP), dir,
		Progress.dash_smoke_count(Game.perk_ranks),
		Balance.teacher_dash_smoke_spread,
		Progress.dash_smoke_scale(Game.perk_ranks),
		Balance.teacher_dash_smoke_seconds)


## 0 when dash is ready to fire again, up to 1 the instant one just did.
## The HUD's status strip reads this to draw a cooldown pip -- see
## hud.gd _update_status().
func dash_cooldown_fraction() -> float:
	Balance.ensure_loaded()
	# The LEVELLED total, matching what _tick_dash actually set _dash_cool
	# to. Measured against the base instead, a Light Feet dash would show a
	# meter that never quite filled.
	var total: float = Progress.dash_duration(Game.perk_ranks) \
		+ Progress.dash_cooldown(Game.perk_ranks)
	if total <= 0.0:
		return 0.0
	return clampf(_dash_cool / total, 0.0, 1.0)


## Whether the tile the teacher is standing on is beside a "lane" or
## "clutter" item -- asked of the classroom, "" when there is no room (a
## bare sim) or nothing tagged nearby.
func _dash_room_kind() -> String:
	var room := get_tree().get_first_node_in_group("classroom")
	if room != null and room.has_method("dash_tile_kind"):
		return room.dash_tile_kind(Grid.world_to_tile(global_position))
	return ""


## Widen the pick zone while the dash-cancel grace is live, and put it back
## the instant it lapses. Written through _apply_reach() so a perk bought
## mid-grace still lands on the right base radius.
func _apply_dash_reach() -> void:
	var want := _dash_cancel_grace > 0.0
	if want == _dash_reach_boosted:
		return
	_dash_reach_boosted = want
	_apply_reach()


## Only the teacher's footsteps are audible.
func on_step() -> void:
	Sfx.play_varied("step", 0.12 if speed_scale() <= 1.0 else 0.2)


## Long Reach widens the pick zone. Re-applied when a perk is bought.
func _apply_reach() -> void:
	if zone == null:
		return
	var r: float = Progress.pick_radius(Game.perk_ranks)
	if _dash_reach_boosted:
		Balance.ensure_loaded()
		r += Balance.teacher_dash_cancel_reach
	for c in zone.get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
			((c as CollisionShape2D).shape as CircleShape2D).radius = r


func carry_work(n: int) -> void:
	carrying += n
	_refresh_carry_icon()
	carrying_changed.emit(carrying)
	if n > 0:
		play_pose(POSE_HANDOFF)


func drop_all_work() -> void:
	if carrying > 0:
		play_pose(POSE_HANDOFF)
	carrying = 0
	_refresh_carry_icon()
	carrying_changed.emit(carrying)


func carry_homework(n: int) -> void:
	carrying_hw += n
	_refresh_carry_icon()
	carrying_changed.emit(carrying)
	if n > 0:
		play_pose(POSE_HANDOFF)


func drop_all_homework() -> void:
	if carrying_hw > 0:
		play_pose(POSE_HANDOFF)
	carrying_hw = 0
	_refresh_carry_icon()
	carrying_changed.emit(carrying)


func _refresh_carry_icon() -> void:
	if carry_icon == null:
		return
	carry_icon.visible = (carrying + carrying_hw) > 0


## Called once at spawn, and again the moment the wardrobe changes it --
## it never changes on its own the way carrying does, so nothing else
## needs to poll it every frame.
func refresh_hat() -> void:
	if hat_sprite == null:
		return
	var h := Cosmetics.hat_by_id(Game.hat_id)
	var art := String(h.get("art", ""))
	if art == "":
		hat_sprite.visible = false
		return
	hat_sprite.texture = load("res://art/%s.png" % art)
	hat_sprite.visible = true
