extends Interactable

## Your own desk, on its own dedicated HOMEWORK key (H): mark the homework
## you've collected.
##
## Used to share a prompt with marking_desk.gd's "hand in classwork" job,
## both on USE/E, whichever was more pressing that moment. Split onto its
## own key on user request, Aug 2026 -- so marking is always reachable by
## name rather than only appearing once nothing else is offered on E.
##
## Shares the teacher desk's tile with marking_desk.gd rather than
## replacing it, the same way the noticeboard's shop and curriculum board
## share one tile on two different keys.

signal marking_requested()


func _init() -> void:
	super()
	uses_key = Key.HOMEWORK
	add_to_group("homework_desk")


func _carrier() -> Node:
	# Same defence-in-depth as marking_desk.gd's own _carrier() -- see its
	# comment for why this check exists at all.
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("carrier")


func can_interact() -> bool:
	var c := _carrier()
	if c == null:
		return false
	return c.carrying_hw > 0 or Game.total_graded_bank() > 0


func prompt_text() -> String:
	var c := _carrier()
	if c == null:
		return ""
	if c.carrying_hw > 0:
		return "Mark & trade %d homework" % c.carrying_hw
	if Game.total_graded_bank() > 0:
		return "Mark & trade papers (%d)" % Game.total_graded_bank()
	return ""


func interact(by: Node) -> void:
	var c: Node = by if (by != null and by.has_method("carry_work")) else _carrier()
	if c == null or (c.carrying_hw <= 0 and Game.total_graded_bank() <= 0):
		return
	marking_requested.emit()
	used.emit(by)
