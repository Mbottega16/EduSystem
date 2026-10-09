extends Interactable

## At the front of a room you hold, on a visit: E for how the day went -- the
## watch screen (or, before the bell has rung on the room, its overview).
## Only opens a screen, so it sits on the mashable key. VisitRoom listens for
## `used`.

## The teacher's name, for the prompt.
var who: String = "the teacher"


func prompt_text() -> String:
	return "Ask %s how it went" % who


func interact(by: Node) -> void:
	used.emit(by)
