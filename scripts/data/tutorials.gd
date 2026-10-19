class_name TutorialData
extends RefCounted

## The tutorial cutscenes (data/tutorials.json), read-only.
##
## Each one has an id, a title, a trigger (a game event name, fired through
## Game.fire_tutorial) and three to six steps. A step is one panel of the
## cutscene: who speaks, a line or two, and optionally a pointer in the room
## and a small animation on what it points at. The runner is
## scripts/ui/tutorial.gd; which ones the player has seen is
## Game.tutorials_seen.

const PATH := "res://data/tutorials.json"
const SPEAKERS := ["principal", "mentor", "teacher"]
const DEMOS := ["land", "flash", "puff"]
const MIN_STEPS := 3
const MAX_STEPS := 6

static var _list: Array = []
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_list = ((parsed as Dictionary).get("tutorials", []) as Array).duplicate(true)


static func all() -> Array:
	ensure_loaded()
	return _list


static func ids() -> Array:
	ensure_loaded()
	return _list.map(func(t: Dictionary) -> String: return String(t.get("id", "")))


static func get_tutorial(id: String) -> Dictionary:
	ensure_loaded()
	for t: Dictionary in _list:
		if String(t.get("id", "")) == id:
			return t
	return {}


## The tutorial a game event triggers, or {} when none does.
static func for_trigger(event: String) -> Dictionary:
	ensure_loaded()
	for t: Dictionary in _list:
		if String(t.get("trigger", "")) == event:
			return t
	return {}


## What is wrong with the data, as short strings. Empty when it is sound.
static func problems() -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	if _list.is_empty():
		out.append("no tutorials loaded")
	var seen_ids := {}
	for t: Dictionary in _list:
		var id := String(t.get("id", ""))
		if id.is_empty() or seen_ids.has(id):
			out.append("bad or repeated id '%s'" % id)
		seen_ids[id] = true
		if String(t.get("title", "")).is_empty() or String(t.get("trigger", "")).is_empty():
			out.append("%s needs a title and a trigger" % id)
		var steps: Array = t.get("steps", [])
		if steps.size() < MIN_STEPS or steps.size() > MAX_STEPS:
			out.append("%s has %d steps" % [id, steps.size()])
		for st: Dictionary in steps:
			if not SPEAKERS.has(String(st.get("speaker", ""))):
				out.append("%s has an unknown speaker '%s'" % [id, st.get("speaker", "")])
			if String(st.get("text", "")).strip_edges().is_empty():
				out.append("%s has a step with no text" % id)
			if st.has("demo") and not DEMOS.has(String(st["demo"])):
				out.append("%s has an unknown demo '%s'" % [id, st["demo"]])
	return out
