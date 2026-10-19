class_name Tutorial
extends Control

## Plays one tutorial (data/tutorials.json, read through TutorialData) as a
## short cutscene over the live room.
##
## The room stays visible and the player is locked (the HUD's Mode.TUTORIAL
## does that). One step is one cream paper panel: the speaker's face, a line or
## two in ink, and, when the step has a "show", a pulsing ring and an arrow on
## that thing in the room. E goes to the next step; Esc skips the rest.
##
## The panel sits at the top of the screen when the pointed-at thing is low in
## the room and at the bottom when it is high, so it never covers it.
##
## This node only DRAWS and keeps its place in the script. Whether to play,
## the seen set, the queue and the input all belong to hud.gd.

signal finished(id: String, skipped: bool)

const PANEL_W := 520.0
const PAD := 20.0
const FACE := 72.0
const TEXT_W := PANEL_W - PAD * 2.0 - FACE - 14.0
const SPEECH_FONT := preload("res://fonts/Galmuri9.ttf")
const UI_SIZE := 20
const INK := Color(0.13, 0.12, 0.17)
const RING := Color(1.0, 0.78, 0.18)
const RING_DARK := Color(0.22, 0.12, 0.04)
## Fewest and most text lines a step may take. The data check holds the writing
## to the top figure; the panel is sized to what a step needs.
const MAX_LINES := 5

const FACES := {
	"principal": "res://art/portrait_principal.png",
	"mentor": "res://art/portrait_mentor.png",
	"teacher": "res://art/portrait_player.png",
}
const NAMES := {"principal": "The principal", "mentor": "The mentor", "teacher": "You"}

var host: Control = null
var tutorial: Dictionary = {}
var step: int = 0
var playing: bool = false
## Set by the HUD: true when this is a replay from the pause menu.
var replay: bool = false

var _panel: NinePatchRect = null
var _face: TextureRect = null
var _title: Label = null
var _text: Label = null
var _hint: Label = null
var _target: Variant = null        ## world position of the pointer, or null
var _clock: float = 0.0


