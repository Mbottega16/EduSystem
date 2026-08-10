class_name Names
extends RefCounted

## Student name pool. Kept as a const table rather than a Resource so it
## greps and diffs cleanly, matching the style of the rest of the data layer.

const FIRST := [
	"Ava", "Leo", "Mia", "Noah", "Zoe", "Kai", "Ivy", "Eli",
	"Luna", "Max", "Nora", "Finn", "Remy", "Sage", "June", "Theo",
	"Wren", "Cleo", "Iris", "Beau", "Milo", "Hazel", "Otis", "Nell",
]

const LAST := [
	"Park", "Reed", "Cole", "Vance", "Cruz", "Day", "Hale", "Frost",
	"Nash", "Pike", "Lund", "Ono", "Quill", "Vega", "Wood", "Sol",
]

## Eight generated sprite sheets — see CHARACTERS in tools/make_art.py.
const ART := [
	"student_a", "student_b", "student_c", "student_d",
	"student_e", "student_f", "student_g", "student_h",
]


## Draws through the supplied RNG so a seeded run is reproducible.
static func random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [
		FIRST[rng.randi_range(0, FIRST.size() - 1)],
		LAST[rng.randi_range(0, LAST.size() - 1)],
	]
