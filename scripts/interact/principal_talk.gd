extends Interactable

## The principal at her desk, in her office: E for a word with her -- the
## office screen it always was (milestones, tutorials, your career), now
## reached by walking up to her rather than by the door alone. Only opens a
## screen, so it sits on the mashable key. PrincipalOffice listens for `used`.


func prompt_text() -> String:
	return "Talk to the principal"


func interact(by: Node) -> void:
	used.emit(by)
