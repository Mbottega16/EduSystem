class_name Trophies
extends RefCounted

## One per boss the roguelike endgame can set you: a subject boss for
## each strand, plus the mixed gauntlet. A trophy is AWARDED by beating
## that boss (Game.award_trophy) -- never derived from ordinary play, the
## way a milestone is. It pays nothing and gates nothing on its own; the
## boss encounter itself is still to build (docs/ROGUELIKE_DESIGN.md).
## This is the shelf it lands on, and it is saved so a run keeps its
## record.
##
## THE RULE FOR ADDING ONE, same as a milestone: it must name something a
## player would tell somebody else about. If it reads like "cleared
## stage 4", it is not a trophy.

const TABLE := [
	{"id": "boss_ela", "name": "The Reading Paper",
		"blurb": "The class sat the paper the district sends round, and passed it."},
	{"id": "boss_math", "name": "The Number Gauntlet",
		"blurb": "Every child, every fact, against the clock. Nobody froze."},
	{"id": "boss_science", "name": "The Science Fair",
		"blurb": "They explained their own experiments to a room of strangers."},
	{"id": "boss_social", "name": "The Mock Election",
		"blurb": "They argued both sides of it and counted the votes themselves."},
	{"id": "boss_gauntlet", "name": "Open Evening",
		"blurb": "Parents, inspectors, the lot, and the room held up under all of it."},
]


static func all() -> Array:
	return TABLE


static func by_id(id: String) -> Dictionary:
	for t: Dictionary in TABLE:
		if String(t.get("id", "")) == id:
			return t
	return {}


static func count() -> int:
	return TABLE.size()
