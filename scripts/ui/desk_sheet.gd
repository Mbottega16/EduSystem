extends Control

## A sheet of paper, laid on wood (UI overhaul, Nov 2026, phases 6 and 7).
##
## Two screens are a sheet rather than a window:
##
##   DESK       the end-of-day report, on the teacher's desk. The wood fills
##              the screen and the day reads as a sheet lying on it.
##   CLIPBOARD  the observation sheet, on a clipboard held up in the room it
##              is about. The room shows round it.
##
## This node draws everything that is NOT the screen's own lines: the wood,
## the paper, the clip, the heading, the stamp, the comparison cards, the
## ledger and the key caps. The lines themselves stay in the HUD's rich label,
## which hud.gd places in text_rect(), so what a test measures is what a
## player reads.
##
## Every colour, font and size is a token from theme.tres, read through
## UITheme. The numbers below are layout only, on the 2px art grid.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MaterialBox := preload("res://scripts/ui/material_box.gd")

enum Kind { DESK, CLIPBOARD }

const SCREEN := Vector2(640, 352)
## Paper edge to the first line of the screen's own text, and the last line
## to the paper's bottom edge. The clipboard keeps its key caps on the paper,
## so its foot is deeper; the desk's key caps sit on the wood.
const HEAD := {Kind.DESK: 56.0, Kind.CLIPBOARD: 64.0}
const FOOT := {Kind.DESK: 12.0, Kind.CLIPBOARD: 36.0}
## How far the clipboard's board shows round its paper.
const BOARD_SIDE := 8.0
const BOARD_TOP := 12.0
const CLIP_SIZE := Vector2(88, 26)
## The desk report's right-hand column (the ledger), and the gap before it.
const SIDE_W := 150.0
const SIDE_GAP := 10.0
const SIDE_LINES := 4
const KEY_H := 24.0
const CARD_SIZE := Vector2(104, 40)
## A stamp is never quite square to the page: it climbs one art pixel (2px)
## for every STAMP_RUN px it runs.
const STAMP_RUN := 32.0
const PENCIL_SIZE := Vector2(76, 6)

var kind: int = Kind.DESK
var wood: Panel = null
var paper: Panel = null
var trim: Control = null
var pencil: Control = null
var clip: Control = null
var tag: ColorRect = null
var tag_label: Label = null
var heading: Label = null
var sub: Label = null
var rule: ColorRect = null
var stamp: Control = null
var side: RichTextLabel = null
var side_rule: ColorRect = null
var cards: Control = null
var keys: Control = null

var _stamp_text: String = ""
var _stamp_token: StringName = &"olive"
var _pad: float = 16.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN
	_pad = float(UITheme.space(&"space_l"))
	wood = _panel(&"WoodPlank")
	pencil = _plain()
	pencil.size = PENCIL_SIZE
	pencil.draw.connect(_draw_pencil)
	paper = _panel(&"PaperSheet")
	trim = _plain()
	trim.draw.connect(_draw_trim)
	clip = _plain()
	clip.size = CLIP_SIZE
	clip.draw.connect(_draw_clip)
	rule = _fill(&"sand")
	side_rule = _fill(&"sand")
	tag = _fill(&"terracotta")
	tag_label = UITheme.label(&"DisplaySmall")
	tag_label.add_theme_color_override("font_color", UITheme.color(&"paper_bright"))
	tag.add_child(tag_label)
	heading = UITheme.label(&"DisplayLabel")
	add_child(heading)
	sub = UITheme.label(&"DisplaySmall")
	add_child(sub)
	side = RichTextLabel.new()
	side.bbcode_enabled = true
	side.scroll_active = false
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_font_override("normal_font", UITheme.font(&"body"))
	side.add_theme_font_size_override("normal_font_size", UITheme.size(&"body"))
	side.add_theme_color_override("default_color", UITheme.color(&"ink"))
	side.add_theme_constant_override("line_separation", 0)
	add_child(side)
	cards = _plain()
	keys = _plain()
	# last, so it prints over the rule it leans on
	stamp = _plain()
	stamp.draw.connect(_draw_stamp)
	visible = false


func _plain() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _panel(material: StringName) -> Panel:
	var p := Panel.new()
	UITheme.wear(p, material)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _fill(token: StringName) -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.color(token)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## How tall the paper has to be to hold `text_h` px of the screen's own lines.
static func paper_height(sheet_kind: int, text_h: float) -> float:
	return float(HEAD[sheet_kind]) + text_h + float(FOOT[sheet_kind])


