extends Interactable

## One student's desk. Everything you do to an individual student happens
## here, chosen by priority rather than by a menu:
##
##   1. they're stuck        -> help them
##   2. classwork finished   -> collect it
##   3. homework brought in  -> collect that
##
## Helping outranks collecting deliberately. A stuck student's work timer is
## frozen, so if you grab a finished sheet from the next desk instead of
## unsticking them, they stay stuck — the priority makes the urgent thing the
## default thing.

enum Action { NONE, HELP, COLLECT_WORK, COLLECT_HW }

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
	if s.hw_state == StudentData.HW.DONE:
		return Action.COLLECT_HW
	return Action.NONE


func can_interact() -> bool:
	return action() != Action.NONE


func prompt_text() -> String:
	var s := student()
	if s == null:
		return ""
	var who: String = s.display_name.split(" ")[0]
	match action():
		Action.HELP: return "Help %s" % who
		Action.COLLECT_WORK: return "Collect %s's work" % who
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
				used.emit(by)
		Action.COLLECT_WORK:
			if s.collect_work():
				Sfx.play_varied("paper")
				show_paper(false)
				if by != null and by.has_method("carry_work"):
					by.carry_work(1)
				used.emit(by)
		Action.COLLECT_HW:
			s.hw_state = StudentData.HW.COLLECTED
			Sfx.play_varied("paper")
			if by != null and by.has_method("carry_homework"):
				by.carry_homework(1)
			used.emit(by)


func show_paper(on: bool) -> void:
	if paper != null:
		paper.visible = on
