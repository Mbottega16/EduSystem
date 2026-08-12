extends Interactable

## One student's desk. Everything you do to an individual student happens
## here, chosen by priority rather than by a menu:
##
##   1. they're stuck        -> help them
##   2. classwork finished   -> collect it
##   3. quiz flagged them    -> go over it with them
##   4. homework brought in  -> collect that
##
## Helping outranks collecting deliberately. A stuck student's work timer is
## frozen, so if you grab a finished sheet from the next desk instead of
## unsticking them, they stay stuck — the priority makes the urgent thing the
## default thing.

enum Action { NONE, HELP, COLLECT_WORK, GO_OVER, COLLECT_HW }

var seat_index: int = -1
var paper: Sprite2D = null      ## the finished sheet sitting on the desk


func student() -> StudentData:
	return Game.student_in_seat(seat_index)


func action() -> int:
	var s := student()
	if s == null:
		return Action.NONE
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
	return action() != Action.NONE


func prompt_text() -> String:
	var s := student()
	if s == null:
		return ""
	var who: String = s.first_name()
	match action():
		Action.HELP: return "Help %s" % who
		Action.COLLECT_WORK: return "Collect %s's work" % who
		Action.GO_OVER: return "Go over the quiz with %s" % who
		Action.COLLECT_HW: return "Take %s's homework" % who
	return ""


func interact(by: Node) -> void:
	var s := student()
	if s == null:
		return
	match action():
		Action.HELP:
			if s.help():
				Sfx.play("help")
				_pop("got it!", Color(0.55, 1.0, 0.6))
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
		Floater.pop(world, global_position + Vector2(0, -18), text, colour)


func show_paper(on: bool) -> void:
	if paper != null:
		paper.visible = on
