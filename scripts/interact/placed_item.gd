extends Interactable

## A piece of furniture you have bought. Walk up to it to pick it up and put
## it somewhere better — the same ghost cursor you placed it with.

signal move_requested(id: String, tile: Vector2i)

var item_id: String = ""
var origin: Vector2i = Vector2i.ZERO


func can_interact() -> bool:
	# Not mid-lesson. Rearranging the room while the class is working would
	# let you dodge the whole point of planning the room in advance.
	if Game.phase == Game.Phase.LESSON:
		return false
	if Items.is_underlay(item_id):
		# If solid furniture is standing on top of this rug, the solid piece owns the direct E interaction;
		# the rug can still be picked up or rearranged in Build Mode ('B').
		for placed: Dictionary in Game.room_items:
			var pid := String(placed["id"])
			if pid != item_id and not Items.is_underlay(pid):
				for t: Vector2i in Items.footprint(pid, placed["tile"]):
					if t in Items.footprint(item_id, origin):
						return false
	return true


func prompt_text() -> String:
	return "Move %s" % String(Items.get_def(item_id).get("name", item_id))


func interact(by: Node) -> void:
	move_requested.emit(item_id, origin)
	used.emit(by)
