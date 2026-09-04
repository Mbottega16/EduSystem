extends Interactable

## One student's desk. Everything you do to an individual student happens
## here, chosen by priority rather than by a menu:
##
##   0. it is a materials day and they have nothing -> hand it to them
##   1. a flare-up is brewing -> catch it before the countdown runs out
##   1. they're playing up    -> settle them
##   2. they're stuck        -> help them
##   3. classwork finished   -> collect it
##   4. quiz flagged them    -> go over it with them
##   5. homework brought in  -> collect that
##
## Helping outranks collecting deliberately. A stuck student's work timer is
## frozen, so if you grab a finished sheet from the next desk instead of
## unsticking them, they stay stuck — the priority makes the urgent thing the
## default thing.

enum Action { NONE, HAND_OUT, DEFUSE, SETTLE, HELP, COLLECT_WORK, GO_OVER, COLLECT_HW }

var seat_index: int = -1
var paper: Sprite2D = null      ## the finished sheet sitting on the desk


func student() -> StudentData:
	return Game.student_in_seat(seat_index)


func action() -> int:
	var s := student()
	if s == null:
		return Action.NONE
	# On a materials day, a child with nothing in front of them cannot get
	# started at all, so putting that right outranks every other job at the
	# desk -- including a flare-up, which at least means they had something
	# to stop doing. Only ever offered on a materials day; on every other
	# day has_supply is already true for everyone.
	if not s.has_supply:
		return Action.HAND_OUT
	# A flare-up is on a clock and catching it stops a disruption before it
	# starts, so it outranks everything else -- including settling.
	if s.flaring():
		return Action.DEFUSE
	# Settling comes next, above even a stuck child. Messing about spreads
	# to the desks either side; being stuck does not. The most urgent thing
	# is the one that gets worse while you deal with something else.
	if s.disrupting:
		return Action.SETTLE
	if s.is_struggling():
		return Action.HELP
	if s.has_work_to_collect():
		return Action.COLLECT_WORK
	# Only ever offered because a quiz was run. It is the payoff for having
	# spent the lesson seconds -- without it the quiz would be a read-out.
	if s.quiz_flagged:
		return Action.GO_OVER
	if s.hw_state == StudentData.HW.DONE:
		return Action.COLLECT_HW
	return Action.NONE


func can_interact() -> bool:
	# A test is silent. No helping, no collecting, no going over anything --
	# it is the one stretch of the game where you can only watch.
	if Game.test_active:
		return false
	return action() != Action.NONE


func prompt_text() -> String:
	var s := student()
	if s == null:
		return ""
	var who: String = s.first_name()
	# The same verbs, reworded for the paper: you cannot HELP a child with
	# an exam question, but you can steady one who has frozen on it.
	var fight: bool = Game.fight_active()
	match action():
		Action.HAND_OUT: return "Give %s their things" % who
		Action.DEFUSE: return "Head off %s before they kick off" % who
		Action.SETTLE: return ("Settle %s" if fight else "Have a word with %s") % who
		Action.HELP: return ("Steady %s" if fight else "Help %s") % who
		Action.COLLECT_WORK: return "Collect %s's work" % who
		Action.GO_OVER: return "Go over the quiz with %s" % who
		Action.COLLECT_HW: return "Take %s's homework" % who
	return ""


func interact(by: Node) -> void:
	var s := student()
	if s == null:
		return
	match action():
		Action.HAND_OUT:
			if Game.give_supply(s):
				Sfx.play_varied("paper")
				_pop("ta!", Color(1, 0.92, 0.6))
				if by != null and by.has_method("play_pose"):
					by.play_pose(Actor.POSE_HANDOFF)
				used.emit(by)
		Action.DEFUSE:
			if s.defuse():
				Game.add_coins(Balance.flare_reward)
				Sfx.play("help")
				_pop("phew!", Color(1.0, 0.8, 0.4))
				used.emit(by)
		Action.SETTLE:
			if s.settle():
				Sfx.play("deny")             # a sterner noise than helping
				_pop("sorry!", Color(1, 0.7, 0.5))
				used.emit(by)
		Action.HELP:
			if s.help():
				Sfx.play("help")
				_pop("steady" if Game.fight_active() else "got it!",
					Color(0.55, 1.0, 0.6))
				used.emit(by)
		Action.COLLECT_WORK:
			if s.collect_work():
				Sfx.play_varied("paper")
				_pop("+work", Color(1, 0.92, 0.6))
				show_paper(false)
				if by != null and by.has_method("carry_work"):
					by.carry_work(1)
				used.emit(by)
		Action.GO_OVER:
			if s.resolve_quiz():
				Sfx.play("help")
				_pop("ohhh!", Color(0.6, 0.85, 1.0))
				used.emit(by)
		Action.COLLECT_HW:
			s.hw_state = StudentData.HW.COLLECTED
			Sfx.play_varied("paper")
			if by != null and by.has_method("carry_homework"):
				by.carry_homework(1)
			used.emit(by)


func _pop(text: String, colour: Color) -> void:
	var world := get_parent()
	while world != null and not world.has_method("student_node"):
		world = world.get_parent()
	if world != null:
		Floater.pop(world, global_position + Vector2(0, -36), text, colour)   # doubled, was -18
		# Chalk dust where it happened. The word tells you WHAT; the puff is
		# what makes the desk feel like the place it happened at.
		Fx.puff(world, global_position + Vector2(0, -10), colour)


func show_paper(on: bool) -> void:
	if paper != null:
		paper.visible = on
