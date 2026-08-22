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


func _ready() -> void:
	visible = false


func say(text: String) -> void:
	if text == "":
		hide_bubble()
		return
	_label.text = text
	visible = true


func hide_bubble() -> void:
	visible = false
