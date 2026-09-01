class_name TermPaths
extends RefCounted

## The fork at the start of each term -- PokeRogue-style autonomy over a
## harder, better-paying path vs. an easier, calmer one.
##
## Modeled directly on the assignment hand (Assignments.draw()/roll()):
## a few pre-rolled options, pick one, discard the rest. The one real
## difference: drawn WITHOUT replacement, unlike the daily hand, which
## allows repeats -- repeating a termly, high-stakes choice would read as
## broken rather than lucky.


static func paths() -> Array:
	Balance.ensure_loaded()
	return Balance.term_paths


static func by_id(id: String) -> Dictionary:
	for p: Dictionary in paths():
		if String(p.get("id", "")) == id:
			return p
	return {}


## A small hand, weighted, without replacement.
static func draw(rng: RandomNumberGenerator, count: int) -> Array:
	Balance.ensure_loaded()
	var pool: Array = paths().duplicate()
	var out: Array = []
	var n: int = mini(count, pool.size())
	for i in n:
		var total := 0.0
		for p: Dictionary in pool:
			total += float(p.get("weight", 0))
		if total <= 0.0:
			break
		var pick := rng.randf() * total
		var chosen_idx := 0
		for j in pool.size():
			pick -= float((pool[j] as Dictionary).get("weight", 0))
			if pick <= 0.0:
				chosen_idx = j
				break
		out.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)
	return out
