extends Node2D

## The supply cupboard's tray, on top of the cabinet: one of each treat in a row,
## and a gap where the one in your hands came from. Drawn in code with the same pixel
## icons the teacher carries (treat_icon.gd). Pure decoration -- nothing reads
## it back.

const TREAT_ICON := preload("res://scripts/world/treat_icon.gd")
const GAP := 3

var _shown: String = "?"


func _process(_delta: float) -> void:
	if _shown != Game.carried:
		_shown = Game.carried
		queue_redraw()


func _draw() -> void:
	var ids := Game.stash_ids()
	var step := float((8 + GAP) * TREAT_ICON.PX)
	var left := -step * float(ids.size() - 1) / 2.0 - 4.0 * float(TREAT_ICON.PX)
	for i in ids.size():
		if String(ids[i]) == Game.carried:
			continue
		TREAT_ICON.draw_treat(self, String(ids[i]), Vector2(left + step * float(i), -4.0 * float(TREAT_ICON.PX)))
