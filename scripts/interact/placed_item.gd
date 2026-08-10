extends Interactable

## A piece of furniture you have bought. Walk up to it to pick it up and put
## it somewhere better — the same ghost cursor you placed it with.

signal move_requested(id: String, tile: Vector2i)

var item_id: String = ""
var origin: Vector2i = Vector2i.ZERO


func can_interact() -> bool:
	# Not mid-lesson. Rearranging the room while the class is working would
	# let you dodge the whole point of planning the room in advance.
	return Game.phase != Game.Phase.LESSON


func prompt_text() -> String:
	return "Move %s" % String(Items.get_def(item_id).get("name", item_id))


func interact(by: Node) -> void:
	move_requested.emit(item_id, origin)
	used.emit(by)
