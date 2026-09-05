class_name Floater
extends Node2D

## A small number or word that rises and fades where something happened.
##
## The teacher's core verb — unsticking a student — used to produce no
## reward moment at all: the bubble vanished and nothing else. In a game
## with no camera movement this is most of the "you did a thing" feedback
## budget.

static func pop(parent: Node2D, at: Vector2, text: String,
		colour: Color = Color(1, 1, 1)) -> void:
	var f := Floater.new()
	f.position = at
	f._text = text
	f._colour = colour
	parent.add_child(f)
	f._go()

var _text: String = ""
var _colour := Color.WHITE
var _label: Label = null


## What this floater is saying. For a caller that only wants to know,
## not to draw -- tests, mainly.
func current_text() -> String:
	return _text


func _go() -> void:
	_label = Label.new()
	_label.text = _text
	_label.add_theme_font_size_override("font_size", 18)   # doubled Aug 2026
	_label.add_theme_color_override("font_color", _colour)
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08))
	_label.add_theme_constant_override("outline_size", 6)   # doubled Aug 2026
	# centred on the point, not starting from it
	_label.position = Vector2(-40, -16)   # doubled Aug 2026
	_label.size = Vector2(80, 24)   # doubled Aug 2026
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

	var tw := create_tween()
	tw.set_parallel(true)
	# doubled Aug 2026, was -14.0
	tw.tween_property(self, "position:y", position.y - 28.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(queue_free)
