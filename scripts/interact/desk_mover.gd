extends Interactable

## Pick up a whole desk — desk, chair, and whoever is sitting at it — and put
## it somewhere else.
##
## On MANAGE (F), not USE (E). E is the verb you mash all lesson long to help
## and collect; rearranging the furniture is emphatically not that, and the
## whole reason the two buttons were split was that one key doing everything
## meant reaching to help a student could end the lesson.
##
## This shares a tile with the desk's own desk_station, and the picker keeps
## exactly one target, so the two must never both be live at once — see
## can_interact() below.

signal desk_move_requested(seat_index: int)

var seat_index: int = -1
## The desk's USE interactable, which this one always yields to.
var station: Interactable = null


func _init() -> void:
	super()
	uses_key = Key.MANAGE


func can_interact() -> bool:
	# Not mid-lesson. Sliding desks around while the class works would dodge
	# the entire point of planning the room in advance -- the same rule
	# placed_item.gd already applies to bought furniture.
	if Game.phase == Game.Phase.LESSON:
		return false
	# Never steal the prompt from something the player can do for a CHILD
	# right now. Both areas sit on the same desk at the same distance, so
	# without an explicit rule the winner is iteration order.
	if station != null and station.can_interact():
		return false
	return true


func prompt_text() -> String:
	var s := Game.student_in_seat(seat_index)
	if s == null:
		return "Move the empty desk"
	return "Move %s's desk" % s.first_name()


func interact(by: Node) -> void:
	desk_move_requested.emit(seat_index)
	used.emit(by)