## Lay the sheet down: `paper_rect` is the paper, in screen px.
func lay(sheet_kind: int, paper_rect: Rect2) -> void:
	kind = sheet_kind
	paper.position = paper_rect.position
	paper.size = paper_rect.size
	trim.position = paper_rect.position
	trim.size = paper_rect.size
	trim.queue_redraw()
	if kind == Kind.DESK:
		# past the screen's edge on every side, so the plank's own border is
		# never seen: the desk has no end
		wood.position = Vector2(-4, -4)
		wood.size = SCREEN + Vector2(8, 8)
		clip.visible = false
		# on the wood under the paper's left-hand corner, across from the keys
		pencil.position = Vector2(paper_rect.position.x + 12.0,
			paper_rect.position.y + paper_rect.size.y + 16.0)
		pencil.visible = true
	else:
		pencil.visible = false
		wood.position = paper_rect.position - Vector2(BOARD_SIDE, BOARD_TOP)
		wood.size = paper_rect.size + Vector2(BOARD_SIDE * 2.0, BOARD_TOP + BOARD_SIDE)
		clip.position = Vector2(roundf(paper_rect.get_center().x - CLIP_SIZE.x * 0.5),
			wood.position.y - 6.0)
		clip.visible = true
	rule.position = paper_rect.position + Vector2(_pad, float(HEAD[kind]) - 10.0)
	rule.size = Vector2(paper_rect.size.x - _pad * 2.0, 2.0)
	var text := text_rect()
	side.visible = false
	side_rule.visible = false
	side.position = Vector2(text.end.x - SIDE_W, text.position.y)
	side.size = Vector2(SIDE_W, float(SIDE_LINES) * float(UITheme.size(&"body")))
	side_rule.position = Vector2(side.position.x - SIDE_GAP, text.position.y + 2.0)
	side_rule.size = Vector2(2.0, side.size.y - 4.0)
	set_heading("")
	set_stamp("")
	set_cards([])
	set_keys([])
	visible = true


func put_away() -> void:
	visible = false


func is_clipboard() -> bool:
	return visible and kind == Kind.CLIPBOARD


## Where the screen's own lines go, in screen px.
func text_rect() -> Rect2:
	var top := float(HEAD[kind])
	return Rect2(paper.position.x + _pad, paper.position.y + top,
		paper.size.x - _pad * 2.0, paper.size.y - top - float(FOOT[kind]))


## The sheet's heading, in the display voice. `sub_text` is small print beside
## it (desk) or under it (clipboard). `tag_text` is a filled chip before the
## heading, in `tag_token`: the sheet's kind at a glance.
func set_heading(text: String, sub_text: String = "", tag_text: String = "",
		tag_token: StringName = &"terracotta") -> void:
	var at := paper.position + Vector2(_pad, _pad)
	tag.visible = tag_text != ""
	var x := at.x
	if tag.visible:
		tag_label.text = tag_text
		tag.color = UITheme.color(tag_token)
		tag.position = at
		tag.size = Vector2(UITheme.text_width(tag_text, &"DisplaySmall") + 12.0,
			float(UITheme.size(&"display")))
		tag_label.position = Vector2(6.0, 4.0)
		x = tag.position.x + tag.size.x + float(UITheme.space(&"space_s"))
	heading.text = text
	heading.position = Vector2(x, at.y)
	sub.text = sub_text
	if kind == Kind.DESK:
		# beside the heading, sitting on the same line as its feet
		sub.position = Vector2(x + UITheme.text_width(text, &"DisplayLabel")
			+ float(UITheme.space(&"space_m")), at.y + 8.0)
	else:
		sub.position = Vector2(at.x, at.y + float(UITheme.size(&"display")) + 6.0)


## The grade, stamped at the top right of the paper in a palette colour.
## "" takes the stamp off.
func set_stamp(text: String, token: StringName = &"olive") -> void:
	_stamp_text = text
	_stamp_token = token
	stamp.visible = text != ""
	if stamp.visible:
		var w := UITheme.text_width(text, &"DisplayLabel") + float(UITheme.space(&"space_m")) * 2.0
		stamp.size = Vector2(w, float(UITheme.size(&"display")) + 14.0 + _stamp_rise(w))
		stamp.position = Vector2(paper.position.x + paper.size.x - _pad - 4.0 - w,
			paper.position.y + 6.0)
		UITheme.step_in(stamp, Vector2(0.0, -4.0))
	stamp.queue_redraw()


func stamp_text() -> String:
	return _stamp_text if stamp.visible else ""


## The desk report's ledger: a few short lines of BBCode down the right.
func set_side(bbcode: String) -> void:
	side.text = bbcode
	side.visible = bbcode != ""
	side_rule.visible = side.visible


