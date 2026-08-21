extends Interactable

## "Right, everyone — quick quiz." Called from the podium, mid-lesson.
##
## On its own dedicated QUIZ key (Q), separate from both the podium's own
## start/end-the-lesson verb (MANAGE/F) and the mashable USE/E a quiz used
## to share with helping and collecting. It moved off USE on user request,
## Aug 2026 -- a quiz calling itself while you mash E to help a stuck
## child was a real risk the moment quiz and help could ever land on the
## same tile's prompt.
##
## THE TRADE, and it is the whole design: a quiz costs LESSON SECONDS, which
## is the one resource a lesson cannot make more of. What you buy is
## knowing who is behind while there is still time to walk over and fix it.
## Homework tells you the same thing tomorrow, when it is too late.

signal quiz_requested()


func _init() -> void:
	super()
	uses_key = Key.QUIZ


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
