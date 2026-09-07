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


## The kick of smoke a dash launches out of.
##
## Not puff(): a puff is five flecks of chalk dust drifting UP, for something
## that has just been finished. This is a low, wide, ground-hugging cloud
## that spreads outward and BACKWARDS along the direction of travel, and it
## grows as it goes rather than only fading -- the difference between "that
## finished" and "that shoved off hard". The trail (afterimage) says where
## the dash went; this says how hard it started.
##
## `count`, `spread` and `size` come from Progress.dash_smoke_*(), so the
## Light Feet perk makes the cloud visibly bigger as it makes the dash
## longer. Seeded from the engine, never Game.rng -- see puff() for why.
static func smoke(parent: Node2D, at: Vector2, heading: Vector2,
		count: int = 8, spread: float = 16.0, size: float = 2.2,
		seconds: float = 0.5) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# Straight back down the direction of travel. A dash fired from a dead
	# stop (the double-tap can do that) has no heading, and a cloud with no
	# direction is still a cloud, so fall back to "outward, every way".
	var back := -heading.normalized() if heading.length() > 0.01 else Vector2.ZERO
	for i in maxi(1, count):
		var s := Sprite2D.new()
		s.texture = DUST
		s.position = at
		# Warm grey, and thinner the more of it there is, so a levelled dash
		# throwing twenty motes does not become an opaque wall over the room.
		s.modulate = Color(0.86, 0.83, 0.78, clampf(0.7 - count * 0.012, 0.28, 0.7))
		s.scale = Vector2.ONE * size * randf_range(0.6, 1.15)
		s.z_index = 59              # under the chalk puff, over the floor
		parent.add_child(s)
		var fan := Vector2.RIGHT.rotated(randf_range(-PI, PI))
		if back != Vector2.ZERO:
			fan = back.rotated(randf_range(-1.1, 1.1))
		var to := at + fan * spread * randf_range(0.45, 1.0) \
			+ Vector2(0, randf_range(-2.0, 3.0))
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", to, seconds) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		# billowing: a real puff of dust gets bigger as it thins out
		tw.tween_property(s, "scale", s.scale * 1.9, seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, seconds).set_delay(seconds * 0.25)
		tw.chain().tween_callback(s.queue_free)


## A fading ghost of a sprite, left where it currently stands. Spawn one
## every frame or two while an actor is dashing and the trail draws itself
## as the actor moves on -- a lunge reads as a lunge rather than the actor
## just briefly moving faster. Seeded from nothing: pure decoration, it
## must never touch Game.rng (see puff() for why).
static func afterimage(src: Sprite2D, parent: Node2D,
		tint := Color(0.75, 0.83, 1.0, 0.4), seconds: float = 0.18) -> void:
	if src == null or not is_instance_valid(src) \
			or parent == null or not is_instance_valid(parent):
		return
	var g := Sprite2D.new()
	g.texture = src.texture
	g.hframes = src.hframes
	g.vframes = src.vframes
	g.frame = src.frame
	g.flip_h = src.flip_h
	g.global_position = src.global_position
	g.z_index = src.z_index - 1
	g.modulate = tint
	g.set_meta("afterimage", true)
	parent.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(g.queue_free)


## How many afterimages `parent` is holding right now -- the cap the dash
## trail checks before spawning another.
static func afterimage_count(parent: Node) -> int:
	if parent == null or not is_instance_valid(parent):
		return 0
	var n := 0
	for c in parent.get_children():
		if c.has_meta("afterimage"):
			n += 1
	return n


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


## One drifting mote of ambient weather — a raindrop, a snowflake, a mote
## of dust in a sunbeam. Spawned above the room at a random x, drifts to a
## random point below, and fades out. The room's OWN day event decides
## whether any of this runs at all and what colour it drifts in, so most
## days are still the plain room they have always been — the point is that
## the handful of days that roll something different now LOOK different,
## not just read differently on last night's report.
##
## Reuses the dust puff's own texture and z-index rather than new art: a
## mote is a puff that falls instead of scattering, and the room already
## knows how to draw one of those.
static func weather_mote(parent: Node2D, top_left: Vector2, size: Vector2,
		colour: Color, fall: bool, seconds: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var s := Sprite2D.new()
	s.texture = DUST
	# DUST is a 2x2 png with one corner transparent, which reads as five
	# converging flecks in a puff() burst but is a near-invisible smudge
	# alone at native size -- confirmed by screenshot, not assumed. Scaled
	# well past puff()'s own size, and stretched along the direction of
	# travel so a raindrop reads as a streak rather than a dot, the same
	# trick real pixel-art rain uses.
	s.scale = Vector2(2.5, 7.0) if fall else Vector2(4.5, 4.5)
	s.modulate = colour
	s.z_index = 55
	var start := top_left + Vector2(randf() * size.x,
		0.0 if fall else size.y)
	s.position = start
	parent.add_child(s)
	# Seeded from the loop, same as puff() -- decoration must never draw
	# from Game.rng or a replay of the same seed stops matching.
	var drift := randf_range(-6.0, 6.0)
	var travel: float = size.y if fall else -size.y
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position",
		start + Vector2(drift, travel), seconds).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(s, "modulate:a", 0.0, seconds).set_delay(seconds * 0.6)
	tw.chain().tween_callback(s.queue_free)


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
