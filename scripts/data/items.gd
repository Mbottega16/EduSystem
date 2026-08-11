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


## The shop's category tabs, in the order they are shown.
static func categories() -> Array:
	Balance.ensure_loaded()
	return Balance.item_categories


static func category_label(cat: String) -> String:
	return cat.capitalize()


## Every item in one category, cheapest first (item_order is already sorted
## by category then cost, so this preserves that).
static func in_category(cat: String) -> Array:
	var out: Array = []
	for id: String in order():
		if String(get_def(id).get("cat", "")) == cat:
			out.append(id)
	return out


static func category_of(id: String) -> String:
	return String(get_def(id).get("cat", ""))


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
