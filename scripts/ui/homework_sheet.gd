class_name HomeworkSheet
extends Control

## The homework sheet, drawn as an actual page instead of a list of words
## describing one.
##
## The data is exactly what Questions.make_sheet() has always produced --
## the "neat" and "working" tells, DELIBERATELY unreliable (see
## questions.gd's own TELL_RELIABILITY comment) -- this only changes how
## it is SHOWN, never what it means. A neat tell draws as legible ink; a
## rushed one draws as a scribble you genuinely cannot read. That is the
## whole point: you are judging handwriting, the same imperfect signal as
## before, not consulting a lookup table that happens to look prettier.
##
## The checkmark or cross is likewise not a reveal of the truth -- it is
## YOUR verdict, stamped on the page the moment you give it (see hud.gd's
## _verdict()), the same way a real teacher's red pen would mark a sheet
## they had just finished reading.

const ROW_H := 76.0
const LINE_GAP := 22.0
const MARGIN_X := 26.0
const INK := Color(0.16, 0.24, 0.46)
const PRINT := Color(0.16, 0.14, 0.12)
const RULE := Color(0.55, 0.68, 0.86, 0.35)
const MARGIN_LINE := Color(0.75, 0.35, 0.35, 0.55)
const PAPER := Color(0.93, 0.90, 0.80, 1.0)
const SCRIBBLE := Color(0.22, 0.2, 0.28, 0.9)
const SCRATCH := Color(0.35, 0.4, 0.55, 0.55)
const GOOD := Color(0.24, 0.72, 0.36, 0.95)
const BAD := Color(0.84, 0.26, 0.26, 0.95)

var _sheet: Dictionary = {}
var _stamp_pass: int = -1     ## -1 none yet, 0 an X, 1 a checkmark

## --- gesture marking -----------------------------------------------------
## Trace the verdict with the mouse instead of pressing a key: one
## continuous stroke reads as a checkmark (pass), two separate strokes read
## as an X (fail) -- the natural way each is actually drawn by hand. Real
## shape recognition (angle/curvature matching) would need visual tuning
## this session cannot do headlessly, so stroke COUNT is the deliberate,
## honest signal instead: nobody draws an X without lifting the pen once.
const _GESTURE_INK := Color(0.75, 0.1, 0.1, 0.9)
## How long to wait, after a stroke ends, for a possible second stroke
## before deciding it was a checkmark. Long enough for a real second
## stroke, short enough that a genuine single check does not feel delayed.
const _GESTURE_WINDOW := 0.45

signal gesture_verdict(pass_it: bool)

var _strokes: Array[PackedVector2Array] = []
var _current_stroke: PackedVector2Array = PackedVector2Array()
var _gesture_wait: float = 0.0


func show_sheet(sheet: Dictionary) -> void:
	_sheet = sheet
	_stamp_pass = -1
	_strokes.clear()
	_current_stroke = PackedVector2Array()
	_gesture_wait = 0.0
	queue_redraw()


## The player's own verdict, stamped once given -- see the class comment.
func stamp(pass_it: bool) -> void:
	_stamp_pass = 1 if pass_it else 0
	_strokes.clear()
	_current_stroke = PackedVector2Array()
	_gesture_wait = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _stamp_pass != -1:
		return   # already marked -- ignore stray input until the next sheet
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_current_stroke = PackedVector2Array([mb.position])
		elif not _current_stroke.is_empty():
			if _current_stroke.size() > 1:   # a real drag, not just a click
				_strokes.append(_current_stroke)
			_current_stroke = PackedVector2Array()
			_gesture_wait = _GESTURE_WINDOW
		queue_redraw()
	elif event is InputEventMouseMotion and not _current_stroke.is_empty():
		_current_stroke.append((event as InputEventMouseMotion).position)
		queue_redraw()


