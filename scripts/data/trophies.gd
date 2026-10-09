class_name Trophies
extends RefCounted

## One per boss the roguelike endgame can set you: a subject boss for
## each strand, plus the mixed gauntlet. A trophy is AWARDED by beating
## that boss (Game.award_trophy, from Game.next_term()'s boss branch) --
## never derived from ordinary play, the way a milestone is. The trophy
## itself pays nothing; clearing the boss also puts the cosmetic decor
## gated on it on sale (Items.is_unlocked). Boss cards, the fight and the
## stakes are the term-path fork's `bosses` table -- see data/balance.json
## and docs/ROGUELIKE_DESIGN.md. This is the shelf trophies land on, saved
## so a run keeps its record.
##
## `art` is the cup it stands as in the hallway's trophy case (TrophyCase,
## scripts/world/trophy_case.gd): one of LimeZu's, imported by
## tools/import_limezu.py. A trophy not yet won leaves its shape there,
## dimmed, so the case shows what is still to win.
##
## THE RULE FOR ADDING ONE, same as a milestone: it must name something a
## player would tell somebody else about. If it reads like "cleared
## stage 4", it is not a trophy.

const TABLE := [
	{"id": "boss_ela", "name": "The Reading Paper", "art": "trophy_gold",
		"blurb": "The class sat the paper the district sends round, and passed it."},
	{"id": "boss_math", "name": "The Number Gauntlet", "art": "trophy_silver",
		"blurb": "Every child, every fact, against the clock. Nobody froze."},
	{"id": "boss_science", "name": "The Science Fair", "art": "trophy_bronze",
		"blurb": "They explained their own experiments to a room of strangers."},
	{"id": "boss_social", "name": "The Mock Election", "art": "trophy_gold_silver",
		"blurb": "They argued both sides of it and counted the votes themselves."},
	{"id": "boss_gauntlet", "name": "Open Evening", "art": "trophy_grand",
		"blurb": "Parents, inspectors, the lot, and the room held up under all of it."},
	{"id": "boss_inspection", "name": "Mock Inspection", "art": "trophy_gilt",
		"blurb": "The visitor came, watched the whole room, and found nothing to write down."},
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
