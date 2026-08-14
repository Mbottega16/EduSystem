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
	# No coin count. The prompt bar names BOTH buttons now, and the board
	# shares its tile with the curriculum, so a redundant number here was
	# pushing the shop's own name off the end of the line -- which is how
	# the shop appeared to vanish. Your coins are on the status strip.
	return "Furniture shop"


func interact(by: Node) -> void:
	catalogue_opened.emit()
	used.emit(by)
