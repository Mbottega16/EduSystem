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


static func strand_label(strand: String) -> String:
	match strand:
		"ela": return "English"
		"math": return "Maths"
		"science": return "Science"
		"social": return "Humanities"
	return strand
