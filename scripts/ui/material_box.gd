@tool
class_name MaterialBox
extends StyleBox

## One classroom material, drawn in code: a chalkboard in its wood frame, a
## sheet of paper, or a piece of wood.
##
## The design system has three materials and theme.tres holds one of these
## for each. A panel never paints its own background; it asks the theme for
## a material and this draws it, at any size, with no texture to stretch.
##
## Everything is drawn on the game's art grid: one art pixel is 2 screen
## pixels (the room's tiles and the UI font are both doubled), so every
## edge, speck and streak here is a whole number of 2px cells.

enum Kind { CHALKBOARD, PAPER, WOOD }

## Which material this is.
@export var kind: Kind = Kind.PAPER
## The surface itself.
@export var fill: Color = Color.WHITE
## What marks the surface: chalk smudges, paper fibres, wood grain.
@export var mark: Color = Color.WHITE
## The frame (chalkboard) or the border (paper, wood).
@export var edge: Color = Color.BLACK
## The frame's dark side, and the line a sheet casts.
@export var edge_shade: Color = Color.BLACK
## The light catching the top edge.
@export var highlight: Color = Color.WHITE
## Border width in px. The design system's border is 2.
@export var border: int = 2
## Extra frame inside the border, in px. A chalkboard's wood frame.
@export var frame: int = 0
## Corner cut in px: 0, 2 or 4.
@export var corner: int = 2
## How many marks the surface carries. 0 is flat colour.
@export_range(0.0, 1.0) var grain: float = 0.5
## A sheet's shadow on whatever is under it, in px down and right. 0 is none.
@export var shadow: int = 0
## The shadow's colour.
@export var shadow_color: Color = Color(0, 0, 0, 0.25)

const CELL := 2


