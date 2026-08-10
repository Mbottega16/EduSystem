extends Interactable

## Your own desk. Where collected work gets handed in.

signal work_handed_in(count: int)

var handed_in: int = 0


func can_interact() -> bool:
	return _carrier() != null and _carrier().carrying > 0


func prompt_text() -> String:
	var c := _carrier()
	if c == null:
		return ""
	return "Hand in %d sheet%s" % [c.carrying, "" if c.carrying == 1 else "s"]


func interact(by: Node) -> void:
	var c: Node = by if (by != null and by.has_method("carry_work")) else _carrier()
	if c == null or c.carrying <= 0:
		return
	handed_in += c.carrying
	c.drop_all_work()
	work_handed_in.emit(handed_in)
	used.emit(by)


## The prompt has to be answerable before anyone touches this, so it finds
## the carrier itself rather than waiting to be handed one.
func _carrier() -> Node:
	for n in get_tree().get_nodes_in_group("carrier"):
		return n
	return null
