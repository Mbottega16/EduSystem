extends Node2D

## A treat from the treat shelf, drawn in code: three small pixel icons on
## the room's own grid (two screen pixels to a pixel of art), built in the
## room's keyline colour. Placeholder art until a pack sprite is chosen -- it is
## shown over the teacher's hand while a treat is carried. (The shelf itself
## is LimeZu's jars, art/treat_shelf.png; the tray that drew these round the
## locker is gone.)

const KEYLINE := Color(0.227, 0.227, 0.314)
## Screen pixels per pixel of art -- the room is authored at 16px a tile and
## doubled.
const PX := 2

## Each icon: rows of characters, one per pixel ("." is empty), and the colour
## each character stands for.
const ICONS := {
	"mint": {
		"rows": [
			"..wwww..",
			".wwrrww.",
			"wwrwwrww",
			"wrwwwwrw",
			"wrwwwwrw",
			"wwrwwrww",
			".wwrrww.",
			"..wwww..",
		],
		"pal": {"w": Color(0.96, 0.95, 0.91), "r": Color(0.85, 0.33, 0.31)},
	},
	"fidget_cube": {
		"rows": [
			"bbbbbbbb",
			"bLLLLLLb",
			"bLdLLLLb",
			"bLLLLLLb",
			"bLLLdLLb",
			"bLLLLLLb",
			"bLLLLLdb",
			"bbbbbbbb",
		],
		"pal": {"b": Color(0.25, 0.45, 0.78), "L": Color(0.56, 0.74, 0.95),
			"d": Color(0.18, 0.28, 0.5)},
	},
	"brain_snack": {
		"rows": [
			"..pppp..",
			".pPPPPp.",
			"pPPdPPPp",
			"pPdPPdPp",
			"pPPdPPPp",
			"pPdPPdPp",
			".pPPPPp.",
			"..pppp..",
		],
		"pal": {"p": Color(0.86, 0.52, 0.62), "P": Color(0.97, 0.76, 0.8),
			"d": Color(0.78, 0.38, 0.5)},
	},
}

var treat: String = ""


func set_treat(id: String) -> void:
	treat = id
	visible = id != ""
	queue_redraw()


func _draw() -> void:
	draw_treat(self, treat, Vector2(-4 * PX, -4 * PX))


## Paint treat `id` on `canvas` with its top-left corner at `origin`: the
## keyline one pixel round it first, then the colours.
static func draw_treat(canvas: CanvasItem, id: String, origin: Vector2) -> void:
	var icon: Dictionary = ICONS.get(id, {})
	if icon.is_empty():
		return
	var rows: Array = icon["rows"]
	var pal: Dictionary = icon["pal"]
	var cell := Vector2(PX, PX)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] == ".":
				continue
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				canvas.draw_rect(Rect2(origin + Vector2(x + d.x, y + d.y) * float(PX), cell), KEYLINE)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var key := row[x]
			if key == ".":
				continue
			canvas.draw_rect(Rect2(origin + Vector2(x, y) * float(PX), cell), pal[key])
