class_name Items
extends RefCounted

## Things you can buy and place in the classroom.
##
## Effects are RANGE-BASED from the item's own tile, not a room-wide
## checklist. That is what makes *where* you put a bookshelf matter — put it
## in a corner and it helps nobody, put it between two desks and it helps
## both. It also falls out of the grid for free.

const CATALOGUE := {
	"bookshelf": {
		"name": "Bookshelf", "cost": 120, "art": "bookshelf",
		"w": 1, "range": 4, "bonus": 0.07,
		"blurb": "Helps anyone sitting within 4 tiles.",
	},
	"lab_bench": {
		"name": "Lab Bench", "cost": 260, "art": "lab_bench",
		"w": 2, "range": 3, "bonus": 0.11,
		"blurb": "A strong boost, but only close by.",
	},
	"art_easel": {
		"name": "Art Easel", "cost": 150, "art": "art_easel",
		"w": 1, "range": 3, "bonus": 0.08,
		"blurb": "Inspiring to sit near.",
	},
	"plant": {
		"name": "Potted Plant", "cost": 60, "art": "plant",
		"w": 1, "range": 3, "bonus": 0.04,
		"blurb": "Cheap, cheerful, a little bit of calm.",
	},
	"rug": {
		"name": "Reading Rug", "cost": 180, "art": "rug",
		"w": 2, "range": 5, "bonus": 0.06,
		"blurb": "Weak up close but reaches the whole room.",
	},
}

## Buying order for the catalogue screen — cheapest first, so the first
## thing a player can afford is the first thing they see.
const ORDER := ["plant", "bookshelf", "art_easel", "rug", "lab_bench"]


static func get_def(id: String) -> Dictionary:
	return CATALOGUE.get(id, {})


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
