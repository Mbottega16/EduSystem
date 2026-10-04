extends Node

## Prints every problem in data/room_templates.json -- the quick author's check
## (the suite runs the same thing).
##
##   godot --headless --path . res://tools/check_templates.tscn
##
## A scene, not --script: autoloads (Game) do not exist under a custom MainLoop.

func _ready() -> void:
	var bad := 0
	for t: Dictionary in RoomTemplates.all():
		var p := RoomTemplates.problems(t)
		print("%-18s %2d pieces  %4d coins  %s" % [t["id"], (t["items"] as Array).size(),
			RoomTemplates.cost(t), "OK" if p.is_empty() else "%d PROBLEMS" % p.size()])
		for line in p:
			print("      - " + line)
			bad += 1
	get_tree().quit(1 if bad > 0 else 0)
