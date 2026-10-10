extends Interactable

## The register lying open on your own desk: the GRADE BOOK (Oct 2026, the
## owner's ask -- "keep a log book of all the grades on the table where you
## submit the papers"). Every grade the run has given, lesson by lesson, is
## in Game.grade_log; this is where you stand to read it, and
## hud.show_grade_book() is the page.
##
## Its own key (GRADES, U), not E. E at this desk already hands in the sheets
## you are carrying, and E is the key you mash: a book that opened on E as
## soon as your arms were empty would land a full screen in the middle of
## that mash. Same reasoning that gave marking homework its own H. It only
## reads, so it is live in every phase and has no hold.

signal grade_book_opened()


func _init() -> void:
	super()
	uses_key = Key.GRADES
	add_to_group("grade_book")


func prompt_text() -> String:
	return "Read the grade book"


func interact(by: Node) -> void:
	grade_book_opened.emit()
	used.emit(by)
