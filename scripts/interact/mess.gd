extends Interactable

## A dropped bit of clutter -- trash on the floor, a spill -- left over from
## a previous day (or from the day just starting). Cleaning it is the same
## verb as everything else on E: stand near it and hold. Nothing about it
## cares what phase the day is in, so it can be done before the lesson, mid
## lesson, or after -- there's no gate to add.
##
## Deliberately NOT scored. This is legwork, same as walking to a desk; it
## pays no coins, no XP, and touches nothing the balance contract measures.
## A cleanliness number that fed back into the grade would be exactly the
## kind of thing CLAUDE.md's "the balance contract must hold" rule exists
## to catch, and there is no request for one here.

## How long the clean-up hold takes. A UX timing, not a balance number --
## same precedent as Bell/Podium/TestCaller's own hold_time constants.
const CLEAN_HOLD_TIME := 2.3

## Carries `self` -- not just the kind -- because queue_free() is deferred:
## is_instance_valid(self) is still TRUE for the rest of this frame, so a
## listener that tried to prune its list by validity right when this fires
## would find nothing to prune yet. Passing identity lets it just erase()
## this exact node instead of guessing from validity.
signal cleaned(mess: Interactable, kind: String)

## "trash" or "spill" -- picks the art and the prompt wording.
var kind: String = "trash"


func _init() -> void:
	super()
	uses_key = Key.USE
	hold_time = CLEAN_HOLD_TIME
	set_pick_radius(28.0)


func prompt_text() -> String:
	return "Wipe up the spill" if kind == "spill" else "Sweep up the mess"


func interact(by: Node) -> void:
	Sfx.play_varied("paper")
	cleaned.emit(self, kind)
	used.emit(by)
	queue_free()
