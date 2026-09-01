extends Interactable

## "Right, everyone -- eyes here." The mass-help skill, called from the
## podium mid-lesson on its own dedicated key (J).
##
## It does in one press what walking to every stuck desk and pressing E
## would: clears confusion, resolves the flagged quizzes. The trade is the
## same shape as the quiz's and steeper -- a big slice of lesson seconds up
## front (classroom.run_answer_all()) and a long cooldown before it comes
## back. It pays NO grade and NO coins: it is a panic button for a room
## that has got away from you, not a way to skip the floor work.

signal answer_all_requested()


func _init() -> void:
	super()
	uses_key = Key.ANSWER_ALL


func can_interact() -> bool:
	if Game.phase != Game.Phase.LESSON:
		return false
	if Game.test_active or not Game.answer_all_ready():
		return false
	return not Game.roster.is_empty()


func prompt_text() -> String:
	return "Answer their questions"


func interact(by: Node) -> void:
	answer_all_requested.emit()
	used.emit(by)
