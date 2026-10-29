class_name Items
extends RefCounted

## Things you can buy and place. The table itself lives in data/balance.json
## so prices and effects can be tuned and simulated without touching code.
##
## Effects are RANGE-BASED from the item's own tile, not a room-wide
## checklist. That is what makes *where* you put a bookshelf matter.

## Classroom theme items (authentic stage and subject art)
const CLASSROOM_ART := [
	"res://art/rug_alphabet_circle.png",
	"res://art/reading_rocking_chair.png",
	"res://art/picture_book_ledge.png",
	"res://art/art_splat_mat.png",
	"res://art/counting_bears_tray.png",
	"res://art/middle_science_bench.png",
	"res://art/topographical_globe.png",
	"res://art/chem_lab_bench.png",
]


static func catalogue() -> Dictionary:
	Balance.ensure_loaded()
	return Balance.items


static func order() -> Array:
	Balance.ensure_loaded()
	return Balance.item_order


## The shop's category tabs, in the order they are shown.
static func categories() -> Array:
	Balance.ensure_loaded()
	return Balance.item_categories


static func category_label(cat: String) -> String:
	return cat.capitalize()


## False for a piece the room simply HAS. Such a thing still needs a full item
## def -- art, a width, a footprint, an `anim` block -- because
## RoomBuilder.DECOR_SEED reads it exactly as it reads a bought piece. What it
## does not need is a price, and no shop tab lists it. Added Oct 2026 so
## animated decor and themed event dressing can exist without inventing a
## cost, a bonus and a range for something that was never for sale.
static func in_shop(id: String) -> bool:
	return bool(get_def(id).get("shop", true))


## Every item in one category, cheapest first (item_order is already sorted
## by category then cost, so this preserves that). Pieces the room simply has
## are filtered out here, which is the one funnel every shop tab goes through.
static func in_category(cat: String) -> Array:
	var out: Array = []
	for id: String in order():
		if String(get_def(id).get("cat", "")) == cat and in_shop(id):
			out.append(id)
	return out


## Lies on the floor or hangs on a wall, so it casts no contact shadow --
## a rug with a shadow under it looks like it is hovering.
static func is_flat(id: String) -> bool:
	return bool(get_def(id).get("flat", false))


## Hangs on the back wall rather than standing on the floor (a clock, a
## banner, the letter frieze). It lives on the wall row, takes up no floor,
## and is placed along the wall -- see Layout.wall_slot_ok().
static func is_wall(id: String) -> bool:
	return bool(get_def(id).get("wall", false))


static func category_of(id: String) -> String:
	return String(get_def(id).get("cat", ""))


## Stands ON a child's desk rather than on the floor (Oct 2026: the study
## folder). It lives in Game.desk_items, not Game.room_items: it takes no
## floor, reaches nobody else, and travels with its desk because a desk keeps
## its index when it moves. What it does is to the one child sitting there.
static func is_desk_top(id: String) -> bool:
	return bool(get_def(id).get("desk_top", false))


## How many copies you may own at once -- in the cabinet, on the floor and on
## desks, all counted (Game.owned_count()). 0 means no limit, which is every
## piece of furniture; a limit makes WHO gets one the decision.
static func max_owned(id: String) -> int:
	return int(get_def(id).get("max_owned", 0))


## Multiplier on work speed for the child whose desk holds this item.
static func desk_work_mult(id: String) -> float:
	return float(get_def(id).get("desk_work_mult", 1.0))


## The concept owning this item confers, if any.
static func teaches(id: String) -> String:
	return String(get_def(id).get("teaches", ""))


## The one subject this item is built for, if any: "ela" / "math" /
## "science" / "social". Empty means it helps every lesson equally, the
## way all 54 of the original items do. A subject item gives its ordinary
## `bonus` on any day and an extra `strand_bonus` on top only when today's
## lesson matches -- so it is a specialise-your-room choice, not a
## strictly-better one. Cannot move the balance contract: room_score()
## clamps to Balance.room_cap and tools/sim.gd fills the contract rooms
## up to that cap regardless.
static func strand(id: String) -> String:
	return String(get_def(id).get("strand", ""))


## The extra room_score an item adds on a day its `strand` matches the
## lesson. Zero for every non-subject item.
static func strand_bonus(id: String) -> float:
	return float(get_def(id).get("strand_bonus", 0.0))


## The concept you must already know before this is on sale, if any.
static func requires(id: String) -> String:
	return String(get_def(id).get("needs", ""))


## The trophy this item is gated behind, if any. "*" means "any boss
## trophy at all" -- the one cosmetic the roguelike subject boss unlocks.
static func requires_trophy(id: String) -> String:
	return String(get_def(id).get("needs_trophy", ""))


## Is it on sale yet? Gating a few items on concepts means the shop grows as
## you TEACH and not only as you earn -- so a term spent on science opens a
## different catalogue from a term spent on English. A handful are gated on
## a boss trophy instead (needs_trophy), reading Game.trophies the same way
## the concept check reads Game's taught list.
static func is_unlocked(id: String) -> bool:
	var need := requires(id)
	if need != "" and not Game.knows_concept(need):
		return false
	var trophy := requires_trophy(id)
	if trophy == "*":
		return not Game.trophies.is_empty()
	if trophy != "" and not Game.trophies.has(trophy):
		return false
	return true


## What the shop can list right now, in one category.
static func available_in_category(cat: String) -> Array:
	var out: Array = []
	for id: String in in_category(cat):
		if is_unlocked(id):
			out.append(id)
	return out


static func get_def(id: String) -> Dictionary:
	return catalogue().get(id, {})


static func cost(id: String) -> int:
	return int(get_def(id).get("cost", 0))


static func width(id: String) -> int:
	return int(get_def(id).get("w", 1))


## Every tile a placement at `origin` would occupy.
static func footprint(id: String, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in width(id):
		out.append(origin + Vector2i(i, 0))
	return out


## The tiles an item reaches desks FROM. A floor piece reaches from where it
## stands; a hung piece from the floor at the foot of its wall, so hanging
## something up costs it nothing a floor piece standing there would not.
static func reach_footprint(id: String, origin: Vector2i) -> Array[Vector2i]:
	var from := origin
	if is_wall(id):
		from = origin + Vector2i(0, Layout.TOP_WALL - Layout.WALL_ROW)
	return footprint(id, from)


## Which seats an item at `origin` would actually help — the thing the
## player could never see while placing.
static func seats_in_range(id: String, origin: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var d := get_def(id)
	if d.is_empty():
		return out
	var reach := int(d.get("range", 0))
	for i in Layout.seat_count():
		var seat: Vector2i = Layout.seat(i)
		var best := 9999
		for t: Vector2i in reach_footprint(id, origin):
			best = mini(best, absi(t.x - seat.x) + absi(t.y - seat.y))
		if best <= reach:
			out.append(i)
	return out