func setup(hud: Control) -> void:
	host = hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_panel = hud._nine_patch(hud.UI_FRAME, Rect2(0, 0, PANEL_W, 120), true)
	for side: String in ["left", "top", "right", "bottom"]:
		_panel.set("patch_margin_" + side, 16)
	add_child(_panel)
	_face = TextureRect.new()
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_face)
	_title = _label(Color(0.36, 0.24, 0.1))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text = _label(INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(Color(0.34, 0.3, 0.26))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(colour: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", SPEECH_FONT)
	l.add_theme_font_size_override("font_size", UI_SIZE)
	l.add_theme_constant_override("line_spacing", 0)
	l.add_theme_color_override("font_color", colour)
	_panel.add_child(l)
	return l


func start(t: Dictionary, is_replay: bool = false) -> void:
	tutorial = t
	replay = is_replay
	step = 0
	playing = true
	visible = true
	_show_step()


func step_count() -> int:
	return (tutorial.get("steps", []) as Array).size()


## E: the next step, or the end after the last one.
func advance() -> void:
	if not playing:
		return
	if step < step_count() - 1:
		step += 1
		_show_step()
	else:
		_end(false)


## Put the cutscene away without saying it finished (another screen took over).
func stop() -> void:
	playing = false
	visible = false
	_target = null


## Esc: leave the rest. Counts as seen.
func skip() -> void:
	if playing:
		_end(true)


func _end(skipped: bool) -> void:
	playing = false
	visible = false
	_target = null
	finished.emit(String(tutorial.get("id", "")), skipped)


## The text of the step on show.
func current_text() -> String:
	return _text.text


func current_step() -> Dictionary:
	var steps: Array = tutorial.get("steps", [])
	if step < 0 or step >= steps.size():
		return {}
	return steps[step]


func _show_step() -> void:
	var st := current_step()
	var speaker := String(st.get("speaker", "principal"))
	_face.texture = load(String(FACES.get(speaker, FACES["principal"])))
	_title.text = "%s  %d/%d" % [String(tutorial.get("title", "")).to_upper(),
		step + 1, step_count()]
	_text.text = String(st.get("text", ""))
	_hint.text = "E - next    Esc - skip" if step < step_count() - 1 \
		else "E - done    Esc - skip"
	_target = _point_for(String(st.get("show", "")))
	var lh := ceilf(SPEECH_FONT.get_height(UI_SIZE))
	var lines := clampi(lines_for(_text.text), 2, MAX_LINES)
	var h := 40.0 + float(lines) * lh + 38.0
	var x := roundf((640.0 - PANEL_W) * 0.5)
	# Out of the pointer's way: top of the screen when it is low in the room.
	var y := 352.0 - h - 14.0
	if _target != null and (_target as Vector2).y > 190.0:
		y = 26.0
	_panel.position = Vector2(x, y)
	_panel.size = Vector2(PANEL_W, h)
	_face.position = Vector2(PAD, 44.0)
	_face.size = Vector2(FACE, FACE)
	_title.position = Vector2(0, 10)
	_title.size = Vector2(PANEL_W, 26)
	_text.position = Vector2(PAD + FACE + 14.0, 40.0)
	_text.size = Vector2(TEXT_W, float(lines) * lh + 4.0)
	_hint.position = Vector2(0, h - 34.0)
	_hint.size = Vector2(PANEL_W, 24)
	_play_demo(String(st.get("demo", "")), String(st.get("show", "")))
	queue_redraw()


## How many lines `text` wraps to in the panel's text column.
static func lines_for(text: String) -> int:
	if text.is_empty():
		return 1
	var h := SPEECH_FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		TEXT_W, UI_SIZE).y
	return maxi(1, roundi(h / SPEECH_FONT.get_height(UI_SIZE)))


# ------------------------------------------------------------------ pointer

func _room() -> Node:
	if host == null or not host.is_inside_tree():
		return null
	var r := host.get_tree().get_first_node_in_group("classroom")
	if r == null or not (r as CanvasItem).is_visible_in_tree():
		return null
	return r


## The thing a "show" names, as a node in the room (or null).
func target_node(key: String) -> Node2D:
	var room := _room()
	if room == null or key.is_empty() or key.begins_with("desk:") or key.begins_with("tile:"):
		return null
	var n: Variant = room.get(key)
	if n is Node2D and is_instance_valid(n):
		return n as Node2D
	return null


## Screen position of a "show", or null when it cannot be found right now.
func _point_for(key: String) -> Variant:
	var room := _room()
	if room == null or key.is_empty():
		return null
	var world := Vector2.ZERO
	if key.begins_with("desk:"):
		var seat := int(key.substr(5))
		if seat < 0 or seat >= Layout.seat_count():
			return null
		world = (room as Node2D).to_global(Grid.tile_to_world(Layout.seat(seat)))
	elif key.begins_with("tile:"):
		var xy := key.substr(5).split(",")
		if xy.size() != 2:
			return null
		world = (room as Node2D).to_global(
			Grid.tile_to_world(Vector2i(int(xy[0]), int(xy[1]))))
	else:
		var n := target_node(key)
		if n == null:
			return null
		world = n.global_position
	return host.get_viewport().get_canvas_transform() * world


func _play_demo(demo: String, key: String) -> void:
	if demo.is_empty():
		return
	var n := target_node(key)
	if n == null:
		return
	var vis: Node2D = n
	var par := n.get_parent()
	if par is Node2D and par != _room():
		vis = par as Node2D
	match demo:
		"land":
			Fx.land(vis)
		"flash":
			Fx.flash(vis)
		"puff":
			Fx.puff(_room() as Node2D, (_room() as Node2D).to_local(n.global_position),
				Color(0.95, 0.9, 0.7, 0.8), 6)


func _process(delta: float) -> void:
	if not playing:
		return
	_clock += delta
	# the camera may be moving: follow the thing
	var st := current_step()
	if st.has("show"):
		_target = _point_for(String(st["show"]))
	queue_redraw()


func _draw() -> void:
	if not playing or _target == null:
		return
	var c: Vector2 = _target
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	var r := 18.0 + 4.0 * pulse
	# a dark keyline under a gold ring reads on any floor
	draw_arc(c, r, 0.0, TAU, 32, RING_DARK, 5.0)
	draw_arc(c, r, 0.0, TAU, 32, RING, 3.0)
	# an arrow above it, bobbing, pointing down at the ring
	var by := -r - 8.0 - 3.0 * pulse
	var tip := c + Vector2(0, by)
	var pts := PackedVector2Array([tip, tip + Vector2(-8, -12), tip + Vector2(8, -12)])
	draw_colored_polygon(pts, RING)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), RING_DARK, 2.0)
