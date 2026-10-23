extends Interactable

## A door into the grade wing, one per stage of the school (Oct 2026).
##
## E at it reads that stage's card (hud.show_stage()): what the stage is like,
## what it pays, and -- for the next stage, once a whole term is taught in this
## one -- the offer to move up. The door only ever reads, so it is on the
## mashable key, like the trophy case; the move itself is a second, deliberate
## F on the card. That also keeps it off F, which the corridor's own doors
## along the bottom already answer to.

## Index into Balance.tier_order.
var tier_index: int = 0

signal chosen(tier_index: int)


func prompt_text() -> String:
	var stage := Game.tier_name(tier_index)
	if tier_index == Game.age_tier:
		return "%s - you teach here" % stage
	if tier_index == Game.age_tier + 1:
		return "%s - move up?" % stage
	return "Look into %s" % stage


func interact(by: Node) -> void:
	chosen.emit(tier_index)
	used.emit(by)
