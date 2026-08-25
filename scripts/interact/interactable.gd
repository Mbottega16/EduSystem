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

const PICK_RADIUS := 40.0   ## doubled Aug 2026 alongside Grid.TILE (16 -> 32)


## Shrink (or grow) this one thing's own reach.
##
## Reach is the SUM of the player's zone and the interactable's circle, so a
## default 20 here plus 20 there is a 40px grab -- two and a half tiles. Two
## landmarks a couple of tiles apart therefore both answer from the same
## spot, and the one on the busier button wins the prompt. Anything sharing
## a corner with something else wants a smaller circle than the default.
func set_pick_radius(r: float) -> void:
	for c in get_children():
		if c is CollisionShape2D and (c as CollisionShape2D).shape is CircleShape2D:
			((c as CollisionShape2D).shape as CircleShape2D).radius = r

## Which key works this thing.
##
##   USE       - the constant, safe, repeated verb: help a stuck child,
##               hand in finished classwork, clean up a mess. Mashable,
##               and it must never be able to end a lesson.
##   MANAGE    - the deliberate, session-level ones left on it: ring the
##               bell, open the furniture shop.
##   TEACH     - start the lesson, at the podium. Split off MANAGE
##               (2026-08-25) for the same reason quiz/homework/move_desk
##               already were: what a key does should not depend on which
##               desk you happen to be standing at.
##   QUIZ      - call a quick quiz, at the podium, mid-lesson.
##   HOMEWORK  - mark the homework you have collected, at your own desk.
##   MOVE_DESK - pick up one specific desk and carry it.
##
## *(Aug 2026 -- three verbs that used to share USE or MANAGE contextually
## got their own dedicated key each, on user request: quiz off USE, and
## homework/desk-move off their old landmarks, so what a key does no
## longer depends on which desk you happen to be standing at. TEACH is the
## fourth, split off MANAGE the same way.)*
enum Key { USE, MANAGE, QUIZ, HOMEWORK, MOVE_DESK, TEACH }

## Every action a landmark can be bound to, in the same order as the enum
## above -- the one place that mapping lives, so action_name() is a lookup
## rather than a chain of special cases that could disagree with itself.
const KEY_ACTIONS := ["interact", "manage", "quiz", "homework", "move_desk", "teach"]

## Seconds the button must be HELD. Zero is instant. Anything irreversible
## gets a hold, so a stray press cannot cost you a lesson.
var hold_time: float = 0.0
var uses_key: int = Key.USE

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


## The action name this interactable listens for.
func action_name() -> String:
	return KEY_ACTIONS[uses_key]


## What the prompt should tell the player to press.
func key_hint() -> String:
	return Settings.binding_text(action_name()).split(",")[0].strip_edges()
