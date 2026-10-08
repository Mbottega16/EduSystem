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
	g.z_index = src.z_index - 1
	g.modulate = tint
	g.set_meta("afterimage", true)
	parent.add_child(g)
	# AFTER add_child: a global position set on a node with no parent yet is
	# just its local one, which is only right for a parent at the origin.
	# The mentor's room sits at (0, 20000), and a trail there landed 20000px
	# below the room.
	g.global_position = src.global_position
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


## A ring of light bursting out of `at` -- "answer all", the teacher's one
## move that reaches the whole room at once, drawn as what it is: a wave
## leaving the teacher and washing over every desk. Two rings (a bright edge,
## a soft one trailing it), a flash of a disc at the centre, and a scatter of
## chalk flung outward. Seeded from the engine, never Game.rng -- see puff().
##
## Returns how long the leading ring takes to reach `radius`, so a caller can
## time something to the moment the wave arrives somewhere: distance / radius
## * that.
static func shockwave(parent: Node2D, at: Vector2, radius: float = 420.0,
		colour := Color(1.0, 0.93, 0.62), seconds: float = 0.7) -> float:
	if parent == null or not is_instance_valid(parent):
		return seconds
	# The flash: a filled disc that blooms and is gone before the ring is far.
	var core := Ring.new()
	core.position = at
	core.fill = true
	core.colour = Color(colour.r, colour.g, colour.b, 0.55)
	core.z_index = 61
	parent.add_child(core)
	var tc := core.create_tween().set_parallel(true)
	tc.tween_property(core, "radius", 46.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tc.tween_property(core, "modulate:a", 0.0, 0.3)
	tc.chain().tween_callback(core.queue_free)
	# The rings. Cubic-out: it leaves hard and slows as it spreads, the
	# shape of a shout rather than of a radar sweep.
	for i in 2:
		var r := Ring.new()
		r.position = at
		r.width = 6.0 if i == 0 else 3.0
		r.colour = colour if i == 0 else Color(1, 1, 1, 0.6)
		r.z_index = 61
		parent.add_child(r)
		var t := r.create_tween().set_parallel(true)
		t.tween_property(r, "radius", radius * (1.0 if i == 0 else 0.82), seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.06 * i)
		t.tween_property(r, "modulate:a", 0.0, seconds * 0.55) \
			.set_delay(seconds * 0.45 + 0.06 * i)
		t.chain().tween_callback(r.queue_free)
	# Chalk flung outward all the way round, riding the ring.
	for i in 18:
		var s := Sprite2D.new()
		s.texture = DUST
		s.position = at
		s.scale = Vector2.ONE * randf_range(1.6, 3.0)
		s.modulate = Color(colour.r, colour.g, colour.b, 0.9)
		s.z_index = 60
		parent.add_child(s)
		var ang := TAU * float(i) / 18.0 + randf_range(-0.12, 0.12)
		var to := at + Vector2(cos(ang), sin(ang)) * randf_range(0.35, 0.6) * radius
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", to, seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, seconds * 0.6).set_delay(seconds * 0.35)
		tw.chain().tween_callback(s.queue_free)
	return seconds


## When a ring tweened by shockwave() reaches distance `d` out of `radius`:
## the inverse of its cubic-out ease, so a desk is touched as the bright edge
## actually passes over it rather than on a straight-line guess.
static func wave_arrival(d: float, radius: float, seconds: float) -> float:
	var x := clampf(d / maxf(1.0, radius), 0.0, 1.0)
	# cubic-out: p = 1 - (1 - t)^3  ->  t = 1 - (1 - p)^(1/3)
	return seconds * (1.0 - pow(1.0 - x, 1.0 / 3.0))


const SPEECH := preload("res://scenes/actors/speech_bubble.tscn")
const MARK_HEARD := preload("res://art/bubble_excl.png")
const CALL_COLOUR := Color(0.62, 0.86, 1.0)
## Above everything in the room, however it sorts its own depth -- the
## mentor's room sets z_index from y by hand, which put a bubble at 64 under
## anyone standing below row 64.
const OVER_ALL := 3000

## "Class, class!" -- "Yes, yes!" The call-and-response, drawn: the caller's
## line in a speech bubble, three thin rings of sound going out from them
## (cool, thin and quick -- answer-all's burst is warm and heavy; the two must
## not read as the same move), and each child it reaches looking up with a
## "!" and a little bounce as the sound gets there, then the whole room's
## answer in one bubble over the middle of the class. Used by the classroom
## for the real thing and by the mentor's room for her demonstration.
## `kids` are the Node2Ds that answer (a child busy playing up does not).
## Decoration only -- engine randomness, never Game.rng.
static func call_and_response(parent: Node2D, caller: Node2D, kids: Array,
		radius: float = 360.0, seconds: float = 0.9) -> void:
	if parent == null or not is_instance_valid(parent) \
			or caller == null or not is_instance_valid(caller):
		return
	var from := parent.to_local(caller.global_position) + Vector2(0, -16)
	_say_for(parent, from + Vector2(0, -14), "Class, class!", 1.0)
	for i in 3:
		var r := Ring.new()
		r.position = from
		r.width = 2.0
		r.colour = CALL_COLOUR
		r.z_index = OVER_ALL
		parent.add_child(r)
		var t := r.create_tween().set_parallel(true)
		t.tween_property(r, "radius", radius, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.14 * i)
		t.tween_property(r, "modulate:a", 0.0, seconds * 0.5) \
			.set_delay(seconds * 0.5 + 0.14 * i)
		t.chain().tween_callback(r.queue_free)
	var mid := Vector2.ZERO
	var top := INF
	var last := 0.0
	var answering := 0
	for k in kids:
		if not (k is Node2D) or not is_instance_valid(k):
			continue
		var kid := k as Node2D
		var at := parent.to_local(kid.global_position)
		mid += at
		top = minf(top, at.y)
		answering += 1
		# Sine-out reaches distance d at asin(d / radius) / (PI / 2) of the
		# way through; a quarter-second after that they react.
		var x := clampf(from.distance_to(at) / radius, 0.0, 1.0)
		var when := seconds * asin(x) / (PI * 0.5) + 0.25
		last = maxf(last, when)
		kid.get_tree().create_timer(when).timeout.connect(func() -> void:
			if not is_instance_valid(kid) or not is_instance_valid(parent):
				return
			land(kid)
			# A child already showing a mark (a stuck "?") keeps it: their
			# answer is the bounce, not a second bubble stacked on the first.
			var own: Variant = kid.get("bubble")
			if own is CanvasItem and (own as CanvasItem).visible:
				return
			var m := Sprite2D.new()
			m.texture = MARK_HEARD
			m.position = at + Vector2(0, -58)
			m.modulate = CALL_COLOUR.lerp(Color.WHITE, 0.5)
			m.z_index = OVER_ALL
			m.scale = Vector2(0.4, 0.4)
			parent.add_child(m)
			var mt := m.create_tween()
			mt.tween_property(m, "scale", Vector2.ONE, 0.16) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			mt.tween_interval(0.5)
			mt.tween_property(m, "modulate:a", 0.0, 0.25)
			mt.tween_callback(m.queue_free))
	if answering == 0:
		return
	mid /= float(answering)
	parent.get_tree().create_timer(last + 0.1).timeout.connect(func() -> void:
		if not is_instance_valid(parent):
			return
		Sfx.play_varied("confirm")
		_say_for(parent, Vector2(mid.x, top - 62.0), "Yes, yes!", 1.2))


## A speech bubble that is not anybody's: dropped into `parent` at `at`,
## saying `text`, gone after `seconds`.
static func _say_for(parent: Node2D, at: Vector2, text: String, seconds: float) -> void:
	var b: Node2D = SPEECH.instantiate()
	b.position = at
	b.z_index = OVER_ALL + 1
	parent.add_child(b)
	b.say(text)
	b.fit_width()
	b.get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.queue_free())


