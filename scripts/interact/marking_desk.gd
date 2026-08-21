extends Interactable

## Your own desk, on USE (E): take the classwork out of your arms.
##
## Used to also open the homework marking screen from here, on the same
## key -- split off onto its own HOMEWORK key (H) and its own Interactable,
## homework_desk.gd, sharing this same tile. See that file for why: two
## unrelated jobs stacked on one prompt meant the desk sometimes offered
## "Hand in" when what you actually walked over for was "Mark", with no way
## to ask for the other one directly.

signal work_handed_in(count: int)

var handed_in: int = 0


func _carrier() -> Node:
	# Defence in depth: player.gd's _pick_target()/_live() already refuse
	# to call this on anything detached from the tree, but get_tree() on a
	# detached node throws "Parameter data.tree is null" regardless of who
	# calls it -- and that error aborts the CALLER's function too (it once
	# aborted _pick_target() itself, which is what silently killed the
	# homework screen). Guard here as well, not just at the call site.
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("carrier")


func can_interact() -> bool:
	var c := _carrier()
	if c == null:
		return false
	return c.carrying > 0


func prompt_text() -> String:
	var c := _carrier()
	if c == null:
		return ""
	if c.carrying > 0:
		return "Hand in %d sheet%s" % [c.carrying, "" if c.carrying == 1 else "s"]
	return ""


func interact(by: Node) -> void:
	var c: Node = by if (by != null and by.has_method("carry_work")) else _carrier()
	if c == null or c.carrying <= 0:
		return
	handed_in += c.carrying
	Sfx.play("paper")
	c.drop_all_work()
	work_handed_in.emit(handed_in)
	used.emit(by)
