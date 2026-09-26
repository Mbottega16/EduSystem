extends Interactable

## One of the mentor's own pupils, at their desk in her room.
##
## Not a StudentData and never in Game.roster -- nothing in the mentor's
## room is graded, saved or ticked (see mentor_room.gd). A hand is either up
## or down, and answering it puts it down. It answers the same two ways a
## real desk's HELP does: E when you stand at it, or a dash that reaches it
## once the chain dash is taught (player.gd's _tick_chain()). That second
## path is the whole reason it exists: this is where the player tries the
## chain the mentor has just shown them, on her class, before their own.

signal answered(by: Node)

## The seated pupil -- a data-less Student node, so the "?" is the real
## bubble a stuck child in your own room shows, not a lookalike.
var pupil: Node = null
var asking: bool = false


func can_interact() -> bool:
	return asking


func prompt_text() -> String:
	return "Answer them"


func interact(by: Node) -> void:
	answer(by)


func raise_hand() -> void:
	if asking:
		return
	asking = true
	if pupil != null and pupil.has_method("set_bubble"):
		pupil.set_bubble(true)


## Put the hand down: the same "got it!" and chalk puff a real desk's HELP
## gives, so what the mentor does and what you do read the same.
func answer(by: Node) -> bool:
	if not asking:
		return false
	asking = false
	if pupil != null and pupil.has_method("set_bubble"):
		pupil.set_bubble(false)
		pupil.play_pose(Actor.POSE_JUMP)
	Sfx.play("help")
	var room := get_parent() as Node2D
	if room != null:
		Floater.pop(room, position + Vector2(0, -44), "got it!",
			Color(0.55, 1.0, 0.6))
		Fx.puff(room, position + Vector2(0, -12), Color(0.55, 1.0, 0.6))
	answered.emit(by)
	return true


## The chain dash's two hooks -- see desk_station.gd for the real-room pair.
## A hand has to be up and the chain has to have been taught; the mentor's
## own demonstration calls answer() directly, before it is.
func dash_answerable() -> bool:
	return asking and Game.chain_dash_taught


func dash_answer(by: Node) -> bool:
	if not dash_answerable():
		return false
	return answer(by)
