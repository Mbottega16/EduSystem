extends Interactable

## The optional reward-video poster. E opens a choice of three lengths,
## each paying more than the last -- and it stays exactly that: a choice
## you walk up to and make, never a pop-up, never forced, never showing up
## uninvited mid-lesson. See docs/ROGUELIKE_DESIGN.md's ads note and
## Balance.ad_tiers (data/balance.json → "ads") for the actual numbers.
##
## Key.USE (E) on purpose, not MANAGE -- watching one is reversible and
## repeatable exactly like every other E verb; nothing about it can end a
## lesson or lose you anything, so it belongs on the mashable button, not
## the session-level one.

signal ad_poster_opened()


func prompt_text() -> String:
	return "Watch for a reward"


func interact(by: Node) -> void:
	ad_poster_opened.emit()
	used.emit(by)
