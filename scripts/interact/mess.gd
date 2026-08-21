extends Interactable

## A dropped bit of clutter -- trash on the floor, a spill -- left over from
## a previous day (or from the day just starting). Cleaning it is a MASH,
## not a hold: press E repeatedly (Balance.mess_clean_presses times) rather
## than hold it down, same as collecting a finished sheet already is --
## hold_time stays 0, so player.gd's own claim_action()/just_pressed gate is
## what makes each press count once. Nothing about it cares what phase the
## day is in, so it can be done before the lesson, mid lesson, or after --
## there's no gate to add.
##
## A flat coin tip on the final press (Balance.mess_clean_reward), not a
## grade input. It is still legwork -- the balance contract measures GRADE,
## and this touches nothing grade reads (grade.room_base etc). See
## room_upkeep's own note in balance.json.

## Carries `self` -- not just the kind -- because queue_free() is deferred:
## is_instance_valid(self) is still TRUE for the rest of this frame, so a
## listener that tried to prune its list by validity right when this fires
## would find nothing to prune yet. Passing identity lets it just erase()
## this exact node instead of guessing from validity.
signal cleaned(mess: Interactable, kind: String)

## "trash" or "spill" -- picks the art and the prompt wording.
var kind: String = "trash"
var _presses: int = 0


func _init() -> void:
	super()
	uses_key = Key.USE
	set_pick_radius(28.0)


func prompt_text() -> String:
	var left: int = Balance.mess_clean_presses - _presses
	var verb := "Wipe up the spill" if kind == "spill" else "Sweep up the mess"
	return "%s (%d)" % [verb, left] if left < Balance.mess_clean_presses else verb


func interact(by: Node) -> void:
	_presses += 1
	Sfx.play_varied("paper")
	used.emit(by)
	if _presses < Balance.mess_clean_presses:
		return

	Game.add_coins(Balance.mess_clean_reward)
	cleaned.emit(self, kind)
	# Freeing THIS node only removed the invisible Area2D that answers E --
	# the sprite and its shadow live one level up, on the prop body
	# RoomBuilder.build_mess() made this a child of, so the art was left
	# behind forever. Free the whole prop instead.
	var body := get_parent()
	if body != null:
		body.queue_free()
	else:
		queue_free()