## Comparison cards along the top right of the paper, side by side:
## [[label, value, token], ...]. The token colours the card's edge and value.
func set_cards(rows: Array) -> void:
	for c in cards.get_children():
		cards.remove_child(c)
		c.queue_free()
	var gap := float(UITheme.space(&"space_s"))
	var x := paper.position.x + paper.size.x - _pad \
		- float(rows.size()) * CARD_SIZE.x - float(maxi(0, rows.size() - 1)) * gap
	for row: Array in rows:
		var token := StringName(row[2])
		var card := Panel.new()
		var box: MaterialBox = (UITheme.box(&"PaperCard") as MaterialBox).duplicate()
		box.edge = UITheme.color(token)
		card.add_theme_stylebox_override("panel", box)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(x, paper.position.y + 10.0)
		card.size = CARD_SIZE
		var label := UITheme.label(&"DisplaySmall", String(row[0]))
		label.position = Vector2(roundf((CARD_SIZE.x - UITheme.text_width(String(row[0]),
			&"DisplaySmall")) * 0.5), 6.0)
		card.add_child(label)
		var value := UITheme.label(&"DisplayLabel", String(row[1]))
		value.name = "Value"
		value.add_theme_color_override("font_color", UITheme.color(token))
		card.add_child(value)
		cards.add_child(card)
		_place_card_value(card)
		x += CARD_SIZE.x + gap


## Change what card `i` says without rebuilding the row.
func set_card_value(i: int, text: String) -> void:
	if i < 0 or i >= cards.get_child_count():
		return
	var card := cards.get_child(i)
	(card.get_node("Value") as Label).text = text
	_place_card_value(card)


## Every card as "label value", for a test or a tool to read.
func cards_text() -> String:
	var out: Array[String] = []
	for card in cards.get_children():
		out.append("%s %s" % [(card.get_child(0) as Label).text,
			(card.get_node("Value") as Label).text])
	return ", ".join(out)


func _place_card_value(card: Node) -> void:
	var value := card.get_node("Value") as Label
	value.position = Vector2(roundf((CARD_SIZE.x - UITheme.text_width(value.text,
		&"DisplayLabel")) * 0.5), 18.0)


## The keys on offer, as key caps with their verbs: [[key, verb], ...].
## The first is the way forward and gets the amber-edged cap.
func set_keys(rows: Array) -> void:
	for c in keys.get_children():
		keys.remove_child(c)
		c.queue_free()
	var x := 0.0
	for i in rows.size():
		var row: Array = rows[i]
		var cap := Panel.new()
		UITheme.wear(cap, &"PaperCard" if i == 0 else &"WoodPlank")
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kw := UITheme.text_width(String(row[0]), &"DisplayLabel")
		cap.position = Vector2(x, 0.0)
		cap.size = Vector2(kw + 12.0, KEY_H)
		cap.add_child(UITheme.label(&"DisplayLabel", String(row[0]), Vector2(6.0, 4.0)))
		keys.add_child(cap)
		x += cap.size.x + 6.0
		var verb := UITheme.label(&"BodyLabel", String(row[1]), Vector2(x, -1.0))
		keys.add_child(verb)
		x += UITheme.text_width(String(row[1]), &"BodyLabel") + float(UITheme.space(&"space_l"))
	x = maxf(0.0, x - float(UITheme.space(&"space_l")))
	keys.size = Vector2(x, KEY_H)
	if kind == Kind.DESK:
		# on the wood, under the paper's right-hand corner
		keys.position = Vector2(paper.position.x + paper.size.x - x - 4.0,
			paper.position.y + paper.size.y + 8.0)
	else:
		keys.position = Vector2(paper.position.x + paper.size.x - _pad - x,
			paper.position.y + paper.size.y - 8.0 - KEY_H)


## The words on the key caps, for a test or a tool to read.
func keys_text() -> String:
	var out: Array[String] = []
	for c in keys.get_children():
		if c is Label:
			out.append((c as Label).text)
		elif c.get_child_count() > 0:
			out.append((c.get_child(0) as Label).text)
	return " ".join(out)


## The clipboard's clip: a sprung bar across the top of the board, its arch
## standing clear of it.
func _draw_clip() -> void:
	var metal := UITheme.color(&"pencil")
	var shine := UITheme.faded(&"paper_bright", 0.55)
	var shade := UITheme.color(&"ink")
	var w := CLIP_SIZE.x
	# the arch: two posts and a top, the board showing through
	clip.draw_rect(Rect2(28, 0, 32, 4), metal)
	clip.draw_rect(Rect2(28, 0, 6, 10), metal)
	clip.draw_rect(Rect2(54, 0, 6, 10), metal)
	clip.draw_rect(Rect2(30, 0, 28, 2), shine)
	# the bar
	clip.draw_rect(Rect2(2, 8, w - 4.0, 16), metal)
	clip.draw_rect(Rect2(0, 10, w, 12), metal)
	clip.draw_rect(Rect2(4, 10, w - 8.0, 2), shine)
	clip.draw_rect(Rect2(2, 22, w - 4.0, 2), shade)
	# two rivets
	clip.draw_rect(Rect2(10, 14, 4, 4), shine)
	clip.draw_rect(Rect2(w - 14.0, 14, 4, 4), shine)


