extends Interactable

## The staff rota, pinned to the corridor's noticeboard (the owner's ask,
## 2026-11-06). F opens it: the day's jobs, each a short shift. On MANAGE, not
## E: choosing which job to do is a deliberate choice of where to be, the same
## verb as a door -- and E is the mash.


func _init() -> void:
	super()
	uses_key = Key.MANAGE


## Hidden until the admin gate opens, and never mid-shift or mid-lesson.
func can_interact() -> bool:
	return Game.admin_unlocked() and Game.duty_active == "" \
		and Game.phase != Game.Phase.LESSON


func prompt_text() -> String:
	return "The staff rota"


func interact(by: Node) -> void:
	used.emit(by)
