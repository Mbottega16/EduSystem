class_name Milestones
extends RefCounted

## Named things to aim at, in a game that never ends.
##
## THE PROBLEM THIS SOLVES. The game is endless by design: terms keep coming
## and the target keeps rising until you miss one. That is a fine shape for
## a management sim and a poor one for a store page -- a player who reaches
## term five with nothing named to aim at stops, and reasonably concludes
## the game is unfinished rather than open-ended.
##
## A milestone is authored progress without an authored ending. It does not
## gate anything and it does not pay anything: the moment it fires is the
## reward, and the list is a map of what this game thinks is worth doing.
##
## THE RULE FOR ADDING ONE: it must name something a player would tell
## somebody else about. "Taught 50 lessons" is a counter. "Got every child
## through" is a story. If it reads like a progress bar, it is not a
## milestone, and the career screen already has counters for that.
##
## Every one is checked against state the game ALREADY tracks -- nothing
## here asks the rest of the game to record anything new.

## id, name, and the one line the player is shown when it fires.
const TABLE := [
	# --- your first term ---
	{"id": "first_term", "name": "Survived a term",
		"blurb": "Twenty days, one class, and you are still here."},
	{"id": "first_up", "name": "Sent one up",
		"blurb": "A child you taught has moved on to somebody else."},

	# --- the room ---
	{"id": "furnished", "name": "A proper classroom",
		"blurb": "Twenty pieces of furniture, and every desk feels it."},
	{"id": "grown", "name": "Knocked a wall through",
		"blurb": "The room is bigger than the one you were given."},

	# --- teaching ---
	{"id": "full_house", "name": "Every single one",
		"blurb": "A whole class passed. Not one of them left behind."},
	{"id": "outstanding", "name": "Outstanding",
		"blurb": "An inspector watched you teach and could not fault it."},
	{"id": "specialist", "name": "Knows the subject",
		"blurb": "Every concept in one subject, learned and taught."},
	{"id": "polymath", "name": "Knows the lot",
		"blurb": "Every concept in the curriculum. All sixty."},

	# --- a career ---
	{"id": "ten_up", "name": "Ten children on",
		"blurb": "Ten of them have gone up because of you."},
	{"id": "fifty_up", "name": "Fifty children on",
		"blurb": "Fifty. That is a career, not a term."},
	{"id": "five_terms", "name": "Five terms in",
		"blurb": "Five classes taught, and five classes lost to the year above."},
	{"id": "ten_terms", "name": "A decade of it",
		"blurb": "Ten terms. You are the one they remember."},

	# --- the hard ones ---
	{"id": "hard_unit", "name": "Taught the hard stuff",
		"blurb": "A class sat the hardest unit in the book, and passed it."},
	{"id": "rich", "name": "A budget at last",
		"blurb": "Two thousand coins, and somewhere to spend them."},
	{"id": "legendary_done", "name": "They finished it",
		"blurb": "You set a Legendary paper and the class handed it in."},
]


static func all() -> Array:
	return TABLE


static func by_id(id: String) -> Dictionary:
	for m: Dictionary in TABLE:
		if String(m.get("id", "")) == id:
			return m
	return {}


static func count() -> int:
	return TABLE.size()


## Which milestones the current run has now earned but not yet been told
## about. Reads only state the game already keeps.
##
## Returns ids. The caller marks them as told, so this is safe to call every
## day without a milestone firing twice.
static func newly_earned(told: Array) -> Array[String]:
	Balance.ensure_loaded()
	var out: Array[String] = []

	var earned := {
		"first_term": Game.term_history.size() >= 1,
		"first_up": Game.graduated.size() >= 1,
		"ten_up": Game.graduated.size() >= 10,
		"fifty_up": Game.graduated.size() >= 50,
		"five_terms": Game.term_history.size() >= 5,
		"ten_terms": Game.term_history.size() >= 10,
		"furnished": Game.room_items.size() >= 20,
		"grown": Grid.W > Grid.BASE_W or Grid.H > Grid.BASE_H,
		"polymath": Game.concepts.size() >= Curriculum.concept_count(),
		"rich": Game.coins >= 2000,
		"specialist": _knows_a_whole_subject(),
		"full_house": _a_whole_class_passed(),
		"outstanding": _an_outstanding_inspection(),
		"hard_unit": _passed_a_hard_unit(),
		"legendary_done": _finished_a_legendary(),
	}

	for m: Dictionary in TABLE:
		var id := String(m.get("id", ""))
		if bool(earned.get(id, false)) and not told.has(id):
			out.append(id)
	return out


## Every concept of any one subject.
static func _knows_a_whole_subject() -> bool:
	for strand: String in Curriculum.strands():
		var total := 0
		var known := 0
		for l: Dictionary in Curriculum.lessons:
			if String(l.get("strand", "")) != strand:
				continue
			for c: Dictionary in Curriculum.concepts_of(String(l.get("id", ""))):
				total += 1
				if Game.knows_concept(String(c.get("id", ""))):
					known += 1
		if total > 0 and known == total:
			return true
	return false


## A term where every child passed. Read from the record rather than from
## the moment, so it survives a reload.
static func _a_whole_class_passed() -> bool:
	for row: Dictionary in Game.term_history:
		if int(row.get("total", 0)) > 0 \
				and int(row.get("passed", 0)) == int(row.get("total", 0)):
			return true
	return false


static func _an_outstanding_inspection() -> bool:
	return not Game.last_inspection.is_empty() \
		and String(Game.last_inspection.get("letter", "")) == "A"


## A test passed on a lesson at the top of the difficulty range.
static func _passed_a_hard_unit() -> bool:
	for s: StudentData in Game.roster:
		for row: Dictionary in s.tests_taken():
			if float(row.get("grade", 0.0)) < Balance.exam_pass:
				continue
			if Curriculum.difficulty(Curriculum.by_id(String(row.get("lesson", "")))) >= 5:
				return true
	return false


static func _finished_a_legendary() -> bool:
	if Game.assignment.is_empty():
		return false
	if String(Game.assignment.get("rarity", "")) != "legendary":
		return false
	for s: StudentData in Game.roster:
		if s.work_state == StudentData.Work.COLLECTED:
			return true
	return false
