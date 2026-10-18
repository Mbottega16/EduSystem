extends Interactable

## The other end of the treat shelf: with a treat in your hands, a child's
## desk offers to take it. The same key as the cupboard (SUPPLY) -- the
## cupboard is on the back wall and the desk is where the child is, so the
## picker takes whichever you stand beside and face.
##
## The treat is paid for here, not when it was taken, and a child who is
## asleep, stuck, fidgeting or flagging gets what it does for them at once
## (Game.give_treat()). Never offered mid-test or mid-paper, and it never
## touches a grade.

var seat_index: int = -1


func _init() -> void:
	super()
	uses_key = Key.SUPPLY


func student() -> StudentData:
	return Game.student_in_seat(seat_index)


func can_interact() -> bool:
	return Game.carried != "" and student() != null and Game.treats_available()


func prompt_text() -> String:
	var s := student()
	if s == null or Game.carried == "":
		return ""
	return "Give %s a %s (%d coins)" % [s.first_name(), Game.treat_name(Game.carried),
		Game.treat_cost(Game.carried)]


func interact(by: Node) -> void:
	var s := student()
	var id := Game.carried
	var why := Game.give_treat(s)
	if why == "":
		Sfx.play("help")
		_pop(String(Balance.consumables.get(id, {}).get("pop", "thanks!")),
			Color(0.75, 1.0, 0.8))
		if by != null and by.has_method("play_pose"):
			by.play_pose(Actor.POSE_HANDOFF)
	else:
		Sfx.play("deny")
		_pop(why, Color(1, 0.7, 0.5))
	used.emit(by)


func _pop(text: String, colour: Color) -> void:
	var world := get_parent()
	while world != null and not world.has_method("student_node"):
		world = world.get_parent()
	if world != null:
		Floater.pop(world, global_position + Vector2(0, -36), text, colour)
		Fx.puff(world, global_position + Vector2(0, -10), colour)
