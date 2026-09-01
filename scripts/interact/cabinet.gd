extends Interactable

## The storage cabinet. Everything you buy waits in here until you place
## it; opening it lets you take furniture out (and dispose of what you do
## not want). The opening scene has the teacher pull the class's desks
## from it -- see main.gd's intro cutscene.
##
## MANAGE (F), the same session-level key the furniture shop is on: this
## is the other half of that screen, not a mash verb.

signal cabinet_opened()

func _init() -> void:
	super()
	uses_key = Key.MANAGE


func can_interact() -> bool:
	return Game.phase != Game.Phase.LESSON


func prompt_text() -> String:
	return "Cabinet"


func interact(by: Node) -> void:
	cabinet_opened.emit()
	used.emit(by)
