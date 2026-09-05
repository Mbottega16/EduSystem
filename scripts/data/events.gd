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
		"id": "none", "weight": 8, "name": "An ordinary day",
		"blurb": "Nothing out of the usual.",
	},
	{
		"id": "supplies", "weight": 6, "name": "Materials day",
		"blurb": "They each need their own things today. Hand them out before the bell.",
		"supplies": true,
	},
	{
		"id": "restless", "weight": 8, "name": "Restless class",
		"blurb": "Something in the air. They will get stuck more today.",
		"stall_mult": 1.6,
	},
	{
		"id": "focused", "weight": 8, "name": "Unusually focused",
		"blurb": "Whatever you did yesterday, it stuck.",
		"stall_mult": 0.55,
	},
	{
		"id": "short_day", "weight": 7, "name": "Assembly this morning",
		"blurb": "The lesson is cut short. Prioritise.",
		"lesson_mult": 0.65,
	},
	{
		"id": "long_day", "weight": 5, "name": "Double period",
		"blurb": "Twice as long to get round everyone.",
		"lesson_mult": 1.5,
	},
	{
		"id": "inspector", "weight": 5, "name": "An inspector is visiting",
		"blurb": "They will watch the lesson. Have the room ready.",
		"inspection": true,
	},
	{
		"id": "wet_play", "weight": 5, "name": "Wet play",
		"blurb": "Nobody went outside. They are fidgety but they are here.",
		"stall_mult": 1.3,
		"coin_mult": 1.2,
	},
	{
		"id": "budget", "weight": 3, "name": "Budget came through",
		"blurb": "A little extra to spend on the room.",
		"bonus_coins": 120,
	},
	{
		"id": "keen", "weight": 3, "name": "Homework club ran late",
		"blurb": "Everyone did their homework last night.",
		"homework_sure": true,
	},
	{
		"id": "fire_drill", "weight": 4, "name": "Fire drill",
		"blurb": "Everyone is out, then back before you know it.",
		"lesson_mult": 0.75,
	},
	{
		"id": "heatwave", "weight": 3, "name": "Heatwave",
		"blurb": "The room is warm and nobody is in a hurry.",
		"stall_mult": 1.35,
	},
	{
		"id": "bug", "weight": 2, "name": "Half the class is away",
		"blurb": "Half the class is away with a bug.",
		"coin_mult": 0.7,
	},
	{
		"id": "visiting_speaker", "weight": 2, "name": "Visiting speaker",
		"blurb": "The morning is busy, but the children are keen.",
		"lesson_mult": 0.8, "coin_mult": 1.2,
	},
	{
		"id": "photocopier", "weight": 2, "name": "Photocopier trouble",
		"blurb": "The copies took longer than the lesson.",
		"lesson_mult": 1.25,
	},
	{
		"id": "supply_teacher", "weight": 2, "name": "Supply teacher",
		"blurb": "Someone new is teaching next door today.",
		"coin_mult": 0.9,
	},
	{
		"id": "cold_snap", "weight": 2, "name": "Cold snap",
		"blurb": "Everyone arrived wrapped up and ready to work.",
		"stall_mult": 0.8,
	},
	{
		"id": "after_school_club", "weight": 2, "name": "After school club",
		"blurb": "The building is busy late into the afternoon.",
		"homework_sure": true,
	},
	{
		"id": "small_grant", "weight": 3, "name": "Small grant",
		"blurb": "A little funding arrived at just the right time.",
		"bonus_coins": 60,
	},
	{
		"id": "cleaning", "weight": 2, "name": "Deep cleaning",
		"blurb": "Everything smells clean and slightly unfamiliar.",
		"lesson_mult": 0.9,
	},
	{
		"id": "sports_day", "weight": 2, "name": "Sports day",
		"blurb": "They are tired, cheerful, and ready for home.",
		"stall_mult": 1.2, "coin_mult": 1.15,
	},
	{
		"id": "parents_evening", "weight": 4, "name": "Parents' evening",
		"blurb": "Evening meetings loom, but a few pockets opened up.",
		"lesson_mult": 0.8, "bonus_coins": 90,
	},
	{
		"id": "birthday", "weight": 4, "name": "Someone's birthday",
		"blurb": "A birthday has the room a little too excited to focus.",
		"stall_mult": 1.25,
	},
	{
		"id": "book_fair", "weight": 4, "name": "The book fair",
		"blurb": "The book fair is on, and something came home in a bag.",
		"grant_item": "bookshelf",
	},
	{
		"id": "new_face", "weight": 4, "name": "A new face",
		"blurb": "A new face is still finding their feet in the room.",
		"stall_mult": 1.15,
	},
]


## `none_streak` is how many days in a row the PREVIOUS rolls have already
## come up "none" -- the caller's job to count, since this function does
## not remember anything between calls. At or past
## Balance.event_none_streak_cap, "none" is excluded from the draw
## entirely (ten-commits.md step 5's spread guarantee) rather than merely
## down-weighted, so a term can never serve twenty ordinary days running
## the way the raw weights alone would allow.
static func roll(rng: RandomNumberGenerator, none_streak: int = 0) -> Dictionary:
	Balance.ensure_loaded()
	var skip_none := none_streak >= Balance.event_none_streak_cap
	var total := 0
	for e: Dictionary in TABLE:
		if skip_none and String(e["id"]) == "none":
			continue
		total += int(e["weight"])
	var pick := rng.randi_range(1, total)
	for e: Dictionary in TABLE:
		if skip_none and String(e["id"]) == "none":
			continue
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