func _draw(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	if shadow > 0:
		_rounded(ci, Rect2(r.position + Vector2(shadow, shadow), r.size), corner, shadow_color)
	# the border, then whatever sits inside it
	_rounded(ci, r, corner, edge_shade if kind == Kind.CHALKBOARD else edge)
	var inner := r.grow(-float(border))
	match kind:
		Kind.CHALKBOARD:
			_draw_frame(ci, inner)
			var board := inner.grow(-float(frame))
			_rect(ci, board, fill)
			_draw_smudges(ci, board)
			_draw_specks(ci, board, mark, 0.10, 14, 1)
			# the frame's lip throws a line of shade along the board's top and left
			var lip := Color(0, 0, 0, 0.22)
			_rect(ci, Rect2(board.position, Vector2(board.size.x, CELL)), lip)
			_rect(ci, Rect2(board.position, Vector2(CELL, board.size.y)), lip)
		Kind.PAPER:
			_rounded(ci, inner, maxi(0, corner - border), fill)
			_draw_specks(ci, inner.grow(-2.0), mark, 0.55, 12, 2)
			# light along the top and left, a pencil-thin shade along the bottom
			_rect(ci, Rect2(inner.position + Vector2(CELL, 0), Vector2(inner.size.x - CELL * 2, CELL)), highlight)
			_rect(ci, Rect2(inner.position + Vector2(0, CELL), Vector2(CELL, inner.size.y - CELL * 2)), highlight)
		Kind.WOOD:
			_rounded(ci, inner, maxi(0, corner - border), fill)
			_draw_wood_grain(ci, inner.grow(-2.0))
			_rect(ci, Rect2(inner.position + Vector2(CELL, 0), Vector2(inner.size.x - CELL * 2, CELL)), highlight)
			_rect(ci, Rect2(Vector2(inner.position.x + CELL, inner.end.y - CELL), Vector2(inner.size.x - CELL * 2, CELL)), edge_shade)


## The chalkboard's wood frame: `frame` px of wood inside the dark border,
## lit along the top, with a streak of grain here and there.
func _draw_frame(ci: RID, inner: Rect2) -> void:
	if frame <= 0:
		return
	_rect(ci, inner, edge)
	_rect(ci, Rect2(inner.position, Vector2(inner.size.x, CELL)), highlight)
	var f := float(frame)
	# grain along the four rails, kept clear of the corners
	var salt := 7
	for x in range(int(inner.position.x) + 12, int(inner.end.x) - 24, 16):
		for y: float in [inner.position.y + CELL, inner.end.y - f + CELL]:
			if f < 6.0:
				continue
			var h := _hash(x, int(y), salt)
			if h % 3 == 0:
				_rect(ci, Rect2(float(x + (h >> 3) % 8), y + float((h >> 7) % maxi(1, int(f) - 4) / CELL * CELL),
					float(6 + (h >> 5) % 5 * CELL), CELL), edge_shade)


## Eraser smudges: a few soft patches where the board was wiped.
func _draw_smudges(ci: RID, board: Rect2) -> void:
	if grain <= 0.0:
		return
	var tint := Color(mark.r, mark.g, mark.b, 0.045)
	var cw := 96
	var chh := 48
	for cy in range(0, int(board.size.y), chh):
		for cx in range(0, int(board.size.x), cw):
			var h := _hash(cx / cw, cy / chh, 3)
			if float(h % 100) / 100.0 > grain * 0.9:
				continue
			var ox := float(cx + (h >> 4) % (cw / 2))
			var oy := float(cy + (h >> 9) % (chh / 2))
			var rows := 2 + (h >> 13) % 4
			for i in rows:
				var hh := _hash(cx + i, cy, 11)
				var w := float(24 + (hh % 5) * 12)
				var dx := float((hh >> 6) % 16) - 8.0
				var seg := Rect2(board.position + Vector2(ox + dx, oy + float(i * CELL * 2)), Vector2(w, CELL * 2))
				seg = seg.intersection(board.grow(-float(CELL)))
				if seg.size.x > 0.0 and seg.size.y > 0.0:
					_rect(ci, seg, tint)


## Single specks, scattered: chalk dust on a board, fibres in paper.
func _draw_specks(ci: RID, area: Rect2, col: Color, alpha: float, cell_px: int, salt: int) -> void:
	if grain <= 0.0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var c := Color(col.r, col.g, col.b, col.a * alpha)
	for cy in range(0, int(area.size.y), cell_px):
		for cx in range(0, int(area.size.x), cell_px):
			var h := _hash(cx / cell_px, cy / cell_px, salt)
			if float(h % 1000) / 1000.0 > grain * 0.22:
				continue
			var px := float(cx + ((h >> 5) % (cell_px / CELL)) * CELL)
			var py := float(cy + ((h >> 11) % (cell_px / CELL)) * CELL)
			if px + CELL > area.size.x or py + CELL > area.size.y:
				continue
			_rect(ci, Rect2(area.position + Vector2(px, py), Vector2(CELL, CELL)), c)


## Short streaks of grain running with the plank.
func _draw_wood_grain(ci: RID, area: Rect2) -> void:
	if grain <= 0.0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	var c := Color(mark.r, mark.g, mark.b, mark.a * 0.5)
	for cy in range(0, int(area.size.y), 6):
		for cx in range(0, int(area.size.x), 24):
			var h := _hash(cx / 24, cy / 6, 5)
			if float(h % 100) / 100.0 > grain * 0.5:
				continue
			var w := float(8 + (h >> 4) % 6 * CELL)
			var px := float(cx + (h >> 9) % 12)
			var seg := Rect2(area.position + Vector2(px, float(cy / CELL * CELL)), Vector2(w, CELL))
			seg = seg.intersection(area)
			if seg.size.x > 0.0:
				_rect(ci, seg, c)


## A rectangle with its corners cut in 2px steps: 0 square, 2 nicked, 4 stepped.
func _rounded(ci: RID, r: Rect2, cut: int, col: Color) -> void:
	if cut <= 0:
		_rect(ci, r, col)
		return
	var c := float(cut)
	_rect(ci, Rect2(r.position.x + c, r.position.y, r.size.x - c * 2.0, r.size.y), col)
	_rect(ci, Rect2(r.position.x, r.position.y + c, c, r.size.y - c * 2.0), col)
	_rect(ci, Rect2(r.end.x - c, r.position.y + c, c, r.size.y - c * 2.0), col)
	if cut >= 4:
		var s := float(CELL)
		for corner_pos: Vector2 in [r.position + Vector2(s, s), Vector2(r.end.x - c, r.position.y + s),
				Vector2(r.position.x + s, r.end.y - c), Vector2(r.end.x - c, r.end.y - c)]:
			_rect(ci, Rect2(corner_pos, Vector2(c - s, c - s)), col)


func _rect(ci: RID, r: Rect2, col: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	RenderingServer.canvas_item_add_rect(ci, r, col)


## A stable scatter: the same panel draws the same marks every time.
static func _hash(x: int, y: int, salt: int) -> int:
	var h := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(0.0, 0.0, float(shadow), float(shadow))
