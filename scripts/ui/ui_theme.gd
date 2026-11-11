class_name UITheme
extends RefCounted

## The reader for the design system.
##
## res://theme.tres is the single source of truth: every UI colour, font,
## size, gap, material and motion number lives there. This script names no
## colour and no size of its own. A panel asks here for a token, or wears one
## of the theme's type variations (wear()), and so follows the theme.
##
##   UITheme.color(&"chalk")        a palette colour
##   UITheme.hex(&"olive")          the same, as BBCode hex
##   UITheme.font(&"body")          a voice: display, body, chalk, chalk_bold, note
##   UITheme.size(&"body")          a type size
##   UITheme.space(&"space_m")      a gap, border or motion constant
##   UITheme.box(&"PaperSheet")     a material: TitleBoard, ChalkBoard,
##                                  PaperSheet, PaperCard, WoodPlank
##   UITheme.wear(label, &"ChalkRow")   put a control in a theme variation
##   UITheme.chalk(&"title")        the chalk shader, set for big or small text
##   UITheme.step_in(panel)         the stepped entrance every panel shares

const THEME: Theme = preload("res://theme.tres")
const CHALK_SHADER: Shader = preload("res://shaders/chalk.gdshader")
## The theme type that holds the tokens.
const TOKENS := &"Edu"

## Off in the suite, where a check reads a panel the same tick it opens or
## closes. The motion tests turn it on for themselves.
static var motion: bool = true

static var _chalk: Dictionary = {}


static func color(token: StringName) -> Color:
	return THEME.get_color(token, TOKENS)


## A palette colour as six hex digits, for [color=#...] in a RichTextLabel.
static func hex(token: StringName) -> String:
	return color(token).to_html(false)


## A palette colour at part strength: chalk that was half rubbed out.
static func faded(token: StringName, alpha: float) -> Color:
	var c := color(token)
	return Color(c.r, c.g, c.b, alpha)


static func font(voice: StringName) -> Font:
	return THEME.get_font(voice, TOKENS)


static func size(voice: StringName) -> int:
	return THEME.get_font_size(voice, TOKENS)


static func space(step: StringName) -> int:
	return THEME.get_constant(step, TOKENS)


## The material a panel is made of: one of the theme's panel variations.
static func box(material: StringName) -> StyleBox:
	return THEME.get_stylebox(&"panel", material)


## Put `c` in a theme variation (a voice for a Label, a material for a Panel).
static func wear(c: Control, variation: StringName) -> void:
	c.theme = THEME
	c.theme_type_variation = variation


## A Label in a voice, placed and ready to add. Mouse-transparent, like every
## other word in this game.
static func label(variation: StringName, text: String = "", at: Vector2 = Vector2.ZERO) -> Label:
	var l := Label.new()
	wear(l, variation)
	l.text = text
	l.position = at
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## How wide `text` is in a label variation's font, in px.
static func text_width(text: String, variation: StringName) -> float:
	var f := THEME.get_font(&"font", variation)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		THEME.get_font_size(&"font_size", variation)).x


## The chalk shader as a material. `kind` is "title" for big letters, whose
## strokes are thick enough to break up, or "text" for anything read as a
## line: there the pressure varies but no pixel drops out of a letter.
static func chalk(kind: StringName) -> ShaderMaterial:
	if not _chalk.has(kind):
		var m := ShaderMaterial.new()
		m.shader = CHALK_SHADER
		m.set_shader_parameter("grit", float(space(StringName("chalk_grit_%s" % kind))) / 100.0)
		m.set_shader_parameter("press", float(space(&"chalk_press")) / 100.0)
		_chalk[kind] = m
	return _chalk[kind]


# ------------------------------------------------------------------ motion
#
# One entrance and one exit for every panel. STEPPED: the panel is drawn in
# a few fixed poses a few hundredths of a second apart, the way a sprite is
# animated, instead of gliding on a curve. The numbers are theme constants.

## Slide `node` in from `from` px away while its alpha rises, in steps.
static func step_in(node: CanvasItem, from: Vector2 = Vector2(0, 8)) -> void:
	_settle(node)
	if not motion or not node.is_inside_tree():
		return
	var steps := maxi(2, space(&"motion_steps"))
	var rest: Vector2 = node.get("position")
	node.set_meta(&"ui_rest", rest)
	_pose(node, rest, from, 1.0 / float(steps))
	var tw := node.create_tween()
	node.set_meta(&"ui_tween", tw)
	for i in range(2, steps + 1):
		tw.tween_interval(float(space(&"motion_step_ms")) / 1000.0)
		tw.tween_callback(_pose.bind(node, rest, from, float(i) / float(steps)))


## The entrance run backwards, then `then` (which hides or frees the node).
static func step_out(node: CanvasItem, to: Vector2 = Vector2(0, 8),
		then: Callable = Callable()) -> void:
	_settle(node)
	if not motion or not node.is_inside_tree() or not node.visible:
		if then.is_valid():
			then.call()
		return
	var steps := maxi(2, space(&"motion_steps"))
	var rest: Vector2 = node.get("position")
	node.set_meta(&"ui_rest", rest)
	var tw := node.create_tween()
	node.set_meta(&"ui_tween", tw)
	for i in range(steps - 1, 0, -1):
		tw.tween_callback(_pose.bind(node, rest, to, float(i) / float(steps)))
		tw.tween_interval(float(space(&"motion_step_ms")) / 1000.0)
	tw.tween_callback(func() -> void:
		_settle(node)
		if then.is_valid():
			then.call())


## Stop any entrance or exit on `node` and put it back at rest.
static func _settle(node: CanvasItem) -> void:
	if node.has_meta(&"ui_tween"):
		var tw: Tween = node.get_meta(&"ui_tween")
		if tw != null and tw.is_valid():
			tw.kill()
		node.remove_meta(&"ui_tween")
	if node.has_meta(&"ui_rest"):
		node.set("position", node.get_meta(&"ui_rest"))
		node.remove_meta(&"ui_rest")
	node.modulate.a = 1.0


## One pose of the entrance: `k` of the way in, on the 2px art grid.
static func _pose(node: CanvasItem, rest: Vector2, from: Vector2, k: float) -> void:
	if not is_instance_valid(node):
		return
	node.set("position", rest + (from * (1.0 - k)).snapped(Vector2(2, 2)))
	node.modulate.a = k
