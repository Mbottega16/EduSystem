extends Interactable

## "Books away. This is the unit test."
##
## The third and last instrument, and the only one you cannot touch once it
## has started:
##
##   quiz      mid-lesson, low stakes, results at once, ACT on them
##   homework  overnight, medium, marked blind the next morning
##   test      end of unit, high stakes, and you may only watch
##
## Shares the podium with the quiz on USE (E) — the quiz is only offered
## DURING a lesson and the test only in the MORNING, so they are never live
## at the same moment. F remains "teach today's lesson".
##
## It is gated on having actually taught the unit. A test on material the
## class has never covered is not a difficulty setting, it is a worse
## lesson with a crueller name.

signal test_requested(lesson_id: String)


func _init() -> void:
	super()
	uses_key = Key.USE
	# Irreversible: it consumes the day and it cannot be re-sat. Everything
	# that cannot be undone in this game is a HOLD, never a tap.
	hold_time = 0.6


func _classroom() -> Node:
	var n := get_parent()
	while n != null and not n.has_method("start_test"):
		n = n.get_parent()
	return n


func can_interact() -> bool:
	if Game.phase != Game.Phase.MORNING or Game.roster.is_empty():
		return false
	# Same reasoning as the podium: never offer nothing at the landmark the
	# day starts from. Latecomers are handed their paper when they sit.
	return not Game.testable_lesson().is_empty()


func prompt_text() -> String:
	var l := Game.testable_lesson()
	if l.is_empty():
		return ""
	return "Unit test: %s" % Curriculum.short_name(l)


func interact(by: Node) -> void:
	var l := Game.testable_lesson()
	if l.is_empty():
		return
	Sfx.play("start")
	test_requested.emit(String(l.get("id", "")))
	used.emit(by)