## A drawn circle -- an outline of `width`, or filled. Pixel-hard (no
## antialiasing), redrawn whenever a tween moves its radius.
class Ring extends Node2D:
	var colour := Color.WHITE
	var width := 4.0
	var fill := false
	var radius := 1.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		if fill:
			draw_circle(Vector2.ZERO, radius, colour, true, -1.0, false)
		else:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, maxi(24, int(radius * 0.6)),
				colour, width, false)


## A swing back and forth that dies away -- the bell, rung. Rotates the
## node about its own origin, so a sprite whose origin is its centre rocks
## in place. Decoration only.
static func wobble(node: Node2D, swing: float = 0.35, seconds: float = 0.7) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw := node.create_tween()
	var steps := 6
	for i in steps:
		var a: float = swing * (1.0 - float(i) / float(steps)) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(node, "rotation", a, seconds / float(steps + 1)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation", 0.0, seconds / float(steps + 1))


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
## `strip` (with `frames`) swaps the dust mote for a drawn, animated one --
## a raindrop's streak, a turning snowflake, a sparkle (Ninja Adventure's
## particles, tools/free_manifest.json) -- played across the mote's whole
## life at its own size. A day with no strip keeps the dust.
static func weather_mote(parent: Node2D, top_left: Vector2, size: Vector2,
		colour: Color, fall: bool, seconds: float,
		strip: Texture2D = null, frames: int = 1) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if strip != null and frames > 1:
		_drawn_mote(parent, top_left, size, colour, fall, seconds, strip, frames)
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


static func _drawn_mote(parent: Node2D, top_left: Vector2, size: Vector2,
		colour: Color, fall: bool, seconds: float, strip: Texture2D, frames: int) -> void:
	var s := Sprite2D.new()
	s.texture = strip
	s.hframes = frames
	s.modulate = colour
	s.z_index = 55
	var start := top_left + Vector2(randf() * size.x, 0.0 if fall else size.y)
	s.position = start
	parent.add_child(s)
	var drift := randf_range(-10.0, 10.0)
	var travel: float = size.y if fall else -size.y
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position", start + Vector2(drift, travel), seconds) \
		.set_trans(Tween.TRANS_LINEAR)
	# Its frames cycle the whole way down, a few times a second.
	var cycles := maxf(1.0, seconds * 6.0 / float(frames))
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(s):
			s.frame = int(t) % frames, 0.0, cycles * float(frames), seconds)
	tw.tween_property(s, "modulate:a", 0.0, seconds * 0.4).set_delay(seconds * 0.6)
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
