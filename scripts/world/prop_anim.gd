extends Node

## Steps a placed prop through the frames of its animation strip.
##
## Built by RoomBuilder.build_purchased() for an item whose entry in
## data/balance.json carries an `anim` block ({art, frames, fps}); the strip is a
## row of equally wide frames imported by tools/import_limezu.py. Purely visual: it
## reads no randomness (so nothing here can disturb the seeded `Game.rng`) and
## touches no state the balance contract measures. `phase` desynchronises two of the
## same prop so a pair of tanks do not shimmer in lockstep.

var sprite: Sprite2D = null
var frames := 1
var fps := 5.0
var _t := 0.0


func setup(spr: Sprite2D, strip: Texture2D, anim: Dictionary, phase: float) -> void:
	sprite = spr
	frames = maxi(1, int(anim.get("frames", 1)))
	fps = maxf(0.1, float(anim.get("fps", 5.0)))
	_t = phase
	if sprite != null and strip != null and frames > 1:
		sprite.texture = strip
		sprite.hframes = frames
		sprite.frame = int(_t * fps) % frames
	else:
		set_process(false)


func _process(delta: float) -> void:
	if sprite == null:
		return
	_t += delta
	sprite.frame = int(_t * fps) % frames
