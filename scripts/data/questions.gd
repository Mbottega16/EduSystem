class_name Questions
extends RefCounted

## The homework question bank, and the generator that turns it into a sheet.
##
## THE DESIGN CONSTRAINT: the answer key is hidden. What you are scoring is
## whether you AGREED with a truth you can't see, and marking a right answer
## wrong hurts exactly as much as marking a wrong one right.
##
## Every answer is genuinely checkable, so the game is fair. But there are
## more sheets than patience, so in practice you learn to triage on TELLS —
## neat or rushed, working shown or not. The tells correlate with
## correctness without determining it, which is what skim-marking actually
## is, and it keeps the minigame from collapsing into a mental-arithmetic
## test.

const BANK := [
	{"q": "7 x 8", "a": "56", "wrong": ["54", "63", "48"]},
	{"q": "6 x 6", "a": "36", "wrong": ["30", "42", "34"]},
	{"q": "9 x 4", "a": "36", "wrong": ["32", "45", "38"]},
	{"q": "12 + 19", "a": "31", "wrong": ["29", "32", "21"]},
	{"q": "45 - 17", "a": "28", "wrong": ["32", "38", "26"]},
	{"q": "8 x 7", "a": "56", "wrong": ["48", "64", "54"]},
	{"q": "72 / 9", "a": "8", "wrong": ["7", "9", "6"]},
	{"q": "13 + 28", "a": "41", "wrong": ["31", "42", "39"]},
	{"q": "100 - 36", "a": "64", "wrong": ["74", "66", "54"]},
	{"q": "5 x 12", "a": "60", "wrong": ["50", "55", "72"]},
	{"q": "144 / 12", "a": "12", "wrong": ["14", "11", "24"]},
	{"q": "17 + 17", "a": "34", "wrong": ["24", "35", "44"]},
]

const QUESTIONS_PER_SHEET := 3

## How strongly a tell agrees with the truth. Deliberately NOT 1.0 — a
## perfect tell would make the sheet readable at a glance and the judgement
## would stop being a judgement.
const TELL_RELIABILITY := 0.75


## Build one student's sheet. `accuracy` (0..1) is the hidden truth, rolled
## from their aptitude by the caller.
static func make_sheet(accuracy: float, rng: RandomNumberGenerator) -> Dictionary:
	var items: Array = []
	var pool := BANK.duplicate()
	for i in QUESTIONS_PER_SHEET:
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		var correct := rng.randf() < accuracy
		var shown: String = pick["a"]
		if not correct:
			var wrongs: Array = pick["wrong"]
			shown = String(wrongs[rng.randi_range(0, wrongs.size() - 1)])
		# the tell agrees with the truth most of the time, but not always
		var tell_good := correct if rng.randf() < TELL_RELIABILITY else not correct
		items.append({
			"q": String(pick["q"]),
			"shown": shown,
			"correct": correct,
			"neat": tell_good,
			"working": tell_good if rng.randf() < 0.8 else not tell_good,
		})
	return {"items": items, "accuracy": accuracy}


## Did the sheet genuinely deserve a pass? The threshold the player is
## implicitly being asked to guess.
static func sheet_is_good(sheet: Dictionary) -> bool:
	var right := 0
	for it: Dictionary in sheet.get("items", []):
		if bool(it["correct"]):
			right += 1
	return right >= 2
