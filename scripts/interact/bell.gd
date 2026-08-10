extends Interactable

## Ends the day. Deliberately across the room from the podium, so calling
## time is a walk rather than a reflex.

signal day_ended(report: Dictionary)


func _classroom() -> Node:
	var n := get_parent()
	while n != null and not n.has_method("end_day"):
		n = n.get_parent()
	return n


func can_interact() -> bool:
	return Game.phase == Game.Phase.AFTERNOON


func prompt_text() -> String:
	if Game.phase == Game.Phase.LESSON:
		return ""
	return "Ring the bell — end day %d" % Game.day


func interact(by: Node) -> void:
	var room := _classroom()
	if room == null:
		return
	Sfx.play("bell")
	day_ended.emit(room.end_day())
	used.emit(by)
