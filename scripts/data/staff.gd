class_name Staff
extends RefCounted

## A teacher you hire, as a POLICY.
##
## `tools/sim.gd` has modelled a teacher this way since the day it was
## written: a reaction time, and whether they teach, collect, settle and
## quiz. It plays whole terms with it and the three-row balance contract is
## measured from its output. That is not a approximation of a teacher — for
## this game it is the definition of one.
##
## So a hired teacher runs on exactly the model the player is subject to,
## and the results a delegated room produces are EARNED rather than assigned
## by a formula that resembles earning. That is the load-bearing promise of
## the whole school layer, and it is only cheap because the machinery was
## already here.
##
## THE RULE FOR ADDING AN ARCHETYPE: a teacher is never strictly better than
## another, only better AT something. A fast reactor who never collects; a
## steady one who cannot settle a noisy room; a quizzer wasted on a good
## class and superb with a struggling one. The moment one dominates, hiring
## stops being a decision and becomes a sort.

const FIRST := [
	"Okafor", "Reyes", "Bhatt", "Lindqvist", "Moreau", "Aziz", "Kowalski",
	"Nakamura", "O'Dowd", "Ferreira", "Haddad", "Novak", "Mensah", "Sokolov",
	"Petrov", "Ndiaye", "Kaur", "Almeida", "Weber", "Tanaka",
]
const TITLE := ["Mr", "Ms", "Mrs", "Dr"]

## The archetypes. Each is a real play-style with a real hole in it.
##
## `reaction` is seconds before they notice a child needs them — the same
## number `tools/sim.gd` calls REACTION, and the same one that separates its
## 'ideal' policy from its 'lazy' one.
const ARCHETYPES := [
	{
		"id": "steady", "name": "Steady",
		"blurb": "Reliable. Will not chase a noisy room.",
		"reaction": 4.0, "teaches": true, "collects": true,
		"settles": false, "quizzes": false, "wage": 22,
	},
	{
		"id": "sharp", "name": "Sharp-eyed",
		"blurb": "Spots a stuck child instantly. Forgets the paperwork.",
		"reaction": 1.0, "teaches": true, "collects": false,
		"settles": true, "quizzes": false, "wage": 30,
	},
	{
		"id": "firm", "name": "Firm",
		"blurb": "Nothing gets out of hand. Slow to notice quiet trouble.",
		"reaction": 8.0, "teaches": true, "collects": true,
		"settles": true, "quizzes": false, "wage": 26,
	},
	{
		"id": "diagnostic", "name": "Diagnostic",
		"blurb": "Quizzes constantly. Superb with a class that is behind.",
		"reaction": 5.0, "teaches": true, "collects": true,
		"settles": false, "quizzes": true, "wage": 34,
	},
	{
		"id": "supply", "name": "Supply",
		"blurb": "Cheap, and it shows. Better than an empty room.",
		"reaction": 14.0, "teaches": true, "collects": false,
		"settles": false, "quizzes": false, "wage": 11,
	},
	{
		"id": "veteran", "name": "Veteran",
		"blurb": "Does everything well. Costs what that is worth.",
		"reaction": 2.0, "teaches": true, "collects": true,
		"settles": true, "quizzes": true, "wage": 52,
	},
]


static func archetype(id: String) -> Dictionary:
	for a: Dictionary in ARCHETYPES:
		if String(a.get("id", "")) == id:
			return a
	return ARCHETYPES[0]


## One applicant: an archetype, a name, and a wage that varies a little.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var a: Dictionary = ARCHETYPES[rng.randi_range(0, ARCHETYPES.size() - 1)]
	var name := "%s %s" % [
		TITLE[rng.randi_range(0, TITLE.size() - 1)],
		FIRST[rng.randi_range(0, FIRST.size() - 1)]]
	var t := a.duplicate()
	t["name"] = name
	# a little spread, so two of the same archetype are not identical hires
	t["wage"] = maxi(6, int(round(float(a["wage"]) * rng.randf_range(0.85, 1.2))))
	return t


## A pool of applicants to choose between.
static func applicants(rng: RandomNumberGenerator, n: int) -> Array:
	var out: Array = []
	var seen := {}
	var guard := 0
	while out.size() < n and guard < 60:
		guard += 1
		var t := roll(rng)
		if seen.has(String(t["name"])):
			continue
		seen[String(t["name"])] = true
		out.append(t)
	return out


## What they are good and bad at, in words, for the hiring screen.
##
## Prose, never numbers — the same rule the rest of the game's UI follows.
## "Spots a stuck child instantly" is a thing you can act on; 1.0 is not.
static func strengths(t: Dictionary) -> String:
	var out: Array[String] = []
	var r := float(t.get("reaction", 5.0))
	if r <= 2.0:
		out.append("very quick")
	elif r <= 5.0:
		out.append("attentive")
	if bool(t.get("collects", false)):
		out.append("collects")
	if bool(t.get("settles", false)):
		out.append("keeps order")
	if bool(t.get("quizzes", false)):
		out.append("quizzes")
	return ", ".join(out) if not out.is_empty() else "turns up"


static func weakness(t: Dictionary) -> String:
	var r := float(t.get("reaction", 5.0))
	if r >= 12.0:
		return "slow to notice"
	if not bool(t.get("collects", false)):
		return "leaves work uncollected"
	if not bool(t.get("settles", false)):
		return "loses a noisy room"
	if not bool(t.get("quizzes", false)):
		return "never checks who is behind"
	if r >= 6.0:
		return "not the quickest"
	return "expensive"
