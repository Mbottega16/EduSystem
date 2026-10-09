class_name TrophyCase
extends Node2D

## The trophy case in the hallway (Oct 2026).
##
## One glass case, one place on its floor per trophy in Trophies.TABLE. A
## trophy you have won stands in its place; one you have not leaves its
## shape there, dimmed, so the case is a map of what is still to win and not
## only a record of what was -- the same reason the career list shows its
## unearned rows. Walk up and press E for the names (hud.show_trophies()).
##
## The art is LimeZu's museum vitrine made long enough for six
## (art/trophy_case.png) with the cups drawn inside it and only its glass
## (art/trophy_case_glass.png, the same size) drawn back over them, so the
## trophies are behind the glass rather than stuck on its front. Pure
## decoration and a reading of Game.trophies: it saves nothing and changes
## nothing.
##
## ORIGIN: bottom-centre, like every prop that stands on a floor.

signal looked()

const CASE := preload("res://art/trophy_case.png")
const GLASS := preload("res://art/trophy_case_glass.png")
const LOOK_SCRIPT := preload("res://scripts/interact/trophy_look.gd")
## The case's floor, in px up from the art's bottom edge: where a cup's foot
## stands, at the front of it.
const FLOOR_UP := 26.0
## The glass's frame, in px in from each side: the cups share what is left.
const INSET := 10.0
## A trophy not yet won: its outline in the dark, faint.
const NOT_YET := Color(0.12, 0.1, 0.16, 0.2)

## One Sprite2D per Trophies.TABLE row, in order -- for the tests.
var cups: Array = []
var look: Interactable = null


func _ready() -> void:
	var body := Sprite2D.new()
	body.name = "Case"
	body.texture = CASE
	body.position = Vector2(0, -CASE.get_height() / 2.0)
	add_child(body)
	var all := Trophies.all()
	var pitch := (CASE.get_width() - INSET * 2.0) / float(maxi(1, all.size()))
	for i in all.size():
		var t: Dictionary = all[i]
		var cup := Sprite2D.new()
		cup.name = "Cup_%s" % String(t.get("id", ""))
		cup.texture = load("res://art/%s.png" % String(t.get("art", "trophy_gold")))
		var x := -CASE.get_width() / 2.0 + INSET + pitch * (float(i) + 0.5)
		# On the room's 2px grid, so a cup's pixels line up with the case's.
		x = roundf(x / 2.0) * 2.0
		cup.position = Vector2(x, -FLOOR_UP - cup.texture.get_height() / 2.0)
		add_child(cup)
		cups.append(cup)
	var glass := Sprite2D.new()
	glass.name = "Glass"
	glass.texture = GLASS
	glass.position = body.position
	add_child(glass)
	look = LOOK_SCRIPT.new()
	look.position = Vector2(0, 18)
	look.set_pick_radius(36.0)
	look.used.connect(func(_by: Node) -> void: looked.emit())
	add_child(look)
	refresh()


## Won ones in full colour, the rest as their dimmed shape. Called on every
## visit to the hallway, so a trophy won since the last one is standing there.
func refresh() -> void:
	var all := Trophies.all()
	for i in mini(cups.size(), all.size()):
		var won := Game.trophies.has(String((all[i] as Dictionary).get("id", "")))
		(cups[i] as Sprite2D).modulate = Color.WHITE if won else NOT_YET
