extends Actor

## A student. In Phase 0 they are placed straight into their seat; Phase 1
## gives them a path to walk in from the door.
##
## Students do NOT collide with each other (layer `actors`, mask `world`
## only). Mutual avoidance between eight bodies in a 16px aisle is a rabbit
## hole that buys nothing here — they never need to swap places.

var data: StudentData = null


func bind(d: StudentData) -> void:
	data = d
	var tex: Texture2D = load("res://art/%s.png" % d.art)
	if tex != null:
		sprite.texture = tex


## Place directly into a seat with no walk. Collision is disabled because the
## desk and chair already block those tiles — leaving a body here lets the
## teacher wedge into a 16px aisle with no way out.
func seat_at(world_pos: Vector2) -> void:
	global_position = world_pos
	sit(DIR_DOWN)
	_set_collision(false)


func _set_collision(on: bool) -> void:
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", not on)
