extends "res://tools/playdrive.gd"

## Walk a real day, the way a player does, and print what happens.
##
## The test suite TELEPORTS the player and presses keys straight into the
## InputMap. That is fine for logic and useless for "can I actually ring the
## bell", because it skips walking, collision, prompt text and every piece
## of state that only exists once a real day has run its course.
##
## This drives movement through the same actions a keyboard drives, waits
## for what a player would wait for, and reports the phase, the prompt and
## the targets at each step. Run it when the game says one thing and the
## suite says another.
##
##   godot --path . res://tools/playtrace.tscn
##
## DELIBERATELY NOT A GATE. This is a narrator: a human reads its steps and
## decides what they mean. playterm.gd is the one with a pass bar and an
## exit code, and it is the one wired into .githooks/pre-push. Do not put
## this behind an automated check without giving it a verdict line first --
## an exit code nobody sets is the exact bug that hid a regression here for
## four days.
##
## The walking, the keypresses and the boot live in playdrive.gd, shared
## with playterm.gd. They used to be copied into both files, which is how
## a fix to walk_to() landed in one copy and not the other.

var _step := 0


func _ready() -> void:
	await boot(12345)
	await _trace()
	get_tree().quit()


func say(what: String) -> void:
	_step += 1
	print("%2d. %s" % [_step, what])


func state() -> String:
	var phase: String = ["MORNING", "LESSON", "AFTERNOON"][Game.phase]
	var use: String = _prompt_of("interact")
	var man: String = _prompt_of("manage")
	# L is the lesson's own key since the Aug 2026 remap; a trace that
	# only printed E and F could not see the one verb the day starts on.
	var tch: String = _prompt_of("teach")
	return "day %d  %s  hud=%s  locked=%s  E=[%s]  F=[%s]  L=[%s]" % [
		Game.day, phase, hud.mode,
		player.input_locked, use, man, tch]


func _prompt_of(action: String) -> String:
	var t: Variant = player.targets.get(action)
	if t == null or not is_instance_valid(t):
		return "-"
	return (t as Interactable).prompt_text()


func _trace() -> void:
	print("\n==================== A REAL DAY ====================")
	await frames(6)          # the very first moment of the day
	say("class in: " + state())
	say("   students=%d  seated=%d  everyone_seated=%s" % [
		world.students.size(),
		world.students.filter(func(n: Actor) -> bool: return n.seated).size(),
		world.everyone_seated()])
	for n: Actor in world.students:
		say("   %-14s at %s  seat %s  seated=%s" % [
			n.data.display_name if n.data != null else "?",
			Grid.world_to_tile(n.global_position),
			Layout.seat(n.data.seat_index) if n.data != null else "-",
			n.seated])
	say("   pick radius = %.1f" % Progress.pick_radius(Game.perk_ranks))
	say("   podium.can_interact=%s  board=%s  bell=%s" % [
		world.podium.can_interact(), world.noticeboard.can_interact(),
		world.bell.can_interact()])

	if not await walk_to(Layout.PODIUM + Vector2i(0, 1)):
		say("!! COULD NOT WALK TO THE PODIUM")
	say("at podium: " + state())

	# "teach" (L), not "manage" (F): the podium's start verb moved to its
	# own key in the Aug 2026 remap, and this trace kept pressing the old
	# one -- so it stalled on day one and was read as "the term never
	# resolves" for a week.
	await tap("teach")
	# The podium draws a hand of papers now; the lesson starts when you
	# take one. Two presses, not one.
	if hud.mode == hud.Mode.HAND:
		await tap("interact")
		await frames(4)
	say("tapped L, took a paper: " + state())

	# let the clock run all the way out, the way an idle player would
	var guard := 0
	while Game.phase == Game.Phase.LESSON and guard < 5000:
		await get_tree().physics_frame
		guard += 1
	say("lesson over after %d frames: %s" % [guard, state()])

	if hud.mode != hud.Mode.NONE:
		await tap("interact")
		say("closed the report: " + state())

	if not await walk_to(Layout.BELL + Vector2i(0, 1)):
		say("!! COULD NOT WALK TO THE BELL — stuck at %s" % [
			Grid.world_to_tile(player.global_position)])
	say("at bell: " + state())
	say("   bell.can_interact = %s   hold_time = %.2f  key = %s" % [
		world.bell.can_interact(), world.bell.hold_time,
		world.bell.action_name()])

	var day_before: int = Game.day
	await hold("manage", 1.0)
	say("held F: " + state())
	if Game.day == day_before:
		say("!! THE BELL DID NOT RING")
	else:
		say("the bell rang. Day is now %d" % Game.day)
	print("====================================================\n")
