extends Interactable

## Your own desk. Two jobs, by priority: take the classwork out of your arms,
## then mark the homework you've collected.

signal work_handed_in(count: int)
signal marking_requested()

var handed_in: int = 0


func _carrier() -> Node:
	return get_tree().get_first_node_in_group("carrier")


func can_interact() -> bool:
	var c := _carrier()
	if c == null:
		return false
	return c.carrying > 0 or c.carrying_hw > 0


func prompt_text() -> String:
	var c := _carrier()
	if c == null:
		return ""
	if c.carrying > 0:
		return "Hand in %d sheet%s" % [c.carrying, "" if c.carrying == 1 else "s"]
	if c.carrying_hw > 0:
		return "Mark %d homework" % c.carrying_hw
	return ""


func interact(by: Node) -> void:
	var c: Node = by if (by != null and by.has_method("carry_work")) else _carrier()
	if c == null:
		return
	if c.carrying > 0:
		handed_in += c.carrying
		c.drop_all_work()
		work_handed_in.emit(handed_in)
	elif c.carrying_hw > 0:
		marking_requested.emit()
	used.emit(by)
