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
##
## SOMEONE AT YOUR DESK (Sept 2026). A "desk" row may also carry a
## `speaker`, a `line` and a list of `choices`. Answering it then opens a
## small screen -- a face, a sentence, two or three ways to answer -- in
## place of the instant payoff a bare row still gives. A row with no
## `choices` behaves exactly as it did before, which is why `phone_call`
## and `conference` below are untouched.
##
## The decision is meant to cost something. Every branch that pays should
## have a sibling that does not, or the screen is a menu rather than a
## choice -- and ignoring it is already a branch, resolved by
## `ignored_effect` when the ring runs out.
##
## `speaker` is "principal", or "student" for whichever seated child the
## roll picked (chosen through Game.rng at spawn, so a seed replays).
##
## Every effect a choice can have must name a `kind` from EFFECTS, which is
## what the suite checks against -- a typo'd effect is otherwise a silent
## no-op. Deliberately narrow: nothing here may touch a child's record,
## because that is what the balance contract measures.

## Everything a choice is allowed to do. `coins`, `reputation` and
## `disrupt_one` already existed as outcomes; `item` drops something in the
## cabinet (exactly where buying puts it, so placing it stays your call);
## `boost` is a stretch of quicker feet that expires at the bell.
const EFFECTS := ["coins", "reputation", "disrupt_one", "item", "boost"]

const TABLE := [
	{"id": "mess", "weight": 40, "name": "Something's spilled",
		"blurb": "A mess just landed somewhere in the room.",
		"landmark": "mess"},
	{"id": "phone_call", "weight": 18, "name": "The phone's ringing",
		"blurb": "The office is trying to reach you.",
		"landmark": "desk", "ring_seconds": 8.0,
		"answer_cost_seconds": 5.0, "answer_reward_coins": 6,
		"ignored_effect": "disrupt_one"},
	{"id": "conference", "weight": 10, "name": "A parent's at the door",
		"blurb": "They want a minute, right now.",
		"landmark": "desk", "ring_seconds": 12.0,
		"answer_cost_seconds": 9.0, "answer_reward_coins": 10,
		"ignored_effect": "reputation", "ignored_value": 2.0},
	{"id": "trip_fund", "weight": 6, "name": "The principal's at your desk",
		"blurb": "She wants a word about the trip fund.",
		"landmark": "desk", "ring_seconds": 10.0,
		"answer_cost_seconds": 4.0,
		"speaker": "principal",
		"line": "The trip fund's short again. Anything you can spare?",
		"choices": [
			{"label": "Give what you can",
				"says": "She writes your name down first.",
				"effects": [{"kind": "coins", "value": -40},
					{"kind": "reputation", "value": 3.0}]},
			{"label": "Tell her the room needs it more",
				"says": "She looks at the room, and does not disagree.",
				"effects": [{"kind": "reputation", "value": -1.0}]},
		],
		"ignored_effect": "reputation", "ignored_value": 2.0},
	{"id": "cover_lesson", "weight": 5, "name": "The principal's at your desk",
		"blurb": "Someone is off, and she is short a teacher.",
		"landmark": "desk", "ring_seconds": 10.0,
		"answer_cost_seconds": 4.0,
		"speaker": "principal",
		"line": "Nobody is covering period five. Could you take it?",
		"choices": [
			{"label": "Take it on",
				"says": "It will cost you the afternoon. She will not forget.",
				"effects": [{"kind": "coins", "value": 55},
					{"kind": "reputation", "value": 2.0},
					{"kind": "disrupt_one"}]},
			{"label": "Say your own class needs you",
				"says": "True, and she knows it. It still lands badly.",
				"effects": [{"kind": "reputation", "value": -1.0}]},
		],
		"ignored_effect": "reputation", "ignored_value": 2.0},
	{"id": "storeroom_key", "weight": 5, "name": "The principal's at your desk",
		"blurb": "She has the storeroom key, and a question.",
		"landmark": "desk", "ring_seconds": 10.0,
		"answer_cost_seconds": 4.0,
		"speaker": "principal",
		"line": "There is a spare from the old room. Want it, or shall I pass it on?",
		"choices": [
			{"label": "Take it for the room",
				"says": "It goes straight in your cabinet.",
				"effects": [{"kind": "item", "id": "bookshelf"}]},
			{"label": "Let another room have it",
				"says": "She did not expect that. It counts.",
				"effects": [{"kind": "reputation", "value": 2.0}]},
		],
		"ignored_effect": "reputation", "ignored_value": 1.0},
	{"id": "child_question", "weight": 6, "name": "Someone is at your desk",
		"blurb": "A child has come up with something on their mind.",
		"landmark": "desk", "ring_seconds": 9.0,
		"answer_cost_seconds": 3.0,
		"speaker": "student",
		"line": "I do not get any of it. Can you start me again?",
		"choices": [
			{"label": "Sit with them properly",
				"says": "It takes a while. They settle right down.",
				"effects": [{"kind": "boost"}]},
			{"label": "Point them at their neighbour",
				"says": "Two heads together, and two heads talking.",
				"effects": [{"kind": "coins", "value": 8},
					{"kind": "disrupt_one"}]},
		],
		"ignored_effect": "disrupt_one"},
	{"id": "child_errand", "weight": 5, "name": "Someone is at your desk",
		"blurb": "A child is offering to make themselves useful.",
		"landmark": "desk", "ring_seconds": 9.0,
		"answer_cost_seconds": 3.0,
		"speaker": "student",
		"line": "I have finished. Can I take the register to the office?",
		"choices": [
			{"label": "Send them",
				"says": "Off they go, pleased with themselves.",
				"effects": [{"kind": "coins", "value": 14}]},
			{"label": "Keep them here and stretch them",
				"says": "They grumble, then get on with it.",
				"effects": [{"kind": "boost"}]},
		],
		"ignored_effect": "disrupt_one"},
	{"id": "child_lost", "weight": 5, "name": "Someone is at your desk",
		"blurb": "Something has gone missing, and there are tears about it.",
		"landmark": "desk", "ring_seconds": 9.0,
		"answer_cost_seconds": 3.0,
		"speaker": "student",
		"line": "My reading book is gone. I have looked everywhere.",
		"choices": [
			{"label": "Stop and look for it together",
				"says": "You find it under a chair. The room waits, not quietly.",
				"effects": [{"kind": "disrupt_one"},
					{"kind": "reputation", "value": 1.0}]},
			{"label": "Give them one from the shelf",
				"says": "Not the same book. It will do for today.",
				"effects": [{"kind": "coins", "value": -12}]},
		],
		"ignored_effect": "disrupt_one"},
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
