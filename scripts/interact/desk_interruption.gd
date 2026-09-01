extends Interactable

## The phone ringing, or a parent turning up -- whatever's waiting for you
## at your own desk mid-lesson. Shares the teacher desk's tile with
## marking_desk.gd (E) and homework_desk.gd (H), the same way the
## noticeboard's shop and curriculum board already share one tile on two
## different keys -- a third unrelated job stacked on an existing prompt
## is exactly the collision this project's "one dedicated key per verb"
## rule exists to avoid.
##
## Key.RESPOND on purpose: answering is reversible and repeatable, same as
## every other USE-shaped verb, but it needed its own key rather than
## folding onto E -- E must never gain a job that isn't mashable, and this
## one has a real cost (lesson seconds) attached to a single press, closer
## in shape to the quiz/podium verbs than to a mash.
##
## See classroom.gd's _on_interruption_answered()/_resolve_ignored_
## interruption() for what answering vs. ignoring actually does -- this
## script only opens the door.

signal interruption_answered()


func _init() -> void:
	super()
	uses_key = Key.RESPOND
	add_to_group("interruption_desk")


func can_interact() -> bool:
	return not Game.interruption.is_empty()


func prompt_text() -> String:
	if Game.interruption.is_empty():
		return ""
	return "Answer it" if Game.interruption.get("id") == "phone_call" else "See them now"


func interact(by: Node) -> void:
	interruption_answered.emit()
	used.emit(by)
