extends Interactable

## Stand at the hallway's trophy case and press E: what is in it, and what
## is not yet (hud.show_trophies()). Only ever reads, so it sits on the
## mashable key -- nothing it does can be undone wrongly. TrophyCase listens
## for `used` and passes it on.


func prompt_text() -> String:
	return "Look at the trophy case"


func interact(by: Node) -> void:
	used.emit(by)
