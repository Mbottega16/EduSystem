extends Interactable

## One student's desk. Two jobs: show whether their work is finished, and let
## the teacher pick that work up.

var seat_index: int = -1
var paper: Sprite2D = null      ## the finished sheet sitting on the desk


func student() -> StudentData:
	return Game.student_in_seat(seat_index)


func can_interact() -> bool:
	var s := student()
	return s != null and s.has_work_to_collect()


func prompt_text() -> String:
	var s := student()
	if s == null:
		return ""
	return "Collect %s's work" % s.display_name.split(" ")[0]


func interact(by: Node) -> void:
	var s := student()
	if s == null or not s.collect_work():
		return
	show_paper(false)
	if by != null and by.has_method("carry_work"):
		by.carry_work(1)
	used.emit(by)


func show_paper(on: bool) -> void:
	if paper != null:
		paper.visible = on
