class_name Traits
extends RefCounted

## What makes one child different from another.
##
## Aptitude and diligence say how WELL a student works. A trait says how they
## behave while they do it, and therefore what you have to do about them --
## which is the part that turns eight rows on a list into eight people.
##
## THE RULE FOR ADDING ONE: it must change what the player does. A trait that
## only prints a sentence on the class list is decoration, and decoration is
## what teaches a player to stop reading the list. Every trait here has a
## hook in the work model, the seating, or both.
##
## Loaded from data/balance.json like everything else tunable.


static func all() -> Dictionary:
	Balance.ensure_loaded()
	return Balance.traits


static func ids() -> Array:
	var out: Array = []
	for k: String in all().keys():
		if not k.begins_with("_"):
			out.append(k)
	out.sort()          # deterministic: the roll must not depend on key order
	return out


static func get_def(id: String) -> Dictionary:
	return all().get(id, {})


static func name_of(id: String) -> String:
	return String(get_def(id).get("name", ""))


static func blurb(id: String) -> String:
	return String(get_def(id).get("blurb", ""))


## A number off a trait, or `fallback` if this child has not got it.
static func value(id: String, key: String, fallback: float) -> float:
	var d := get_def(id)
	return float(d[key]) if d.has(key) else fallback


static func has_flag(id: String, key: String) -> bool:
	return bool(get_def(id).get(key, false))


## Roll one for a new arrival. Uses the run's seeded rng like every other
## random decision in this project.
static func roll(rng: RandomNumberGenerator) -> String:
	var list := ids()
	if list.is_empty():
		return ""
	return String(list[rng.randi_range(0, list.size() - 1)])
