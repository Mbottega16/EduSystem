class_name Curriculum
extends RefCounted

## The lessons you actually teach, loaded from data/curriculum.json.
##
## These are REAL Maryland state standards — a genuine code and the source
## document's own wording for the objective. Do not edit an objective to make
## a lesson read better, and do not invent a code for a new lesson: an
## uncited lesson is more honest than a fabricated citation.

static var _loaded: bool = false
static var lessons: Array = []
static var sources: Array = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open("res://data/curriculum.json", FileAccess.READ)
	if f == null:
		push_error("curriculum.json missing")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("curriculum.json is malformed")
		return
	var d := parsed as Dictionary
	lessons = d.get("lessons", [])
	sources = d.get("_sources", [])


static func count() -> int:
	ensure_loaded()
	return lessons.size()


static func by_id(id: String) -> Dictionary:
	ensure_loaded()
	for l: Dictionary in lessons:
		if String(l.get("id", "")) == id:
			return l
	return lessons[0] if not lessons.is_empty() else {}


static func pick(rng: RandomNumberGenerator) -> Dictionary:
	ensure_loaded()
	if lessons.is_empty():
		return {}
	return lessons[rng.randi_range(0, lessons.size() - 1)]


## The short name, for the HUD strip where there is no room for
## "Handwriting & Grammar".
static func short_name(lesson: Dictionary) -> String:
	return String(lesson.get("short", lesson.get("name", "Lesson")))


## Every distinct subject strand — used to pick a matching homework bank and
## to give each student a favourite.
static func strands() -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	for l: Dictionary in lessons:
		var s := String(l.get("strand", ""))
		if s != "" and not out.has(s):
			out.append(s)
	return out


## How hard this lesson is, 1..5. Three is the neutral middle.
static func difficulty(lesson: Dictionary) -> int:
	return clampi(int(lesson.get("difficulty", 3)), 1, 5)


static func strand_label(strand: String) -> String:
	match strand:
		"ela": return "English"
		"math": return "Maths"
		"science": return "Science"
		"social": return "Humanities"
	return strand


## Every concept in the game, flattened, with its parent lesson attached.
##
## A concept is a COMPONENT of its lesson's standard and cites that same real
## code -- it does not get an identifier of its own. Minting a plausible
## looking sub-code would be exactly the fabricated citation the header of
## this file forbids.
static func concepts() -> Array:
	ensure_loaded()
	var out: Array = []
	for l: Dictionary in lessons:
		for c: Dictionary in l.get("concepts", []):
			var row: Dictionary = (c as Dictionary).duplicate()
			row["lesson"] = String(l.get("id", ""))
			row["lesson_name"] = String(l.get("name", ""))
			row["strand"] = String(l.get("strand", ""))
			out.append(row)
	return out


static func concepts_of(lesson_id: String) -> Array:
	ensure_loaded()
	return by_id(lesson_id).get("concepts", [])


static func concept(concept_id: String) -> Dictionary:
	for c: Dictionary in concepts():
		if String(c.get("id", "")) == concept_id:
			return c
	return {}


static func concept_count() -> int:
	return concepts().size()


## Which concepts teaching `lesson_id` `times` times has put within reach.
static func concepts_unlocked_at(lesson_id: String, times: int) -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in concepts_of(lesson_id):
		if times >= int(c.get("at", 1)):
			out.append(String(c.get("id", "")))
	return out
