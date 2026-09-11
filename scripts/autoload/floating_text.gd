extends Node

# Simple floating text that appears at a world position, rises and fades out.
# Usage: FloatingText.spawn("+10", world_position)
#
# Fixed 2026-09-11: the original draft preloaded a scenes/floating_text.tscn
# that was never created (would have failed to load at all, as an autoload,
# the moment the game booted) and used Godot 3 idioms (.instance(),
# get_tree() called from a static func) that don't exist in Godot 4. Rebuilt
# to build its Label in code -- no scene dependency, no static-context calls
# to instance-only methods.

const DURATION = 1.5
const RISE_DISTANCE = 30

static func spawn(text: String, world_position: Vector2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var ft := Label.new()
	ft.text = text
	ft.position = world_position
	ft.z_index = 100
	tree.get_root().add_child(ft)
	var tween := ft.create_tween()
	tween.tween_property(ft, "modulate:a", 0.0, DURATION)
	tween.parallel().tween_property(ft, "position:y", ft.position.y - RISE_DISTANCE, DURATION)
	tween.tween_callback(ft.queue_free)
