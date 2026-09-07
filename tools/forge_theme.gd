class_name ForgeTheme
extends RefCounted

## One look for the whole Master Forge.
##
## Every forge script used to hand-roll its own colours with
## `add_theme_color_override` at the point of use -- a green title here, a
## grey hint there, buttons left entirely default. The result was a tool
## where "Forge" (rebuilds an asset), "Refresh list" (harmless) and
## "Sync & Reimport" (runs a whole import pass) were three identical
## borderless words in a row, and nothing on screen said which was which.
##
## This builds ONE Theme resource, assigned to the forge's root Control, so
## every child inherits it. A tab that wants a button to stand out calls
## primary() rather than inventing its own colour.
##
## The rule the rest of the tool follows:
##   primary()    one per screen area -- the thing you came here to do
##   secondary()  everything else that is safe to press
##   danger()     destructive or slow; you should read it before clicking

# --- palette -------------------------------------------------------------
const BG         := Color("#141418")   ## window ground
const PANEL      := Color("#1c1c23")   ## a raised working surface
const PANEL_HI   := Color("#252530")   ## hover / the selected tab
const SUNKEN     := Color("#0f0f13")   ## a field you type into
const LINE       := Color("#33333f")   ## borders and rules
const INK        := Color("#e8e8ee")   ## body text
const DIM        := Color("#8d93a0")   ## secondary text
const FAINT      := Color("#5f6572")   ## captions, group names
const ACCENT     := Color("#f0b64d")   ## the primary action, and selection
const ACCENT_INK := Color("#1a1408")   ## text ON accent
const ACCENT_DIM := Color("#3a2f19")   ## an accent-tinted fill
const GOOD       := Color("#84d68f")
const WARN       := Color("#f0c866")
const BAD        := Color("#f08a8a")

const RADIUS := 4


static func flat(bg: Color, border: Color = Color(0, 0, 0, 0),
		width: int = 0, radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


# --- per-widget overrides ------------------------------------------------

## The one action this area exists for. Filled, so it reads as a button
## from across the room rather than as another word in a sentence.
static func primary(b: Button) -> Button:
	_paint(b, flat(ACCENT), flat(ACCENT.lightened(0.12)),
		flat(ACCENT.darkened(0.18)), ACCENT_INK, ACCENT_INK)
	b.add_theme_color_override("font_hover_color", ACCENT_INK)
	b.add_theme_font_size_override("font_size", 14)
	return b


## Safe, reversible, and there are usually several. Outlined.
static func secondary(b: Button) -> Button:
	_paint(b, flat(PANEL, LINE, 1), flat(PANEL_HI, DIM, 1),
		flat(SUNKEN, ACCENT, 1), INK, ACCENT)
	return b


## Slow or destructive. Read before pressing.
static func danger(b: Button) -> Button:
	_paint(b, flat(PANEL, BAD.darkened(0.35), 1), flat(Color("#2a1a1a"), BAD, 1),
		flat(Color("#3a1c1c"), BAD, 1), BAD, BAD)
	b.add_theme_color_override("font_hover_color", BAD)
	return b


## A toggle in a group where exactly one is on -- the editor's tools. The
## pressed state is a filled amber tint, not the default's near-invisible
## shade shift, because "which tool am I holding" was genuinely unreadable.
static func tool_toggle(b: Button) -> Button:
	_paint(b, flat(PANEL, LINE, 1), flat(PANEL_HI, DIM, 1),
		flat(ACCENT_DIM, ACCENT, 2), DIM, ACCENT)
	b.add_theme_color_override("font_hover_color", INK)
	return b


static func _paint(b: Button, normal: StyleBoxFlat, hover: StyleBoxFlat,
		pressed: StyleBoxFlat, ink: Color, ink_pressed: Color) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", pressed)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_pressed_color", ink_pressed)
	b.add_theme_color_override("font_hover_pressed_color", ink_pressed)
	b.add_theme_color_override("font_focus_color", ink)


# --- small building blocks the tabs kept re-inventing --------------------

## A heading that separates one group of controls from the next. The forge
## was one undifferentiated column of widgets before these existed.
static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", FAINT)
	return l


