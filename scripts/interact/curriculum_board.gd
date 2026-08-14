extends Interactable

## What you have learned to teach.
##
## The noticeboard opens the shop on F (MANAGE); this is the same board on E.
## They are always both live, which is fine — they are different keys, and
## the picker only has to choose between things sharing an ACTION.
##
## Getting this backwards put two MANAGE interactables on one tile, and the
## shop simply stopped opening. Check the key on the thing you are sharing a
## tile with; do not assume it.
##
## The screen exists because a concept has to be legible to be worth
## anything. EduSystems' own notes record concepts that unlocked a name on a
## list and changed nothing, and called it "the single clearest reason the
## learning system doesn't make sense". A list you can read, with the real
## standard beside it and a number attached, is the cheap half of not
## repeating that; concept_bonus() is the other half.

signal curriculum_opened()


func _init() -> void:
	super()
	uses_key = Key.USE


func prompt_text() -> String:
	return "Curriculum (%d/%d)" % [Game.concepts.size(), Curriculum.concept_count()]


func interact(by: Node) -> void:
	curriculum_opened.emit()
	used.emit(by)
