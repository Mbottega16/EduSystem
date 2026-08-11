extends Interactable

## The furniture catalogue. An in-world object you walk to rather than a
## hotkey menu, for the same reason as everything else here: a menu you can
## open from anywhere would quietly undermine "walking is the game".

signal catalogue_opened()

func _init() -> void:
	super()
	uses_key = Key.MANAGE


func can_interact() -> bool:
	return Game.phase != Game.Phase.LESSON


func prompt_text() -> String:
	return "Furniture  (%d coins)" % Game.coins


func interact(by: Node) -> void:
	catalogue_opened.emit()
	used.emit(by)