## A numbered step header: a filled amber chip with the number, then the
## step's name at a size you actually read. The tabs are a 1-2-3 and now
## look like one -- the old header was 11px grey caps that the eye slid
## straight past, so nothing said where to start.
static func step(n: int, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)

	var chip := PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := flat(ACCENT, Color(0, 0, 0, 0), 0, 4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", sb)
	var num := Label.new()
	num.text = str(n)
	num.add_theme_font_size_override("font_size", 12)
	num.add_theme_color_override("font_color", ACCENT_INK)
	chip.add_child(num)
	row.add_child(chip)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", INK)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	return row


static func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func gap(w: int = 0, h: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c


## A framed working surface. Grouping related controls inside one of these
## is most of what made the tabs legible.
static func card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat(PANEL, LINE, 1, 6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


# --- the inherited theme -------------------------------------------------

## Built once and assigned to the forge root; every child inherits it.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13

	_theme_button(t, "Button")
	_theme_button(t, "OptionButton")
	_theme_button(t, "MenuButton")

	# Check widgets are switches, not buttons -- a border around them read
	# as "press me" and competed with the real buttons beside them.
	for cls: String in ["CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, flat(Color(0, 0, 0, 0)))
		t.set_stylebox("hover", cls, flat(PANEL_HI))
		t.set_stylebox("pressed", cls, flat(Color(0, 0, 0, 0)))
		t.set_stylebox("focus", cls, flat(Color(0, 0, 0, 0)))
		t.set_color("font_color", cls, DIM)
		t.set_color("font_hover_color", cls, INK)
		t.set_color("font_pressed_color", cls, ACCENT)

	for cls: String in ["LineEdit", "TextEdit", "SpinBox"]:
		var field := flat(SUNKEN, LINE, 1)
		field.content_margin_top = 6
		field.content_margin_bottom = 6
		var focused := flat(SUNKEN, ACCENT, 1)
		focused.content_margin_top = 6
		focused.content_margin_bottom = 6
		t.set_stylebox("normal", cls, field)
		t.set_stylebox("focus", cls, focused)
		t.set_color("font_color", cls, INK)
		t.set_color("font_placeholder_color", cls, FAINT)
		t.set_color("caret_color", cls, ACCENT)

	t.set_stylebox("panel", "PanelContainer", flat(PANEL, LINE, 1, 6))
	t.set_stylebox("panel", "Panel", flat(PANEL, LINE, 1, 6))
	t.set_color("font_color", "Label", INK)

	var rt := flat(SUNKEN, LINE, 1)
	rt.content_margin_left = 10
	rt.content_margin_right = 10
	rt.content_margin_top = 8
	rt.content_margin_bottom = 8
	t.set_stylebox("normal", "RichTextLabel", rt)
	t.set_color("default_color", "RichTextLabel", INK)

	# Tabs: the open one is filled and amber-topped. Before this the only
	# difference between the open tab and the others was a hairline.
	var tab_sel := flat(PANEL_HI, Color(0, 0, 0, 0), 0, 5)
	tab_sel.border_width_top = 2
	tab_sel.border_color = ACCENT
	var tab_un := flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 5)
	var tab_hov := flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 5)
	for sb: StyleBoxFlat in [tab_sel, tab_un, tab_hov]:
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
	for cls: String in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", cls, tab_sel)
		t.set_stylebox("tab_unselected", cls, tab_un)
		t.set_stylebox("tab_hovered", cls, tab_hov)
		t.set_stylebox("tabbar_background", cls,
			flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
		t.set_color("font_selected_color", cls, ACCENT)
		t.set_color("font_unselected_color", cls, DIM)
		t.set_color("font_hovered_color", cls, INK)
		t.set_font_size("font_size", cls, 14)
	var tab_panel := flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	tab_panel.content_margin_left = 0
	tab_panel.content_margin_right = 0
	tab_panel.content_margin_top = 10
	tab_panel.content_margin_bottom = 0
	t.set_stylebox("panel", "TabContainer", tab_panel)

	for cls: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls,
			flat(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 3))
		t.set_stylebox("grabber", cls,
			flat(Color("#3c3c4a"), Color(0, 0, 0, 0), 0, 3))
		t.set_stylebox("grabber_highlight", cls,
			flat(Color("#50505f"), Color(0, 0, 0, 0), 0, 3))
		t.set_stylebox("grabber_pressed", cls,
			flat(ACCENT, Color(0, 0, 0, 0), 0, 3))

	# A StyleBoxFlat here fills the separator's whole rect, which drew the
	# group dividers in the editor toolbar as solid grey slabs between the
	# buttons. A separator is a LINE.
	for cls: String in ["HSeparator", "VSeparator"]:
		var rule := StyleBoxLine.new()
		rule.color = LINE
		rule.thickness = 1
		rule.vertical = (cls == "VSeparator")
		t.set_stylebox("separator", cls, rule)
		t.set_constant("separation", cls, 12)

	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	return t


static func _theme_button(t: Theme, cls: String) -> void:
	t.set_stylebox("normal", cls, flat(PANEL, LINE, 1))
	t.set_stylebox("hover", cls, flat(PANEL_HI, DIM, 1))
	t.set_stylebox("pressed", cls, flat(SUNKEN, ACCENT, 1))
	t.set_stylebox("focus", cls, flat(Color(0, 0, 0, 0), ACCENT, 1))
	t.set_stylebox("disabled", cls, flat(Color("#191920"), Color("#26262e"), 1))
	t.set_color("font_color", cls, INK)
	t.set_color("font_hover_color", cls, Color.WHITE)
	t.set_color("font_pressed_color", cls, ACCENT)
	t.set_color("font_disabled_color", cls, FAINT)