## Ticked by hud.gd's own _process the same way it ticks everything else in
## MARKING mode, rather than this Control owning its own timer node.
func tick_gesture(delta: float) -> void:
	if _gesture_wait <= 0.0 or not _current_stroke.is_empty():
		return
	_gesture_wait -= delta
	if _gesture_wait > 0.0:
		return
	if _strokes.is_empty():
		return
	var pass_it: bool = _strokes.size() == 1   # one stroke = check, two+ = X
	gesture_verdict.emit(pass_it)


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), PAPER)
	draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, s.y), MARGIN_LINE, 1.5)
	var y := 16.0
	while y < s.y:
		draw_line(Vector2(2.0, y), Vector2(s.x - 2.0, y), RULE, 1.0)
		y += LINE_GAP

	var font := ThemeDB.fallback_font
	var items: Array = _sheet.get("items", [])
	for i in items.size():
		var it: Dictionary = items[i]
		var row_y: float = 38.0 + float(i) * ROW_H
		_draw_scratch(it, row_y - 20.0, font)
		var q := "%s = " % String(it.get("q", ""))
		draw_string(font, Vector2(MARGIN_X + 10.0, row_y), q,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PRINT)
		var q_w: float = font.get_string_size(
			q, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var ans_at := Vector2(MARGIN_X + 16.0 + q_w, row_y)
		if bool(it.get("neat", true)):
			draw_string(font, ans_at, String(it.get("shown", "")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
		else:
			_draw_scribble(it, ans_at)

	if _stamp_pass == 1:
		_draw_check(Vector2(s.x - 60.0, 20.0))
	elif _stamp_pass == 0:
		_draw_cross(Vector2(s.x - 58.0, 18.0))
	else:
		# The player's own pen, mid-gesture -- a finished stroke stays on
		# the page as real red ink while the game waits to see if a second
		# one is coming (see tick_gesture()'s _GESTURE_WINDOW).
		for stroke: PackedVector2Array in _strokes:
			if stroke.size() > 1:
				draw_polyline(stroke, _GESTURE_INK, 3.0, true)
		if _current_stroke.size() > 1:
			draw_polyline(_current_stroke, _GESTURE_INK, 3.0, true)


## A small, STABLE seed drawn from the item's own already-decided content --
## not Game.rng, and not randomize()'d off the clock either. The scribble
## is cosmetic, never a gameplay decision: the same sheet has to draw the
## same scribble every time it is redrawn (a resize, a re-render), so it is
## derived from data that is already fixed rather than rolled fresh each
## paint. Nothing here ever decides anything the way Game.rng's rolls do.
func _rng_for(it: Dictionary, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(it.get("q", "")) + String(it.get("shown", "")) + str(salt))
	return rng


## Not text at all -- an actual illegible scrawl, because the whole point
## of a rushed tell is that you cannot read it, not that it is rendered in
## a slightly messier font.
func _draw_scribble(it: Dictionary, at: Vector2) -> void:
	var rng := _rng_for(it, 1)
	var pts: PackedVector2Array = []
	var x := at.x
	for i in 8:
		pts.append(Vector2(x, at.y - 5.0 + rng.randf_range(-6.0, 6.0)))
		x += rng.randf_range(6.0, 10.0)
	draw_polyline(pts, SCRIBBLE, 2.0)


## The "working shown" tell: a few small scratch marks above the line, as
## if worked out before the answer was written down. Absent, not just
## faint, when there was none -- an empty margin is itself the tell.
func _draw_scratch(it: Dictionary, at_y: float, _font: Font) -> void:
	if not bool(it.get("working", false)):
		return
	var rng := _rng_for(it, 2)
	var x := MARGIN_X + 16.0
	for i in 3:
		var pts: PackedVector2Array = []
		for j in 3:
			pts.append(Vector2(x, at_y + rng.randf_range(-4.0, 4.0)))
			x += rng.randf_range(3.0, 6.0)
		draw_polyline(pts, SCRATCH, 1.0)
		x += 3.0


func _draw_check(at: Vector2) -> void:
	draw_polyline(PackedVector2Array([
		at + Vector2(0.0, 10.0), at + Vector2(9.0, 20.0), at + Vector2(28.0, -8.0),
	]), GOOD, 5.0)


func _draw_cross(at: Vector2) -> void:
	draw_line(at, at + Vector2(26.0, 26.0), BAD, 5.0)
	draw_line(at + Vector2(0.0, 26.0), at + Vector2(26.0, 0.0), BAD, 5.0)
