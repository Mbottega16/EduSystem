class_name RoomLight
extends Node

## The light level of a whole space, and the fade that brings it up.
##
## The school's rule, set Oct 2026 on the owner's direction ("I want the rooms
## to be dark when you're in one room but phase into opening in another"): the
## space you are in is lit, every other space sits dim, and walking in raises
## the lights rather than snapping them on. The dim state is therefore
## information and not only mood -- a dim room is one somebody else is running
## (see memory: EduSystem puppets ONE room; a delegated room is a RoomSim
## policy, not a second body to teach with).
##
## Done with `modulate` on the space's own root, so it costs nothing and needs
## no lights, no occluders and no second viewport: every child -- the room, its
## furniture, its children, and the teacher once reparented in -- is multiplied
## by the same colour, which is what a change in light actually does.
##
## Only the fade IN is animated. A space is hidden the moment you leave it, so
## fading it out would be animating something nobody can see, and would put a
## wait in front of a transition every other system treats as immediate.

## Where a dim space sits. Cool rather than merely dark: an unlit room reads as
## evening, and a flat grey multiply reads as a bug. Close to LimeZu's own
## keyline family (#3a3a50) so the art and the darkness agree.
const DIM := Color(0.40, 0.43, 0.58)

## Long enough to see, short enough that it never delays the player. The door
## itself takes longer to walk through than this.
const FADE := 0.35


## Bring `space` up from dim to full. Call it right after making the space
## visible, from whichever transition just moved the player in.
##
## Any fade already running on that space is replaced (`create_tween()` on the
## node, so walking in and out faster than the fade cannot stack two of them).
static func phase_in(space: CanvasItem) -> void:
	if space == null:
		return
	space.modulate = DIM
	if not space.is_inside_tree():
		space.modulate = Color.WHITE
		return
	var tw := space.create_tween()
	tw.tween_property(space, "modulate", Color.WHITE, FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Put a space back to full light with no fade -- for a load, a test, or any
## path that must not depend on a tween having finished.
static func full(space: CanvasItem) -> void:
	if space != null:
		space.modulate = Color.WHITE
