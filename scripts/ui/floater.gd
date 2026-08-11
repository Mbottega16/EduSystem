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


func _go() -> void:
	_label = Label.new()
	_label.text = _text
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", _colour)
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08))
	_label.add_theme_constant_override("outline_size", 3)
	# centred on the point, not starting from it
	_label.position = Vector2(-20, -8)
	_label.size = Vector2(40, 12)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 14.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(queue_free)
