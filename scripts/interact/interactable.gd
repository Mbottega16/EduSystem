class_name Interactable
extends Area2D

## Something you can stand next to and press E on.
##
## PLACEMENT RULE, and it matters more than it looks: the Area2D goes on the
## FURNITURE, never on the person sitting at it. From any orthogonally
## adjacent standing tile a desk is a uniform 16px away, while the next desk
## along is 48px — so a 20px pick radius discriminates perfectly. Put the
## area on the seated student instead (10px behind the desk) and you get 26px
## from the front but 19px from the side, and you fight that asymmetry
## forever.

const PICK_RADIUS := 20.0

@warning_ignore("unused_signal")
signal used(by: Node)


func _init() -> void:
	collision_layer = 8      # "interactable" — see [layer_names] in project.godot
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PICK_RADIUS
	shape.shape = circle
	add_child(shape)


## Shown in the prompt box when this is the selected target.
func prompt_text() -> String:
	return ""


## False hides it from the picker entirely, so a thing with nothing to offer
## never steals the prompt from a thing that does.
func can_interact() -> bool:
	return true


func interact(_by: Node) -> void:
	pass
