extends Interactable

## The front of the room. The lesson is started and ended here.
##
## You walk up to it rather than pressing a hotkey, because the whole premise
## is that the teacher's movement is the game. The podium ends the LESSON;
## the bell ends the DAY. Two distinct verbs, deliberately at opposite ends of
## the room.

signal lesson_started(assigned: int)
## Setting work is a CHOICE now: a hand of 3-7 papers is drawn and you pick one.
signal hand_requested()

func _init() -> void:
	super()
	uses_key = Key.TEACH
signal lesson_ended(results: Array)
signal test_ended(results: Array)


func _classroom() -> Node:
	var n := get_parent()
	while n != null and not n.has_method("start_lesson"):
		n = n.get_parent()
	return n


## Starting a lesson is free to undo, so it is a tap. Ending one early
## throws away whatever the class had not finished, so it is a hold.
func _update_hold() -> void:
	hold_time = 0.55 if Game.phase == Game.Phase.LESSON else 0.0


func can_interact() -> bool:
	_update_hold()
	if Game.phase == Game.Phase.MORNING:
		# NOT "everyone is seated". That gate meant the podium offered
		# absolutely nothing for the ten seconds the class takes to file in
		# -- no prompt, no reason, just a blank prompt bar at the one landmark
		# the whole day starts from. A player walks up, sees nothing, and
		# concludes the game is broken. They were right to.
		#
		# You can start the lesson whenever you like now. Anyone still on
		# their way gets their work the moment they sit down, so starting
		# early costs THEM a little working time and costs you nothing you
		# cannot see.
		return not Game.roster.is_empty()
	return Game.phase == Game.Phase.LESSON


func prompt_text() -> String:
	if Game.phase == Game.Phase.MORNING:
		return "Teach %s" % String(Game.lesson.get("name", Game.subject))
	if Game.phase == Game.Phase.LESSON:
		return "Collect the papers" if Game.test_active else "End the lesson early"
	return ""


func interact(by: Node) -> void:
	var room := _classroom()
	if room == null:
		return
	if Game.phase == Game.Phase.MORNING:
		# The hand comes first. The lesson does not begin until a paper has
		# been chosen, because the paper is what the lesson IS.
		Sfx.play("blip")
		hand_requested.emit()
	elif Game.phase == Game.Phase.LESSON:
		if Game.test_active:
			test_ended.emit(room.end_test())
		else:
			lesson_ended.emit(room.end_lesson())
	used.emit(by)
