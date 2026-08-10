extends Interactable

## The front of the room. The lesson is started and ended here.
##
## You walk up to it rather than pressing a hotkey, because the whole premise
## is that the teacher's movement is the game. The podium ends the LESSON;
## the bell ends the DAY. Two distinct verbs, deliberately at opposite ends of
## the room.

signal lesson_started(assigned: int)
signal lesson_ended(results: Array)


func _classroom() -> Node:
	var n := get_parent()
	while n != null and not n.has_method("start_lesson"):
		n = n.get_parent()
	return n


func can_interact() -> bool:
	if Game.phase == Game.Phase.MORNING:
		var room := _classroom()
		return room != null and room.everyone_seated() and not Game.roster.is_empty()
	return Game.phase == Game.Phase.LESSON


func prompt_text() -> String:
	if Game.phase == Game.Phase.MORNING:
		return "Start the lesson - %s" % Game.subject
	if Game.phase == Game.Phase.LESSON:
		return "End the lesson"
	return ""


func interact(by: Node) -> void:
	var room := _classroom()
	if room == null:
		return
	if Game.phase == Game.Phase.MORNING:
		lesson_started.emit(room.start_lesson())
	elif Game.phase == Game.Phase.LESSON:
		lesson_ended.emit(room.end_lesson())
	used.emit(by)
