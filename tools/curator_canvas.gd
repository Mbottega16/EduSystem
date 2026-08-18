extends Control

## The pixel canvas inside the gallery's edit mode.
##
## One job: turn mouse input into a pixel coordinate and hand it back.
## curator.gd owns the Image, the palette and the tool state; this only
## draws it zoomed and forwards clicks. Kept as its own script rather than
## folded into curator.gd because it needs its own `_draw()` and
## `_gui_input()`, and every other tool in this project is one script per
## responsibility.

signal pixel_down(pos: Vector2i)
signal pixel_drag(pos: Vector2i)
signal pixel_up()

var image: Image = null
var zoom := 12
## Nonzero draws character-sheet cell boundaries (16x24 frames on an
## 80x96 sheet) so the grid reads as 20 frames rather than one slab.
var cell_w := 0
var cell_h := 0

var _dragging := false


func set_image(img: Image) -> void:
	image = img
	custom_minimum_size = Vector2(image.get_width() * zoom, image.get_height() * zoom)
	queue_redraw()


func set_zoom(z: int) -> void:
	zoom = z
	if image != null:
		custom_minimum_size = Vector2(image.get_width() * zoom, image.get_height() * zoom)
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


func _gui_input(e: InputEvent) -> void:
	if image == null:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				pixel_down.emit(_to_pixel(mb.position))
			elif _dragging:
				_dragging = false
				pixel_up.emit()
			accept_event()
	elif e is InputEventMouseMotion and _dragging:
		pixel_drag.emit(_to_pixel((e as InputEventMouseMotion).position))
		accept_event()


func _to_pixel(local: Vector2) -> Vector2i:
	return Vector2i(int(floor(local.x / float(zoom))), int(floor(local.y / float(zoom))))
