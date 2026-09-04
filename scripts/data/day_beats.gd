class_name DayBeats
extends RefCounted

## The day's beat: one line, in the teacher's own voice, shown over their
## portrait at the start of a day. It is NOT a tutorial and NOT a DayEvent
## -- it is the RUN narrating itself, and across a boss term it tightens
## day by day into the fight.
##
## Content, not tunables. These are const string pools, the same shape the
## intro's own pages take in hud.gd. Selection is deterministic -- keyed
## off the term and the day, never Game.rng -- so a given morning always
## reads the same after a reload.
##
## line_for(ctx) returns "" for a day with no beat. Ordinary days mostly
## return "" on purpose: a line every single morning wears through fast. A
## boss term is the exception -- every one of its days gets one.

## The long grind through the middle of a boss term. Walked by day rather
## than repeated, so it reads as a stretch of days rather than one day
## looping.
const BOSS_MIDDLE := [
	"Another day on it. Keep them moving.",
	"The paper will not wait. Teach what is in front of you.",
	"Every lesson between here and then is the fight.",
	"No trick to it now -- the room and the days.",
	"Harder terms than this have been survived.",
	"Closer than they were. Hard to see from inside it.",
	"Grade the work, plan the next, walk the room. Again.",
]

## The first morning of an ordinary term, keyed by the path card chosen.
const TERM_OPENERS := {
	"quiet_term": "A quiet stretch. Bank the calm while it lasts.",
	"ordinary_term": "A normal twenty days. Nothing owed but the class.",
	"busy_term": "A loud one coming. Longer lessons, more to hold.",
	"chaotic_term": "Everything at once this term. Hold it, it pays.",
}

## The first morning of a boss term, keyed by the boss card taken.
const BOSS_OPENERS := {
	"boss_ela": "The Reading Paper is set. Whole class, one morning.",
	"boss_math": "Number Gauntlet is set. Every child, on the clock.",
	"boss_science": "Science Fair is set. They present to strangers.",
	"boss_social": "Mock Election is set. Every vote counted openly.",
	"boss_gauntlet": "Open Evening is set. Parents, inspectors, the lot.",
}


## `ctx` keys, all supplied by the caller (main.gd, read off Game/Balance):
##   term, day, term_days : ints
##   path_kind            : "boss" on a boss term, else "" (or the card kind)
##   path_id              : the chosen term-path card id
##   boss_name            : the boss card's name, only set on a boss term
static func line_for(ctx: Dictionary) -> String:
	var term: int = int(ctx.get("term", 1))
	var day: int = int(ctx.get("day", 1))
	var term_days: int = int(ctx.get("term_days", 20))

	if String(ctx.get("path_kind", "")) == "boss":
		var bid := String(ctx.get("path_id", ""))
		var bname := String(ctx.get("boss_name", "the assessment"))
		if day <= 1:
			return String(BOSS_OPENERS.get(bid,
				"%s is set. The whole class, one morning." % bname))
		if day >= term_days:
			return "%s today. Doors open within the hour." % bname
		match term_days - day:
			3: return "Three days out. The room is nearly there."
			2: return "Two mornings left. Drill what will not stick."
			1: return "Tomorrow. What is not taught tonight stays untaught."
		return BOSS_MIDDLE[(day - 2) % BOSS_MIDDLE.size()]

	# the cold open already IS the first beat of the first term
	if term == 1 and day == 1:
		return ""
	if day == 1:
		return String(TERM_OPENERS.get(String(ctx.get("path_id", "")),
			"A new term. One class, twenty days."))
	if day == int(term_days / 2):
		return "Halfway. Whoever was going to settle has."
	return ""
