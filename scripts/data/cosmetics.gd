class_name Cosmetics
extends RefCounted

## Hats and backdrops. Purely decorative -- neither touches a grade, a
## stall chance, or anything else the balance contract reads, the same
## way a hat or a wallpaper never has in any sim this one takes after.
##
## The dashboard has said "Hat: none chosen yet" / "Background: none
## chosen yet" since the day it was built -- a hook, deliberately not
## built at the time. This is that hook, finally used.
##
## Kept as plain const tables in code, not balance.json: this is content
## (names, art, a colour), not a tunable, the same reasoning that already
## keeps Names.FIRST/LAST out of the balance file.

const HATS := [
	{"id": "", "name": "None", "art": ""},
	{"id": "cap", "name": "Beanie", "art": "cap"},
	{"id": "bow", "name": "Bow", "art": "bow"},
	{"id": "wizard", "name": "Wizard Hat", "art": "wizard"},
]

## A flat colour behind the character portrait -- the dashboard, the
## student file, the principal's popup. Never the classroom itself:
## reskinning the room is a much bigger job than this hook was ever
## meant to cover, and the portrait is where every other cosmetic in
## this game already shows itself.
const BACKGROUNDS := [
	{"id": "", "name": "None", "colour": Color(0, 0, 0, 0)},
	{"id": "chalkboard", "name": "Chalkboard", "colour": Color(0.13, 0.24, 0.18)},
	{"id": "morning", "name": "Morning Sky", "colour": Color(0.55, 0.72, 0.86)},
	{"id": "dusk", "name": "Dusk", "colour": Color(0.42, 0.28, 0.45)},
]


static func hat_names() -> Array[String]:
	var out: Array[String] = []
	for h: Dictionary in HATS:
		out.append(String(h["name"]))
	return out


static func hat_by_id(id: String) -> Dictionary:
	for h: Dictionary in HATS:
		if String(h["id"]) == id:
			return h
	return HATS[0]


static func hat_index(id: String) -> int:
	for i in HATS.size():
		if String(HATS[i]["id"]) == id:
			return i
	return 0


static func background_names() -> Array[String]:
	var out: Array[String] = []
	for b: Dictionary in BACKGROUNDS:
		out.append(String(b["name"]))
	return out


static func background_by_id(id: String) -> Dictionary:
	for b: Dictionary in BACKGROUNDS:
		if String(b["id"]) == id:
			return b
	return BACKGROUNDS[0]


static func background_index(id: String) -> int:
	for i in BACKGROUNDS.size():
		if String(BACKGROUNDS[i]["id"]) == id:
			return i
	return 0
