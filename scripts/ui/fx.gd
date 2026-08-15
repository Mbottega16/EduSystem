class_name Fx
extends RefCounted

## Small, shared visual effects.
##
## The whole non-UI juice budget used to be Floater popups, the bubble
## pop-in and the seated idle bob. Everything else was flat: no particles, no
## shake, nothing that reacted to a thing landing. This is the shared place
## for that, so effects are one call rather than a hand-rolled tween at each
## site — the reason the game had so few of them.
##
## THE RULE, learned the hard way when the shop animated: results animate,
## lists do not. Anything the player is steering must not move under them.

const DUST := preload("res://art/dust.png")


## A puff of chalk dust. Used where something is finished or handed over —
## work collected, a child unstuck, an item put down.
static func puff(parent: Node2D, at: Vector2, colour := Color(1, 1, 1, 0.8),
		count: int = 5) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for i in count:
		var s := Sprite2D.new()
		s.texture = DUST
		s.position = at
		s.modulate = colour
		s.z_index = 60
		parent.add_child(s)
		# Spread upward and outward. Seeded from the loop rather than from
		# Game.rng deliberately: this is decoration, and decoration must
		# never consume draws from the run's seeded stream or a replay of
		# the same seed stops matching.
		var ang := -PI * 0.5 + randf_range(-0.9, 0.9)
		var dist := randf_range(5.0, 12.0)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position",
			at + Vector2(cos(ang), sin(ang)) * dist, 0.45) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.45).set_delay(0.1)
		tw.chain().tween_callback(s.queue_free)


## A quick squash-and-settle, for something that has just landed.
static func land(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.scale = Vector2(1.25, 0.75)
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A one-shot colour flash.
static func flash(node: CanvasItem, colour := Color(1.6, 1.6, 1.2),
		seconds: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = colour
	node.create_tween().tween_property(node, "modulate", Color.WHITE, seconds)


## Shake the screen a little.
##
## Deliberately small and short. The room is one screen with no camera, so a
## big shake moves everything the player is reading; this is a bump, not an
## earthquake, and it is reserved for the three moments that resolve
## something — the bell, an inspection, the exam.
static func shake(camera: Camera2D, strength: float = 2.0,
		seconds: float = 0.25) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var tw := camera.create_tween()
	var steps := 6
	for i in steps:
		var fall: float = strength * (1.0 - float(i) / float(steps))
		tw.tween_property(camera, "offset",
			Vector2(randf_range(-fall, fall), randf_range(-fall, fall)),
			seconds / float(steps))
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.05)


## Count a number up, into a Label, rather than having it appear.
static func count_to(label: Label, prefix: String, value: int,
		suffix: String = "", seconds: float = 0.5) -> void:
	if label == null or not is_instance_valid(label):
		return
	var tw := label.create_tween()
	tw.tween_method(
		func(v: float) -> void:
			label.text = "%s%d%s" % [prefix, int(round(v)), suffix],
		0.0, float(value), seconds).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
