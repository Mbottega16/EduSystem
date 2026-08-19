extends Interactable

## One door in the hallway, or the door out of your own room.
##
## Two places use this script: a single instance sits at the door hole in
## the player's OWN room (Layout.DOOR) and leads to the hallway; the
## hallway itself instances one per room you hold, plus one more for the
## next room you could open. Same script, same verb, because stepping
## through either door is the same action from the player's side -- you
## are choosing which room to be in.

## "home"    -- the door out of your own room, or (in the hallway) the
##              door back to it.
## "office"  -- the principal's office. Always there, second door along --
##              it is about you, not a room you are running, so it does
##              not count against Game.rooms or the room cap.
## "room"    -- a room you already hold. `room_index` is which one.
## "open"    -- the next room you could open. Only ever built when
##              Game.can_open_room() is true -- LOCKED ITEMS ARE HIDDEN
##              rather than greyed out, same rule the shop follows.
var door_kind: String = "home"
var room_index: int = -1
## True for the single door that sits in the player's OWN room and leads
## OUT to the hallway. False for every door built inside the hallway
## itself, "home" included -- the same door_kind reads differently
## depending which side of it you are standing on.
var leads_out: bool = false

signal chosen(kind: String, room_index: int)


func _init() -> void:
	super()
	uses_key = Key.MANAGE


## Never live mid-lesson. Leaving the room you are teaching, or wandering
## into the hallway while a class is sat a test, is not a door -- it is
## abandoning the room, and nothing about this feature is meant to make
## that free.
func can_interact() -> bool:
	return Game.phase != Game.Phase.LESSON


func prompt_text() -> String:
	match door_kind:
		"home":
			return "Step into the hallway" if leads_out else "Back to your room"
		"office":
			return "The principal's office"
		"open":
			return "Open a room (%d coins)" % Game.room_cost()
		_:
			if room_index < 0 or room_index >= Game.rooms.size():
				return "Empty doorway"
			var r: Dictionary = Game.rooms[room_index]
			var teacher: Dictionary = r.get("teacher", {})
			if teacher.is_empty():
				return "%s - unstaffed" % String(r.get("name", "Room"))
			var last: Dictionary = r.get("last", {})
			var grade := String(last.get("letter", "")) if not last.is_empty() else "not run yet"
			return "%s - %s (%s)" % [String(r.get("name", "Room")),
				String(teacher.get("name", "")), grade]


func interact(by: Node) -> void:
	chosen.emit(door_kind, room_index)
	used.emit(by)
