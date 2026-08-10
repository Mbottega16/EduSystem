extends Interactable

## The front of the room. Assigning work to the class happens here — you walk
## up to it rather than pressing a hotkey, because the whole premise is that
## the teacher's movement is the game.

signal work_assigned(count: int)


## Only offer it when at least one seated student has nothing to do. That
## stops the prompt sitting there uselessly while the class is already busy.
func can_interact() -> bool:
	return _idle_seated_count() > 0


func prompt_text() -> String:
	return "Assign work (%d)" % _idle_seated_count()


func interact(_by: Node) -> void:
	var n := 0
	for s: StudentData in Game.roster:
		if _is_seated(s) and s.assign_work():
			n += 1
	if n > 0:
		work_assigned.emit(n)
		used.emit(_by)


## A student still walking to their chair can't be handed a sheet.
func _is_seated(s: StudentData) -> bool:
	var world := get_parent()
	while world != null and not world.has_method("student_node"):
		world = world.get_parent()
	if world == null:
		return true
	var node: Actor = world.student_node(s.seat_index)
	return node != null and node.seated


func _idle_seated_count() -> int:
	var n := 0
	for s: StudentData in Game.roster:
		if s.work_state == StudentData.Work.NONE and _is_seated(s):
			n += 1
	return n
