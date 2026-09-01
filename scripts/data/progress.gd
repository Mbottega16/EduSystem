class_name Progress
extends RefCounted

## The teacher's own progression: experience, level, and spent perk points.
##
## Held as plain data on Game rather than as its own autoload, so a headless
## test or the term simulator can construct a levelled teacher without a
## scene. All the numbers live in data/balance.json.

## Perk ids, in the order the staff board lists them.
static func perk_order() -> Array:
	Balance.ensure_loaded()
	var out: Array = []
	for id: String in Balance.perks.keys():
		out.append(id)
	return out


static func perk_def(id: String) -> Dictionary:
	Balance.ensure_loaded()
	return Balance.perks.get(id, {})


static func max_rank(id: String) -> int:
	return int(perk_def(id).get("ranks", 1))


## XP needed to reach `level` from level 1. Deliberately linear: a curve
## that steepens would mean late perks arrive after the term has ended.
static func xp_for_level(level: int) -> int:
	Balance.ensure_loaded()
	return maxi(0, level - 1) * Balance.teacher_xp_per_level


## What a given amount of XP is worth, capped.
static func level_for_xp(xp: int) -> int:
	Balance.ensure_loaded()
	if Balance.teacher_xp_per_level <= 0:
		return 1
	return clampi(1 + int(xp / Balance.teacher_xp_per_level), 1, Balance.teacher_max_level)


## One point per level after the first.
static func points_for_level(level: int) -> int:
	return maxi(0, level - 1)


# ------------------------------------------------------------- effects
# Each reads the SPENT ranks and turns them into the number the game uses.
# Everything funnels through here so there is one place to look when a perk
# does not seem to be doing anything.

static func speed(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return Balance.teacher_speed \
		+ Balance.perk_brisk_walk_speed * float(ranks.get("brisk_walk", 0))


static func pick_radius(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return Balance.teacher_pick_radius \
		+ Balance.perk_long_reach_radius * float(ranks.get("long_reach", 0))


static func carries_unlimited(ranks: Dictionary) -> bool:
	return int(ranks.get("steady_hands", 0)) > 0


## How much a student's stall chance is multiplied by while the teacher is
## stood near them. 1.0 means no effect.
static func calm_multiplier(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	var r := int(ranks.get("calm_presence", 0))
	if r <= 0:
		return 1.0
	return pow(Balance.perk_calm_presence_mult, float(r))


static func calm_radius(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return Balance.perk_calm_presence_radius


## Sheets removed from the nightly marking pile.
##
## This is what "grade quicker" turned into. Marking has no timer on purpose
## -- EduSystems found per-question marking hit 32-120 taps a lesson and had
## to be redesigned to one verdict per sheet -- so the only honest way to
## make it quicker is to have fewer of them, with the rest going at whatever
## standard you have been marking to.
static func sheets_skipped(ranks: Dictionary) -> int:
	Balance.ensure_loaded()
	return Balance.perk_practised_marker_sheets * int(ranks.get("practised_marker", 0))


## Presses a piece of mess needs before it's cleaned. Floored at 1 --
## Quick Sweep makes cleanup faster, not free.
static func mess_presses(ranks: Dictionary) -> int:
	Balance.ensure_loaded()
	return maxi(1, Balance.mess_clean_presses \
		- Balance.perk_quick_sweep_presses * int(ranks.get("quick_sweep", 0)))


## Extra tiles added to the settle-the-room radius.
static func voice_range_bonus(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return Balance.perk_carrying_voice_tiles * float(ranks.get("carrying_voice", 0))


## A multiplier on Game.lesson_length()'s existing chain -- one more
## factor alongside the day event's and the term path's, never touching
## Balance.lesson_seconds itself. 1.0 means no effect.
static func lesson_length_mult(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return 1.0 + Balance.perk_quick_study_pct * float(ranks.get("quick_study", 0))


## A bias fed into Assignments._roll_rarity() that shifts the weighted
## pick toward rarer tiers without touching what rarity actually pays.
static func assignment_luck(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return Balance.perk_lucky_break_bias * float(ranks.get("lucky_break", 0))


## A fraction off a shop item's BUY price only -- never its sell value,
## so a discount you paid for doesn't also deflate what you get back for
## selling something.
static func shop_discount(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	return clampf(Balance.perk_thrifty_pct * float(ranks.get("thrifty", 0)), 0.0, 0.9)


## Multiplies (compounding per rank) only the dis_spread term in
## Game.tick_class() -- trouble still STARTS from boredom/frustration
## exactly as often, it just travels to fewer neighbouring desks.
static func disruption_spread_mult(ranks: Dictionary) -> float:
	Balance.ensure_loaded()
	var r := int(ranks.get("iron_will", 0))
	if r <= 0:
		return 1.0
	return pow(Balance.perk_iron_will_mult, float(r))
