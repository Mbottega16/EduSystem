class_name Complication
extends RefCounted

## A mid-lesson complication: trash, a phone call, a parent turning up --
## something that happens WHILE a lesson is already running, not once at
## the start of the day the way DayEvent is.
##
## Same weighted-table shape as DayEvent, deliberately -- but rolled by
## Classroom._tick_complications() every second a lesson is live, not once
## per day, since this needs to fire zero-to-several times inside a single
## lesson. Balance.comp_onset_per_second/comp_max_per_lesson (data/
## balance.json -> "complication") govern how OFTEN; this table only says
## WHICH one, the same division of labor flare-ups already use.
##
## A future complication is a new row here, not a new script, as long as
## it reuses an existing "landmark" ("mess" or "desk") -- that's the actual
## answer to "any potential number of things" the roguelike pivot asked
## for room to grow into.

const TABLE := [
	{"id": "mess", "weight": 55, "name": "Something's spilled",
		"blurb": "A mess just landed somewhere in the room.",
		"landmark": "mess"},
	{"id": "phone_call", "weight": 30, "name": "The phone's ringing",
		"blurb": "The office is trying to reach you.",
		"landmark": "desk", "ring_seconds": 8.0,
		"answer_cost_seconds": 5.0, "answer_reward_coins": 6,
		"ignored_effect": "disrupt_one"},
	{"id": "conference", "weight": 15, "name": "A parent's at the door",
		"blurb": "They want a minute, right now.",
		"landmark": "desk", "ring_seconds": 12.0,
		"answer_cost_seconds": 9.0, "answer_reward_coins": 10,
		"ignored_effect": "reputation", "ignored_value": 2.0},
]


static func by_id(id: String) -> Dictionary:
	for row: Dictionary in TABLE:
		if String(row.get("id", "")) == id:
			return row
	return {}


## Roll one complication, by weight -- identical shape to DayEvent.roll().
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for row: Dictionary in TABLE:
		total += float(row.get("weight", 0))
	var pick := rng.randf() * total
	for row: Dictionary in TABLE:
		pick -= float(row.get("weight", 0))
		if pick <= 0.0:
			return row
	return TABLE[0]
