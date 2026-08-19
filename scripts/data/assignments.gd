class_name Assignments
extends RefCounted

## The paper you set, drawn as a small hand of cards.
##
## Setting work used to be a formality: you tapped the podium and every child
## got the same anonymous sheet. Now three are drawn and you pick one, so the
## first thing you do each morning is a decision.
##
## TWO AXES, rolled separately and then correlated:
##
##   RARITY      what it PAYS -- coins, and the experience the work is worth
##               to the children who finish it
##   DIFFICULTY  how LONG the paper is
##
## They are correlated on purpose, so a Legendary is usually a demanding
## piece of work. That is what makes the hand a decision rather than a
## ranking: the question is not "which is best" but "can this class, today,
## with the room I have built, actually finish this" -- because work you
## never collect counts for half.
##
## Rarity pays coins and XP and never grade. The three-row balance contract
## is measured from work completion, and a multiplier on the lesson term
## would move the design pillar by luck instead of by play.


static func rarities() -> Array:
	Balance.ensure_loaded()
	return Balance.assign_rarities


static func forms() -> Array:
	Balance.ensure_loaded()
	return Balance.assign_forms


static func rarity(id: String) -> Dictionary:
	for r: Dictionary in rarities():
		if String(r.get("id", "")) == id:
			return r
	return rarities()[0] if not rarities().is_empty() else {}


static func rarity_colour(id: String) -> String:
	return String(rarity(id).get("colour", "b9b4a8"))


static func rarity_name(id: String) -> String:
	return String(rarity(id).get("name", "Common"))


static func pay(id: String) -> float:
	return float(rarity(id).get("pay", 1.0))


## Roll one rarity, by weight.
static func _roll_rarity(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for r: Dictionary in rarities():
		total += float(r.get("weight", 0))
	var pick := rng.randf() * total
	for r: Dictionary in rarities():
		pick -= float(r.get("weight", 0))
		if pick <= 0.0:
			return String(r.get("id", "common"))
	return "common"


## One card, for the subject being taught.
##
## The form is biased upward by rarity -- a Legendary Worksheet would be a
## free lunch, and a hand full of free lunches is not a decision.
static func roll(rng: RandomNumberGenerator, lesson: Dictionary) -> Dictionary:
	Balance.ensure_loaded()
	var rid := _roll_rarity(rng)
	var tier := 0
	for i in rarities().size():
		if String(rarities()[i].get("id", "")) == rid:
			tier = i
	var all := forms()
	if all.is_empty():
		return {}
	# a floor that rises with rarity, then a free roll above it
	var lo: int = clampi(tier - 1, 0, all.size() - 1)
	var idx: int = rng.randi_range(lo, all.size() - 1)
	var form: Dictionary = all[idx]
	return {
		"rarity": rid,
		"form": String(form.get("name", "Worksheet")),
		"difficulty": int(form.get("difficulty", 1)),
		"subject": String(lesson.get("short", lesson.get("name", "Lesson"))),
		"lesson": String(lesson.get("id", "")),
	}


## The hand you choose from. A fresh count every morning, not always the
## same size -- see the note on hand_size_min in balance.json, which is
## also the hook for a later teacher LUCK skill (a lucky teacher draws
## more, and eventually better, cards; nothing here should need to change
## when that lands, only the numbers it reads).
static func draw(rng: RandomNumberGenerator, lesson: Dictionary) -> Array:
	Balance.ensure_loaded()
	var lo: int = maxi(1, Balance.assign_hand_size_min)
	var hi: int = maxi(lo, Balance.assign_hand_size_max)
	var n: int = rng.randi_range(lo, hi)
	var out: Array = []
	for i in n:
		out.append(roll(rng, lesson))
	return out


## "Chemistry Project", which is what the children would call it.
static func title(card: Dictionary) -> String:
	if card.is_empty():
		return "Classwork"
	return "%s %s" % [String(card.get("subject", "")), String(card.get("form", ""))]
