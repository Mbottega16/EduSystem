extends Control

## The pixel canvas inside the gallery's edit mode.
##
## One job: turn mouse input into a pixel coordinate and hand it back.
## curator.gd owns the Image, the palette and the tool state; this only
## draws it zoomed and forwards clicks. Kept as its own script rather than
## folded into curator.gd because it needs its own `_draw()` and
## `_gui_input()`, and every other tool in this project is one script per
## responsibility.
##
## It lives inside a ScrollContainer (V/Editor/Body/CanvasWrap). Zoom grows
## the Control and the ScrollContainer provides the scrollbars; the wheel
## zooms toward the cursor and the middle mouse button drags to pan.

signal pixel_down(pos: Vector2i)
signal pixel_drag(pos: Vector2i)
signal pixel_up()
## Fired on plain mouse-move (not while painting or panning) so the editor
## can show which pixel the cursor is over. `pos` can be out of bounds.
signal pixel_hover(pos: Vector2i)
signal zoom_changed(z: int)

const MIN_ZOOM := 1
const MAX_ZOOM := 40

var image: Image = null
var zoom := 12
## Nonzero draws character-sheet cell boundaries (32x48 frames on a
## 288x192 sheet, 9x4) so the grid reads as 36 frames rather than one slab.
var cell_w := 0
var cell_h := 0

var _dragging := false
var _panning := false

## An in-progress shape (line / rect / ellipse) the editor asks us to
## outline over the image without committing it. Array[Vector2i].
var preview: Array = []
var preview_colour := Color(1, 1, 1, 0.9)


func set_image(img: Image) -> void:
	image = img
	_resize()
	queue_redraw()


func set_zoom(z: int) -> void:
	zoom = clampi(z, MIN_ZOOM, MAX_ZOOM)
	_resize()
	queue_redraw()


func _resize() -> void:
	if image != null:
		custom_minimum_size = Vector2(image.get_width() * zoom, image.get_height() * zoom)


func set_preview(pts: Array) -> void:
	preview = pts
	queue_redraw()


func clear_preview() -> void:
	if not preview.is_empty():
		preview = []
		queue_redraw()


func _draw() -> void:
	if image == null:
		return
	var w := image.get_width()
	var h := image.get_height()
	# A checkerboard behind transparency, so "erased to nothing" is a
	# visible state rather than indistinguishable from "never painted".
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var r := Rect2(x * zoom, y * zoom, zoom, zoom)
			if c.a < 0.999:
				var checker := (x + y) % 2 == 0
				draw_rect(r, Color(0.30, 0.30, 0.33) if checker else Color(0.22, 0.22, 0.25))
			if c.a > 0.001:
				draw_rect(r, c)
	if zoom >= 6:
		for x in range(w + 1):
			draw_line(Vector2(x * zoom, 0), Vector2(x * zoom, h * zoom),
				Color(0, 0, 0, 0.15))
		for y in range(h + 1):
			draw_line(Vector2(0, y * zoom), Vector2(w * zoom, y * zoom),
				Color(0, 0, 0, 0.15))
	if cell_w > 0 and cell_h > 0:
		for x in range(0, w + 1, cell_w):
			draw_line(Vector2(x * zoom, 0), Vector2(x * zoom, h * zoom),
				Color(1, 0.8, 0.3, 0.8), 2.0)
		for y in range(0, h + 1, cell_h):
			draw_line(Vector2(0, y * zoom), Vector2(w * zoom, y * zoom),
				Color(1, 0.8, 0.3, 0.8), 2.0)
	for pv in preview:
		var q: Vector2i = pv
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
			continue
		var rr := Rect2(q.x * zoom, q.y * zoom, zoom, zoom)
		draw_rect(rr, Color(preview_colour.r, preview_colour.g, preview_colour.b, 0.28))
		draw_rect(rr, preview_colour, false, maxf(1.0, zoom * 0.15))


func _gui_input(e: InputEvent) -> void:
	if image == null:
		return

	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = true
					pixel_down.emit(_to_pixel(mb.position))
				elif _dragging:
					_dragging = false
					pixel_up.emit()
				accept_event()
			MOUSE_BUTTON_MIDDLE:
				# hold to pan
				_panning = mb.pressed
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at(mb.position, 1)
					accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at(mb.position, -1)
					accept_event()

	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _panning:
			var sc := get_parent() as ScrollContainer
			if sc != null:
				sc.scroll_horizontal -= int(mm.relative.x)
				sc.scroll_vertical -= int(mm.relative.y)
			accept_event()
		elif _dragging:
			pixel_drag.emit(_to_pixel(mm.position))
			accept_event()
		else:
			pixel_hover.emit(_to_pixel(mm.position))


## Change zoom by `dir` (+1 / -1) while keeping the pixel currently under
## the cursor at the same place on screen.
func _zoom_at(local_pos: Vector2, dir: int) -> void:
	var nz := clampi(zoom + dir, MIN_ZOOM, MAX_ZOOM)
	if nz == zoom:
		return
	var sc := get_parent() as ScrollContainer
	var scroll := Vector2.ZERO
	if sc != null:
		scroll = Vector2(sc.scroll_horizontal, sc.scroll_vertical)
	var view_pos := local_pos - scroll          # cursor within the visible box
	var pixel := local_pos / float(zoom)        # sprite pixel under the cursor

	zoom = nz
	_resize()
	queue_redraw()
	zoom_changed.emit(zoom)

	if sc != null:
		# The ScrollContainer clamps scroll to the content size, which only
		# grows on the next layout pass -- wait one frame before re-anchoring.
		await get_tree().process_frame
		sc.scroll_horizontal = int(round(pixel.x * zoom - view_pos.x))
		sc.scroll_vertical = int(round(pixel.y * zoom - view_pos.y))


func _to_pixel(local: Vector2) -> Vector2i:
	return Vector2i(int(floor(local.x / float(zoom))), int(floor(local.y / float(zoom))))
