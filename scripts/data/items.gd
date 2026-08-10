class_name Items
extends RefCounted

## Things you can buy and place. The table itself lives in data/balance.json
## so prices and effects can be tuned and simulated without touching code.
##
## Effects are RANGE-BASED from the item's own tile, not a room-wide
## checklist. That is what makes *where* you put a bookshelf matter.


static func catalogue() -> Dictionary:
	Balance.ensure_loaded()
	return Balance.items


static func order() -> Array:
	Balance.ensure_loaded()
	return Balance.item_order


static func get_def(id: String) -> Dictionary:
	return catalogue().get(id, {})


static func cost(id: String) -> int:
	return int(get_def(id).get("cost", 0))


static func width(id: String) -> int:
	return int(get_def(id).get("w", 1))


## Every tile a placement at `origin` would occupy.
static func footprint(id: String, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in width(id):
		out.append(origin + Vector2i(i, 0))
	return out


## Which seats an item at `origin` would actually help — the thing the
## player could never see while placing.
static func seats_in_range(id: String, origin: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var d := get_def(id)
	if d.is_empty():
		return out
	var reach := int(d.get("range", 0))
	for i in Layout.seat_count():
		var seat: Vector2i = Layout.SEATS[i]
		var best := 9999
		for t: Vector2i in footprint(id, origin):
			best = mini(best, absi(t.x - seat.x) + absi(t.y - seat.y))
		if best <= reach:
			out.append(i)
	return out
