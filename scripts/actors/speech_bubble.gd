class_name SpeechBubble
extends Node2D

## The player's own voice, in a small box above their own head.
##
## Built for the storyline cutscene (the disgruntled teacher's first
## Monday, see hud.gd's INTRO_PAGES) but general enough to reuse anywhere a
## line is worth saying IN THE ROOM rather than behind a full panel.
## hud.gd's principal_says() is a narrator's box fixed in a HUD corner;
## this follows the speaker instead, because it is meant to read as the
## character talking, not as someone commenting on them.

@onready var _label: Label = $Box/Label
@onready var _box: Control = $Box

## The bubble's bottom edge (where the tail meets it) and its padding round
## the words, in the scene's own units -- see speech_bubble.tscn.
const BOTTOM := -10.0
const PAD_Y := 12.0
const MIN_H := 30.0


func _ready() -> void:
	visible = false


## Say it, in a box only as tall as the words need: one line for "Yes,
## yes!", three for a sentence. The box grows UP from the tail, so the tail
## stays pointing at the speaker whatever the length.
func say(text: String) -> void:
	if text == "":
		hide_bubble()
		return
	_label.text = text
	var font := _label.get_theme_font("font")
	var size := _label.get_theme_font_size("font_size")
	var w := _box.size.x - 16.0
	var line_h := font.get_height(size)
	var lines := maxi(1, roundi(font.get_multiline_string_size(text,
		HORIZONTAL_ALIGNMENT_CENTER, w, size).y / line_h))
	var h := maxf(MIN_H, lines * line_h + (lines - 1) * 2.0 + PAD_Y)
	_box.offset_top = BOTTOM - h
	_box.offset_bottom = BOTTOM
	visible = true


## Narrow the box to its words -- for a short line ("Yes, yes!") said over
## a crowd of desks, where the full-width bubble would cover three of them.
func fit_width() -> void:
	var font := _label.get_theme_font("font")
	var size := _label.get_theme_font_size("font_size")
	var w := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	w = minf(_box.size.x, ceilf((w + 24.0) / 2.0) * 2.0)
	_box.offset_left = -w / 2.0
	_box.offset_right = w / 2.0


func hide_bubble() -> void:
	visible = false


## What it is currently saying, or "" while hidden. For a caller that only
## wants to know, not to draw -- tests, mainly.
func current_text() -> String:
	if not visible or _label == null:
		return ""
	return _label.text
