class_name DayEvent
extends RefCounted

## Something that makes today different from yesterday.
##
## Every day used to be byte-identical: same eight seats, same work, same
## subject-that-meant-nothing. One rolled event per day is the cheapest
## possible source of variety, and each one changes an actual number rather
## than just printing a line.

const TABLE := [
	{
		"id": "none", "weight": 30, "name": "An ordinary day",
		"blurb": "Nothing out of the usual.",
	},
	{
		"id": "restless", "weight": 12, "name": "Restless class",
		"blurb": "Something in the air. They will get stuck more today.",
		"stall_mult": 1.6,
	},
	{
		"id": "focused", "weight": 12, "name": "Unusually focused",
		"blurb": "Whatever you did yesterday, it stuck.",
		"stall_mult": 0.55,
	},
	{
		"id": "short_day", "weight": 10, "name": "Assembly this morning",
		"blurb": "The lesson is cut short. Prioritise.",
		"lesson_mult": 0.65,
	},
	{
		"id": "long_day", "weight": 8, "name": "Double period",
		"blurb": "Twice as long to get round everyone.",
		"lesson_mult": 1.5,
	},
	{
		"id": "inspector", "weight": 8, "name": "An inspector is visiting",
		"blurb": "Grades today are worth far more than usual.",
		"coin_mult": 2.2,
	},
	{
		"id": "wet_play", "weight": 8, "name": "Wet play",
		"blurb": "Nobody went outside. They are fidgety but they are here.",
		"stall_mult": 1.3,
		"coin_mult": 1.2,
	},
	{
		"id": "budget", "weight": 6, "name": "Budget came through",
		"blurb": "A little extra to spend on the room.",
		"bonus_coins": 120,
	},
	{
		"id": "keen", "weight": 6, "name": "Homework club ran late",
		"blurb": "Everyone did their homework last night.",
		"homework_sure": true,
	},
]


static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for e: Dictionary in TABLE:
		total += int(e["weight"])
	var pick := rng.randi_range(1, total)
	for e: Dictionary in TABLE:
		pick -= int(e["weight"])
		if pick <= 0:
			return e
	return TABLE[0]


static func by_id(id: String) -> Dictionary:
	for e: Dictionary in TABLE:
		if String(e["id"]) == id:
			return e
	return TABLE[0]


static func multiplier(event: Dictionary, key: String) -> float:
	return float(event.get(key, 1.0))