## The stamp: a ring and the words, both in one palette colour, a little off
## square. The tilt is STEPPED, the way a slope is drawn in pixel art: the
## stamp climbs one art pixel every STAMP_RUN px, and each letter stands whole
## on the step under it. Turning the node instead smears every glyph off the
## pixel grid.
func _draw_stamp() -> void:
	if _stamp_text == "":
		return
	var col := UITheme.color(_stamp_token)
	var font := UITheme.font(&"display")
	var px := UITheme.size(&"display")
	var w := stamp.size.x
	var h := stamp.size.y - _stamp_rise(w)
	var steps := _stamp_steps(w)
	for k in steps:
		var x0 := float(k) * STAMP_RUN
		var run := minf(w, x0 + STAMP_RUN) - x0
		var dy := float(steps - 1 - k) * 2.0
		stamp.draw_rect(Rect2(x0, dy, run, 2.0), col)
		stamp.draw_rect(Rect2(x0, dy + h - 2.0, run, 2.0), col)
	stamp.draw_rect(Rect2(0.0, float(steps - 1) * 2.0, 2.0, h), col)
	stamp.draw_rect(Rect2(w - 2.0, 0.0, 2.0, h), col)
	var x := roundf((w - font.get_string_size(_stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x) * 0.5)
	for i in _stamp_text.length():
		var ch := _stamp_text[i]
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var k := clampi(int((x + cw * 0.5) / STAMP_RUN), 0, steps - 1)
		var dy := float(steps - 1 - k) * 2.0
		stamp.draw_string(font, Vector2(x, dy + roundf((h + float(px)) * 0.5)), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += cw


func _stamp_steps(w: float) -> int:
	return maxi(1, int(ceil(w / STAMP_RUN)))


## How far the stamp's right end stands above its left, in px.
func _stamp_rise(w: float) -> float:
	return float(_stamp_steps(w) - 1) * 2.0


## A pencil left on the desk beside the report: six-sided yellow, a pink
## rubber in its band, sharpened to a point.
func _draw_pencil() -> void:
	var body := UITheme.color(&"amber")
	var lit := UITheme.faded(&"paper_bright", 0.45)
	var x := 0.0
	# the rubber and the band that holds it
	pencil.draw_rect(Rect2(x, 0, 8, 6), UITheme.color(&"terracotta"))
	pencil.draw_rect(Rect2(x + 8.0, 0, 4, 6), UITheme.color(&"sand"))
	pencil.draw_rect(Rect2(x + 8.0, 4, 4, 2), UITheme.color(&"pencil"))
	# the barrel, lit along its top edge
	pencil.draw_rect(Rect2(x + 12.0, 0, 52, 6), body)
	pencil.draw_rect(Rect2(x + 12.0, 0, 52, 2), lit)
	pencil.draw_rect(Rect2(x + 12.0, 4, 52, 2), UITheme.color(&"wood_dark"))
	# the cut wood and the point
	pencil.draw_rect(Rect2(x + 64.0, 0, 6, 6), UITheme.color(&"paper"))
	pencil.draw_rect(Rect2(x + 70.0, 2, 4, 2), UITheme.color(&"paper"))
	pencil.draw_rect(Rect2(x + 72.0, 2, 4, 2), UITheme.color(&"ink"))


## The sheet's left-hand margin rule, and on a desk sheet the three binder
## holes punched along its edge so the wood shows through.
func _draw_trim() -> void:
	var h := trim.size.y
	if h <= 8.0:
		return
	trim.draw_rect(Rect2(12.0, 4.0, 2.0, h - 8.0), UITheme.faded(&"terracotta", 0.22))
	if kind == Kind.DESK:
		var hole := UITheme.color(&"wood")
		var rim := UITheme.color(&"wood_dark")
		for share: float in [0.22, 0.5, 0.78]:
			var hy := snappedf(h * share - 3.0, 2.0)
			trim.draw_rect(Rect2(4.0, hy, 6.0, 6.0), hole)
			trim.draw_rect(Rect2(4.0, hy, 6.0, 2.0), rim)
