extends Interactable

## "Right, everyone — quick quiz." Called from the podium, mid-lesson.
##
## On USE (E), while the podium's own start/end-the-lesson verb stays on
## MANAGE (F). A quiz is safe and reversible in a way that ending a lesson
## emphatically is not, so it belongs on the mashable button — and the two
## being different keys is what makes it safe to put them on one landmark.
##
## THE TRADE, and it is the whole design: a quiz costs LESSON SECONDS, which
## is the one resource a lesson cannot make more of. What you buy is
## knowing who is behind while there is still time to walk over and fix it.
## Homework tells you the same thing tomorrow, when it is too late.

signal quiz_requested()


func _init() -> void:
	super()
	uses_key = Key.USE


func can_interact() -> bool:
	if Game.phase != Game.Phase.LESSON:
		return false
	if Game.quiz_done or Game.test_active:
		return false
	return not Game.roster.is_empty()


func prompt_text() -> String:
	return "Quick quiz"


func interact(by: Node) -> void:
	quiz_requested.emit()
	used.emit(by)
