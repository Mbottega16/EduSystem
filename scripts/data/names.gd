class_name Names
extends RefCounted

## Student name pool. Kept as a const table rather than a Resource so it
## greps and diffs cleanly, matching the style of the rest of the data layer.
##
## Names are short on purpose — the class-list column is `%-11s` at font 8
## and the bio title has to fit 320px at font 12.

const FIRST := [
	"Ava", "Leo", "Mia", "Noah", "Zoe", "Kai", "Ivy", "Eli",
	"Luna", "Max", "Nora", "Finn", "Remy", "Sage", "June", "Theo",
	"Wren", "Cleo", "Iris", "Beau", "Milo", "Hazel", "Otis", "Nell",
	"Asa", "Bree", "Cass", "Dov", "Esme", "Fern", "Gil", "Halle",
	"Ida", "Jonah", "Kit", "Lark", "Mabel", "Ned", "Opal", "Pia",
	"Quinn", "Rosa", "Silas", "Tess", "Uma", "Vince", "Willa", "Zane",
]

const LAST := [
	"Park", "Reed", "Cole", "Vance", "Cruz", "Day", "Hale", "Frost",
	"Nash", "Pike", "Lund", "Ono", "Quill", "Vega", "Wood", "Sol",
	"Bly", "Kerr", "Marsh", "Finch", "Doyle", "Rowe", "Tate", "Voss",
	"Ames", "Bex", "Croft", "Dunn", "Ellis", "Ford", "Gale", "Hart",
]

## Eight generated sprite sheets — see CHARACTERS in tools/make_art.py.
const ART := [
	"student_a", "student_b", "student_c", "student_d",
	"student_e", "student_f", "student_g", "student_h",
]


## A name whose FIRST name is not already used by anyone in `taken`.
##
## Two students who cannot be told apart is the single most confusing thing
## a class can do, and every screen in this game prints the first name only.
## The old version drew independently with no memory of the roster, which at
## a class of eight meant a ~71% chance of a duplicate first name.
##
## FILTERS the pool rather than re-rolling on a clash. A retry loop consumes
## a variable number of RNG draws, which would make how many students already
## exist change what every LATER student gets — still reproducible, but
## impossible to reason about. Filtering keeps the draw count per student
## fixed, so a seeded run keeps its shape.
static func unique_name(rng: RandomNumberGenerator, taken: Array) -> String:
	var used := {}
	for full: String in taken:
		var parts := String(full).split(" ", false)
		if parts.size() > 0:
			used[parts[0]] = true

	var avail: Array = []
	for n: String in FIRST:
		if not used.has(n):
			avail.append(n)
	# Can't happen at cap 8 against a pool of this size — a guard, not a path.
	if avail.is_empty():
		avail = FIRST.duplicate()

	return "%s %s" % [
		avail[rng.randi_range(0, avail.size() - 1)],
		LAST[rng.randi_range(0, LAST.size() - 1)],
	]
