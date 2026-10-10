extends Control

const BUILD_STAMP := preload("res://scripts/data/version.gd")

## Status strip, interaction prompt, and the full-screen overlays.
##
## The status strip deliberately sits over the top wall band, where nothing
## gameplay-relevant is ever drawn — so the HUD costs no play area at all.
##
## Overlays are rendered as TEXT rather than as widget trees. At 320x176 a
## laid-out list of labels and a "> " selection marker is not merely
## adequate, it is more legible than real controls would be, and it keeps
## the whole UI layer to one script.

## The full-screen panel's backing (hud.tscn's Overlay). The intro's slate
## swaps in a see-through one; _open() puts this back for every other screen.
const OVERLAY_COLOUR := Color(0.06, 0.05, 0.08, 0.93)

enum Mode { NONE, REPORT, CATALOGUE, MARKING, TITLE, CLASS_LIST, PAUSE, STUDENT,
	CURRICULUM, SPECIALISM, HAND, CAREER, SCHOOL, DASHBOARD, WATCH, OFFICE, INTRO,
	ADS, PATHS, MENTOR, HELP, CALLER, SKIP, SKIP_REPORT, TROPHIES, GRADE_BOOK }
## SELL became CABINET (Sep 2026): buying no longer places on the spot,
## it drops the item in the cabinet; you place it from the cabinet, and
## selling is done from there too. Same five-stop Tab cycle, one label
## and one screen changed.
enum Shop { BUY, CABINET, STAFF, ROOM, CRAFT, IDEAS }
## The dashboard's own three pages, cycled by the same "menu" key the shop
## already cycles its tabs with -- one overview screen for "who am I, what
## do I have", not a fourth thing bolted onto E/F.
enum Dash { OVERVIEW, ITEMS, SKILLS, WARDROBE }
var _dash: int = Dash.OVERVIEW
## The two ways the room can grow. It only ever grows right and down --
## the door is a fixed point on the left wall.
const ROOM_ROWS := ["wide", "tall", "desk"]
## Actions offered on a student's own file.
enum Act { TUITION, PARENTS, GRADUATE, COUNT }

signal item_chosen(id: String)
## Which of the drawn papers the player took.
signal assignment_chosen(index: int)
## Long Reach changes the size of the player's pick zone, so it has to
## be rebuilt when a perk is bought.
signal perk_bought()
## The storyline cutscene's dialogue, one line at a time. hud.gd owns the
## PAGING (INTRO_PAGES, _sel, when it is done); main.gd owns the WORLD
## (the player who says it), so the words cross that boundary as a signal
## rather than hud reaching into world.player directly.
signal intro_line_changed(text: String)
## Fired once, the moment the title slate is dismissed -- main.gd's cue to
## put the teacher at the door, stash the desks, and start the walk to
## the cabinet.
signal intro_walk_requested()
## One press of E during the desk-pull phase -- main.gd pulls one desk
## out of the cabinet and, on the last one, brings the class in.
signal intro_desk_pull_requested()
signal intro_finished()

@onready var status: Label = $Status
## One line across the top of the room -- a question opening in the boss
## paper. Outside $Overlay, like the mascot box, so it shows in free roam.
@onready var banner: Label = $Banner
@onready var prompt: Label = $Prompt
@onready var prompt_box: ColorRect = $PromptBox
@onready var overlay: ColorRect = $Overlay
@onready var title: Label = $Overlay/Title
@onready var body: Label = $Overlay/Body
## A second body for the one screen that needs COLOUR rather than columns.
## A Label is one colour by definition, and the curriculum is a list of four
## different subjects -- which is exactly the thing colour is for.
@onready var rich: RichTextLabel = $Overlay/Rich
## The book the curriculum and the lesson plans are read out of, and the
## page that turns across it. See tools/make_ui.py for the art.
@onready var book: TextureRect = $Overlay/Book
@onready var rich_left: RichTextLabel = $Overlay/RichLeft
@onready var flip: TextureRect = $Overlay/Flip
## The homework sheet, drawn as an actual page -- see homework_sheet.gd.
@onready var sheet: HomeworkSheet = $Overlay/Sheet
## The reveal running on the rich body, kept so a screen opened twice in
## quick succession cannot leave two of them fighting over visible_ratio.
var _reveal: Tween = null
@onready var hint: Label = $Overlay/Hint
@onready var portrait: TextureRect = $Overlay/Portrait
## A flat colour behind the portrait -- the "Background" cosmetic. Only
## ever shown alongside the portrait itself, on the two dashboard pages
## that display your own character (never the student bio: that is
## someone else's portrait, not yours).
@onready var portrait_bg: ColorRect = $Overlay/PortraitBg
## A small face for the room's overall grade band (A/B good, C/D ok, E/F
## struggling) -- Dashboard Overview only. Oct 2026, built on explicit
## request despite the project's own stated preference for prose over a
## visual score on anything judging a child (see show_inspection()'s own
## doc comment) -- a deliberate, confirmed override, not an oversight;
## see make_ui.py's mood_icon() for the fuller note.
@onready var mood_icon: TextureRect = $Overlay/MoodIcon
## The principal's own corner, for a tutorial tip -- deliberately OUTSIDE
## $Overlay. Overlay is hidden whenever mode == NONE (close()), which is
## exactly when a tip needs to fire: nobody has a screen open, they are
## mid-room and about to do the thing the tip is about.
@onready var mascot_box: NinePatchRect = $MascotBox
@onready var mascot_portrait: TextureRect = $MascotPortrait
## The paper the corner's words are printed on while someone is talking --
## see _speech_style(). The plain key-prompt bar keeps its dark strip.
@onready var speech_box: NinePatchRect = $SpeechBox
## The dedicated 96x96 busts the Sept 2026 art pass drew (tools/make_art.py
## make_portrait()) -- a face at corner/panel size, not a walk-cycle frame
## stretched up to it. Preloaded like the sheets above rather than loaded
## by string each call, since these two are used every time the mascot box
## or the day's beat shows a face.
const PRINCIPAL_PORTRAIT := preload("res://art/portrait_principal.png")
const PLAYER_PORTRAIT := preload("res://art/portrait_player.png")

@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_speaker: Label = $DialogueBox/SpeakerLabel
@onready var dialogue_portrait: TextureRect = $DialogueBox/SpeakerPortrait
@onready var dialogue_portrait_border: NinePatchRect = $DialogueBox/PortraitBorder
@onready var dialogue_portrait_bg: ColorRect = $DialogueBox/PortraitBg
@onready var dialogue_text: Label = $DialogueBox/TextBody
@onready var dialogue_advance: Control = $DialogueBox/AdvanceIndicator
@onready var dialogue_arrow: Label = $DialogueBox/AdvanceIndicator/Arrow

## Speech is set in a pixel font, black on white, like a Pokemon text box
## (the owner's ask, Oct 2026: "the same font as Pokemon"). Nintendo's own
## font is theirs and cannot ship in this game; Galmuri9 is an SIL OFL font
## drawn after the Nintendo DS text it imitates, which is as close as a font
## this game may legally carry gets. It is drawn on a 10px em, so at 20 one of
## its pixels is two screen pixels -- the same size as one pixel of the
## room's art, which is the whole reason for that size. Subset to Latin
## (tools: fontTools.subset); the licence sits beside it in fonts/.
const SPEECH_FONT := preload("res://fonts/Galmuri9.ttf")
const SPEECH_SIZE := 20
## ...and since Oct 2026 every other word the HUD prints is in it too
## (fonts/ui_theme.tres on the HUD's root), on the owner's call. Two sizes
## only, both whole multiples of the 10px em: UI_SIZE for text, UI_SMALL for
## the odd tiny label. Anything else would smear its pixels.
const UI_SIZE := 20
const UI_SMALL := 10
const INK := Color(0.13, 0.12, 0.17)
## Where the key-prompt bar's label lives when nobody is talking...
const PROMPT_HOME := Rect2(0, 316, 640, 32)
## ...and the speech box beside the speaker's face when somebody is: its
## right and bottom edges are fixed, its top rises to fit the line.
const SPEECH_RIGHT := 636.0
const SPEECH_LEFT := 88.0
const SPEECH_BOTTOM := 348.0
const SPEECH_PAD := Vector2(12, 7)
const SPEECH_MIN_H := 50.0
const SPEECH_LINE_GAP := 2
var _speaking: bool = false

var _dialogue_full_text: String = ""
var _dialogue_visible_chars: int = 0
var _dialogue_char_timer: float = 0.0
var _dialogue_typing: bool = false
var _arrow_bob: float = 0.0
var _blip_counter: int = 0

var mode: int = Mode.NONE
var _player: Node = null
var _sel: int = 0
var _shop: int = Shop.BUY

const UI_FRAME := preload("res://art/ui_frame.png")
const UI_FRAME_MARGIN := 12
var _frame: NinePatchRect = null     ## the bamboo border round the overlay
var _slot: NinePatchRect = null      ## the cream slot behind a shop item's picture
var _preview: RoomPreview = null     ## the Ideas tab's half-size room picture
var _ideas_frame: NinePatchRect = null
var _info: RichTextLabel = null      ## the Ideas tab's blurb / pieces / cost lines
## What the highlighted item is for, shown on the hint bar.
var _shop_blurb: String = ""
## Which category tab the buy list is showing. 29 items in one flat
## list is more than fits the panel, let alone more than you can scan.
var _cat: int = 0

## How many list rows fit the overlay body alongside a tab strip, a blurb
## and the scroll markers.
const LIST_ROWS := 4

## The widest a body line can be before the Label wraps it -- and a wrapped
## line is a SECOND line, which is how three separate panels came to overflow
## while every one of them looked short enough in the source.
##
## Taken from real screenshots: a 45-character row renders on one line in
## the 288px panel. Do NOT tune this against get_line_count() -- headless
## Godot has no renderer, falls back to different font metrics, and will
## happily report wrapping that does not happen.
const LINE_CHARS := 47


## Clip a line to the panel width. Truncating is honest here: these are
## fixed-width columns, so what gets cut is the tail of the last column
## rather than something load-bearing.
func _clip(text: String) -> String:
	return text if text.length() <= LINE_CHARS else text.substr(0, LINE_CHARS)


## The one caller where truncating is NOT honest: the status strip is an
## assembled sentence, not a fixed-width column, and a long coin count (a
## six-figure career total, or a dev-room cheat) can push its tail past
## LINE_CHARS with nothing to say so. Silent clipping is the exact failure
## mode this project has been burned by before -- this is the same shape
## of bug in a new place, closed the same way: if a cut happened, say so.
func _clip_visibly(text: String) -> String:
	if text.length() <= LINE_CHARS:
		return text
	return text.substr(0, LINE_CHARS - 1) + "…"


## First visible row so that _sel stays on screen, scrolling only when the
## selection would leave the window.
func _window_start(total: int, shown: int) -> int:
	if total <= shown:
		return 0
	return clampi(_sel - shown / 2, 0, total - shown)

# marking state
var _marking: Array = []       ## StudentData still to be judged
var _marked_right: int = 0
## Counts down MARKING_STAMP_SECONDS after a verdict, ticked in _process()
## below. > 0 means a check/X is currently up and input is ignored.
var _marking_hold: float = 0.0

## The ad poster: which tier is highlighted, and (while > 0) the
## compressed "watching" countdown from Balance.ad_tiers[_ad_tier].wait --
## ticked in _process() below, same shape as _marking_hold.
var _ad_sel: int = 0
var _ad_watching: float = 0.0
var _ad_tier: int = -1
var _shown_hints := {}
## Whose file is open. One field rather than a mode stack: there is
## exactly one transition to remember (class list -> bio -> back).
var _bio: StudentData = null
var _bio_sel: int = 0
## A student's file has two pages, cycled by the same "menu" key the shop
## and dashboard already use for tabs: the FILE (seat, ability, actions)
## and their STORY (transcript arc + the notable-moments reel, in prose).
## Paging beats cramming -- the file was already at the panel's row limit.
const BIO_FILE := 0
const BIO_STORY := 1
## Page three: everything pulling on this child RIGHT NOW.
const BIO_ACTING := 2
var _bio_page: int = BIO_FILE

## The career screen has two pages, cycled by the same "menu" key: the
## MILESTONES/trophies list it always was, and THE ONES WHO LEFT -- the
## alumni wall, every child ever sent up, read from meta.alumni so it
## survives new_run(). Which is the whole point: a career you can look
## back on.
const CAREER_MILESTONES := 0
const CAREER_ALUMNI := 1
var _career_page: int = CAREER_MILESTONES
## Which alum's story is open on the alumni page. -1 is the list itself.
var _alum_open: int = -1
## The exam is the one screen whose closing DOES something, so it has to be
## told apart from every other report.
var _showing_exam: bool = false
## The run itself has ended. Closing this one starts a new run rather than
## a new term.
var _showing_run_over: bool = false
## The new-term announcement is up. Closing THIS one hands off to the
## path-pick screen instead of straight back to play -- see show_new_term()
## and the Mode.REPORT close handling below.
var _showing_new_term: bool = false
## The school screen is showing the hiring list rather than the rooms.
var _hiring: bool = false
## Which room a hire is FOR.
var _hiring_for: int = 0

## WATCHING A DELEGATED ROOM: the day it already had, played back.
##
## `resolve_rooms()` already ran this exact roll to get yesterday's letter,
## and RoomSim recorded one frame a second while it did. This does not
## re-simulate anything -- it steps through the SAME frames at a speed a
## person can actually watch, so what you see is what earned the grade,
## not a guess dressed up to look like it.
var _watch_room: int = -1
var _watch_frames: Array = []
var _watch_result: Dictionary = {}
var _watch_i: int = 0
var _watch_clock: float = 0.0
## Set only when watching your OWN auto-taught lesson rather than a
## delegated room -- closing that watch hands off to the ordinary lesson
## report (these results) instead of back to the school board.
var _watch_own_results: Array = []
## Seconds of real time per frame (each frame is one simulated second).
const WATCH_FRAME_SECONDS := 0.12


func _ready() -> void:
	# LimeZu's bamboo frame round every full-screen panel, and (in the shop) as a
	# cream slot the item's picture sits in. Children of the overlay, so they
	# show and hide with it; added FIRST so they draw behind everything else.
	_frame = _nine_patch(UI_FRAME, Rect2(2, 2, 636, 348), false)
	overlay.add_child(_frame)
	overlay.move_child(_frame, 0)
	_slot = _nine_patch(UI_FRAME, Rect2(488, 40, 120, 168), true)
	overlay.add_child(_slot)
	overlay.move_child(_slot, 1)
	_slot.visible = false
	_ideas_frame = _nine_patch(UI_FRAME, Rect2(282, 40, 344, 200), false)
	overlay.add_child(_ideas_frame)
	overlay.move_child(_ideas_frame, 2)
	_preview = RoomPreview.new()
	_preview.position = Vector2(294, 52)
	overlay.add_child(_preview)
	overlay.move_child(_preview, 3)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.position = Vector2(32, 244)
	_info.size = Vector2(576, 70)
	_info.add_theme_color_override("default_color", Color(0.95, 0.91, 0.77))
	_info.add_theme_font_size_override("normal_font_size", UI_SIZE)
	_info.add_theme_constant_override("line_separation", 0)
	overlay.add_child(_info)
	_set_ideas_ui(false)
	# A new run must not inherit the last one's screen.
	Game.run_started.connect(func() -> void:
		if mode != Mode.TITLE:
			close())
	# Trace an X or a check with the mouse instead of pressing a key -- see
	# homework_sheet.gd's own comment for why stroke COUNT is the signal.
	sheet.gesture_verdict.connect(_verdict)
	_build_move_bar()


## A LimeZu UI frame stretched to `rect` as a 9-slice: the 12px bamboo border
## (6 art pixels doubled) never stretches, only the middle does. `centre` fills
## the middle with the frame's cream; false leaves it clear so the dark panel
## shows through.
func _nine_patch(tex: Texture2D, rect: Rect2, centre: bool) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = tex
	n.position = rect.position
	n.size = rect.size
	n.patch_margin_left = UI_FRAME_MARGIN
	n.patch_margin_top = UI_FRAME_MARGIN
	n.patch_margin_right = UI_FRAME_MARGIN
	n.patch_margin_bottom = UI_FRAME_MARGIN
	n.draw_center = centre
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## The Ideas tab's extra furniture: the framed picture of the room and the
## lines beneath it. Off for every other screen; and the shared text box gets
## its full width back.
func _set_ideas_ui(on: bool) -> void:
	if _preview == null:
		return
	_preview.visible = on
	_ideas_frame.visible = on
	_info.visible = on
	rich.offset_right = 278.0 if on else 608.0


## `tex` enlarged by the biggest WHOLE number that still fits `w` x `h`
## (nearest-neighbour), never shrunk below 1. Pixel art keeps its square pixels.
func _scaled_whole(tex: Texture2D, w: int, h: int) -> Texture2D:
	if tex == null:
		return null
	var k := maxi(1, mini(w / maxi(1, tex.get_width()), h / maxi(1, tex.get_height())))
	if k == 1:
		return tex
	var img := tex.get_image()
	img.resize(tex.get_width() * k, tex.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## `text` cut at a word so it fits `width` px in the pixel font, with "..."
## when anything went. Plain text only (measure the words, then colour them).
func _fit_px(text: String, width: float, size: int = UI_SIZE) -> String:
	if SPEECH_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var words := text.split(" ")
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		var cut := " ".join(words).rstrip(",.;:") + "…"
		if SPEECH_FONT.get_string_size(cut, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			return cut
	return text.substr(0, 4) + "…"


## The hint bar's own cut: at a word, to the bar's width in the pixel font.
## It used to be _clip() -- 47 CHARACTERS, a budget measured for the panel
## body -- which cut "Tab - craft a lesson" to "Tab - craft a les".
func _hint_clip(text: String) -> String:
	return _fit_px(text, 616.0)


## A footnote line (a perk's blurb, a room idea's description) that would
## wrap at UI_SIZE is set at UI_SMALL instead, whole -- these are the lines
## where every word is the information, so cutting one is worse than small.
## Returns BBCode.
func _fit_or_small(text: String, width: float) -> String:
	if SPEECH_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI_SIZE).x <= width:
		return text
	return "[font_size=%d]%s[/font_size]" % [UI_SMALL, text]


## A one-line label (the hint bar, a screen's title) whose words would run
## past its own width at UI_SIZE drops to UI_SMALL rather than being cut off
## at the frame. Checked every frame, because a dozen screens write these.
func _fit_line(l: Label) -> void:
	if l == null or not l.is_visible_in_tree():
		return
	var wide := SPEECH_FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UI_SIZE).x > l.size.x - 8.0
	var want := UI_SMALL if wide else UI_SIZE
	if l.get_theme_font_size("font_size") != want:
		l.add_theme_font_size_override("font_size", want)


## Where the overlay's face/item picture normally sits, top right.
const PORTRAIT_HOME := Rect2(500, 52, 96, 144)
## A child's file: the bust at 2x in the top-right corner, beside the title
## and the file's short first line. At the full 96px it sat across the
## first six rows, and the pixel font's longer lines ran under it.
const PORTRAIT_FILE := Rect2(556, 6, 48, 48)

func _portrait_at(r: Rect2) -> void:
	portrait.offset_left = r.position.x
	portrait.offset_top = r.position.y
	portrait.offset_right = r.position.x + r.size.x
	portrait.offset_bottom = r.position.y + r.size.y


## Display only. Every INPUT read lives on the physics tick below.
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("carrier")
	_update_status()
	_update_prompt()
	_update_move_bar()
	_fit_line(hint)
	_fit_line(title)
	if mode == Mode.WATCH and _watch_i < _watch_frames.size() - 1:
		_watch_clock += _delta
		if _watch_clock >= WATCH_FRAME_SECONDS:
			_watch_clock = 0.0
			_watch_i += 1
			_render_watch_frame()
	if mode == Mode.MARKING:
		sheet.tick_gesture(_delta)
		if _marking_hold > 0.0:
			_marking_hold = maxf(0.0, _marking_hold - _delta)
			if _marking_hold <= 0.0:
				_finish_marking_if_ready()
	if mode == Mode.ADS and _ad_watching > 0.0:
		_ad_watching = maxf(0.0, _ad_watching - _delta)
		if _ad_watching <= 0.0:
			_finish_ad()
	# A hint that was parked because a screen was up when it fired -- the
	# mentor nudge does this, since a day ends WITH the day report on
	# screen. Shown the moment the player is back in free roam.
	if mode == Mode.NONE and not _queued_hint.is_empty() \
			and _next_queued_hint_at <= Time.get_ticks_msec() / 1000.0:
		# Gated on the queue's OWN timer, not the shared _hint_until --
		# principal_says() does not change `mode`, so without some gate a
		# second entry would pop and overwrite the first's popup the very
		# next frame, before it was ever seen. See _next_queued_hint_at's
		# own comment for why it isn't just _hint_until.
		var q: Array = _queued_hint.pop_front()
		principal_says(String(q[0]), String(q[1]))
		_next_queued_hint_at = Time.get_ticks_msec() / 1000.0 + 5.0

	# the day's beat, once the player is back in free roam
	if mode == Mode.NONE and _queued_beat != "":
		var b := _queued_beat
		_queued_beat = ""
		show_day_beat(b)
	# type it on, a few characters a frame, while its window is open
	if _beat_full != "":
		if _hint_until <= Time.get_ticks_msec() / 1000.0:
			_beat_full = ""
			_beat_chars = 0
		elif _beat_chars < _beat_full.length():
			_beat_chars = mini(_beat_full.length(),
				_beat_chars + maxi(1, int(ceil(_delta * 45.0))))
			prompt.text = _beat_full.substr(0, _beat_chars)
	if banner.visible and _banner_until <= Time.get_ticks_msec() / 1000.0:
		banner.visible = false

	# Pokémon-style dialogue box typewriter reveal and advance indicator bob
	if dialogue_box != null and dialogue_box.visible:
		if _dialogue_typing:
			_dialogue_char_timer += _delta * 38.0
			while _dialogue_char_timer >= 1.0 and _dialogue_visible_chars < _dialogue_full_text.length():
				_dialogue_char_timer -= 1.0
				_dialogue_visible_chars += 1
				dialogue_text.text = _dialogue_full_text.substr(0, _dialogue_visible_chars)
				_blip_counter += 1
				if _blip_counter % 3 == 0:
					Sfx.play("blip")
			if _dialogue_visible_chars >= _dialogue_full_text.length():
				_dialogue_typing = false
				dialogue_advance.visible = true
		if dialogue_advance.visible and dialogue_arrow != null:
			_arrow_bob += _delta * 6.0
			dialogue_arrow.position.y = sin(_arrow_bob) * 3.0

	# Every face on screen blinks now and then. Real play only: the suite and
	# the screenshot tools must see the face they asked for, not whichever
	# frame the clock happened to land on -- the same carve-out the dialogue
	# box's typing already makes.
	if Game.save_path == Game.SAVE_PATH:
		_blink_clock += _delta
		if _blink_shut and _blink_clock >= BLINK_SHUT_SECONDS:
			_blink(false)
		elif not _blink_shut and _blink_clock >= BLINK_EVERY_SECONDS:
			_blink(true)


## THE BLINK. tools/limezu_chars.py bakes portrait_<art>_talk.png beside each
## bust: the resting face, then -- where the face can take it without the
## mouth twitching -- the same face with its eyes shut, on the same crop. A
## one-frame strip is a face that never blinks; nothing here needs its name.
const BLINK_EVERY_SECONDS := 3.4
const BLINK_SHUT_SECONDS := 0.14
var _blink_clock: float = 0.0
var _blink_shut: bool = false
## TextureRect -> the open-eyed texture it goes back to.
var _blink_open: Dictionary = {}
var _blink_frames: Dictionary = {}


## Shut (or open) the eyes of every face currently showing. Only a texture
## that IS a plain bust (res://art/portrait_<art>.png) is touched, so a hat
## preview or an item picture in the same TextureRect is left alone.
func _blink(shut: bool) -> void:
	_blink_clock = 0.0
	_blink_shut = shut
	if not shut:
		for r: TextureRect in _blink_open.keys():
			if is_instance_valid(r) and r.texture == _blink_frames.get(r):
				r.texture = _blink_open[r]
		_blink_open.clear()
		return
	for r: TextureRect in [mascot_portrait, dialogue_portrait, portrait]:
		if r == null or not r.is_visible_in_tree() or r.texture == null:
			continue
		var path := r.texture.resource_path
		if not (path.begins_with("res://art/portrait_") and path.ends_with(".png")) \
				or path.ends_with("_talk.png"):
			continue
		var shut_tex := _shut_eyes(path.get_file().get_basename().trim_prefix("portrait_"))
		if shut_tex == null:
			continue
		_blink_open[r] = r.texture
		_blink_frames[r] = shut_tex
		r.texture = shut_tex


var _shut_cache: Dictionary = {}

## The eyes-shut frame for one character, or null for a face that cannot
## blink (a one-frame strip) or has no strip at all.
func _shut_eyes(art: String) -> Texture2D:
	if _shut_cache.has(art):
		return _shut_cache[art]
	var path := "res://art/portrait_%s_talk.png" % art
	var out: Texture2D = null
	if ResourceLoader.exists(path):
		var strip: Texture2D = load(path)
		if strip.get_width() >= strip.get_height() * 2:
			var a := AtlasTexture.new()
			a.atlas = strip
			a.region = Rect2(strip.get_height(), 0, strip.get_height(), strip.get_height())
			out = a
	_shut_cache[art] = out
	return out


## ALL input, on ONE clock.
##
## Opening the class list and the pause menu used to be read here in
## _process (the idle tick) while everything else was read in
## _physics_process. Two clocks meant Input.is_action_just_pressed() was
## being asked about two different frames, so a press could be seen by one
## and missed by the other — which is exactly what happened: Tab opened the
## class list in play but never in a test, because the test drives the
## physics tick.
## The wheel and the mouse, for the two screens that are a folder of pages
## -- the assignment hand, and (since it was built as a near-duplicate of
## it) the term-path pick.
##
## _input rather than the physics poll because a wheel notch is an EVENT --
## it has no held state to sample, so polling would miss it entirely.
func _input(e: InputEvent) -> void:
	if mode != Mode.HAND and mode != Mode.PATHS:
		return
	var hand: Array = Game.hand if mode == Mode.HAND else Game.term_path_hand
	if hand.is_empty():
		return
	var n: int = hand.size()
	var show_page := show_hand if mode == Mode.HAND else show_term_paths
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var b := (e as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_DOWN:
			_sel = (_sel + 1) % n
			Sfx.play_varied("paper")
			show_page.call()
			accept_event()
		elif b == MOUSE_BUTTON_WHEEL_UP:
			_sel = (_sel - 1 + n) % n
			Sfx.play_varied("paper")
			show_page.call()
			accept_event()
		elif b == MOUSE_BUTTON_LEFT:
			# clicking the page turns it, the way you would nudge a corner
			_sel = (_sel + 1) % n
			Sfx.play_varied("paper")
			show_page.call()
			accept_event()


func _physics_process(_delta: float) -> void:
	if mode == Mode.NONE:
		if Input.is_action_just_pressed("menu"):
			show_class_list()
		elif Input.is_action_just_pressed("dashboard"):
			_dash = Dash.OVERVIEW
			show_dashboard()
		elif Input.is_action_just_pressed("pause"):
			show_pause()
		elif Input.is_action_just_pressed("help"):
			show_help()
		elif Input.is_action_just_pressed("skip_days"):
			# Only between lessons. Handing over days you have not started
			# is a plan; handing over the one you are stood in the middle
			# of is auto-teach, which already has its own key.
			if Game.phase == Game.Phase.LESSON or Game.test_active:
				principal_says("skip_lesson", "Not in the middle of a lesson.")
			else:
				show_skip()
		return
	if mode == Mode.PAUSE:
		_pause_input()
		return
	_handle_input()


func _update_status() -> void:
	# ONE LINE, and it runs off the right-hand edge if you let it. What
	# belongs on it changes with the phase, so it is built in priority order
	# and cut rather than assembled and hoped over: mid-lesson the subject
	# and the coin count are things you already know and cannot act on,
	# while the clock, your voice and who needs you are the whole job.
	var left: int = maxi(0, Balance.term_days - Game.day + 1)
	var teaching: bool = Game.phase == Game.Phase.LESSON
	var paper := ""
	var bits: Array[String] = ["%sDay %d/%d" % [
		"T%d " % Game.term if Game.term > 1 else "",
		Game.day, Balance.term_days]]
	# A mode you cannot see is a mode you forget is on -- same reasoning
	# as autopilot's own tag below. Shown regardless of phase: auto-teach
	# resolves a lesson the instant it starts, so there is barely a
	# "teaching" phase for a lesson-only tag to ever actually be seen in.
	if Game.auto_teach:
		bits.append("AUTO-TEACH")

	if teaching and Game.fight_active():
		_fight_bits(bits)
	elif teaching:
		var room := get_tree().get_first_node_in_group("classroom")
		if room != null:
			bits.append("%ds" % int(ceil(room.lesson_left)))
		# What paper is on the desks. In WORDS: the strip is a Label, so it
		# cannot carry the rarity's colour the way the card screen does.
		# Held back and added near the END: it was third on the line, ahead
		# of the room's mood and your voice, and it is the one thing on the
		# strip you can do nothing about mid-lesson.
		if not Game.assignment.is_empty():
			paper = Assignments.rarity_name(
				String(Game.assignment.get("rarity", "common")))
		# A mode you cannot see is a mode you forget is on.
		if _player != null and is_instance_valid(_player) and _player.autopilot:
			bits.append("AUTO%s" % ("" if _player.auto_target_name == ""
				else " " + _player.auto_target_name))
		if not Game.test_active:
			# Attention first: it is the difference between a lesson
			# happening and a lesson not happening, so it outranks the rest.
			# The class in a word, not attention as pips: "is the room with
			# me" was the one thing a new player had to add up from bars.
			# Away from the front but still held by a call-and-response:
			# say THAT, not "NOT teaching" -- the room is with you, and the
			# word should tell you why.
			if not Game.teaching and Game.call_hold > 0.0:
				bits.append("LISTENING")
			else:
				bits.append("%steaching" % ("" if Game.teaching else "NOT "))
			bits.append("room: %s" % Game.class_mood())
			var pips := int(round(Game.voice * 4.0))
			bits.append("voice %s%s" % ["|".repeat(pips), ".".repeat(4 - pips)])
		# A buff you cannot see is a buff you do not believe in.
		if Game.quiz_focus:
			bits.append("FOCUSED")
	else:
		# What you are actually playing towards, ordered right after the
		# day counter rather than last -- a long coin count (a six-figure
		# career total, or a dev-room cheat) can push the tail of this
		# line past LINE_CHARS, and "need N" silently disappearing is
		# losing the one number the rest of the line exists to explain.
		# Whatever else gets clipped, this survives.
		bits.append("need %d" % Game.term_target())
		bits.append("%s %s" % [Curriculum.short_name(Game.lesson),
			"*".repeat(Curriculum.difficulty(Game.lesson))])
		bits.append("%d coins" % Game.coins)
		if left <= 3:
			bits.append("LAST %d DAYS" % left)

	if _player != null and is_instance_valid(_player):
		if _player.carrying > 0:
			bits.append("%d work" % _player.carrying)
		if _player.carrying_hw > 0:
			bits.append("%d hw" % _player.carrying_hw)

	var stuck := 0
	var waiting := 0
	var noisy := 0
	var chatting := 0
	for st: StudentData in Game.roster:
		if st.disrupting:
			noisy += 1
		# what you can SEE, not what is true -- the strip must never quietly
		# know more about the room than the room is showing you
		if st.is_visibly_struggling():
			stuck += 1
		if st.has_work_to_collect():
			waiting += 1
		if st.chatting():
			chatting += 1

	# via a group, not current_scene -- current_scene is not Main when the
	# game is instantiated inside a test or a screenshot harness
	var place := get_tree().get_first_node_in_group("placement")
	if place != null and place.active:
		bits.append("helps %d" % place.reach_count())
		# ten-commits.md step 4: the overlay already draws the orange
		# outline; the strip is where you'd already look for a count. "Too
		# close" since the cost of crowding became talking (Game.tick_chat).
		if place.crowd_count() > 0:
			bits.append("%d too close" % place.crowd_count())

	# Loudest first: messing about is the one that gets worse while you are
	# somewhere else.
	if noisy > 0:
		bits.append("%d NOISY" % noisy)
	if stuck > 0:
		bits.append("%d stuck" % stuck)
	# After stuck: a chat ends by itself, a stuck child never does.
	if chatting > 0:
		bits.append("%d chatting" % chatting)
	if waiting > 0:
		bits.append("%d ready" % waiting)

	if paper != "":
		bits.append(paper)

	# The dash's and answer-all's recharge pips used to sit here, last on
	# the line and so the first thing it dropped. They are the move bar's
	# job now (bottom right, _update_move_bar()), with the call beside them.

	status.text = _fit_status(bits)


## Fit the strip by MEASURING it. It used to borrow LINE_CHARS (47), a
## character budget taken for the 288px PANEL body, and so clipped the
## room's mood and your voice -- the two things the strip exists for -- off
## a 624px line that was a third empty ("teaching   room: ..."). The font's
## own metrics agree with the screen (checked against a screenshot, Oct
## 2026: ~8.2px a character at 18), so the strip asks the font.
func _fits_status(line: String) -> bool:
	var f := status.get_theme_font("font")
	var px := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1,
		status.get_theme_font_size("font_size")).x
	return px <= status.size.x - 4.0


## Drop whole bits from the END -- they are added most-important first --
## rather than cutting a word in half, and say "..." when anything went.
func _fit_status(bits: Array[String]) -> String:
	var shown: Array[String] = bits.duplicate()
	var line := "   ".join(shown)
	while not _fits_status(line) and shown.size() > 1:
		shown.pop_back()
		line = "   ".join(shown) + "   …"
	while not _fits_status(line) and line.length() > 2:
		line = line.substr(0, line.length() - 2) + "…"
	return line


## The strip while the boss paper is being sat: which question, the
## paper's clock, how the room is holding (pips and a word, never a
## number), the voice. The day counter goes -- the banner already said
## what day it is, and the width is needed.
func _fight_bits(bits: Array[String]) -> void:
	var f: BossFight = Game.fight
	bits.clear()
	bits.append("Q%d/%d" % [f.round + 1, f.total_rounds()])
	bits.append("%ds" % int(ceil(f.seconds_left())))
	# The word alone. Pips beside it pushed "N stuck" -- the one thing
	# you act on -- off the end of the line; the word already bands it.
	bits.append("hold %s" % f.composure_word())
	var vp := int(round(Game.voice * 4.0))
	bits.append("voice %s%s" % ["|".repeat(vp), ".".repeat(4 - vp)])


func _update_prompt() -> void:
	if mode != Mode.NONE:
		prompt.visible = false
		prompt_box.visible = false
		speech_box.visible = false
		mascot_box.visible = false
		mascot_portrait.visible = false
		return
	# a timed hint owns the prompt bar while it is up. The mascot is not
	# reset here -- it is only ever turned ON by principal_says(), and
	# turned off below the moment the hint itself expires, so it never
	# outlives the words it was said over.
	if _hint_until > Time.get_ticks_msec() / 1000.0:
		return
	mascot_box.visible = false
	mascot_portrait.visible = false
	_speech_style(false)
	# The OFFERS -- both buttons, always, every verb live where you stand --
	# are the coloured badges over the teacher's head (player.gd
	# _update_key_prompts()), with a hold meter on a held one. This bar used
	# to say the same thing again a screen away, word for word, clipped to
	# fit ("hold L ."). The owner agreed it should stop (Oct 2026 critique):
	# it is the speech box now and nothing else, so when nobody is talking
	# the bottom of the room is the room.
	#
	# What the badges inherited from the bar, and must keep: both buttons
	# named, never one target (stand at the noticeboard and the SHOP on F
	# must show beside the curriculum on E); and offers() rather than targets
	# directly, since a freed node read into a typed variable once killed
	# every button in the game.
	prompt.visible = false
	prompt_box.visible = false


# ------------------------------------------------------------- the move bar
## The mentor's three moves, bottom right: each one's icon, its key, and how
## soon it is back (Oct 2026, the owner's pick from that month's critique).
## Readiness used to be the LAST pips on the status strip -- the first thing
## the strip drops when it is full -- and a move you cannot see is ready is a
## move you do not use.
##
## Hide, don't grey: a slot is only there while its move can be used at all
## (taught, and for the two lesson moves, mid-lesson). What a slot shows is
## TIME: a shade over the icon that drains as the move comes back, and a
## flash the moment it is ready. Out of the way while someone is talking --
## the speech box owns the bottom of the screen for its few seconds.
const UI_SPEECH := preload("res://art/ui_speech.png")
const MOVE_SLOT := 40.0
const MOVE_ICON := 32.0
const MOVE_GAP := 4.0
const MOVES := [
	{"id": "dash", "action": "dash", "icon": preload("res://art/ui_move_dash.png")},
	{"id": "answer_all", "action": "answer_all", "icon": preload("res://art/ui_move_answer.png")},
	{"id": "call", "action": "call_response", "icon": preload("res://art/ui_move_call.png")},
]
## id -> {"root", "shade", "key", "was"}
var _move_slots: Dictionary = {}


func _build_move_bar() -> void:
	var pad := (MOVE_SLOT - MOVE_ICON) / 2.0
	for m: Dictionary in MOVES:
		var root := Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.size = Vector2(MOVE_SLOT, MOVE_SLOT)
		root.visible = false
		var frame := NinePatchRect.new()
		frame.texture = UI_SPEECH
		frame.size = root.size
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			frame.set_patch_margin(side, 8)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(frame)
		var icon := TextureRect.new()
		icon.texture = m["icon"]
		icon.position = Vector2(pad, pad)
		icon.size = Vector2(MOVE_ICON, MOVE_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon)
		# The recharge: ink over the icon, from the top, as tall as the wait
		# still left.
		var shade := ColorRect.new()
		shade.color = Color(INK.r, INK.g, INK.b, 0.6)
		shade.position = Vector2(pad, pad)
		shade.size = Vector2(MOVE_ICON, 0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
		var key := Label.new()
		key.add_theme_font_override("font", SPEECH_FONT)
		key.add_theme_font_size_override("font_size", UI_SMALL)
		key.add_theme_color_override("font_color", INK)
		key.add_theme_color_override("font_outline_color", Color(0.92, 0.89, 0.95))
		key.add_theme_constant_override("outline_size", 4)
		key.position = Vector2(2, MOVE_SLOT - 15)
		key.size = Vector2(MOVE_SLOT - 5, 12)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(key)
		add_child(root)
		_move_slots[m["id"]] = {"root": root, "shade": shade, "key": key, "was": 0.0}


## Can this move be used at all right now? (Not "is it recharged" -- that is
## the shade's job, not the slot's.)
func _move_usable(id: String) -> bool:
	match id:
		"dash":
			return Game.dash_taught
		"answer_all":
			return Game.answer_all_taught and Game.phase == Game.Phase.LESSON \
				and not Game.test_active
		"call":
			return Game.call_response_taught and Game.phase == Game.Phase.LESSON \
				and not Game.test_active and Game.fight == null
	return false


## How much of the wait is left, 0 (ready) .. 1 (just used). The call waits
## on two things -- its cooldown and enough voice -- and shows whichever is
## further off.
func _move_wait(id: String) -> float:
	match id:
		"dash":
			if _player != null and is_instance_valid(_player):
				return clampf(_player.dash_cooldown_fraction(), 0.0, 1.0)
		"answer_all":
			return clampf(Game.answer_all_cooldown
				/ maxf(0.01, Balance.answer_all_cooldown_seconds), 0.0, 1.0)
		"call":
			var cd := Game.call_cooldown / maxf(0.01, Balance.call_cooldown_seconds)
			var short := 1.0 - Game.voice / maxf(0.01, Balance.call_voice_cost)
			return clampf(maxf(cd, short), 0.0, 1.0)
	return 0.0


func _update_move_bar() -> void:
	var bar_on := mode == Mode.NONE and not speech_box.visible \
		and _player != null and is_instance_valid(_player)
	var shown: Array[String] = []
	for m: Dictionary in MOVES:
		var on := bar_on and _move_usable(String(m["id"]))
		(_move_slots[m["id"]]["root"] as Control).visible = on
		if on:
			shown.append(String(m["id"]))
	var x := SPEECH_RIGHT - shown.size() * (MOVE_SLOT + MOVE_GAP) + MOVE_GAP
	for m: Dictionary in MOVES:
		var id := String(m["id"])
		if not shown.has(id):
			continue
		var slot: Dictionary = _move_slots[id]
		var root := slot["root"] as Control
		root.position = Vector2(x, SPEECH_BOTTOM - MOVE_SLOT)
		x += MOVE_SLOT + MOVE_GAP
		var wait := _move_wait(id)
		(slot["shade"] as ColorRect).size.y = round(MOVE_ICON * wait)
		if wait <= 0.0 and float(slot["was"]) > 0.0:
			Fx.flash(root, Color(1.8, 1.8, 1.5), 0.3)
		slot["was"] = wait
		(slot["key"] as Label).text = Settings.binding_text(
			String(m["action"])).split(",")[0].strip_edges()


# ---------------------------------------------------------------- overlays

## Where the text sits on each page of the open book. The right page is
## where the content goes and the left page sets the scene, so `rich` (which
## both book screens already render into) moves to the RIGHT and `rich_left`
## picks up the heading.
# Widened from (340, 64, 248, 228) once the curriculum rows grew a fourth
# column: the paper in book_open.png runs to within 18px of the book edge
# and the gutter ends 12px off the spine, so the page had margin the text
# was not using.
const BOOK_RIGHT := Rect2(334, 64, 256, 228)
## (40..314 since the pixel font, Oct 2026: its title line is shorter than
## the old font's at 24, and the hint sits lower, so the body gained a row.)
const BOOK_RICH_HOME := Rect2(32, 40, 576, 274)
## Preloaded, not load()ed by name: the art audit scans the source for
## literal paths, and a frame built by string interpolation is invisible to
## it -- which is exactly the sort of orphan that scan exists to catch.
const FLIP_TEXTURES := [
	preload("res://art/book_flip0.png"),
	preload("res://art/book_flip1.png"),
	preload("res://art/book_flip2.png"),
	preload("res://art/book_flip3.png"),
]
const FLIP_FRAMES := 4
const FLIP_STEP := 0.045
## Which page the book is currently showing, so a TURN can be told from an
## OPEN. Every way of turning -- the wheel, a click, the keys, on either
## screen -- goes through the same render, so watching _sel here catches
## them all rather than hooking six call sites.
var _book_page_shown: int = -1


## Put the book under the screen, or take it away again.
##
## The dark Overlay stays: the room should still be dimmed behind, so the
## book reads as something held up in the classroom rather than a picture
## pasted over it. Only the text moves -- onto the right-hand page, with the
## heading on the left, which is why neither screen had to be rewritten,
## only re-laid-out.
func _book(on: bool) -> void:
	book.visible = on
	rich_left.visible = on
	if on and book.texture == null:
		book.texture = load("res://art/book_open.png")
	if on:
		rich.offset_left = BOOK_RIGHT.position.x
		rich.offset_top = BOOK_RIGHT.position.y
		rich.offset_right = BOOK_RIGHT.position.x + BOOK_RIGHT.size.x
		rich.offset_bottom = BOOK_RIGHT.position.y + BOOK_RIGHT.size.y
		# Ink on paper, not paper on ink. Every other screen in this game is
		# light text on a dark panel; this is the one that is the other way
		# round, and the colour has to follow or it is unreadable.
		rich.add_theme_color_override("default_color", Color(0.24, 0.2, 0.16))
	else:
		rich.offset_left = BOOK_RICH_HOME.position.x
		rich.offset_top = BOOK_RICH_HOME.position.y
		rich.offset_right = BOOK_RICH_HOME.position.x + BOOK_RICH_HOME.size.x
		rich.offset_bottom = BOOK_RICH_HOME.position.y + BOOK_RICH_HOME.size.y
		rich.remove_theme_color_override("default_color")


## A page sweeping across the spine. Four drawn frames stepped by a tween,
## the same trick the lesson-plan shuffle already uses -- long enough to
## read as a turn, short enough that paging through plans is not a chore.
func _play_page_flip() -> void:
	if not book.visible:
		return
	flip.visible = true
	var t := create_tween()
	for i in FLIP_FRAMES:
		t.tween_callback(_flip_frame.bind(i))
		t.tween_interval(FLIP_STEP)
	t.tween_callback(func() -> void: flip.visible = false)


## Called by a book screen once it knows which page it is drawing. Flips
## only when the page actually changed -- opening the book is not a turn.
func _book_turned(page: int) -> void:
	if _book_page_shown != -1 and _book_page_shown != page:
		_play_page_flip()
	_book_page_shown = page


func _flip_frame(i: int) -> void:
	flip.texture = FLIP_TEXTURES[i]
	Sfx.play_varied("paper")


func _open(m: int) -> void:
	# Which page the book is showing survives a re-open of the SAME screen,
	# because that is what a page turn is: show_curriculum()/show_hand() are
	# called again to draw the next page. Only moving to a different screen
	# forgets where you were.
	if mode != m:
		_book_page_shown = -1
	if m != Mode.INTRO:
		hide_dialogue()
	mode = m
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 6)
	# every mode that wants a portrait turns it back on; this is the
	# single line that stops one screen leaking into the next
	portrait.visible = false
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_at(PORTRAIT_HOME)
	portrait.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	portrait_bg.visible = false
	if _slot != null:
		_slot.visible = false
	_set_ideas_ui(false)
	mood_icon.visible = false
	# ...and the book, for the same reason.
	_book(false)
	flip.visible = false
	# the same single line that stops one screen leaking into the next
	rich.visible = false
	sheet.visible = false
	body.visible = true
	# ...and the intro slate's see-through backing and hidden hint, which it
	# only puts back when it moves on to its own next page. Any screen opened
	# with the slate still up -- or after it was closed from outside -- used to
	# keep both: text straight on the room, no footer (Oct 2026, seen in every
	# screenshot taken from a fresh run).
	if m != Mode.INTRO:
		overlay.color = OVERLAY_COLOUR
		hint.visible = true
	# ...and this one. Closing the exam starts a term; closing anything else
	# must not. show_exam() sets it again straight after this runs, so the
	# flag can only ever be true for the screen that set it.
	_showing_exam = false
	_showing_run_over = false
	_showing_new_term = false
	_hiring = false
	overlay.visible = true
	# a banner belongs to the room; it has no business under a report
	banner.visible = false
	if _player != null and is_instance_valid(_player):
		_player.input_locked = true


func close() -> void:
	mode = Mode.NONE
	overlay.visible = false
	hide_dialogue()
	# The book has to be put away here as well as in _open(). close() can be
	# reached without another screen ever opening -- show_hand() closes
	# itself when there is nothing to deal -- and a book left standing would
	# then be sitting under whatever opened next.
	_book(false)
	flip.visible = false
	_book_page_shown = -1
	if _player != null and is_instance_valid(_player):
		_player.input_locked = false


## The first thing anyone sees. The game used to boot straight into play
## with no explanation of anything at all.
##
## Sized to the panel deliberately, and NINE lines is the limit -- the
## suite's "the title screen fits" asserts it against PANEL_LINES_SMALL.
## The note here used to say SEVEN, from the pre-Aug-2026 320x176 body at
## font 8; the screen had already grown to eight lines and the number was
## quietly wrong, which is the kind of stale limit that stops the next
## person adding a line the screen needs. Earlier drafts ran off the
## bottom and overlapped the hint bar.
func show_title() -> void:
	_open(Mode.TITLE)
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 0)
	title.text = "E D U S Y S T E M"
	# This screen had gone stale. It still described only the original loop,
	# so a player who had just been given traits, disruption, a voice and
	# three assessments was told about none of them and quite reasonably
	# concluded that nothing had changed.
	body.text = "\n".join([
		"You are the teacher. WASD walks. What you can do",
		"floats over your head: E, F, and the rest. Tab: class.",
		"Teach at the PODIUM, then walk the room:",
		"  amber ? stuck     red ! playing up (it SPREADS)",
		"  blue ? behind     C settles who can hear you",
		"Collect on E, mark homework on H, ring the BELL",
		"on F. Q for a quick quiz; test a unit you know well.",
		# The STAKE, not just the clock. The status strip has printed
		# "need N" since the first minute of the game and nothing on the
		# way in ever said what it counted -- the only screen that
		# explains the target is the one BETWEEN terms, which you reach
		# by already having survived one. Same words as the end-of-term
		# verdict ("kept the job"), so it reads as the same promise.
		# `target_base`, not Game.term_target(): quit-to-title comes back
		# here, and term_target() would report the abandoned run's term.
		"%d days, then the exam. %d must pass to keep the job." % [
			Balance.term_days, Balance.term_target_base],
	])
	hint.text = "E - begin        %s" % BUILD_STAMP.stamp()


## The pause menu. Deliberately short: the full settings live on the title
## screen, and a pause menu that tries to be a second settings app is a
## great deal of duplicated UI for very little.
var _pause_sel: int = 0

func show_pause() -> void:
	_open(Mode.PAUSE)
	_pause_sel = 0
	Sfx.play("blip")
	_render_pause()


func _render_pause() -> void:
	title.text = "PAUSED"
	var rows := ["Resume", "The school  %d room%s" % [Game.rooms.size() + 1,
		"" if Game.rooms.is_empty() else "s"],
		"Your career  %d/%d" % [Game.milestones.size(), Milestones.count()],
		"Controls  (%s in play)" % Settings.binding_text("help"),
		"Sound  %s" % _vol_bar(), "Quit to title"]
	var lines: Array[String] = ["", ""]
	for i in rows.size():
		lines.append("      %s %s" % [">" if i == _pause_sel else " ", rows[i]])
	# No blank separator here: a sixth row (Controls) pushed this one line
	# past PANEL_LINES_SMALL, and the day line below earns its place more
	# than a spacer does.
	lines.append("      Day %d of %d, %s" % [Game.day, Balance.term_days, Game.subject])
	body.text = "\n".join(lines)
	hint.text = "Left/Right changes volume.  E picks."


## Resume / school / career / controls / sound / quit.
const PAUSE_ROWS := 6


func _vol_bar() -> String:
	var n := int(round(Settings.sfx_volume * 10.0))
	return "[%s%s]" % ["#".repeat(n), ".".repeat(10 - n)]


func _pause_input() -> void:
	if Input.is_action_just_pressed("move_down"):
		_pause_sel = (_pause_sel + 1) % PAUSE_ROWS
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_up"):
		_pause_sel = (_pause_sel + PAUSE_ROWS - 1) % PAUSE_ROWS
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		if _pause_sel == 4:
			var d := 0.1 if Input.is_action_just_pressed("move_right") else -0.1
			Settings.sfx_volume = clampf(Settings.sfx_volume + d, 0.0, 1.0)
			Settings.apply_audio()
			Settings.save_settings()
			Sfx.play("blip")
	elif Input.is_action_just_pressed("cancel"):
		close()
		return
	elif Game.claim_interact():
		if _pause_sel == 0:
			close()
			return
		elif _pause_sel == 1:
			_sel = 0
			show_school()
			return
		elif _pause_sel == 2:
			_sel = 0
			_career_page = CAREER_MILESTONES
			_alum_open = -1
			show_career()
			return
		elif _pause_sel == 3:
			show_help()
			return
		elif _pause_sel == 5:
			Game.save_game()
			close()
			get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
			return
	_render_pause()


## What every verb does, in one line each, keyed by action. The controls
## page on the title screen lists the bindings; this is the in-play sheet
## that says what they are FOR. Kept next to Settings.ACTIONS rather than
## inside it so the settings autoload stays about bindings, and asserted
## complete by the suite so a new verb cannot ship without a line here.
const HELP_LINES := {
	"move_up": "Walk. Every verb is somewhere you stand.",
	"move_down": "Walk.",
	"move_left": "Walk.",
	"move_right": "Walk.",
	"interact": "Help a stuck child, collect work, hand it in, clean up.",
	"manage": "Ring the bell, open the shop, step through a door.",
	"teach": "Start the lesson at the podium. Begin the paper on its day.",
	"quiz": "A quick quiz, mid-lesson. Costs time, tells you who is behind.",
	"answer_all": "Unstick the whole room at once. Long wait after.",
	"homework": "Mark the homework you collected, at your desk.",
	"grades": "Every grade you have given, read at your desk.",
	"move_desk": "Move a desk. Desks that touch get talking.",
	"voice": "Settle the desks within earshot.",
	"call_response": "Class, class! The room is with you a while, anywhere.",
	"build": "Rearrange the room from a free cursor. Not mid-lesson.",
	"autopilot": "Walk to whoever needs you. Never presses a button.",
	"auto_teach": "Hand the lesson to the simulation. Toggle.",
	"dash": "A burst of speed. Or double-tap a direction.",
	"skip_days": "Hand the room over and let a few days run without you.",
	"fullscreen": "Fill the screen, or give the window back.",
	"menu": "The class list. Cycles the shop's tabs.",
	"dashboard": "You: items, skills, wardrobe.",
	"watch": "Watch a delegated room's day, from the school board.",
	"fire": "Let a hired teacher go, from the school board.",
	"respond": "Answer the phone or the parent at your desk.",
	"pause": "Pause.",
	"help": "This sheet.",
}
## How many verbs the help sheet shows at once, leaving room for the
## heading and the window marker.
const HELP_ROWS := 8


## The in-play controls sheet: every verb, its key, and what it is for.
## Windowed like the Controls page, since the list is longer than the
## panel. Read-only -- rebinding stays on the title screen.
func show_help() -> void:
	_open(Mode.HELP)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	var acts: Array = Settings.ACTIONS
	_sel = clampi(_sel, 0, maxi(0, acts.size() - 1))
	var lo := _window_start(acts.size(), HELP_ROWS)
	title.text = "WHAT THE KEYS DO   %d-%d of %d" % [
		lo + 1, mini(acts.size(), lo + HELP_ROWS), acts.size()]
	var lines: Array[String] = []
	for i in range(lo, mini(acts.size(), lo + HELP_ROWS)):
		var a := String((acts[i] as Dictionary).get("action", ""))
		lines.append("[color=#%s]%s[/color] [color=#%s]%-6s[/color] %s" % [
			C_ROOM if i == _sel else DIM, ">" if i == _sel else " ",
			C_COIN, Settings.binding_text(a).substr(0, 6),
			_clip(String(HELP_LINES.get(a, String((acts[i] as Dictionary).get("label", "")))))])
	rich.text = "\n".join(lines)
	_reveal_rich(0.2)
	hint.text = "Up/Down more    Esc or %s - close    (rebind on the title screen)" % \
		Settings.binding_text("help")


func _handle_help_input() -> void:
	var n: int = Settings.ACTIONS.size()
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("help") \
			or Game.claim_interact():
		Sfx.play("blip")
		close()
	elif Input.is_action_just_pressed("move_down"):
		_sel = (_sel + 1) % n
		Sfx.play("blip")
		show_help()
	elif Input.is_action_just_pressed("move_up"):
		_sel = (_sel - 1 + n) % n
		Sfx.play("blip")
		show_help()


## Move the corner's words between the dark key-prompt bar and the white
## speech box. `text` sizes the box: it grows upward a line at a time, so a
## long tip wraps onto the paper instead of running off the screen's edge --
## which the old single-line bar did with anything past ~47 characters.
func _speech_style(on: bool, text: String = "") -> void:
	speech_box.visible = on
	if on:
		prompt_box.visible = false
		var w := SPEECH_RIGHT - SPEECH_LEFT - SPEECH_PAD.x * 2.0
		var line_h := SPEECH_FONT.get_height(SPEECH_SIZE)
		var lines := maxi(1, roundi(SPEECH_FONT.get_multiline_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, w, SPEECH_SIZE).y / line_h))
		var need := lines * line_h + (lines - 1) * SPEECH_LINE_GAP
		var h := maxf(SPEECH_MIN_H, ceilf(need) + SPEECH_PAD.y * 2.0)
		speech_box.position = Vector2(SPEECH_LEFT, SPEECH_BOTTOM - h)
		speech_box.size = Vector2(SPEECH_RIGHT - SPEECH_LEFT, h)
		prompt.position = speech_box.position + SPEECH_PAD
		prompt.size = Vector2(w, h - SPEECH_PAD.y * 2.0)
	if on == _speaking:
		return
	_speaking = on
	if on:
		prompt.add_theme_font_override("font", SPEECH_FONT)
		prompt.add_theme_font_size_override("font_size", SPEECH_SIZE)
		prompt.add_theme_color_override("font_color", INK)
		prompt.add_theme_constant_override("line_spacing", SPEECH_LINE_GAP)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		prompt.remove_theme_font_override("font")
		prompt.remove_theme_font_size_override("font_size")
		prompt.remove_theme_color_override("font_color")
		prompt.remove_theme_constant_override("line_spacing")
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
		prompt.position = PROMPT_HOME.position
		prompt.size = PROMPT_HOME.size


## A one-off nudge, shown once per run. Silence is the worst teacher.
##
## Kept as the plain text-only version -- nothing currently calls it
## instead of principal_says(), but a tip that needs to fire from a place
## with no room to draw a portrait (mid-transition, say) has somewhere to
## go that is not "invent a face for it".
func hint_once(id: String, text: String) -> void:
	if _shown_hints.has(id) or mode != Mode.NONE or not Settings.show_hints:
		return
	_shown_hints[id] = true
	prompt.visible = true
	prompt_box.visible = true
	prompt.text = text
	_hint_until = Time.get_ticks_msec() / 1000.0 + 4.0


## The principal, appearing in the corner to explain something -- the same
## once-per-run nudge as hint_once, with a face on it. This is the mascot
## the tutorial content actually speaks through now; every hint in the game
## goes through here rather than through the plain text-only version.
func principal_says(id: String, text: String) -> void:
	if _shown_hints.has(id) or mode != Mode.NONE or not Settings.show_hints:
		return
	_shown_hints[id] = true
	_speech_style(true, text)
	prompt.visible = true
	prompt.text = text
	# The dedicated bust (Sept 2026 art pass), not a cropped sheet frame --
	# a real face at the corner's own size instead of a desk-distance
	# 32x48 walk frame stretched up to it.
	mascot_portrait.texture = PRINCIPAL_PORTRAIT
	mascot_portrait.visible = true
	mascot_box.visible = true
	_hint_until = Time.get_ticks_msec() / 1000.0 + 5.0


## Hints parked until the player is next in free roam (mode NONE). The
## mentor nudge needs this: it fires from Game.day_changed, which lands
## while the day report is still on screen, so principal_says() would just
## no-op. _process() drains one entry per frame nothing else is up.
##
## A real FIFO, not a single slot -- step 10 of the ten-commit queue added
## a second same-day nudge (crafting unlocking) that fires from the exact
## same day_changed signal as the mentor one. A single overwritten slot
## meant the second call silently ate the first's nudge whenever both
## landed on the same day; queueing lets both still get shown, one after
## the other.
var _queued_hint: Array = []
## Gates when the NEXT queued entry may drain -- deliberately separate from
## `_hint_until`, which principal_says()/hint_once()/show_day_beat() all
## also write. Gating on that shared field meant a stray value left over
## from an unrelated, much earlier popup (still in its own display window)
## could block a brand new queued hint from ever showing at all. 0.0 so
## the very first drain is never blocked by anything.
var _next_queued_hint_at: float = 0.0

func queue_hint(id: String, text: String) -> void:
	if _shown_hints.has(id) or not Settings.show_hints:
		return
	# Don't pile up a second copy of the same id while one is still
	# pending -- a signal that fires often (Game.new_run()'s run_started,
	# say) would otherwise queue a duplicate every single time until the
	# first one finally drains.
	for q: Array in _queued_hint:
		if String(q[0]) == id:
			return
	_queued_hint.append([id, text])


## The day's beat -- the teacher's own line, over their portrait, at the
## bottom of the screen: the run narrating itself. It shares the corner
## popup's nodes with principal_says() but it is NOT a tutorial -- no
## once-per-run dedup, no show_hints gate, and it repeats (a fresh line
## most mornings of a boss term). DayBeats owns the words; this shows them.
## The text types on rather than snapping in -- _process() drives the
## reveal, and _update_prompt() already leaves the bar alone while
## _hint_until is in the future.
func show_day_beat(text: String) -> void:
	if text.is_empty() or mode != Mode.NONE:
		return
	_beat_full = text
	_beat_chars = 0
	_speech_style(true, text)
	prompt.text = ""
	prompt.visible = true
	mascot_portrait.texture = PLAYER_PORTRAIT
	mascot_portrait.visible = true
	mascot_box.visible = true
	# up long enough to read the whole line AFTER it finishes typing on
	_hint_until = Time.get_ticks_msec() / 1000.0 + 2.5 + 0.035 * float(text.length())


var _queued_beat: String = ""
var _beat_full: String = ""
var _beat_chars: int = 0

## Park a beat until the player is back in free roam -- day_changed and
## term_began both fire with a report still on screen, exactly like the
## mentor nudge.
func queue_day_beat(text: String) -> void:
	if not text.is_empty():
		_queued_beat = text


# -------------------------------------------------------- pokemon dialogue box
## Display a Pokémon-style dialogue box on the lower portion of the screen,
## with a speaker name tag, portrait frame, typewriter text reveal, and advance arrow.
func say_dialogue(speaker: String, portrait_tex: Texture2D, text: String, instant: bool = false) -> void:
	if dialogue_box == null:
		return
	_dialogue_full_text = text
	_dialogue_char_timer = 0.0
	_arrow_bob = 0.0
	_blip_counter = 0

	dialogue_speaker.text = speaker
	if portrait_tex != null:
		dialogue_portrait.texture = portrait_tex
		dialogue_portrait.visible = true
		dialogue_portrait_border.visible = true
		dialogue_portrait_bg.visible = true
		dialogue_text.offset_left = 104.0
		dialogue_text.offset_right = 592.0
	else:
		dialogue_portrait.visible = false
		dialogue_portrait_border.visible = false
		dialogue_portrait_bg.visible = false
		dialogue_text.offset_left = 20.0
		dialogue_text.offset_right = 592.0

	dialogue_box.visible = true

	if instant or Game.save_path != Game.SAVE_PATH:
		_dialogue_typing = false
		_dialogue_visible_chars = text.length()
		dialogue_text.text = text
		dialogue_advance.visible = true
	else:
		_dialogue_typing = true
		_dialogue_visible_chars = 0
		dialogue_text.text = ""
		dialogue_advance.visible = false


func hide_dialogue() -> void:
	if dialogue_box != null:
		dialogue_box.visible = false
	_dialogue_typing = false
	_dialogue_full_text = ""


func is_dialogue_typing() -> bool:
	return _dialogue_typing


func finish_dialogue_typing() -> void:
	_dialogue_typing = false
	_dialogue_visible_chars = _dialogue_full_text.length()
	if dialogue_text != null:
		dialogue_text.text = _dialogue_full_text
	if dialogue_advance != null:
		dialogue_advance.visible = true


## A line across the top of the room, faded in, gone after `seconds`. The
## boss paper's questions come through here; anything else the whole room
## should read at once can too.
func show_banner(text: String, seconds: float = 4.0) -> void:
	if text.is_empty():
		return
	banner.text = _clip(text)
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_until = Time.get_ticks_msec() / 1000.0 + seconds


var _hint_until: float = 0.0
var _banner_until: float = 0.0


## YOUR OWN DASHBOARD. Not a landmark verb -- you are not standing anywhere
## specific to ask "who am I, what do I have" -- so it lives on its own key
## (I), the same way the class list and pause already do not compete with
## E/F. Those two stay exactly what they were: E is the mashable verb, F is
## session-level, and neither of them gained a third or fourth job here.
##
## Three pages, cycled with the same "menu" key the shop already cycles its
## own tabs with: OVERVIEW (who you are, how many children, your level),
## ITEMS (what you have bought, by category), SKILLS (every perk you have
## spent points on, read-only -- spending them is still the staff room's
## job; this is a mirror, not a second till).
func show_dashboard() -> void:
	_open(Mode.DASHBOARD)
	# THE BUG THIS FIXES: every other screen sets its own title.text, but
	# this one never did -- _open() does not clear it, so the dashboard
	# silently kept showing whatever the PREVIOUS screen's title was.
	# Open Career, close it, then open the dashboard with I, and it read
	# "YOUR CAREER 6/23" over the tab strip. Confirmed by screenshot.
	title.text = "YOUR DASHBOARD"
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	_render_dashboard()


func _render_dashboard() -> void:
	Balance.ensure_loaded()
	var lines: Array[String] = []
	var tabs := ["Overview", "Items", "Skills", "Wardrobe"]
	var strip := ""
	for i in tabs.size():
		strip += "[color=#%s]%s[/color]  " % [
			C_LESSON if i == _dash else DIM, tabs[i]]
	lines.append(strip)
	lines.append("")

	# OVERVIEW and WARDROBE both want the portrait -- the latter is the
	# whole point of the page, seeing the hat actually sit on your own
	# character rather than reading its name off a list. _render_dashboard()
	# is called directly when cycling pages (not through _open(), which is
	# the usual place a portrait gets hidden again), so this has to manage
	# it itself or a stale portrait would follow you onto Items/Skills.
	portrait.visible = (_dash == Dash.OVERVIEW or _dash == Dash.WARDROBE)
	# The "Background" cosmetic: a flat colour behind the portrait, on
	# both pages that show it. An empty/"none" colour has alpha 0, so it
	# stays invisible without a separate visibility flag to manage.
	portrait_bg.visible = portrait.visible
	# Same leak portrait/portrait_bg already had to be guarded against --
	# this is called directly when cycling pages, not just through
	# _open(), so a stale mood face would follow Overview onto Items/
	# Skills/Wardrobe without this.
	mood_icon.visible = (_dash == Dash.OVERVIEW)
	portrait_bg.color = Color(Cosmetics.background_by_id(Game.background_id).get("colour", Color(0, 0, 0, 0)))
	if _dash == Dash.WARDROBE:
		portrait.texture = load("res://art/portrait_player.png")

	match _dash:
		Dash.OVERVIEW:
			lines.append_array(_render_dash_overview())
		Dash.ITEMS:
			lines.append_array(_render_dash_items())
		Dash.SKILLS:
			lines.append_array(_render_dash_skills())
		Dash.WARDROBE:
			lines.append_array(_render_dash_wardrobe())

	rich.text = "
".join(lines)
	rich.visible_ratio = 1.0
	hint.text = "Up/Down row   Left/Right choose   E / Esc - close" 		if _dash == Dash.WARDROBE else "Tab - next page    E / Esc - close"


## Who you are, at a glance. The character portrait is the hook for the
## cosmetic slots that are coming -- a hat and a background are asked for
## and explicitly NOT built yet, so the two lines are placeholders that
## read honestly as "not chosen" rather than as a broken feature.
func _render_dash_overview() -> Array[String]:
	portrait.texture = load("res://art/portrait_player.png")   # visibility is handled by _render_dashboard()
	# The face alone carries the grade band -- no new text line, since
	# this panel is already at its line budget (see the note below).
	# Visibility is handled by _render_dashboard(), same as portrait.
	var letter := Game.grade_letter(Game.class_average())
	var mood_state := "good" if letter in ["A", "B"] \
		else "ok" if letter in ["C", "D"] else "struggling"
	mood_icon.texture = load("res://art/mood_%s.png" % mood_state)

	# The panel does not scroll (scroll_active = false on Rich in
	# hud.tscn) -- content past its 128px height clips SILENTLY, and that
	# clip point sits below what the raw line count suggests once
	# font-8/line-separation-2 is accounted for. Learned the hard way:
	# a 10-line version of this page visibly cut its last row. Kept
	# deliberately short, with real margin, rather than exactly at
	# whatever the budget arithmetic claims should just barely fit.
	var lines: Array[String] = []
	lines.append("[color=#%s]Level %d[/color]   [color=#%s]%s[/color]" % [
		C_KNOW, Game.teacher_level, DIM,
		Curriculum.strand_label(Game.specialism) if Game.specialism != ""
			else "no speciality yet"])
	lines.append("[color=#%s]Class[/color]      %d of %d seats" % [
		DIM, Game.roster.size(), Game.seat_capacity()])
	lines.append("[color=#%s]Furniture[/color]  %d piece%s, %d coins" % [
		DIM, Game.room_items.size(), "" if Game.room_items.size() == 1 else "s",
		Game.coins])
	# A day-count progress bar -- calendar/time, not a judgement of a
	# child, so it is outside the prose-not-numbers rule the mood icon
	# above has to carry an explicit exception note for (day counters are
	# the sanctioned case; see CLAUDE.md). Same pip-bar convention the
	# teaching HUD's own "voice" meter already uses ("|".repeat(pips)),
	# not a new visual language.
	var term_days: int = Balance.term_days
	var pips: int = int(round(8.0 * float(Game.day) / float(maxi(term_days, 1))))
	lines.append("[color=#%s]Term[/color]       day %d of %d  [%s%s]" % [
		DIM, Game.day, term_days, "|".repeat(pips), ".".repeat(8 - pips)])
	lines.append("")
	# Deliberately unimplemented -- see the function doc above.
	lines.append("[color=#%s]Hat[/color]         none chosen yet" % DIM)
	lines.append("[color=#%s]Background[/color]  none chosen yet" % DIM)
	return lines


## What you have bought, by category -- a count and what it is worth to a
## desk, not the tile-by-tile list the shop's own SELL tab already gives
## you. Reading "what have I got" a category at a time is the thing a
## dashboard is for; reading "which exact item is at which exact tile" is
## still the sell list's job.
func _render_dash_items() -> Array[String]:
	var lines: Array[String] = []
	if Game.room_items.is_empty():
		lines.append("[color=#%s]Nothing bought yet.[/color]" % DIM)
		return lines
	var counts: Dictionary = {}
	var worth: Dictionary = {}
	for placed: Dictionary in Game.room_items:
		var id := String(placed.get("id", ""))
		var cat := Items.category_of(id)
		counts[cat] = int(counts.get(cat, 0)) + 1
		worth[cat] = float(worth.get(cat, 0.0)) + float(Items.get_def(id).get("bonus", 0.0))
	for cat: String in Items.categories():
		if not counts.has(cat):
			continue
		lines.append("[color=#%s]%-10s[/color] %2d   %s" % [
			cat_colour(cat), Items.category_label(cat), int(counts[cat]),
			_worth_bar(float(worth[cat]))])
	lines.append("")
	lines.append("[color=#%s]%d piece%s, worth %d coins new[/color]" % [
		DIM, Game.room_items.size(), "" if Game.room_items.size() == 1 else "s",
		_room_spend()])
	return lines


## What is currently standing in the room would cost to buy again -- there
## is no purchase-history ledger, so this is "worth", not "spent".
func _room_spend() -> int:
	var total := 0
	for placed: Dictionary in Game.room_items:
		total += Items.cost(String(placed.get("id", "")))
	return total


## The same rank bars the staff room draws, without a cursor and without
## the "E to spend a point" hint -- spending stays the staff room's job.
## A summary, not a full listing -- deliberately, since this page has no
## cursor to window with the way the (now-windowed) Staff Room does. Eleven
## perks stopped fitting the moment six landed alongside the roguelike
## pivot's skill list; a fixed row budget that scales with however many
## perks the game eventually has needs a summary here, not a growing list.
func _render_dash_skills() -> Array[String]:
	var lines: Array[String] = []
	lines.append("[color=#%s]%d point%s unspent[/color]" % [
		C_COIN, Game.perk_points_free(),
		"" if Game.perk_points_free() == 1 else "s"])
	lines.append("")
	var order := Progress.perk_order()
	if order.is_empty():
		lines.append("[color=#%s]No perks defined.[/color]" % DIM)
		return lines
	var ranked := 0
	for id: String in order:
		if Game.perk_rank(id) > 0:
			ranked += 1
	lines.append("[color=#%s]%d of %d skills trained[/color]" % [
		C_LESSON if ranked > 0 else DIM, ranked, order.size()])
	lines.append("")
	lines.append("[color=#%s]See the Staff Room for the full list and[/color]" % DIM)
	lines.append("[color=#%s]what each rank does.[/color]" % DIM)
	return lines


## Hat and background -- the two lines the OVERVIEW page has read "none
## chosen yet" on since the dashboard was first built. _sel picks the
## row (0 = hat, 1 = background); Left/Right steps through that row's
## own list. Nothing here is a landmark verb or touches a grade -- it is
## exactly as decorative as it looks, the same as a hat is everywhere
## else in this genre.
func _render_dash_wardrobe() -> Array[String]:
	_sel = clampi(_sel, 0, 1)
	var lines: Array[String] = []
	lines.append("[color=#%s]%sHat[/color]         %s" % [
		C_LESSON if _sel == 0 else DIM, ">" if _sel == 0 else " ",
		String(Cosmetics.hat_by_id(Game.hat_id).get("name", "None"))])
	lines.append("[color=#%s]%sBackground[/color]  %s" % [
		C_LESSON if _sel == 1 else DIM, ">" if _sel == 1 else " ",
		String(Cosmetics.background_by_id(Game.background_id).get("name", "None"))])
	return lines


## Step the hat or the background (whichever row _sel is on) one entry
## along its own list, wrapping. Takes effect immediately, same as
## Settings' own Left/Right sliders -- there is no separate confirm step
## for something this low-stakes.
func _adjust_wardrobe(dir: int) -> void:
	if _sel == 0:
		var i := (Cosmetics.hat_index(Game.hat_id) + dir + Cosmetics.HATS.size()) 				% Cosmetics.HATS.size()
		Game.hat_id = String(Cosmetics.HATS[i]["id"])
		if _player != null and is_instance_valid(_player) and _player.has_method("refresh_hat"):
			_player.refresh_hat()
	else:
		var i := (Cosmetics.background_index(Game.background_id) + dir
			+ Cosmetics.BACKGROUNDS.size()) % Cosmetics.BACKGROUNDS.size()
		Game.background_id = String(Cosmetics.BACKGROUNDS[i]["id"])
	Sfx.play("blip")
	_render_dashboard()


## Everyone in the room, what they are good at, and how they have been doing.
## Eight names and eight sprites do not make eight people if the player can
## never see anything that distinguishes them.
func show_class_list(keep_sel: bool = false) -> void:
	_open(Mode.CLASS_LIST)
	if not keep_sel:
		_sel = 0
	_sel = clampi(_sel, 0, maxi(0, Game.roster.size() - 1))
	_render_class_list()


## Split out from show_class_list so moving the selection can redraw without
## re-running _open(), which would re-lock the player and reset the font on
## every single keypress.
func _render_class_list() -> void:
	title.text = "YOUR CLASS"
	# eight students plus a three-line lesson header does not fit at the
	# default size; the panel is 128px and this needs about 13 rows
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 0)
	var lines: Array[String] = []
	# The objective is the source document's own wording, so a player can
	# see what the lesson is genuinely for rather than just a subject word.
	# Two header lines, not three. Eight students plus a three-line header
	# is one line more than the panel holds, and the objective is on the
	# noticeboard as well.
	lines.append(_clip("Today: %s  [%s]" % [
		String(Game.lesson.get("name", "")),
		String(Game.lesson.get("standard", ""))]))
	# No column header. A full class is eight rows and the panel holds nine
	# lines including the lesson line, so the header was the difference
	# between showing everyone and hiding whoever sits in seat eight.
	for i in Game.roster.size():
		var s: StudentData = Game.roster[i]
		var notes: Array[String] = []
		# The trait first: it is the note that changes what you DO.
		var tname := Traits.name_of(s.trait_id)
		if tname != "":
			notes.append(tname.to_lower())
		if s.aptitude >= 0.65:
			notes.append("quick")
		elif s.aptitude <= 0.4:
			notes.append("needs time")
		if s.diligence >= 0.65:
			notes.append("reliable")
		elif s.diligence <= 0.4:
			notes.append("forgets hw")
		# `misjudged` is deliberately NOT shown. It is derived from
		# hw_true_accuracy, which is hidden on purpose, so printing it would
		# hand the player the answer to the marking game for free and make
		# careful marking pointless.
		lines.append("%s %-10s %-9s %-5s %s" % [
			">" if i == _sel else " ",
			s.first_name(), Curriculum.strand_label(s.favourite),
			"-" if s.grades.is_empty() else Game.grade_letter(s.average_grade()),
			", ".join(notes)])
	body.text = "\n".join(lines)
	hint.text = "Up/Down choose    E their file    Esc close"


## One student's file.
##
## Everything here is something the game actually tracked — no invented
## backstory — and every number is turned into a letter, a count of days, or
## a word. Never a float, never a percentage: you should come to know a child
## by teaching them, not by reading a statistic off a screen.
func show_student(s: StudentData) -> void:
	if s == null:
		return
	if _bio != s:
		_bio_page = BIO_FILE      # a file just opened always starts on page one
	_bio = s
	_open(Mode.STUDENT)
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 0)

	title.text = s.display_name
	if title.text.length() > 22:
		title.text = "%s %s." % [s.first_name(), s.surname().substr(0, 1)]

	# The dedicated bust (Sept 2026 art pass) -- a face, not a walk-cycle
	# frame stretched up to portrait size.
	portrait.texture = load("res://art/portrait_%s.png" % s.art)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_at(PORTRAIT_FILE)
	portrait.visible = true

	if _bio_page == BIO_STORY:
		_render_student_story(s)
		return
	if _bio_page == BIO_ACTING:
		_render_student_acting(s)
		return

	# The portrait sits top-RIGHT and the text runs full width beneath it.
	# An earlier version put the portrait on the left and indented the text
	# with spaces to clear it -- but a space is about 2px at font 8, not the
	# 5 that assumed, so the portrait was drawn straight over the words.
	var lines: Array[String] = []
	lines.append("Seat %d, joined on day %d." % [s.seat_index + 1, s.joined_day])
	lines.append(_ability_line(s))
	lines.append(_subject_line(s))
	lines.append(_grades_line(s))
	lines.append(_homework_line(s))
	lines.append(_help_line(s))
	# No blank separator. With every line filled in -- a full transcript, a
	# marked sheet, ready to move up -- the file is exactly at the panel's
	# limit, and the "> " markers already tell the actions from the prose.
	lines.append_array(_bio_actions(s))
	body.text = "\n".join(lines)
	hint.text = "Tab their story   Up/Down choose   E do it   Esc back"


## Page three: everything acting on this child RIGHT NOW, as prose.
##
## The point of this page is a question the game could not answer before:
## "why is THIS one struggling?" Every pull on a child was real and none of
## it was legible -- their trait, the day, the room, where you happen to be
## standing, what they are doing to themselves.
##
## It NAMES each influence and which way it pulls. It never prints the
## value, because the rule this whole file obeys is that the stored data
## keeps the numbers and only the screen bends -- and a page of decimals
## about a child is exactly what that rule exists to prevent. You are meant
## to read this the way a teacher reads a room, not the way a spreadsheet
## reads a row.
##
## Ordered worst-first: what is holding them back comes before what is
## helping, because the reason you opened this page is that something is
## wrong. Capped to the panel budget, so a child with everything going on
## still fits.
func _render_student_acting(s: StudentData) -> void:
	# The builder itself lives in StudentRead.acting_on() now -- shared with
	# the in-room read above a desk, so the two can never disagree about a
	# child. See scripts/data/student_read.gd for why it moved.
	var read := StudentRead.acting_on(s)
	var against: Array[String] = read.get("against", [])
	var helping: Array[String] = read.get("helping", [])

	var lines: Array[String] = []
	if against.is_empty() and helping.is_empty():
		lines.append("Nothing much is pulling on them either way today.")
	else:
		if not against.is_empty():
			lines.append("AGAINST THEM")
			lines.append_array(against)
		if not helping.is_empty():
			if not against.is_empty():
				lines.append("")
			lines.append("FOR THEM")
			lines.append_array(helping)
	# The panel is the panel. Anything past it is the least urgent thing on
	# a page that is already ordered worst-first.
	if lines.size() > 11:
		lines = lines.slice(0, 11)
	body.text = "
".join(lines)
	hint.text = "Tab back to the file    Esc back"


## Page two of a child's file: what actually HAPPENED to them, as prose.
## The transcript arc, then the notable-moments reel rendered from its kind
## ids to sentences HERE -- which is how "prose, never numbers" stays a
## rule the stored data obeys and only the screen bends. Read-only: no
## actions, so Up/Down/E do nothing here and only Tab / Esc are live.
func _render_student_story(s: StudentData) -> void:
	var lines: Array[String] = []
	lines.append(_transcript_line(s))
	lines.append("")
	var story := _moments_prose(s)
	if story.is_empty():
		lines.append("Nothing has stood out yet -- early days for them.")
	else:
		lines.append_array(story)
	body.text = "\n".join(lines)
	hint.text = "Tab what's acting on them    Esc back"


## The notable-moments reel, as at most four sentences. Grouped by kind so
## a child who got stuck ten times reads as "got stuck a lot", not ten
## lines. Ordered by when each kind first happened, so it runs start to
## finish and a graduation lands last.
func _moments_prose(s: StudentData) -> Array[String]:
	if s.moments.is_empty():
		return []
	var order: Array[String] = []
	var first_day := {}
	var count := {}
	for m: Dictionary in s.moments:
		var k := String(m.get("kind", ""))
		if not order.has(k):
			order.append(k)
			first_day[k] = int(m.get("day", 0))
		count[k] = int(count.get(k, 0)) + 1
	var out: Array[String] = []
	for k: String in order:
		var line := _moment_sentence(k, int(count[k]), int(first_day[k]), s)
		if line != "":
			out.append(line)
	if out.size() > 4:
		out = out.slice(0, 2) + out.slice(out.size() - 2)
	return out


## One kind of moment, in a sentence. `n` is how many times it happened,
## `day` the first time. Never a number in the returned text.
func _moment_sentence(kind: String, n: int, day: int, s: StudentData) -> String:
	var when := "early on" if day <= s.joined_day + 3 else "later"
	match kind:
		"got_stuck":
			if n > 1:
				return "Got stuck a lot at first, the work stalling until someone came over."
			return "Hit a wall early on and needed a hand to get going again."
		"quiz_caught":
			return "A quiz caught them out %s -- the first clear sign they had slipped behind." % when
		"grade_jump":
			if n > 1:
				return "Their work came together in bursts, jumping a grade more than once."
			return "Their work jumped a whole grade %s, the day it clicked." % when
		"grade_drop":
			if n > 1:
				return "Lost a grade more than once, and clawed it back each time."
			return "Slid a grade for a stretch %s before finding their feet." % when
		"kept_back":
			if n > 1:
				return "Was not ready at the bell more than once, and stayed on each time."
			return "Was not ready when the term ended, and stayed on for another."
		"rose_to_paper":
			return "Rose to the paper on the day, while the room around them wobbled."
		"froze_on_paper":
			return "Froze on the paper more than once, and carried that morning for a while."
		"graduated":
			return "Left your class ready for what came next."
		"caught_flare":
			if n > 1:
				return "Reached them before it went off more than once -- you know their tells now."
			return "Caught it before it went off %s, calm again before it spread." % when
		"never_stuck":
			return "Went a whole term without ever once getting stuck."
		"favourite_streak":
			if n > 1:
				return "Strung together lessons in their best subject more than once."
			return "Strung together several lessons in their best subject, one after another."
		"helped_neighbour":
			return "Helped the child beside them for the first time, without being asked."
		"got_chatting":
			return "Got talking to the desk beside them %s, and the work stopped while they did." % when
		"worked_it_out":
			return "Looked it up in their study folder %s and got going again on their own." % when
		"fire_drill":
			return "Filed out for a fire drill %s, and filed straight back in." % when
	return ""


## What you can DO for this child. The file was read-only; spending on one
## student, and choosing when to send them up, are the two decisions that
## make it worth opening.
func _bio_actions(s: StudentData) -> Array[String]:
	Balance.ensure_loaded()
	var out: Array[String] = []
	var tuition := s.coaching_cost(Balance.coach_tuition_cost)
	var parents := s.coaching_cost(Balance.coach_parents_cost)

	var t_label := "Extra tuition            %d" % tuition
	var p_label := "A word with their parents %d" % parents
	if not s.can_be_coached():
		t_label = "Extra tuition            (had enough)"
		p_label = "A word with their parents (had enough)"

	var g_label := "Send them up             not ready yet"
	if s.is_ready_to_graduate():
		var extra := maxi(0, s.level - Balance.stu_ready_level)
		g_label = "Send them up             +%d coins" % [
			Balance.grad_base_coins + Balance.grad_coins_per_level * extra]

	# The "learned all they can" note rides on the Send-them-up row rather
	# than taking a line of its own: the file is already at the panel's
	# limit, and an extra line here pushes an ACTION off the bottom -- which
	# is the half of the screen you can actually press.
	if s.is_capped():
		g_label += "  (all they can learn)"
	var labels := [t_label, p_label, g_label]
	for i in labels.size():
		out.append(_clip("%s %s" % [">" if i == _bio_sel else " ", labels[i]]))
	return out


## What they are good at, and what they have turned out to be good at.
##
## Folded into ONE line rather than given its own. The file already runs to
## seven lines of a panel that holds about six, and every line added here
## pushes an ACTION off the bottom -- which is the half of the screen you
## can actually press.
func _subject_line(s: StudentData) -> String:
	var line := "Best at %s." % Curriculum.strand_label(s.favourite)
	var best := s.best_subject()
	if best != "" and s.transcript.size() >= 2:
		line += "  Strongest so far: %s." % best
	return line


## What this child has actually been taught, in one line.
##
## Their record, not the class's. It is the difference between "a student"
## and "this student", and it is what makes sending them up feel like
## something happening to somebody.
func _transcript_line(s: StudentData) -> String:
	if s.transcript.is_empty():
		return "No record yet -- they have not sat a lesson."
	var subjects := {}
	for row: Dictionary in s.transcript:
		subjects[String(row.get("name", ""))] = true
	var best := s.best_subject()
	var line := "%d lesson%s on record, across %d subject%s." % [
		s.transcript.size(), "" if s.transcript.size() == 1 else "s",
		subjects.size(), "" if subjects.size() == 1 else "s"]
	if best != "" and subjects.size() > 1:
		line += "  Strongest in %s." % best
	return line


## How this child works, in one line.
##
## The TRAIT wins when there is one, because it is the more useful sentence:
## "will not say when they are lost" tells you what to do about them, and
## "works at a steady pace" does not. Pace is still shown when there is no
## trait to say anything better.
func _ability_line(s: StudentData) -> String:
	var blurb := Traits.blurb(s.trait_id)
	if blurb != "":
		return blurb
	if s.aptitude >= 0.65:
		return "Picks things up quickly."
	if s.aptitude <= 0.40:
		return "Needs a bit longer than most."
	return "Works at a steady pace."


func _grades_line(s: StudentData) -> String:
	if s.grades.is_empty():
		return "Not been graded yet."
	var line := "Averaging a %s over %d lesson%s" % [
		Game.grade_letter(s.average_grade()), s.grades.size(),
		"" if s.grades.size() == 1 else "s"]
	# trend: their latest grade against everything before it
	if s.grades.size() >= 3:
		var earlier := 0.0
		for i in s.grades.size() - 1:
			earlier += s.grades[i]
		earlier /= float(s.grades.size() - 1)
		var d: float = s.grades[s.grades.size() - 1] - earlier
		if d > 0.05:
			return line + ", and improving."
		if d < -0.05:
			return line + ", and slipping."
	return line + "."


func _homework_line(s: StudentData) -> String:
	if s.hw_set_total <= 0:
		# nothing to go on yet, so fall back to their disposition
		return ("Usually remembers homework." if s.diligence >= 0.55
			else "Forgets homework more often than not.")
	var ratio := float(s.hw_done_total) / float(s.hw_set_total)
	var how := "none"
	if ratio >= 0.95:
		how = "all"
	elif ratio >= 0.7:
		how = "most"
	elif ratio >= 0.4:
		how = "about half"
	elif ratio > 0.0:
		how = "hardly any"
	return "Has handed in %s of the homework set." % how


func _help_line(s: StudentData) -> String:
	if s.helps_total <= 0:
		return "You have never gone over to help them."
	if s.helps_total == 1:
		return "You have gone over to help them once."
	if s.helps_total <= 4:
		return "You have gone over to help them a few times."
	return "You have gone over to help them often."


## End of term. The whole run, scored.
func show_exam(result: Dictionary) -> void:
	_open(Mode.REPORT)
	_showing_exam = true
	Sfx.play("grade")
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)

	var boss_term: bool = String(Game.term_path.get("kind", "")) == "boss"
	title.text = "%s  -  %s" % [
		String(Game.term_path.get("name", "")).to_upper() if boss_term else "END OF TERM",
		String(result.get("letter", "F"))]

	# Two children to a line, in the colour of their verdict. Twenty days
	# come down to this screen, and a column of identical "(no)"s says
	# nothing about which of them you nearly got there with.
	var rows: Array = result.get("rows", [])
	var lines: Array[String] = []
	var i := 0
	while i < rows.size():
		var cell := _exam_cell_rich(rows[i])
		if i + 1 < rows.size():
			cell += "  " + _exam_cell_rich(rows[i + 1])
		lines.append(cell)
		i += 2

	var passed: int = int(result.get("passed", 0))
	var total: int = int(result.get("total", 0))
	lines.append("")
	# The TARGET, not just the count. A number you are measured against
	# after the fact is a punishment; the same number known all term is a
	# thing to play towards -- and this is the only screen where it resolves.
	if boss_term:
		# A boss term is judged on the class as a whole against the paper's
		# own bar (Game.next_term()'s boss branch), not the seat count -- so
		# this line says which side of the bar, in words. The bar itself is
		# never printed.
		var cleared: bool = float(result.get("average", 0.0)) \
			>= float(Game.term_path.get("target", 1.0))
		lines.append("[color=#%s]%d of %d passed[/color]   [color=#%s]%s[/color]" % [
			C_GOOD if cleared else C_BAD, passed, total,
			C_GOOD if cleared else C_BAD,
			"the paper is CLEARED" if cleared else "the paper is NOT cleared"])
	else:
		var target: int = Game.term_target()
		var met: bool = passed >= target
		lines.append("[color=#%s]%d of %d passed[/color]   need %d   [color=#%s]%s[/color]" % [
			C_GOOD if met else C_BAD, passed, total, target,
			C_GOOD if met else C_BAD,
			"kept the job" if met else "NOT ENOUGH"])

	# What you BUILT, not just what they scored. The room, the curriculum
	# and the children you saw all the way through are the three things a
	# term actually leaves behind, and none of them were on this screen.
	lines.append("[color=#%s]%s[/color]" % [DIM, _term_legacy()])
	rich.text = "\n".join(lines)
	_reveal_rich(0.6)
	hint.text = _hint_clip("E - begin term %d%s" % [Game.term + 1,
		"   (cheats were used)" if Game.cheated else ""])


## One line on what kind of term that was. It is the last sentence the game
## says to you, so it should be about the class rather than the arithmetic.
func _term_verdict(passed: int, total: int) -> String:
	if total == 0:
		return "Nobody sat it."
	var share := float(passed) / float(total)
	if share >= 0.99:
		return "Every one of them."
	if share >= 0.6:
		return "A good class."
	if share >= 0.3:
		return "Some got there."
	if passed > 0:
		return "A hard term."
	return "Not this time."


## The three things a term leaves behind.
func _term_legacy() -> String:
	var bits: Array[String] = []
	bits.append("%d concept%s taught" % [Game.concepts.size(),
		"" if Game.concepts.size() == 1 else "s"])
	bits.append("%d item%s in the room" % [Game.room_items.size(),
		"" if Game.room_items.size() == 1 else "s"])
	if not Game.graduated.is_empty():
		bits.append("%d sent up" % Game.graduated.size())
	return "   ".join(bits)


## One child on the exam board, in the colour of their verdict.
func _exam_cell_rich(row: Dictionary) -> String:
	var s: StudentData = row["student"]
	var ok: bool = bool(row.get("passed", false))
	var hue := strand_colour("ela") if ok else "d08a86"
	return "[color=#%s]%-7s %s[/color]" % [
		hue, s.first_name().substr(0, 7), String(row.get("letter", "?"))]


## One child on the exam board.
##
## The pass reads as (ok)/(no), not as +/-. A bare minus sat right next to
## the letter and turned an F into what looked like an F-minus, which is a
## grade rather than a verdict.
func _exam_cell(row: Dictionary) -> String:
	var s: StudentData = row["student"]
	return "%-9s %s %s" % [s.first_name(), String(row["letter"]),
		"(ok)" if bool(row["passed"]) else "(no)"]


## The paper is over. One line per child, in the colour of how they held
## up, then the room in a word. Nothing here is a grade: the exam is sat
## at the bell, and this morning is what feeds into it.
func show_fight_report(report: Dictionary) -> void:
	_open(Mode.REPORT)
	Sfx.play("grade")
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "%s  -  %s" % [String(report.get("boss", "THE PAPER")).to_upper(),
		String(report.get("composure", "")).to_upper()]
	var rows: Array = report.get("rows", [])
	var lines: Array[String] = []
	var i := 0
	while i < rows.size() and lines.size() < 7:
		var cell := _fight_cell(rows[i])
		if i + 1 < rows.size():
			cell += "  " + _fight_cell(rows[i + 1])
		lines.append(cell)
		i += 2
	if i < rows.size():
		lines.append("[color=#%s]...[/color]" % DIM)
	lines.append("")
	lines.append("[color=#%s]%s[/color]" % [C_KNOW,
		_composure_sentence(String(report.get("composure", "")))])
	lines.append("[color=#%s]The results are read at the bell.[/color]" % DIM)
	rich.text = "\n".join(lines)
	_reveal_rich(0.6)
	hint.text = "E - close.   Ring the bell to sit the results."


## One child on the paper board: their name and how they held up, green
## if they rose to it, red if they lost it, plain otherwise.
func _fight_cell(row: Dictionary) -> String:
	var s: StudentData = row["student"]
	var r := int(row.get("rallied", 0))
	var h := int(row.get("held", 0))
	var d := int(row.get("dropped", 0))
	var hue := DIM
	if d > 0 and r + h < d:
		hue = "d08a86"
	elif r > 0 and d == 0:
		hue = strand_colour("ela")
	elif r + h + d > 0:
		hue = "cfcfcf"
	return "[color=#%s]%-7s %-14s[/color]" % [hue, s.first_name().substr(0, 7),
		String(row.get("word", ""))]


## The room, in a sentence. The last thing the paper says.
func _composure_sentence(word: String) -> String:
	match word:
		"steady": return "The room held. Every question, answered as a class."
		"wobbling": return "It wobbled, but it held. They will remember this one."
		"cracking": return "The room cracked under it. Some of them got through."
		"gone": return "The room came apart. A hard morning for everyone in it."
	return "The paper is sat."


## What the inspector made of it.
##
## Three verdicts in words, not three numbers. The player is never shown a
## decimal anywhere else in this game and an inspection is not the place to
## start -- "the room is doing its job" is a thing you can act on, 0.62 is
## not.
func show_inspection(report: Dictionary) -> void:
	_open(Mode.REPORT)
	Sfx.play("grade")
	title.text = "INSPECTION  -  %s" % String(report.get("letter", "F"))
	var lines: Array[String] = [
		_clip("The room:     %s" % _insp_verdict(float(report.get("room", 0.0)),
			"doing its job", "helping a little", "bare")),
		_clip("The lesson:   %s" % _insp_verdict(float(report.get("lesson", 0.0)),
			"well run", "getting there", "not under control")),
		_clip("The material: %s" % _insp_verdict(float(report.get("knowledge", 0.0)),
			"you know it", "you are learning it", "you have not taught this")),
	]
	if bool(report.get("passed", false)):
		lines.append(_clip("Funding of %d coins follows." % int(report.get("grant", 0))))
	else:
		lines.append("No funding this time.")
	body.text = "
".join(lines)
	# The average and the citation ride on the hint bar. Four verdict lines
	# is already the whole panel, and the fifth was landing under it.
	hint.text = _hint_clip("E - close.   %s today.   %s" % [
		Game.grade_letter(Game.class_average()),
		String(report.get("standard", ""))])


## Three bands, in words. The thresholds are deliberately generous at the
## bottom: an inspector saying "bare" about a room you have spent nothing on
## is information, not a punishment.
func _insp_verdict(v: float, good: String, middling: String, poor: String) -> String:
	if v >= 0.66:
		return good
	if v >= 0.33:
		return middling
	return poor


## Unit test results.
##
## No "why" column, unlike the lesson report. There is nothing you could
## have done differently on the day — that is what the instrument is for —
## so an explanation here would be a lie about where the result came from.
func show_test_report(results: Array) -> void:
	_open(Mode.REPORT)
	var total := 0.0
	for r: Dictionary in results:
		total += float(r["grade"])
	var avg: float = total / maxf(1.0, float(results.size()))

	# The average goes in the title and the names run TWO to a line. A full
	# class is eight children, and the panel holds about six lines -- one
	# name per line plus a summary ran straight under the hint bar.
	title.text = "%s  -  %s" % [
		String(Game.lesson.get("name", "")).to_upper(), Game.grade_letter(avg)]

	var lines: Array[String] = []
	var i := 0
	while i < results.size():
		var left: Dictionary = results[i]
		var cell := "%-11s %s" % [
			(left["student"] as StudentData).first_name(), String(left["letter"])]
		if i + 1 < results.size():
			var right: Dictionary = results[i + 1]
			cell += "     %-11s %s" % [
				(right["student"] as StudentData).first_name(),
				String(right["letter"])]
		lines.append(cell)
		i += 2
	body.text = "
".join(lines)
	# No "why" column, unlike the lesson report: there is nothing you could
	# have done differently on the day, which is the point of the instrument.
	hint.text = "%s   E - close.   The room you built, not the day." % String(
		Game.lesson.get("standard", ""))


## A panning shot over every student taught this run, before the term-by-term
## report. Built entirely in code -- no new scene/art -- because there is no
## "player holding a yearbook" pose in art/ yet; this uses each student's
## existing front-facing portrait frame (the same AtlasTexture region
## show_student() already crops) in a plain scrolling list instead. Swap in
## real held-book framing here later without touching the data side at all.
##
## Every currently-enrolled student plus everyone graduated this run,
## deduplicated by name (a student who graduated then a same-named new
## enrolment is vanishingly unlikely and not worth guarding against here).
func _show_yearbook(on_finished: Callable) -> void:
	var entries: Array = []
	var seen: Dictionary = {}
	for s: StudentData in Game.roster:
		if seen.has(s.display_name):
			continue
		seen[s.display_name] = true
		entries.append({"name": s.display_name, "art": s.art})
	for row: Dictionary in Game.graduated:
		var n: String = String(row.get("name", ""))
		if seen.has(n):
			continue
		seen[n] = true
		entries.append({"name": n, "art": String(row.get("art", "student_a"))})

	if entries.is_empty():
		on_finished.call()
		return

	var scroller := ScrollContainer.new()
	scroller.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(scroller)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(overlay.size.x, 0)
	col.add_theme_constant_override("separation", 6)
	scroller.add_child(col)

	var header := Label.new()
	header.text = "CLASS OF TERM %d" % Game.term
	header.add_theme_font_size_override("font_size", UI_SIZE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header)

	for entry: Dictionary in entries:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var pic := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = load("res://art/%s.png" % String(entry["art"]))
		at.region = Rect2(0, 0, 32, 48)
		pic.texture = at
		pic.custom_minimum_size = Vector2(32, 48)
		row.add_child(pic)

		var name_label := Label.new()
		name_label.text = "  %s" % String(entry["name"])
		name_label.add_theme_font_size_override("font_size", UI_SIZE)
		row.add_child(name_label)

		col.add_child(row)

	# Auto-pan top to bottom, then hand off to the text report. Skippable --
	# any input during the pan cuts straight to on_finished, same as every
	# other paged/timed reveal in this file.
	await get_tree().process_frame
	await get_tree().process_frame
	var max_scroll: int = max(scroller.get_v_scroll_bar().max_value - overlay.size.y, 0)
	if max_scroll <= 0:
		await get_tree().create_timer(1.2).timeout
		scroller.queue_free()
		on_finished.call()
		return

	var pan_seconds: float = clamp(entries.size() * 0.35, 1.5, 6.0)
	var tw := create_tween()
	tw.tween_property(scroller, "scroll_vertical", max_scroll, pan_seconds)
	var finished := false
	tw.finished.connect(func() -> void: finished = true)
	while not finished:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			tw.kill()
			break
		await get_tree().process_frame
	scroller.queue_free()
	on_finished.call()


## The run is over: a term missed its target.
##
## Every term you taught, in order, so the run reads as a career rather than
## a failure notice. The last row is the one that ended it, and it is the
## only row with a number beside it that you did not reach.
func show_run_over(info: Dictionary) -> void:
	_open(Mode.REPORT)
	_showing_run_over = true
	Sfx.play("deny")
	body.visible = false
	rich.visible = false
	# The yearbook carries its own header; the panel's title still held the
	# last screen's ("END OF TERM - D", or the intro's "MONDAY") and printed
	# straight through it.
	title.text = ""
	await _show_yearbook(func() -> void: _show_run_over_report())


func _show_run_over_report() -> void:
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)

	title.text = "THAT IS THE END OF IT"
	var lines: Array[String] = []
	for row: Dictionary in Game.term_history:
		var met: bool = bool(row.get("met", false))
		lines.append("[color=#%s]Term %-2d  %s   %d of %d passed   needed %d[/color]" % [
			C_GOOD if met else C_BAD, int(row["term"]),
			String(row["letter"]), int(row["passed"]), int(row["total"]),
			int(row.get("target", Balance.term_target_base))])
	lines.append("")
	lines.append("[color=#%s]%d term%s taught.  %d children sent up.  %d concepts.[/color]" % [
		C_KNOW, Game.term_history.size(),
		"" if Game.term_history.size() == 1 else "s",
		Game.graduated.size(), Game.concepts.size()])
	rich.text = "\n".join(lines)
	_reveal_rich(0.6)
	hint.text = "E - start again"


## THE HAND. A shuffled hand of 3-7 papers, drawn at the podium, and you
## set one of them.
##
## Rarity is what it PAYS and difficulty is how LONG it is, and they are
## correlated -- so the rare ones are usually demanding and the question is
## not "which is best" but "can this class, today, in the room I have built,
## actually finish this". Work you never collect counts for half, so a
## Legendary Project nobody completes is worth less than a Common Worksheet
## everybody hands in.
## THE LESSON-PLAN FOLDER. One page at a time, the way a teacher at a desk
## actually goes through them.
##
## The hand used to be a list of three rows, which reads as a menu. A page
## reads as a PLAN: room for the objective, the standard it comes from, what
## it asks of the class and what it pays. The same 3-7 cards (a fresh
## shuffle every morning, not always the same count), but you meet them one
## at a time and have to turn to see the next.
##
## Turned with the scroll wheel, a click, or Up/Down -- whichever your hand
## is already on.
##
## `fresh` marks a hand that was JUST drawn, as opposed to turning a page in
## one already on the table -- only a fresh hand gets the shuffle. Paging
## calls this with no argument, which defaults to false, so turning a page
## never re-triggers it.
func show_hand(fresh: bool = false) -> void:
	_open(Mode.HAND)
	body.visible = false
	rich.visible = true
	_book(true)
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)

	if Game.hand.is_empty():
		close()
		return
	if fresh:
		_play_shuffle()
	else:
		_render_hand()


## A quick riffle before the hand settles -- card backs flickering through a
## few frames with a paper-shuffle sound each one, then the real hand reveals
## as normal. Text-and-tween rather than a sprite fan: this UI is a single
## page you turn, not a physical table of cards, so the flourish is a
## suspense beat rather than a full card-game redeal.
const SHUFFLE_STEPS := 6
const SHUFFLE_STEP_SECONDS := 0.07


func _play_shuffle() -> void:
	var n: int = Game.hand.size()
	title.text = "SHUFFLING..."
	var t := create_tween()
	for i in SHUFFLE_STEPS:
		t.tween_callback(_shuffle_frame.bind(n, i))
		t.tween_interval(SHUFFLE_STEP_SECONDS)
	t.tween_callback(_render_hand)


func _shuffle_frame(n: int, i: int) -> void:
	Sfx.play_varied("paper")
	var row := ""
	for c in n:
		# a riffling fill: which pips are "up" shifts every frame, so the
		# row visibly ripples rather than just fading in
		var lit := (c + i) % 2 == 0
		row += "[color=#%s]%s[/color]" % [
			"e8dcc2" if lit else DIM, _cells(BAR_FULL if lit else BAR_EMPTY, 1)]
	rich.text = "

      %s
" % row


## The actual page content -- split out of show_hand() so a page TURN can
## call straight in without repeating the shuffle every time.
func _render_hand() -> void:
	var n: int = Game.hand.size()
	if n == 0:
		close()
		return
	_sel = clampi(_sel, 0, n - 1)
	var card: Dictionary = Game.hand[_sel]
	var rid := String(card.get("rarity", "common"))
	var hue := _on_paper(Assignments.rarity_colour(rid))
	var lesson := Curriculum.by_id(String(card.get("lesson", "")))

	title.text = "LESSON PLANS  -  %d of %d" % [_sel + 1, n]

	# The LEFT page says what this plan IS; the right page says what it asks
	# of you. Nothing crosses the spine.
	var left: Array[String] = []
	# Not manually wrapped: the label autowraps to the page, and a hand-broken
	# title stops being the string anything can match on.
	left.append("[color=#%s]%s[/color]" % [hue, Assignments.title(card)])
	left.append("")
	left.append("[color=#%s]%s[/color]  [color=#%s]pays x%.2f[/color]" % [
		hue, Assignments.rarity_name(rid), C_COIN, Assignments.pay(rid)])
	left.append("[color=#%s]%s[/color]" % [INK_DIM,
		String(lesson.get("standard", "")) if String(lesson.get("standard", "")) != ""
			else "no citation"])
	rich_left.text = "
".join(left)

	var lines: Array[String] = []
	# what it actually asks of them
	# The pay moved to the left page beside the rarity it comes from: on
	# this 256px page in the pixel font it wrapped, and pushed the page edge
	# off the bottom.
	lines.append("[color=#%s]Length[/color]  %s" % [
		INK_DIM, _difficulty_bar(int(card.get("difficulty", 1)))])
	var obj := String(lesson.get("objective", ""))
	if obj != "":
		# Autowrapped by the label to the page, not hand-broken to a count:
		# a manual wrap clipped the objective mid-word on a narrower page.
		lines.append("[color=#%s]%s[/color]" % [INK_DIM, obj])
	lines.append("")
	# the page edge, so it is obvious there ARE more
	var edge := ""
	for i in n:
		edge += "[color=#%s]%s[/color]" % [
			Assignments.rarity_colour(String(Game.hand[i].get("rarity", "common"))),
			_cells(BAR_FULL if i == _sel else BAR_EMPTY, 1)]
	lines.append("%s   [color=#%s]turn the page[/color]" % [edge, INK_DIM])

	rich.add_theme_constant_override("line_separation", 2)
	rich.text = "\n".join(lines)
	# A long objective (six lines on this page) pushed the page edge half a
	# line off the paper -- the fit test counted four "\n"s and passed it.
	# Measured now: lines closer together first, then the gap before the edge,
	# then the objective in small print -- the longest (division's, 261
	# characters) runs to a dozen lines at full size on a 256px page.
	if _rich_overflows():
		rich.add_theme_constant_override("line_separation", 0)
	if _rich_overflows() and lines.size() >= 2 and lines[lines.size() - 2] == "":
		lines.remove_at(lines.size() - 2)
		rich.text = _join_rich(lines)
	if _rich_overflows() and obj != "":
		lines[1] = "[font_size=%d]%s[/font_size]" % [UI_SMALL, lines[1]]
		rich.text = _join_rich(lines)
	_reveal_rich(0.22)
	hint.text = "Scroll / click / Up-Down to turn    E - set this one"
	_book_turned(_sel)


## THE FORK AT THE START OF A TERM -- PokeRogue-style: a few pre-rolled
## paths, drawn without replacement (see TermPaths.draw()), pick one and
## the rest are discarded. Deliberately a near-duplicate of show_hand()/
## _render_hand() above, reusing the same page-turn feel and the same
## shuffle reveal (_shuffle_frame() below is already hand-agnostic).
##
## Reached only from show_new_term()'s own close -- see the Mode.REPORT
## handling in _handle_input() and the _showing_new_term flag.
func show_term_paths(fresh: bool = false) -> void:
	_open(Mode.PATHS)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)

	if Game.term_path_hand.is_empty():
		close()
		return
	_sel = 0
	if fresh:
		_play_path_shuffle()
	else:
		_render_term_paths()


func _play_path_shuffle() -> void:
	var n: int = Game.term_path_hand.size()
	title.text = "SHUFFLING..."
	var t := create_tween()
	for i in SHUFFLE_STEPS:
		t.tween_callback(_shuffle_frame.bind(n, i))
		t.tween_interval(SHUFFLE_STEP_SECONDS)
	t.tween_callback(_render_term_paths)


func _render_term_paths() -> void:
	var n: int = Game.term_path_hand.size()
	if n == 0:
		close()
		return
	_sel = clampi(_sel, 0, n - 1)
	var row: Dictionary = Game.term_path_hand[_sel]
	# density_mult runs roughly 0.5..2.4 across the four paths on file --
	# folded onto the same 1..5 ladder _difficulty_bar() already draws for
	# an assignment's own length, so "how much can go wrong" reads the
	# same visual language a returning player already knows.
	var level := clampi(int(round(float(row.get("density_mult", 1.0)) * 2.0)), 1, 5)

	title.text = "CHOOSE YOUR TERM  -  %d of %d" % [_sel + 1, n]

	var lines: Array[String] = []
	lines.append("[color=#%s]%s[/color]" % [C_ROOM, String(row.get("name", "Term"))])
	lines.append("[color=#%s]%s[/color]" % [DIM, _wrap(String(row.get("blurb", "")), 52, 2)])
	lines.append("")
	lines.append("[color=#%s]Lessons run[/color]  x%.2f     [color=#%s]pays x%.2f[/color]" % [
		DIM, float(row.get("lesson_mult", 1.0)), C_COIN, float(row.get("coin_mult", 1.0))])
	lines.append("[color=#%s]How much can go wrong[/color]  %s" % [
		DIM, _difficulty_bar(level)])
	lines.append("")
	# the page edge, same shape as the hand's own
	var edge := ""
	for i in n:
		edge += "[color=#%s]%s[/color]" % [
			C_ROOM if i == _sel else DIM, _cells(BAR_FULL if i == _sel else BAR_EMPTY, 1)]
	lines.append("%s   [color=#%s]turn the page[/color]" % [edge, DIM])

	rich.text = "\n".join(lines)
	_reveal_rich(0.22)
	hint.text = "Scroll / Up-Down to turn    E - start this term"


## THE SCHOOL: every room, and how it did.
##
## This is the manager altitude's whole screen. A delegated room is resolved
## by RUNNING its lesson with its teacher's policy, so every letter here was
## earned by the same model the player is subject to -- which is what makes
## a bad row worth walking into tomorrow rather than a number to shrug at.
##
## Your own room is the first line and is marked as yours: it is played, not
## resolved, and the point of the screen is the comparison.
func show_school() -> void:
	Balance.ensure_loaded()
	_open(Mode.SCHOOL)
	# _sel can outlive the school it indexed -- a room closed under it, or a
	# larger school from a previous run -- and both show_school() below and
	# the Mode.SCHOOL branch of _handle_input() index Game.rooms[_sel] raw.
	# One clamp on the way in covers every site, since SCHOOL is only ever
	# entered through here. (Was four silent "out of bounds get index"
	# errors a test run: they fail no assertion, so the suite never saw them.)
	_sel = clampi(_sel, 0, maxi(0, Game.rooms.size() - 1))
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "THE SCHOOL  -  %d room%s" % [
		Game.rooms.size() + 1, "" if Game.rooms.is_empty() else "s"]

	var lines: Array[String] = []
	lines.append("[color=#%s]%-9s %-13s %s[/color]" % [
		DIM, "YOURS", "you", Game.grade_letter(Game.class_average())])

	for i in Game.rooms.size():
		var r: Dictionary = Game.rooms[i]
		var t: Dictionary = r.get("teacher", {})
		var last: Dictionary = r.get("last", {})
		var letter := String(last.get("letter", "-"))
		var staffed: bool = not t.is_empty()
		# An unstaffed room is the loudest thing on this screen, because it
		# is costing you a room and teaching nobody.
		var hue := C_BAD if not staffed else (
			C_GOOD if letter in ["A", "B"] else (DIM if letter == "-" else C_HOMEWORK))
		lines.append("%s [color=#%s]%-9s %-13s %s[/color]" % [
			">" if i == _sel else " ", hue, String(r.get("name", "Room")),
			String(t.get("name", "NOBODY")).substr(0, 13), letter])

	lines.append("")
	if Game.rooms.is_empty():
		lines.append("[color=#%s]One room, and it is yours. Open another and[/color]" % DIM)
		lines.append("[color=#%s]somebody else will have to teach it.[/color]" % DIM)
	else:
		var sel: Dictionary = Game.rooms[_sel] if _sel < Game.rooms.size() else {}
		var t2: Dictionary = sel.get("teacher", {})
		if t2.is_empty():
			lines.append("[color=#%s]Nobody is teaching it. The children sit there.[/color]" % C_BAD)
		else:
			lines.append("[color=#%s]%s[/color]  [color=#%s]but %s[/color]" % [
				C_GOOD, Staff.strengths(t2), C_BAD, Staff.weakness(t2)])
			lines.append("[color=#%s]letting them go costs %d coins[/color]" % [
				DIM, Balance.fire_cost])
		lines.append("[color=#%s]furniture %s   %d/day in wages[/color]" % [
			DIM, _furniture_bar(int(sel.get("furniture", 0))), Game.wage_bill()])

	rich.text = "\n".join(lines)
	_reveal_rich(0.3)
	var watch_hint := ""
	if _can_watch(_sel):
		watch_hint = "V watch  "
	var sel_staffed: bool = Game.rooms.is_empty() or \
		not (Game.rooms[_sel].get("teacher", {}) as Dictionary).is_empty()
	# Whichever of hire/fire actually applies to the selected room, never
	# both -- a staffed room cannot be hired into (see hire()'s own refusal)
	# and an empty one has nobody to let go, so offering the wrong verb
	# would just train the player to expect a press that does nothing. The
	# cost lives in the body text above, not here -- adding "G fire" pushed
	# this line past LINE_CHARS with every other verb still spelled out in
	# full, so Up/Down and Esc (arrows-to-navigate and Escape-to-back-out
	# both being true on nearly every screen this game has) are the two
	# left unstated to make room. Found by screenshotting the actual
	# result, not by counting characters -- the truncation was silent.
	var staff_hint := "G fire" if sel_staffed else "E hire"
	hint.text = _hint_clip("%s  F furnish  %sB new(%d)" % [
		staff_hint, watch_hint, Game.room_cost()])


## Whether room `i` has a day worth watching -- staffed and resolved at
## least once. A fresh room has a teacher but no history yet; the bell
## has to ring on it first.
func _can_watch(i: int) -> bool:
	if i < 0 or i >= Game.rooms.size():
		return false
	var r: Dictionary = Game.rooms[i]
	if (r.get("teacher", {}) as Dictionary).is_empty():
		return false
	var last: Dictionary = r.get("last", {})
	return not (last.get("history", []) as Array).is_empty()


## Open the day room `i` already had, and start stepping through it.
func show_watch(i: int) -> void:
	if not _can_watch(i):
		return
	_watch_room = i
	var r: Dictionary = Game.rooms[i]
	_watch_result = r.get("last", {})
	_watch_frames = _watch_result.get("history", [])
	_watch_i = 0
	_watch_clock = 0.0
	_open(Mode.WATCH)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "WATCHING  -  %s" % String(r.get("name", "Room"))
	_render_watch_frame()


## Auto-teach resolved YOUR OWN lesson. Same screen, same stepping, same
## "watch" key to skip to the bell -- the whole point of reusing it is
## that a room you delegate and a lesson you auto-teach are shown the
## same honest way. `_watch_room = -1` is what tells _render_watch_frame()
## and the WATCH input handler this is not a room in Game.rooms.
func show_own_watch(history: Array, results: Array) -> void:
	_watch_room = -1
	_watch_own_results = results
	_watch_result = {"letter": Game.grade_letter(Game.class_average())}
	_watch_frames = history
	_watch_i = 0
	_watch_clock = 0.0
	_open(Mode.WATCH)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "WATCHING  -  Auto-teach"
	_render_watch_frame()


## One frame: who is where, coloured the same way the rest of the game
## colours a struggling or noisy child, plus a running tally so the letter
## at the end does not land as a surprise.
func _render_watch_frame() -> void:
	var lines: Array[String] = []
	var frame: Dictionary = _watch_frames[_watch_i] if _watch_i < _watch_frames.size() else {}
	var teacher_name := "Auto-teach"
	if _watch_room >= 0:
		teacher_name = String((Game.rooms[_watch_room] as Dictionary).get("teacher", {}).get("name", ""))
	var at_front: bool = bool(frame.get("at_front", false))
	lines.append("[color=#%s]%s[/color]  [color=#%s]%s[/color]" % [
		C_LESSON, teacher_name,
		C_GOOD if at_front else DIM,
		"at the front, teaching" if at_front else "away from the front"])
	lines.append("")

	var faces: Array = frame.get("faces", [])
	var stuck := 0
	var noisy := 0
	var done := 0
	for f: Dictionary in faces:
		var st := String(f.get("state", "working"))
		var hue := DIM
		var tag := "working"
		match st:
			"disrupting":
				hue = C_BAD
				tag = "unsettled"
				noisy += 1
			"stuck":
				hue = C_HOMEWORK
				tag = "stuck"
				stuck += 1
			"done":
				hue = C_GOOD
				tag = "finished"
				done += 1
		lines.append("  [color=#%s]%-13s %s[/color]" % [
			hue, String(f.get("name", "")).substr(0, 13), tag])

	lines.append("")
	var frac: float = float(_watch_i) / maxf(1.0, float(_watch_frames.size() - 1))
	if _watch_i >= _watch_frames.size() - 1:
		lines.append("[color=#%s]The bell went. %s[/color]" % [
			DIM, "%d finished, %d still stuck, %d unsettled" % [done, stuck, noisy]])
		lines.append("[color=#%s]Grade: %s[/color]" % [
			C_GOOD, String(_watch_result.get("letter", "-"))])
	else:
		lines.append("[color=#%s]%s[/color]" % [
			DIM, _watch_bar(frac)])

	rich.text = "\n".join(lines)


func _watch_bar(frac: float) -> String:
	var n := clampi(int(round(frac * 20.0)), 0, 20)
	return "[color=#%s]%s[/color][color=#3a3a42]%s[/color]" % [
		C_ROOM, _cells(BAR_FULL, n), _cells(BAR_EMPTY, 20 - n)]


func _furniture_bar(level: int) -> String:
	Balance.ensure_loaded()
	var n: int = clampi(level, 0, Balance.furniture_steps)
	return "[color=#%s]%s[/color][color=#3a3a42]%s[/color]" % [
		C_ROOM, _cells(BAR_FULL, n),
		_cells(BAR_EMPTY, Balance.furniture_steps - n)]


## Who is going. Prose, never numbers -- the same rule the rest of the game
## follows, and the reason a hire reads as a person rather than a stat line.
func show_hiring() -> void:
	_open(Mode.SCHOOL)
	_hiring = true
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "WHO WILL TEACH IT?"

	if Game.applicants.is_empty():
		Game.draw_applicants()
	_sel = clampi(_sel, 0, maxi(0, Game.applicants.size() - 1))
	var lines: Array[String] = []
	for i in Game.applicants.size():
		var t: Dictionary = Game.applicants[i]
		lines.append("%s [color=#%s]%-15s[/color] [color=#%s]%d/day[/color]" % [
			">" if i == _sel else " ", C_LESSON, String(t.get("name", "")),
			C_COIN, int(t.get("wage", 0))])
		lines.append("  [color=#%s]%s[/color]" % [
			DIM, String(t.get("blurb", ""))])
	rich.text = "\n".join(lines)
	_reveal_rich(0.25)
	var sel: Dictionary = Game.applicants[_sel] if _sel < Game.applicants.size() else {}
	hint.text = "E hire   Esc back.   " + _fit_px("%s, but %s" % [
		Staff.strengths(sel), Staff.weakness(sel)], 340.0)


## YOUR CAREER: every milestone, earned and unearned.
##
## The UNEARNED ones are the point. A list of what you have done is a trophy
## cabinet; a list that also shows what there is to do is a map, and a game
## with no ending needs the map far more than the cabinet.
## The career list: every milestone, then every boss trophy, in one
## windowed list with one cursor. A trophy that hasn't been won yet reads
## exactly like an unearned milestone -- "- - -" -- so the shelf is
## visible from the first run without spoiling what is on it.
func _career_rows() -> Array:
	var out: Array = []
	for m: Dictionary in Milestones.all():
		out.append({"id": String(m.get("id", "")), "name": String(m.get("name", "")),
			"blurb": String(m.get("blurb", "")), "won": Game.milestones.has(String(m.get("id", "")))})
	for t: Dictionary in Trophies.all():
		out.append({"id": String(t.get("id", "")), "name": "%s  (trophy)" % String(t.get("name", "")),
			"blurb": String(t.get("blurb", "")), "won": Game.trophies.has(String(t.get("id", "")))})
	return out


func show_career() -> void:
	_open(Mode.CAREER)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)

	title.text = "YOUR CAREER  %d/%d   trophies %d/%d" % [
		Game.milestones.size(), Milestones.count(),
		Game.trophies.size(), Trophies.count()]

	if _career_page == CAREER_ALUMNI:
		_render_alumni()
		return

	var rows := _career_rows()
	# a window, because there are more entries than the panel holds
	_sel = clampi(_sel, 0, maxi(0, rows.size() - 1))
	var lo := _window_start(rows.size(), 9)
	var lines: Array[String] = []
	for i in range(lo, mini(rows.size(), lo + 9)):
		var r: Dictionary = rows[i]
		var won: bool = bool(r.get("won", false))
		lines.append("%s [color=#%s]%s[/color]" % [
			">" if i == _sel else " ", C_COIN if won else DIM,
			String(r.get("name", "")) if won else "- - -"])
	rich.text = "\n".join(lines)
	_reveal_rich(0.25)

	var sel: Dictionary = rows[_sel] if _sel < rows.size() else {}
	hint.text = _hint_clip("Esc - close.   Tab - the ones who left.   %s%s" % [
		"" if bool(sel.get("won", false)) else "Not yet: ", String(sel.get("blurb", ""))])


## The alumni wall -- every child ever sent up, newest first, read from
## meta.alumni so it outlives a run. The list, or one alum's story if
## _alum_open points at one. Their story is rendered from the SAME
## helpers as a living child's file page two (transcript arc + moments
## reel), fed a throwaway StudentData rebuilt from the graduation
## snapshot -- so the wall can never drift from the file it mirrors.
func _render_alumni() -> void:
	var al: Array = Game.meta.get("alumni", [])
	if al.is_empty():
		rich.text = "[color=#%s]No one has left yet.[/color]\n\nWhen you send a child up -- or one passes the exam -- they are remembered here, for the rest of your career." % DIM
		_reveal_rich(0.2)
		hint.text = "Tab - back to milestones    Esc - close"
		return

	# newest first
	var recs: Array = al.duplicate()
	recs.reverse()

	if _alum_open >= 0 and _alum_open < recs.size():
		var rec: Dictionary = recs[_alum_open]
		var s := _alum_student(rec)
		var lines: Array[String] = []
		lines.append("[color=#%s]%s[/color]" % [C_COIN, String(rec.get("name", ""))])
		lines.append("[color=#%s]%s[/color]" % [DIM, _alum_left_line(rec)])
		lines.append("")
		lines.append(_transcript_line(s))
		lines.append("")
		var story := _moments_prose(s)
		if story.is_empty():
			lines.append("Nothing much stood out in their time with you -- a quiet run through.")
		else:
			lines.append_array(story)
		rich.text = "\n".join(lines)
		_reveal_rich(0.2)
		hint.text = "Esc - back to the list"
		return

	_sel = clampi(_sel, 0, recs.size() - 1)
	var lo := _window_start(recs.size(), 9)
	var out: Array[String] = []
	for i in range(lo, mini(recs.size(), lo + 9)):
		var r: Dictionary = recs[i]
		out.append("%s [color=#%s]%-16s[/color] [color=#%s]Class of Term %d[/color]" % [
			">" if i == _sel else " ", C_COIN, String(r.get("name", "")),
			DIM, int(r.get("term", 1))])
	rich.text = "\n".join(out)
	_reveal_rich(0.2)
	hint.text = "Up/Down choose   E open their story   Tab back   Esc close"


## A throwaway StudentData carrying only what the story helpers read --
## name, trait, what they were taught, and their moments reel. Not enrolled,
## never ticked; it exists for one render and is dropped.
func _alum_student(rec: Dictionary) -> StudentData:
	var s := StudentData.new()
	s.display_name = String(rec.get("name", ""))
	s.art = String(rec.get("art", "student_a"))
	s.trait_id = String(rec.get("trait_id", ""))
	s.aptitude = float(rec.get("aptitude", 0.5))
	s.favourite = String(rec.get("favourite", ""))
	s.joined_day = int(rec.get("joined_day", 1))
	s.helps_total = int(rec.get("helps_total", 0))
	s.level = int(rec.get("level", 1))
	s.transcript = (rec.get("transcript", []) as Array).duplicate(true)
	s.moments = (rec.get("moments", []) as Array).duplicate(true)
	return s


## How prepared they were the day they left, in words. The snapshot keeps
## the number; this page, like every page about a child, does not.
func _alum_left_line(rec: Dictionary) -> String:
	var r := float(rec.get("readiness", 0.5))
	var joined := int(rec.get("joined_day", 1))
	var how := "ready for what came next"
	if r >= 0.8:
		how = "more than ready -- you took them further than you had to"
	elif r < 0.45:
		how = "a little green, sent up before they had fully found their feet"
	return "Joined on day %d, left %s." % [joined, how]


## The short, terse version of every principal_says() nudge the game can
## fire live, kept here as well so a player who dismissed one -- or never
## triggered it -- can still go and read it. Deliberately NOT the single
## source of truth for the live text (each call site owns its own wording,
## same as everywhere else in this game); this is a reference shelf, not a
## second copy that could drift and contradict the real thing.
const TUTORIALS := [
	"Teaching: work only moves while you are at the front.",
	"Collecting: finished work only counts once you collect it.",
	"The room: furniture cannot be rearranged while the class works.",
	"The hallway: every room you hold has a door in it now.",
	"Consumables: bought and spent the same day, never placed.",
	"A mess: press E on it. Any time -- before, during or after class.",
	"The janitor: staff who clean the room without being asked to.",
	"Some days look different. That is today's event, not decoration.",
	"Milestones: no reward but the moment itself, and no penalty for missing one.",
	"Dash: tap Shift, or double-tap a direction. Watch the status bar for its cooldown.",
	"Answer all (J): unstick the whole room at once. Costs most of the lesson, then a long wait.",
]


## Milestones, career totals and the tutorial shelf, in one room -- the
## principal's own office, reached through the hallway rather than a menu,
## same as everything else that got a physical door this year.
##
## Deliberately a SUMMARY, not a second copy of the career list: E opens
## the real thing (show_career(), which already knows how to page past
## thirty milestones and reveal a blurb only once earned). Duplicating
## that render here would be the two drifting apart the first time either
## one changes.
## The storyline tutorial: three pages, played once, at the start of a
## genuinely new career (Game.intro_seen gates it -- see main.gd). Same
## mechanics the boot "How to play" page already states plainly; this is
## the same information in the voice of the person it is happening to,
## not a second reference for the same facts.
##
## THE ARC, told rather than mechanically built: nothing here invents a
## "district" system -- there is no such layer, and inventing one just to
## honour a line of dialogue would be exactly the kind of decoration this
## project's own rules warn against. What is real and already built is
## the school layer this game already has: more rooms, hired staff,
## reputation, a career that keeps going. The last page names that
## honestly as what is actually coming, not a bigger promise than the
## game can keep.
## The title card -- a film's slate, said once before the scene itself
## starts. Backstory and voice, not a control sheet: what the keys DO is
## the mentor's job now (scripts/world/mentor_room.gd), not this. The one
## instruction left is the one the cutscene then acts out -- "start with
## the desks" -- so the words and the action still match. Panel-fit
## verified the same way every other screen is: <= 11 lines at font 16.
const INTRO_SLATE := [
	"Years of these, and a new one still lands the",
	"same way. Fresh floor polish, sharpened pencils,",
	"a register of names you will know by Friday.",
	"A cabinet holding all you need, folded flat.",
	"",
	"Nobody else decides what this room becomes.",
	"That part is yours, and that is the good part.",
	"",
	"The bell goes in twenty minutes.",
	"Start with the desks.",
]

## The scene itself: said from a bubble above the teacher's own head as
## they walk the empty room and pull the desks out -- see main.gd's
## _start_intro_cutscene(). Voice, not instruction: no key names anywhere
## in here (that teaching moved to the mentor). A comic bubble holds two
## SHORT lines, not a paragraph wrapped narrower -- and fixed at two, not
## "two or three", because the front row where this is said sits close
## enough to the top wall that a taller bubble crowds the status bar.
## Found by screenshotting the worst-case page, not by counting characters.
const INTRO_PAGES := [
	["Desks first.", "Everything else follows."],
	["Eight of them,", "eight desks to fill."],
	["Some will race ahead.", "Some will want you close."],
	["You will learn which", "soon enough."],
	["A room speaks first,", "before anyone talks."],
	["Which way the chairs face.", "How near the walls sit."],
	["Give them room to breathe", "and the day goes easy."],
	["Get this right and the", "room starts helping you."],
	["Stay with it and the", "room fades into the day."],
	["Down the hall: more rooms,", "more kids to meet."],
	["No one tells you that.", "A nice surprise, really."],
]


func show_intro() -> void:
	_open(Mode.INTRO)
	_sel = -1     # -1 slate, -2 desk-pull, >= 0 indexes INTRO_PAGES
	_render_intro()


func _render_intro() -> void:
	if _sel == -1:
		overlay.visible = true
		title.text = "MONDAY"
		# Font 16 / spacing 2, the same panel budget every other screen is
		# fit to (CLAUDE.md: 11 rows at font 16). The slate runs to ten.
		body.add_theme_font_size_override("font_size", UI_SIZE)
		body.add_theme_constant_override("line_spacing", 0)
		body.text = "\n".join(INTRO_SLATE)
		hint.text = "E - go on"
		overlay.color = Color(0.04, 0.03, 0.06, 0.45)
		body.visible = false
		hint.visible = false
		say_dialogue("Ms. Clara", PLAYER_PORTRAIT,
			"Years of these, and a new one still lands the same way. Fresh floor polish, sharpened pencils... The bell goes in twenty minutes. Start with the desks.")
		return
	# The slate is gone and stays gone -- the room is visible behind the
	# dialogue box for the rest of the scene, which is the whole point of a
	# cutscene over a panel that talks ABOUT the room instead.
	overlay.visible = false
	overlay.color = OVERLAY_COLOUR
	body.visible = true
	hint.visible = true
	if _sel == -2:
		# The desk-pull. A dialogue box and countdown prompt while the teacher
		# pulls desks out of the cabinet.
		var left: int = Game.desks_in_store
		var msg := "Chairs are stacked.\nDesks are in the cabinet."
		intro_line_changed.emit(msg)
		prompt.text = ("E - pull a desk out  (%d left)" % left) if left > 0 \
			else "E - right then"
		prompt.visible = true
		prompt_box.visible = true
		say_dialogue("Ms. Clara", PLAYER_PORTRAIT,
			msg + ("  (%d left in cabinet)" % left if left > 0 else ""))
		return
	var page_line := "\n".join(INTRO_PAGES[_sel])
	intro_line_changed.emit(page_line)
	prompt.text = "E - go on" if _sel < INTRO_PAGES.size() - 1 else "E - right then"
	prompt.visible = true
	prompt_box.visible = true
	say_dialogue("Ms. Clara", PLAYER_PORTRAIT, page_line)


func _handle_intro_input() -> void:
	if not Game.claim_interact():
		return
	Sfx.play("blip")
	if _dialogue_typing and Game.save_path == Game.SAVE_PATH:
		finish_dialogue_typing()
		return
	if _sel == -1:
		# Leave the slate -> the desk-pull. main.gd puts the teacher at the
		# door, stashes every desk, and walks them to the cabinet.
		_sel = -2
		intro_walk_requested.emit()
		_render_intro()
	elif _sel == -2:
		if Game.desks_in_store > 0:
			intro_desk_pull_requested.emit()
		if Game.desks_in_store <= 0:
			_sel = 0                    # room furnished; on to the scene proper
		_render_intro()
	elif _sel < INTRO_PAGES.size() - 1:
		_sel += 1
		_render_intro()
	else:
		Game.intro_seen = true
		hide_dialogue()
		intro_finished.emit()
		close()


# ---------------------------------------------------------------- the mentor
#
# The teacher down the hall. First visit is a short paged dialogue -- the
# same page-at-a-time-on-E shape as the intro's slate, generalised only as
# far as it needs to be (its own Mode, its own pages, one _handle_*_input).
# It teaches the two verbs that are locked until now (the dash and the
# mass-help "answer all") and, standing in a room whose desks are visibly
# spaced out, is honest about what a neighbour is worth both ways. After
# that, a revisit shows an idle line -- or, when a boss term is due, a
# prose-only RoomSim readiness read (a tier of confidence, never a number).

## Which page teaches which verb: leaving that page sets the flag, so a
## verb unlocks exactly as it is explained.
const MENTOR_DASH_PAGE := 1
const MENTOR_ANSWER_ALL_PAGE := 2
const MENTOR_PAGES := [
	[
		"Shut the door. Look how these desks sit --",
		"room between every one of them. That is not",
		"me being tidy. It is the whole lesson, and I",
		"will show you. Two things first, though, for",
		"when a room gets away from you.",
	],
	[
		"Your feet. When a child is about to go off,",
		"you will not always have time to walk over.",
		"",
		"Double-tap a direction and you break into a",
		"run. A short burst, then a breath before the",
		"next one. Try it on your way out.",
	],
	[
		"The whole room at once. There is a key for",
		"it -- answer all.",
		"",
		"One press and every stuck hand goes down and",
		"every flagged quiz settles. It costs you most",
		"of the lesson clock and a long wait after. A",
		"rope to grab, not a way to teach.",
	],
	[
		"Now the desks. Push two together and those",
		"two get talking -- and neither does a stroke",
		"while they do. Walk over and it stops.",
		"",
		"But it runs both ways. A calm neighbour will",
		"quietly help the one who is stuck. A restless",
		"one makes stalling spread like a cold.",
	],
	[
		"So it is not spread them out and forget it.",
		"It is knowing who you have sat next to whom,",
		"and moving a desk when the pairing is wrong.",
		"",
		"Off you go. Mind the gaps on the way.",
	],
]

## The chain dash, taught by SHOWING it. One page to set the demonstration
## up, then the overlay gets out of the way while she does it with her own
## class (mentor_room.play_chain_demo()), then these pages say what the
## player just watched. The chain is taught when the last one is closed.
const MENTOR_CHAIN_INTRO := [
	[
		"One more thing for your feet, and it is easier",
		"shown than said. I am going to ask my lot",
		"something they are not sure of.",
		"",
		"Watch what I do when the hands go up.",
	],
]
## The call-and-response ("Class, class!" -- "Yes, yes!"), the mentor's third
## move, on the visit after the chain. Said, then shown: the last page hands
## over to her own class answering her (mentor_room.play_call_demo()), and
## the call is taught as that page closes.
const MENTOR_CALL := [
	[
		"One more, and then I will leave you be.",
		"",
		"Every time you go to a desk the front goes",
		"quiet -- and a quiet front is a drifting room.",
		"You have felt it. Work slows behind your back.",
	],
	[
		"So before you go, you call them.",
		"",
		"\"Class, class!\" And they answer: \"Yes, yes!\"",
		"Every one of them turns round to you, wherever",
		"you happen to be standing.",
	],
	[
		"For a few breaths they stay with you, even with",
		"your back to them. That is your trip to a desk,",
		"paid for. Then they drift, the way they always",
		"do, and you are back to the front.",
	],
	[
		"It costs you voice, the same voice that settles",
		"the noisy ones, so you cannot do both as often",
		"as you would like. And a child playing up will",
		"not answer. That is how you see who needs you.",
		"",
		"There is a key for it: the call. Watch my lot.",
	],
]

const MENTOR_CHAIN_AFTER := [
	[
		"See that? I never walked. I ran at a hand,",
		"answered it as I got there, and was off to",
		"the next before the first one had sat back.",
		"",
		"Run into a child with their hand up and you",
		"answer them on arrival. No stopping to ask.",
	],
	[
		"And land an answer, and your feet are ready",
		"again at once -- no breath between. Hand to",
		"hand to hand. That is a chain.",
		"",
		"Miss, and you wait like anyone. And a quiet",
		"one who has not put a hand up yet? You still",
		"have to notice them yourself.",
	],
	[
		"Go on, have a go. My lot will keep putting",
		"their hands up while you are in here.",
		"",
		"Even a chain runs out of breath after a few.",
		"Mind the gaps.",
	],
]

const _MENTOR_IDLE := [
	"Still room between the desks, I see. Good.",
	"",
	"Come back when there is a big paper on the way",
	"and I will tell you if the room is ready for it.",
]

## TEACH is the first-visit paged dialogue; READ is the boss-term
## readiness projection; IDLE is the plain revisit line. CHAIN_INTRO and
## CHAIN_AFTER bracket the chain-dash demonstration -- a first visit runs
## straight on into them after TEACH, and a save that already had the dash
## gets them on its next walk down the hall.
enum MentorTalk { TEACH, READ, IDLE, CHAIN_INTRO, CHAIN_AFTER, CALL }
var _mentor_talk: int = MentorTalk.IDLE

## The chain-dash page is closed and the overlay is out of the way -- main.gd
## starts the mentor's demonstration in her room.
signal mentor_demo_requested()
## The last CHAIN_AFTER page is closed: the chain is taught, and her class
## starts putting hands up for the player to try it on.
signal mentor_chain_taught()
## The last CALL page is closed: the call is taught, and she shows it.
signal mentor_call_demo_requested()


func show_mentor() -> void:
	_open(Mode.MENTOR)
	if not Game.dash_taught:
		_mentor_talk = MentorTalk.TEACH
		_sel = 0
	elif not Game.chain_dash_taught:
		_mentor_talk = MentorTalk.CHAIN_INTRO
		_sel = 0
	elif not Game.call_response_taught:
		_mentor_talk = MentorTalk.CALL
		_sel = 0
	elif _boss_term_due():
		_mentor_talk = MentorTalk.READ
	else:
		_mentor_talk = MentorTalk.IDLE
	_render_mentor()


## A boss term is the current one, or the next one is on the cadence -- so
## "just before" a boss term counts as well as being in it. See
## Game.draw_term_paths() / Balance.boss_term_interval.
func _boss_term_due() -> bool:
	Balance.ensure_loaded()
	if String(Game.term_path.get("kind", "")) == "boss":
		return true
	return Balance.boss_term_interval > 0 \
		and Game.term % Balance.boss_term_interval == 0


## Someone at your desk, waiting on an answer.
##
## Deliberately the smallest screen in the game: a face, one sentence from
## them, two or three ways to answer, and after you pick, one sentence back.
## The lesson clock does NOT stop while this is open -- nothing else in this
## HUD stops it either, and dithering costing you seconds is the point.
##
## Prose only, in both directions. A choice never prints its price; you feel
## it at the purse afterwards. "Give what you can", never "-40 coins".
var _caller_row: Dictionary = {}
var _caller_who: StudentData = null
var _caller_sel := 0
var _caller_said := ""


func show_caller(row: Dictionary, who: StudentData) -> void:
	_caller_row = row
	_caller_who = who
	_caller_sel = 0
	_caller_said = ""
	_open(Mode.CALLER)
	_render_caller()


## Who is doing the asking, as a name the player already knows.
func _caller_name() -> String:
	if String(_caller_row.get("speaker", "")) == "student" and _caller_who != null:
		return _caller_who.display_name
	return "THE PRINCIPAL"


func _render_caller() -> void:
	overlay.visible = true
	body.visible = true
	rich.visible = false
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 0)
	# The same busts every other screen showing a face already uses.
	if String(_caller_row.get("speaker", "")) == "student" and _caller_who != null:
		portrait.texture = load("res://art/portrait_%s.png" % _caller_who.art)
	else:
		portrait.texture = PRINCIPAL_PORTRAIT
	portrait.visible = true
	title.text = _caller_name()
	var rows: Array[String] = []
	if _caller_said != "":
		# Answered. Their reply, and nothing to choose any more.
		rows.append(_caller_said)
		body.text = "
".join(rows)
		hint.text = "E - back to it"
		return
	rows.append("\"%s\"" % String(_caller_row.get("line", "")))
	rows.append("")
	var choices: Array = _caller_row.get("choices", [])
	for i in choices.size():
		var c: Dictionary = choices[i]
		rows.append("%s %s" % [">" if i == _caller_sel else " ",
			String(c.get("label", ""))])
	body.text = "
".join(rows)
	hint.text = "W/S - choose    E - say it"


## Selection then confirmation, the same idiom the student file uses for its
## own actions -- no new key for a screen that is only ever open for a moment.
func _handle_caller_input() -> void:
	var choices: Array = _caller_row.get("choices", [])
	if _caller_said != "":
		if Game.claim_interact() or Input.is_action_just_pressed("cancel"):
			close()
		return
	if Input.is_action_just_pressed("move_down"):
		_caller_sel = (_caller_sel + 1) % maxi(1, choices.size())
		Sfx.play("blip")
		_render_caller()
	elif Input.is_action_just_pressed("move_up"):
		_caller_sel = (_caller_sel - 1 + choices.size()) % maxi(1, choices.size())
		Sfx.play("blip")
		_render_caller()
	elif Game.claim_interact():
		caller_answered.emit(_caller_row, _caller_sel, _caller_who)


## The room owns the outcome, not this screen: hud says what was picked, the
## classroom decides what it does, and hands back the line to show.
signal caller_answered(row: Dictionary, index: int, who: StudentData)


## Show what they said back, once the room has resolved it.
func caller_replied(said: String) -> void:
	_caller_said = said if said != "" else "They nod, and go back to their seat."
	Sfx.play("confirm")
	_render_caller()


func _render_mentor() -> void:
	overlay.visible = true
	body.visible = true
	rich.visible = false
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 0)
	# The mentor's own bust -- a recolour of the one character model, same
	# as show_student() does for a child.
	portrait.texture = load("res://art/portrait_mentor.png")
	portrait.visible = true
	match _mentor_talk:
		MentorTalk.TEACH, MentorTalk.CHAIN_INTRO, MentorTalk.CHAIN_AFTER, MentorTalk.CALL:
			var pages := _mentor_pages()
			_sel = clampi(_sel, 0, pages.size() - 1)
			title.text = "THE MENTOR"
			body.text = "\n".join(pages[_sel])
			var last := _sel >= pages.size() - 1
			if (_mentor_talk == MentorTalk.CHAIN_INTRO \
					or _mentor_talk == MentorTalk.CALL) and last:
				hint.text = "E - watch"
			elif _mentor_talk == MentorTalk.TEACH and last \
					and not Game.chain_dash_taught:
				hint.text = "E - go on"
			else:
				hint.text = "E - go on" if not last else "E - back to it"
		MentorTalk.READ:
			title.text = "A WORD BEFORE THE PAPER"
			body.text = _mentor_readiness_text() + _mentor_tactic_text()
			hint.text = "E - close"
		_:
			title.text = "THE MENTOR"
			body.text = "\n".join(_MENTOR_IDLE)
			hint.text = "E - close"


## RoomSim, run against the player's OWN roster and room, phrased as a tier
## of confidence. Never a number: this game does not print a score for a
## child, and a boss preview is not where it starts. Runs on a COPY of the
## roster and a throwaway RNG, so reading it neither scrambles the class's
## lesson state nor perturbs the seeded run.
func _mentor_readiness_text() -> String:
	Balance.ensure_loaded()
	if Game.roster.is_empty():
		return "\n".join([
			"No class to read yet. Come back once there",
			"are children in the room."])
	var probe: Array = []
	for s: StudentData in Game.roster:
		probe.append(StudentData.from_dict(s.to_dict()))
	var rv := 0.0
	var seats := 0
	for i in Layout.seat_count():
		if Game.student_in_seat(i) != null:
			rv += Game.room_score(i)
			seats += 1
	rv = rv / maxf(1.0, float(seats))
	var throw := RandomNumberGenerator.new()
	throw.seed = int(Game.rng.seed) + Game.term * 7919 + Game.day
	var sim := RoomSim.play_day(probe, Staff.archetype("steady"), rv,
		Game.lesson, throw)
	var avg := float(sim.get("average", 0.0))
	if avg >= Balance.grade_band_b:
		return "\n".join([
			"I have watched rooms like yours walk a paper",
			"like this. Go in expecting to pass it."])
	if avg >= Balance.grade_band_c:
		return "\n".join([
			"It could go either way. Move a desk or two,",
			"teach it hard, and you are in with a shout."])
	return "\n".join([
		"Honestly? Not yet. As the room stands, this",
		"paper will be a hard morning for the class."])


## What the paper actually DOES, from its card, so the readiness read is
## followed by something to do about it. Only once a boss card has been
## taken at the fork; before that there is nothing to point at.
func _mentor_tactic_text() -> String:
	if String(Game.term_path.get("kind", "")) != "boss":
		return ""
	var tactic := String(Game.term_path.get("tactic", ""))
	if tactic.is_empty():
		return ""
	return "\n\n" + _wrap(tactic, 46, 3)


## The page set the current talk is walking through.
func _mentor_pages() -> Array:
	match _mentor_talk:
		MentorTalk.CHAIN_INTRO:
			return MENTOR_CHAIN_INTRO
		MentorTalk.CHAIN_AFTER:
			return MENTOR_CHAIN_AFTER
		MentorTalk.CALL:
			return MENTOR_CALL
	return MENTOR_PAGES


## Back from the demonstration: the mentor is at the front again, and says
## what the player just watched.
func show_mentor_after_demo() -> void:
	_open(Mode.MENTOR)
	_mentor_talk = MentorTalk.CHAIN_AFTER
	_sel = 0
	_render_mentor()


func _handle_mentor_input() -> void:
	if not Game.claim_interact():
		return
	Sfx.play("blip")
	if _mentor_talk == MentorTalk.CHAIN_INTRO \
			or _mentor_talk == MentorTalk.CHAIN_AFTER:
		_handle_chain_page()
		return
	if _mentor_talk == MentorTalk.CALL:
		if _sel < MENTOR_CALL.size() - 1:
			_sel += 1
			_render_mentor()
			return
		Game.call_response_taught = true
		close()
		mentor_call_demo_requested.emit()
		return
	if _mentor_talk != MentorTalk.TEACH:
		close()
		return
	# Each verb unlocks as the mentor finishes explaining it.
	if _sel == MENTOR_DASH_PAGE:
		Game.dash_taught = true
	elif _sel == MENTOR_ANSWER_ALL_PAGE:
		Game.answer_all_taught = true
	if _sel < MENTOR_PAGES.size() - 1:
		_sel += 1
		_render_mentor()
	else:
		# belt and braces: whatever page order a future edit lands on, the
		# visit as a whole always leaves both verbs taught
		Game.dash_taught = true
		Game.answer_all_taught = true
		# A first visit runs straight on into the chain dash -- the feet
		# page has only just been read, so this is the moment it lands.
		if not Game.chain_dash_taught:
			_mentor_talk = MentorTalk.CHAIN_INTRO
			_sel = 0
			_render_mentor()
			return
		close()


## CHAIN_INTRO's last page hands the screen to the demonstration; the last
## CHAIN_AFTER page teaches the chain and lets the player try it.
func _handle_chain_page() -> void:
	var pages := _mentor_pages()
	if _sel < pages.size() - 1:
		_sel += 1
		_render_mentor()
		return
	if _mentor_talk == MentorTalk.CHAIN_INTRO:
		close()
		mentor_demo_requested.emit()
		return
	Game.chain_dash_taught = true
	close()
	mentor_chain_taught.emit()


func show_office() -> void:
	_open(Mode.OFFICE)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "THE PRINCIPAL'S OFFICE"
	# No portrait here, on purpose -- Rich runs the full body height in
	# this screen (a list this long has nowhere else to go), and the
	# portrait box sits square inside that rectangle. On the student bio
	# screen the text is written to start BELOW the portrait; a list
	# screen like this one cannot promise the same and a portrait UNDER
	# wrapped text is worse than no portrait, confirmed by screenshot
	# rather than assumed. The corner popup (principal_says) is where the
	# face actually appears now.

	var all := Milestones.all()
	var earned := Game.milestones.size()
	var n := clampi(int(round(float(earned) / float(maxi(1, all.size())) * 20.0)), 0, 20)

	var lines: Array[String] = []
	lines.append("[color=#%s]The school is %s, and that is because of you.[/color]" % [
		DIM, Game.reputation_words()])
	lines.append("[color=#%s]Milestones[/color]  [color=#%s]%s[/color][color=#3a3a42]%s[/color]  %d/%d" % [
		C_COIN, C_COIN, _cells(BAR_FULL, n), _cells(BAR_EMPTY, 20 - n), earned, all.size()])
	lines.append("[color=#%s]%d terms taught, %d children sent up.[/color]" % [
		DIM, Game.term_history.size(), Game.graduated.size()])
	lines.append("")

	# TUTORIALS is windowed, the same way Career pages past thirty
	# milestones -- confirmed by screenshot rather than assumed: with all
	# ten printed flat, the panel cut off after the fourth with no sign
	# anything was missing, the exact silent-clip failure mode this
	# project keeps a rule against. A shelf that is meant to grow with the
	# game cannot be a fixed list that quietly stops being fully visible
	# the day it does.
	var shown := 5
	_sel = clampi(_sel, 0, maxi(0, TUTORIALS.size() - 1))
	var lo := _window_start(TUTORIALS.size(), shown)
	lines.append("[color=#%s]TUTORIALS[/color]  [color=#%s]%d-%d of %d[/color]" % [
		C_COIN, DIM, lo + 1, mini(TUTORIALS.size(), lo + shown), TUTORIALS.size()])
	# The tip under the cursor is printed whole; the others are one line each,
	# cut at a word, so the list keeps its shape in the pixel font.
	for i in range(lo, mini(TUTORIALS.size(), lo + shown)):
		var tip := String(TUTORIALS[i]) if i == _sel \
			else _fit_px(String(TUTORIALS[i]), rich.size.x - 16.0)
		lines.append("[color=#%s]%s%s[/color]" % [
			C_LESSON if i == _sel else DIM, ">" if i == _sel else " ", tip])
	rich.text = "\n".join(lines)
	_reveal_rich(0.3)
	hint.text = "Up/Down more tips   E - full career list   Esc - close"


func _handle_office_input() -> void:
	if Input.is_action_just_pressed("cancel"):
		Sfx.play("blip")
		close()
	elif Input.is_action_just_pressed("move_down"):
		_sel = (_sel + 1) % TUTORIALS.size()
		Sfx.play("blip")
		show_office()
	elif Input.is_action_just_pressed("move_up"):
		_sel = (_sel - 1 + TUTORIALS.size()) % TUTORIALS.size()
		Sfx.play("blip")
		show_office()
	elif Game.claim_interact():
		Sfx.play("blip")
		_career_page = CAREER_MILESTONES     # always open on the list
		_alum_open = -1
		_sel = 0
		show_career()



## THE TROPHY CASE: what stands in the hallway's case, and what is still to
## win. Opened from the case itself (TrophyCase, E). One row per trophy --
## won ones by name, the rest "- - -" exactly as the career list shows them --
## and the one under the cursor told in full below.
func show_trophies() -> void:
	_open(Mode.TROPHIES)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	var all := Trophies.all()
	title.text = "THE TROPHY CASE  %d/%d" % [Game.trophies.size(), all.size()]
	_sel = clampi(_sel, 0, maxi(0, all.size() - 1))
	var lines: Array[String] = []
	lines.append("[color=#%s]One for every boss term your class has beaten.[/color]" % DIM)
	lines.append("")
	for i in all.size():
		var t: Dictionary = all[i]
		var won := Game.trophies.has(String(t.get("id", "")))
		lines.append("%s [color=#%s]%s[/color]" % [">" if i == _sel else " ",
			C_COIN if won else DIM, String(t.get("name", "")) if won else "- - -"])
	lines.append("")
	var sel: Dictionary = all[_sel] if _sel < all.size() else {}
	var sel_won := Game.trophies.has(String(sel.get("id", "")))
	lines.append("[color=#%s]%s%s[/color]" % [C_LESSON if sel_won else DIM,
		"" if sel_won else "Not yet: ", String(sel.get("blurb", ""))])
	rich.text = "
".join(lines)
	_reveal_rich(0.25)
	hint.text = "Up/Down - look along the shelf   Esc - close"


func _handle_trophies_input() -> void:
	var n := Trophies.count()
	if Input.is_action_just_pressed("cancel") or Game.claim_interact():
		Sfx.play("blip")
		close()
	elif Input.is_action_just_pressed("move_down"):
		_sel = (_sel + 1) % n
		Sfx.play("blip")
		show_trophies()
	elif Input.is_action_just_pressed("move_up"):
		_sel = (_sel - 1 + n) % n
		Sfx.play("blip")
		show_trophies()


# ------------------------------------------------------------ the grade book
#
# The owner's ask (Oct 2026): "keep a log book of all the grades on the table
# where you submit the papers". The register lying open on your desk, read on
# its own key (U, interact/grade_book.gd): every grade the run has given
# (Game.grade_log), in the same open book the curriculum and the lesson plans
# use. Like a real register it fills a page at a time, and a new term starts a
# new page. The left page says which lessons a page holds; the right page is
# the register itself -- a row per child, a letter per lesson. The children
# who have since moved up keep their rows, which is what a transcript, which
# leaves with its child, cannot do.
#
# Letters, never the numbers under them. A letter is how this game already
# reports a grade (the lesson report, the exam); "prose, never numbers" bans
# the 0.62 behind it, not the B. The days heading the columns are a day
# counter -- the rule's own sanctioned exception.

## Lessons to a page.
const GRADE_BOOK_COLS := 5
## Children to a page before it scrolls on Up/Down: with the header row and a
## mark for more above or below, the right page's ten rows.
const GRADE_BOOK_ROWS := 7
## The ink a middling grade is written in: plain, neither good nor bad news.
const INK_PLAIN := "3d3428"
## Space either side of a letter in the register: 12px letter + 2 x 6 is a
## 24px column, five of them and a name fit the page's 256px.
const GB_PAD := 6
## Which page is open, counting from the first; -1 opens on the newest.
var _gb_page: int = -1
## The first child row shown, when the class is longer than the page.
var _gb_top: int = 0


## The book cut into its pages: GRADE_BOOK_COLS entries each, and never two
## terms on one page. [[entry, ...], ...], oldest first.
func grade_book_pages() -> Array:
	var pages: Array = []
	var cur: Array = []
	var cur_term := -1
	for e: Dictionary in Game.grade_log:
		var t := int(e.get("term", 1))
		if not cur.is_empty() and (t != cur_term or cur.size() >= GRADE_BOOK_COLS):
			pages.append(cur)
			cur = []
		cur_term = t
		cur.append(e)
	if not cur.is_empty():
		pages.append(cur)
	return pages


## The children with a grade on this page, as {id, name, here}: the class as
## it sits now first, in seat order, then anyone who has moved on since, in
## the order the book first meets them -- their rows stay, written in fainter.
func grade_book_children(page: Array) -> Array:
	var on_page := {}
	for e: Dictionary in page:
		for r: Dictionary in e.get("rows", []):
			on_page[int(r.get("id", -1))] = String(r.get("name", ""))
	var out: Array = []
	var now := Game.roster.duplicate()
	now.sort_custom(func(a: StudentData, b: StudentData) -> bool:
		return a.seat_index < b.seat_index)
	for s: StudentData in now:
		if on_page.has(s.id):
			out.append({"id": s.id, "name": s.first_name(), "here": true})
			on_page.erase(s.id)
	for e: Dictionary in page:
		for r: Dictionary in e.get("rows", []):
			var rid := int(r.get("id", -1))
			if on_page.has(rid):
				out.append({"id": rid, "name": String(on_page[rid]), "here": false})
				on_page.erase(rid)
	return out


## One child's grade in one entry of the book, or -1 if they had none there.
static func _grade_in(entry: Dictionary, sid: int) -> float:
	for r: Dictionary in entry.get("rows", []):
		if int(r.get("id", -1)) == sid:
			return float(r.get("grade", 0.0))
	return -1.0


## A grade as the book writes it: the letter, in ink that says how it went --
## green for the top two, red for the bottom ones, plain for the middle.
func _book_letter(g: float) -> String:
	var l := Game.grade_letter(g)
	var hue := INK_PLAIN
	if l == "A" or l == "B":
		hue = _on_paper(C_GOOD)
	elif l == "D" or l == "E" or l == "F":
		hue = _on_paper(C_BAD)
	return "[color=#%s]%s[/color]" % [hue, l]


## What heads an entry's column, and names it on the left page: its day, or
## "Ex" for the term exam, which is sat at the bell of the last one.
static func _book_day(entry: Dictionary) -> String:
	if String(entry.get("kind", "")) == "exam":
		return "Ex"
	return str(int(entry.get("day", 0)))


## Opened at the desk: on the newest page, from the top of the class.
func open_grade_book() -> void:
	_gb_page = -1
	_gb_top = 0
	show_grade_book()


func show_grade_book() -> void:
	_open(Mode.GRADE_BOOK)
	body.visible = false
	rich.visible = true
	_book(true)
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "THE GRADE BOOK"
	var pages := grade_book_pages()
	if pages.is_empty():
		_gb_page = -1
		rich_left.text = "[color=#%s]Nothing written in it yet.[/color]" % INK_DIM
		rich.text = "Every grade you give goes in here, lesson by lesson, and stays after the child has moved on."
		_reveal_rich(0.2)
		hint.text = "Esc - close"
		return
	if _gb_page < 0 or _gb_page >= pages.size():
		_gb_page = pages.size() - 1
	_book_turned(_gb_page)
	var page: Array = pages[_gb_page]

	# --- the left page: which lessons these are ---
	var legend := ""
	var total := 0.0
	var marks := 0
	for e: Dictionary in page:
		var label := String(e.get("name", ""))
		match String(e.get("kind", "lesson")):
			"test":
				label += " test"
		var hue := strand_colour(String(e.get("strand", "")))
		if String(e.get("kind", "")) == "exam":
			hue = C_COIN
		legend += "[cell padding=0,0,8,0][color=#%s]%s[/color][/cell][cell][color=#%s]%s[/color][/cell]" % [
			INK_DIM, _book_day(e), _on_paper(hue), _fit_px(label, 186)]
		for r: Dictionary in e.get("rows", []):
			total += float(r.get("grade", 0.0))
			marks += 1
	var left: Array[String] = []
	left.append("[color=#%s]Term %d[/color]" % [_on_paper(C_LESSON),
		int((page[0] as Dictionary).get("term", 1))])
	left.append("[table=2]%s[/table]" % legend)
	if marks > 0:
		var avg := Game.grade_letter(total / float(marks))
		left.append("[font_size=%d][color=#%s]On these the class comes out at %s %s.[/color][/font_size]" % [
			UI_SMALL, INK_DIM, "an" if avg in ["A", "E", "F"] else "a", avg])
	left.append("[font_size=%d][color=#%s]Page %d of %d[/color][/font_size]" % [
		UI_SMALL, INK_DIM, _gb_page + 1, pages.size()])
	rich_left.text = "\n".join(left)

	# --- the right page: the register ---
	var kids := grade_book_children(page)
	_gb_top = clampi(_gb_top, 0, maxi(0, kids.size() - GRADE_BOOK_ROWS))
	# A table cell is only as wide as its text, and in this Godot an expand
	# ratio does not widen a one-word column -- the letters ran together into
	# one word ("BAADD"). Padding spaces them instead: every letter is the same
	# 12px in this font and so is every small day number, so even padding
	# either side keeps each one centred over its column.
	var col := "[cell padding=%d,0,%d,0]" % [GB_PAD, GB_PAD]
	var cells := "[cell padding=0,0,10,0] [/cell]"
	for e: Dictionary in page:
		cells += "%s[font_size=%d][color=#%s]%s[/color][/font_size][/cell]" % [
			col, UI_SMALL, INK_DIM, _book_day(e)]
	for k: Dictionary in kids.slice(_gb_top, _gb_top + GRADE_BOOK_ROWS):
		cells += "[cell padding=0,0,10,0][color=#%s]%s[/color][/cell]" % [
			INK_PLAIN if bool(k["here"]) else INK_DIM, _fit_px(String(k["name"]), 96)]
		for e: Dictionary in page:
			var g := _grade_in(e, int(k["id"]))
			cells += "%s%s[/cell]" % [col,
				_book_letter(g) if g >= 0.0 else "[color=#%s]-[/color]" % INK_DIM]
	var right: Array[String] = []
	if _gb_top > 0:
		right.append("[center][color=#%s]^ more above[/color][/center]" % INK_DIM)
	right.append("[table=%d]%s[/table]" % [page.size() + 1, cells])
	if _gb_top + GRADE_BOOK_ROWS < kids.size():
		right.append("[center][color=#%s]v more below[/color][/center]" % INK_DIM)
	rich.text = "\n".join(right)
	_reveal_rich(0.25)
	hint.text = _hint_clip("Left/Right - turn the page%s   Esc - close" % (
		"   Up/Down - more names" if kids.size() > GRADE_BOOK_ROWS else ""))


func _handle_grade_book_input() -> void:
	var pages := grade_book_pages().size()
	if Input.is_action_just_pressed("cancel") or Game.claim_interact() \
			or Game.claim_action("grades"):
		Sfx.play("blip")
		close()
	elif pages > 0 and Input.is_action_just_pressed("move_left"):
		if _gb_page > 0:
			_gb_page -= 1
			_gb_top = 0
			show_grade_book()
		else:
			Sfx.play("deny")              # the first page: nothing earlier
	elif pages > 0 and Input.is_action_just_pressed("move_right"):
		if _gb_page < pages - 1:
			_gb_page += 1
			_gb_top = 0
			show_grade_book()
		else:
			Sfx.play("deny")              # the newest page: nothing later yet
	elif pages > 0 and Input.is_action_just_pressed("move_down"):
		_gb_top += 1
		Sfx.play("blip")
		show_grade_book()
	elif pages > 0 and Input.is_action_just_pressed("move_up"):
		_gb_top = maxi(0, _gb_top - 1)
		Sfx.play("blip")
		show_grade_book()


## What kind of teacher are you?
##
## Asked once, at the start of a run. Your own subject is a step easier to
## get a class through and pays better; everything else is a step harder.
## It is a lean rather than a cage -- a class that only ever sees one
## subject learns one subject, so you will teach out of field sometimes.
func show_specialism() -> void:
	_open(Mode.SPECIALISM)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	title.text = "WHAT DO YOU TEACH?"

	var strands := Curriculum.strands()
	_sel = clampi(_sel, 0, maxi(0, strands.size() - 1))
	var lines: Array[String] = []
	for i in strands.size():
		var st := String(strands[i])
		var count := 0
		for l: Dictionary in Curriculum.lessons:
			if String(l.get("strand", "")) == st:
				count += 1
		lines.append("%s [color=#%s]%-12s[/color] [color=#%s]%d lessons[/color]" % [
			">" if i == _sel else " ", strand_colour(st),
			Curriculum.strand_label(st), DIM, count])
	lines.append("")
	lines.append("[color=#%s]Your own subject is easier to teach and pays more.[/color]" % DIM)
	lines.append("[color=#%s]The rest are harder. You can still teach them.[/color]" % DIM)
	rich.text = "\n".join(lines)
	_reveal_rich(0.35)
	hint.text = "Up/Down choose    E - this is my subject"


## A new term. Who left, who stayed, who is new.
##
## This screen is the reward for the one before it: it names what you KEEP.
## The room, the curriculum and your own experience carry over, because they
## are what you spent twenty days building -- and the class does not, which
## is the cost. Teach them well and they move up and out, and you begin
## again with children you have never met.
func show_new_term(info: Dictionary) -> void:
	_open(Mode.REPORT)
	# Closing THIS report hands off to the path-pick screen rather than
	# straight back to play -- see the Mode.REPORT close handling.
	_showing_new_term = true
	Sfx.play("start")
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)

	var prev: Dictionary = info.get("previous", {})
	title.text = "TERM %d" % int(info.get("term", Game.term))

	var moved: Array = info.get("moved_up", [])
	var joined: Array = info.get("joined", [])
	var lines: Array[String] = []
	lines.append("[color=#%s]Last term: %s, %d of %d passed.[/color]" % [
		DIM, String(prev.get("letter", "?")), int(prev.get("passed", 0)),
		int(prev.get("total", 0))])
	if moved.is_empty():
		lines.append("[color=#%s]Nobody moved up. They are all still here.[/color]"
			% C_BAD)
	else:
		lines.append("[color=#%s]Moved up:[/color] %s" % [C_GOOD,
			_names_line(moved)])
	if not joined.is_empty():
		lines.append("[color=#%s]New in your class:[/color] %s" % [C_ROOM,
			_names_line(joined)])
	lines.append("")
	lines.append("[color=#%s]You keep[/color]  %d items   %d concepts   level %d   %d coins" % [
		C_KNOW, Game.room_items.size(), Game.concepts.size(),
		Game.teacher_level, Game.coins])
	lines.append("[color=#%s]This term you need %d of them through.[/color]" % [
		C_BAD, int(info.get("target", Game.term_target()))])
	var boss_prev := String(prev.get("boss", ""))
	if boss_prev != "" and bool(prev.get("met", false)):
		lines.append("[color=#%s]%s: cleared. The trophy is on the shelf.[/color]" % [
			C_COIN, boss_prev])
	rich.text = "\n".join(lines)
	_reveal_rich(0.5)
	hint.text = "E - first day of term %d" % int(info.get("term", Game.term))


## First names only, and never more than the line holds.
func _names_line(names: Array) -> String:
	var out: Array[String] = []
	for n: String in names:
		out.append(String(n).split(" ")[0])
	var line := ", ".join(out)
	return line if line.length() <= 34 else line.substr(0, 31) + "..."


## What you have learned to teach, and what is still ahead.
##
## Each row carries the REAL standard code its lesson cites. A concept is a
## component of that standard and shares its code rather than getting a
## made-up one of its own — see the note at the top of data/curriculum.json.
## One colour per subject, so the shape of what you have taught is readable
## before a single word is. Four strands, four hues, and the same hue is used
## for that subject everywhere it appears.
const STRAND_COLOUR := {
	"math": "8ab4f8",      # blue
	"ela": "9fd89f",       # green
	"science": "f2c66b",   # amber
	"social": "d0a3e8",    # violet
}
const DIM := "6a6a72"
## The book pages are cream, and every other screen in this game is dark --
## so the greys that read as "quiet" on a black panel read as "missing" on
## paper. These are the same roles, re-mixed for ink.
const INK_DIM := "6b5f4a"       # DIM, on paper


## A UI colour, re-mixed to read as ink on the book's cream pages.
##
## The whole palette was built for a dark panel, where "quiet" is pale --
## and a pale grey on cream paper is not quiet, it is gone. A common
## lesson plan's own title was invisible until this existed. Hue is kept,
## so a rarity still reads as itself; only the lightness is pulled down far
## enough to sit on paper.
func _on_paper(hex: String) -> String:
	var c := Color.from_string("#" + hex, Color(0.2, 0.18, 0.14))
	while c.get_luminance() > 0.34:
		c = c.darkened(0.15)
	return c.to_html(false)


static func strand_colour(strand: String) -> String:
	return String(STRAND_COLOUR.get(strand, "cfcfcf"))


## The subject's own mark, as BBCode, for a RichTextLabel.
##
## One per STRAND, not per lesson: there are 40 lessons and four strands, and
## the row already carries the lesson's name -- what the icon adds is the
## family, which the name does not say at a glance. Drawn by
## tools/make_ui.py::strand_icon(), in the same four colours as
## STRAND_COLOUR above, which a test holds the two ends of.
##
## Empty string for an unknown strand rather than a broken-image box: a
## crafted lesson with a strand nobody drew an icon for should lose the
## icon, not the row.
## Written out as LITERAL paths rather than assembled from the strand name.
## The art audit scans this source for res:// literals, and a path built by
## interpolation is invisible to it -- which is exactly how these four icons
## landed in the "on disk, nothing mentions it" list the moment they were
## drawn. FLIP_TEXTURES carries the same warning for the same reason.
const STRAND_ICON_PATH := {
	"ela": "res://art/icon_ela.png",
	"math": "res://art/icon_math.png",
	"science": "res://art/icon_science.png",
	"social": "res://art/icon_social.png",
}


static func strand_icon(strand: String) -> String:
	if not STRAND_ICON_PATH.has(strand):
		return ""
	return "[img=16]%s[/img]" % String(STRAND_ICON_PATH[strand])


## How many subjects the panel lists at once, leaving room for the heading
## and the two detail lines under it.
const CURRIC_ROWS := 7


## WHAT YOU CAN TEACH.
##
## This screen used to be ten rows of "Reading  RF4  ***  next after 1 more".
## Every one of those columns is meaningful to somebody who wrote the game and
## meaningless to somebody playing it: RF4 is a citation, the stars had no
## label, and the one sentence saying why any of it mattered was on the hint
## bar where nobody reads it.
##
## It is a list with a cursor now. Each row says, in words, how well you know
## that subject. The citation and the objective belong to whichever row is
## selected and sit underneath, where they read as provenance rather than as
## noise. Nothing was removed -- it stopped being the loudest thing on screen.
func show_curriculum() -> void:
	_open(Mode.CURRICULUM)
	body.visible = false
	rich.visible = true
	_book(true)
	rich.add_theme_constant_override("line_separation", 1)
	# 11, not the 12 every other book screen uses: this is the one with four
	# columns on a row. Confirmed by screenshot, not by counting characters.
	rich.add_theme_font_size_override("normal_font_size", UI_SMALL)

	var lessons := Curriculum.lessons
	if lessons.is_empty():
		return
	_sel = clampi(_sel, 0, lessons.size() - 1)
	_book_turned(_sel)
	title.text = "WHAT YOU CAN TEACH"

	var left: Array[String] = []
	var lines: Array[String] = []
	# What you are teaching next, and what you trained in -- the two things
	# this screen is now FOR.
	var next_id := Game.chosen_lesson if Game.chosen_lesson != "" 		else String(Game.lesson.get("id", ""))
	left.append("[color=#%s]You teach %s[/color]
[color=#%s]%s[/color]" % [
		C_LESSON, Curriculum.short_name(Curriculum.by_id(next_id)),
		INK_DIM, "trained in %s" % Curriculum.strand_label(Game.specialism)
			if Game.specialism != "" else "no speciality"])
	var known: int = Game.concepts.size()
	if known == 0:
		left.append("[color=#%s]Teach a subject and you get better at teaching it.[/color]"
			% C_LESSON)
	else:
		# Prose, never numbers. This printed "+12% to every grade", which
		# is the one rule the whole UI is meant to keep -- and the test
		# only covered the student file, so nothing caught it.
		#
		# Banded off the RATIO to the cap rather than the raw figure, so
		# the thresholds stay in balance.json where every tunable lives.
		var ratio: float = Game.concept_bonus() / maxf(0.0001, Balance.concept_bonus_cap)
		var worth := "is starting to show"
		if ratio >= 0.99:
			worth = "is worth as much as it can be"
		elif ratio >= 0.66:
			worth = "lifts every grade you give"
		elif ratio >= 0.33:
			worth = "is worth real marks now"
		left.append("[color=#%s]Knowing your subjects %s.[/color]" % [
			C_LESSON, worth])

	var lo := _window_start(lessons.size(), CURRIC_ROWS)
	for i in range(lo, mini(lessons.size(), lo + CURRIC_ROWS)):
		var l: Dictionary = lessons[i]
		var lid := String(l.get("id", ""))
		var total: int = Curriculum.concepts_of(lid).size()
		var got := 0
		for c: Dictionary in Curriculum.concepts_of(lid):
			if Game.knows_concept(String(c.get("id", ""))):
				got += 1
		var hue := strand_colour(String(l.get("strand", "")))
		var taught: bool = Game.times_taught(lid) > 0
		var mine: bool = Game.specialism != "" 			and String(l.get("strand", "")) == Game.specialism
		# The row carries four things now: the strand mark, the name, how
		# hard it is, and how well you know it. It does not fit at font 12 --
		# the icon was the straw, and the longest row ("Essay Writing")
		# wrapped onto a second line, which breaks the panel budget. The
		# width came from the page and the type size rather than from
		# dropping one of the four: the difficulty bar and the mastery words
		# each have a test asserting they are on every row, and both tests
		# are right that they should be.
		lines.append("%s%s%s [color=#%s]%s[/color] %s [color=#%s]%s[/color]" % [
			"*" if mine else " ",
			">" if i == _sel else " ",
			strand_icon(String(l.get("strand", ""))),
			hue if taught else INK_DIM,
			Curriculum.short_name(l).rpad(9),
			_difficulty_bar(Curriculum.difficulty(l)),
			INK_DIM, _mastery_words(l, got, total)])

	# The left page doubles as a detail panel for whatever the marker is on.
	# That is a better home for the difficulty bar than a column was: it is
	# about the one subject you are actually deciding on.
	var pick: Dictionary = lessons[_sel]
	left.append("")
	left.append("%s [color=#%s]%s[/color]" % [
		strand_icon(String(pick.get("strand", ""))),
		strand_colour(String(pick.get("strand", ""))),
		Curriculum.short_name(pick)])
	# How many times you have stood at the podium and taught THIS.
	#
	# The number was already kept (Game.taught, which is what unlocks
	# concepts) and had never been shown; the screen said "you know it well"
	# and left you to guess whether that was two lessons or nine. It is a
	# count of what YOU have done, not a score standing in for a child's
	# ability, which is the side of the prose-never-numbers rule that
	# CLAUDE.md names as the sanctioned exception -- the same side a coin
	# total and a day counter sit on.
	left.append("[color=#%s]%s[/color]" % [INK_DIM, _taught_words(
		String(pick.get("id", "")))])
	left.append("[color=#%s]%s[/color]" % [INK_DIM, _wrap(_mastery_words(pick,
		_known_of(pick),
		Curriculum.concepts_of(String(pick.get("id", ""))).size()), 22, 1)])

	rich_left.text = "
".join(left)

	rich.text = "\n".join(lines)
	_reveal_rich(0.3)

	# The selected subject, and what teaching it AGAIN would buy you. Naming
	# the next concept is worth more than restating the objective: it is the
	# thing the player is deciding about.
	var std := String(lessons[_sel].get("standard", ""))
	hint.text = _hint_clip("%s%s   E - teach this next%s" % [
		std, "" if std == "" else "  ",
		"   Tab - craft a lesson" if Game.lesson_crafting_unlocked() else ""])


## How many times you have taught this lesson, in words and a number.
##
## Singular for one, because "Taught 1 time" is the kind of thing that makes
## a screen feel generated rather than written.
func _taught_words(lesson_id: String) -> String:
	var n := Game.times_taught(lesson_id)
	if n == 0:
		return "Never taught"
	if n == 1:
		return "Taught once"
	if n == 2:
		return "Taught twice"
	return "Taught %d times" % n



## TEACH ON YOUR OWN — choose how many days to hand over.
##
## A chooser rather than a straight "skip 5": the number IS the decision.
## One day is a day off; five is most of a week of a term you are being
## judged on, run by someone competent who is not you.
##
## Deliberately says what it costs before you commit. A confirmation screen
## that only says "are you sure" makes the player guess what they are sure
## about.
var _skip_days: int = 1

func show_skip() -> void:
	var most: int = Game.skip_days_available()
	if most <= 0:
		# Nothing to say yes to. The exam is the one day the game is
		# actually asking about, so a skip may not reach it.
		principal_says("skip_none", "Not now — the exam is too close.")
		return
	_open(Mode.SKIP)
	body.visible = false
	rich.visible = true
	_skip_days = clampi(_skip_days, 1, most)
	title.text = "TEACH ON YOUR OWN"

	var lines: Array[String] = []
	lines.append("[color=#%s]How many days should the class carry on without you?[/color]"
		% DIM)
	lines.append("")
	var pips := ""
	for i in most:
		pips += "[color=#%s]%s[/color]" % [
			C_LESSON if i < _skip_days else BAR_TRACK,
			_cells(BAR_FULL if i < _skip_days else BAR_EMPTY, 1)]
	lines.append("   %s   [color=#%s]%s[/color]" % [pips, C_LESSON,
		"1 day" if _skip_days == 1 else "%d days" % _skip_days])
	lines.append("")
	# What it costs, in the terms the rest of the game uses. Prose, and no
	# number standing in for what any child will manage -- see CLAUDE.md.
	lines.append("[color=#%s]They will be taught steadily, but not by you.[/color]" % DIM)
	lines.append("[color=#%s]No homework goes out on a day you are not here,[/color]" % DIM)
	lines.append("[color=#%s]so none comes back to mark.[/color]" % DIM)
	if _skip_days >= most:
		lines.append("[color=#%s]That is as far as you can go before the exam.[/color]"
			% C_HOMEWORK)
	rich.text = "\n".join(lines)
	hint.text = _hint_clip("Left/Right - days   E - hand it over")


## Run the days the player just agreed to, then show what happened.
func _do_skip() -> void:
	var n := _skip_days
	var world: Node = get_tree().get_first_node_in_group("classroom")
	if world == null or not world.has_method("run_skipped_days"):
		close()
		return
	Sfx.play("confirm")
	var rows: Array = world.run_skipped_days(n)
	show_skip_report(rows)


## What the days you were not there for came to.
##
## One row per day, because "three days passed" with a single average is the
## kind of summary that hides the day it went wrong on -- and the day it went
## wrong on is the whole reason to look.
func show_skip_report(rows: Array) -> void:
	_open(Mode.SKIP_REPORT)
	body.visible = false
	rich.visible = true
	title.text = "WHILE YOU WERE AWAY"
	var lines: Array[String] = []
	if rows.is_empty():
		lines.append("[color=#%s]Nothing happened. No days were handed over.[/color]" % DIM)
	for row: Dictionary in rows:
		var d: Dictionary = row
		lines.append("[color=#%s]Day %d[/color]  %s  [color=#%s]%s[/color]  [color=#%s]+%d coins[/color]" % [
			DIM, int(d.get("day", 0)),
			String(d.get("subject", "")).rpad(12),
			C_LESSON, String(d.get("letter", "?")),
			C_COIN, int(d.get("coins", 0))])
		if String(d.get("joined", "")) != "":
			lines.append("   [color=#%s]%s joined the class.[/color]"
				% [C_GOOD, String(d.get("joined", ""))])
	lines.append("")
	lines.append("[color=#%s]You are back in the room.[/color]" % DIM)
	rich.text = "\n".join(lines)
	hint.text = _hint_clip("E - back to it")

## How many of a subject's concepts you already have.
func _known_of(l: Dictionary) -> int:
	var got := 0
	for c: Dictionary in Curriculum.concepts_of(String(l.get("id", ""))):
		if Game.knows_concept(String(c.get("id", ""))):
			got += 1
	return got


## What one more lesson in this subject unlocks, by name.
func _next_concept_line(l: Dictionary) -> String:
	var lid := String(l.get("id", ""))
	var times := Game.times_taught(lid)
	for c: Dictionary in Curriculum.concepts_of(lid):
		if not Game.knows_concept(String(c.get("id", ""))):
			var more: int = maxi(1, int(c.get("at", 1)) - times)
			return "%d more unlocks \"%s\"" % [more, String(c.get("name", ""))]
	return "nothing left to learn here"


## How hard a lesson is, on a scale you can see BEFORE you commit to
## teaching it. A difficulty you only discover afterwards is a trap rather
## than a decision.
##
## Warm at the hard end and cool at the easy end, so the column reads as a
## temperature down the list rather than as five identical bars.
func _difficulty_bar(level: int) -> String:
	var hue := C_GOOD
	if level >= 4:
		hue = C_BAD
	elif level == 3:
		hue = C_HOMEWORK
	return "[color=#%s]%s[/color][color=#%s]%s[/color]" % [
		hue, _cells(BAR_FULL, level), BAR_TRACK, _cells(BAR_EMPTY, 5 - level)]


## How well you know a subject, as a ladder of states that actually differ.
##
## The first draft printed "N more lessons to learn more" on nearly every
## row, which is a countdown wearing the costume of a description -- seven
## rows saying almost the same thing is a wall of text again. The countdown
## is genuinely useful, so it moved to the detail line for the row you have
## selected, where it is about the decision in front of you.
func _mastery_words(l: Dictionary, got: int, total: int) -> String:
	if Game.times_taught(String(l.get("id", ""))) == 0:
		return "never taught it"
	if total > 0 and got >= total:
		return "you know it inside out"
	if got == 0:
		return "just started it"
	if got * 2 >= total:
		return "you know it well"
	return "getting the hang of it"


## A bar rather than pips. Pips need a legend; a bar does not.
func _mastery_bar(got: int, total: int, hue: String) -> String:
	if total <= 0:
		return ""
	var width := 5
	var n := int(round(float(got) / float(total) * float(width)))
	return "[color=#%s]%s[/color][color=#%s]%s[/color]" % [
		hue, _cells(BAR_FULL, n), BAR_TRACK, _cells(BAR_EMPTY, width - n)]


## Wipe the rich body on, left to right.
##
## RichTextLabel.visible_ratio does this for free, and on a screen built out
## of coloured bars it reads as the bars FILLING rather than as text typing --
## which is the whole reason these screens are bars and not numbers.
##
## Deliberately quick. This is a result you are waiting for, and an
## animation you have to sit through stops being juice the second time you
## see it.
func _reveal_rich(seconds: float = 0.35) -> void:
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	rich.visible_ratio = 0.0
	_reveal = create_tween()
	_reveal.tween_property(rich, "visible_ratio", 1.0, seconds) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## What one item is worth to a desk, as a small bar.
##
## The catalogue used to describe every item with the same four words --
## "helps a little, close by" -- which made a 40-coin cushion and a 320-coin
## lab bench read identically. Scaled against the best bonus in the game, so
## the bar answers "compared to what" rather than being a number with no
## scale attached.
func _worth_bar(bonus: float) -> String:
	var best := 0.001
	for id: String in Items.order():
		best = maxf(best, float(Items.get_def(id).get("bonus", 0.0)))
	var n := clampi(int(round(bonus / best * 5.0)), 1, 5)
	return "[color=#%s]%s[/color][color=#%s]%s[/color]" % [
		C_LESSON, _cells(BAR_FULL, n), BAR_TRACK, _cells(BAR_EMPTY, 5 - n)]




## The quiz results, straight away, worst first.
##
## The ORDER is the whole screen. This is read mid-lesson with the clock
## running, so the useful thing is not a table of scores — it is a queue of
## names to walk to, longest way behind at the top.
func show_quiz_report(result: Dictionary) -> void:
	_open(Mode.REPORT)
	title.text = "QUICK QUIZ"
	var lines: Array[String] = []
	for r: Dictionary in result.get("rows", []):
		var s: StudentData = r["student"]
		lines.append("%-11s %d/%d %s" % [
			s.first_name(), int(r["right"]), int(r["of"]),
			"  <- behind" if bool(r["flagged"]) else ""])
	lines.append("")
	var n: int = int(result.get("flagged", 0))
	if n == 0:
		lines.append("Nobody is lost. Carry on.")
	else:
		lines.append("%d %s behind. Go over it at their desk." % [
			n, "is" if n == 1 else "are"])
	body.text = "\n".join(lines)
	hint.text = "E - back to the lesson"


func show_lesson_report(results: Array) -> void:
	_open(Mode.REPORT)
	title.text = "%s  (%s)" % [
		String(Game.lesson.get("name", Game.subject)).to_upper(),
		String(Game.lesson.get("standard", ""))]
	# Plain English, not the raw floats this used to print. A player should
	# be able to see WHY a grade happened and what to do differently.
	# The class average moves to the TITLE and the blank line goes: a full
	# class is eight rows, and eight rows plus a spacer plus a summary is
	# two lines more than the panel holds.
	title.text += "   avg %s" % Game.grade_letter(Game.class_average())
	var lines: Array[String] = []
	for r: Dictionary in results:
		var s: StudentData = r["student"]
		lines.append(_clip("%-11s %s   %s" % [
			s.first_name(), String(r["letter"]), _why(s)]))
	body.text = "\n".join(lines)
	hint.text = "E - close.   Ring the bell to end the day."


## A one-line explanation of a grade, in words.
## Wrap text to `width`, keeping at most `max_lines` of it. The panels are
## fixed-height, so an un-wrapped standards objective would run off them.
func _wrap(text: String, width: int, max_lines: int) -> String:
	var out: Array[String] = []
	var line := ""
	for word: String in text.split(" ", false):
		if line.length() + word.length() + 1 > width:
			out.append(line)
			line = word
			if out.size() >= max_lines:
				break
		else:
			line = word if line == "" else line + " " + word
	if out.size() < max_lines and line != "":
		out.append(line)
	if out.size() >= max_lines and text.length() > width * max_lines:
		out[max_lines - 1] = out[max_lines - 1].substr(0, width - 3) + "..."
	return "\n".join(out)


func _why(s: StudentData) -> String:
	var bits: Array[String] = []
	var done := int(round(s.work_fraction() * 100.0))
	if s.work_state == StudentData.Work.COLLECTED:
		bits.append("%d%% done, collected" % done)
	elif done >= 100:
		bits.append("finished but not collected")
	else:
		bits.append("only %d%% done" % done)
	if s.helps_received > 0:
		bits.append("helped %dx" % s.helps_received)
	if s.hw_state == StudentData.HW.MARKED:
		bits.append("hw marked")
	var room := Game.room_score(s.seat_index)
	if room <= Balance.room_base + 0.001:
		bits.append("bare desk")
	return ", ".join(bits)


## The colours the whole game grades in. One meaning per hue, everywhere:
## a bar segment, a legend and a breakdown line all use the same blue for
## "the room", so the colour itself carries the meaning after one reading.
const C_ROOM := "8ab4f8"       # the room you built
const C_LESSON := "9fd89f"     # the lesson you taught
const C_HOMEWORK := "f2c66b"   # homework marked
const C_KNOW := "d0a3e8"       # knowing your material
const C_GOOD := "9fd89f"
const C_BAD := "d08a86"
const C_COIN := "f2c66b"

## One colour per shop category, so a row's hue says what KIND of thing it
## is before the name is read -- and the tab strip is the key, because the
## selected tab is drawn in the same hue as the rows beneath it.
const CAT_COLOUR := {
	"seating": "8ab4f8",     # blue
	"surfaces": "c9a87c",    # wood
	"learning": "9fd89f",    # green
	"subjects": "e8a34a",    # amber -- ten-commits.md step 8, split out of
	                        # learning so specialising a room reads as its
	                        # own section, not a colour shared with the rest
	"comfort": "f2a0b5",     # rose
	"decor": "d0a3e8",       # violet
	"consumable": "f2c66b", # coin gold -- spent, not placed
}


static func cat_colour(cat: String) -> String:
	return String(CAT_COLOUR.get(cat, "cfcfcf"))

## Bars are drawn with block characters rather than #, because a solid bar
## reads as a quantity at a glance and a row of hashes reads as text.
## The empty part of a bar. Light enough to SEE: at #3a3a42 a row with a
## value of zero drew nothing at all, which reads as a rendering fault
## rather than as "this was worth nothing today" -- and on a panel whose job
## is explaining a grade, the zero rows are the important ones.
const BAR_TRACK := "5a5a66"
const BAR_FULL := "█"
const BAR_EMPTY := "░"


## A run of bar cells, at the pixel font's SMALL size. Its block glyphs are a
## full 20px em wide at UI_SIZE, so a 30-cell bar was 600px and wrapped the
## line it sat on; at UI_SMALL a cell is 10px, about what the old font drew.
## RichText only -- every bar in this file is built into BBCode.
func _cells(ch: String, n: int) -> String:
	if n <= 0:
		return ""
	return "[font_size=%d]%s[/font_size]" % [UI_SMALL, ch.repeat(n)]


## One stacked bar, in segments, each in its own colour.
## `parts` is [[amount 0..1, colour], ...]; the remainder is drawn empty.
func _stacked_bar(parts: Array, width: int = 30) -> String:
	var out := ""
	var used := 0
	for part: Array in parts:
		var n: int = clampi(int(round(float(part[0]) * float(width))), 0,
			width - used)
		if n > 0:
			out += "[color=#%s]%s[/color]" % [String(part[1]),
				_cells(BAR_FULL, n)]
			used += n
	if used < width:
		out += "[color=#%s]%s[/color]" % [BAR_TRACK, _cells(BAR_EMPTY, width - used)]
	return out


## WHERE TODAY'S GRADE CAME FROM, and what to do about it.
##
## The first version of this screen printed "room 40%  lesson 0%  hw 3%".
## Every one of those is a percentage of a maximum it never mentioned, so 40
## could not be judged and none of it suggested an action. It showed the
## working and still explained nothing.
##
## Each part is now measured against the most it COULD have been, carries an
## arrow for which way it moved since yesterday, and the panel ends with one
## sentence naming the weakest part and what to do about it.
func _grade_rows(split: Dictionary, before: Dictionary) -> Array[String]:
	Balance.ensure_loaded()
	var room := float(split.get("room", 0.0))
	var lesson := float(split.get("lesson", 0.0))
	var hw := float(split.get("homework", 0.0))
	var know := float(split.get("known", 0.0))

	var out: Array[String] = []
	out.append(_stacked_bar([[room, C_ROOM], [lesson, C_LESSON],
		[hw, C_HOMEWORK], [know, C_KNOW]]))
	out.append(_part_line("the room", room, Balance.room_cap, C_ROOM, before, "room"))
	out.append(_part_line("the lesson", lesson, Balance.lesson_cap, C_LESSON,
		before, "lesson"))
	out.append(_part_line("homework", hw, Balance.homework_cap, C_HOMEWORK,
		before, "homework"))
	out.append(_part_line("what you know", know, Balance.concept_bonus_cap,
		C_KNOW, before, "known"))
	return out


## One part of the grade: what it was worth, out of what it could have been.
func _part_line(label: String, got: float, ceiling: float, hue: String,
		before: Dictionary, key: String) -> String:
	var share: float = 0.0 if ceiling <= 0.0 else clampf(got / ceiling, 0.0, 1.0)
	var arrow := ""
	if before.has(key):
		var was := float(before[key])
		if got > was + 0.005:
			arrow = "[color=#%s] up[/color]" % C_GOOD
		elif got < was - 0.005:
			arrow = "[color=#%s] down[/color]" % C_BAD
	return "[color=#%s]%s[/color] %s [color=#%s]%d of %d[/color]%s" % [
		hue, label.rpad(14), _stacked_bar([[share, hue]], 10),
		DIM, int(round(got * 100.0)), int(round(ceiling * 100.0)), arrow]


## The one sentence the screen exists for: what is holding the class back,
## and the thing to do about it tomorrow.
func _diagnosis(split: Dictionary) -> String:
	Balance.ensure_loaded()
	var parts := [
		["the lesson", float(split.get("lesson", 0.0)), Balance.lesson_cap,
			"Teach for longer, and collect the work."],
		["the room", float(split.get("room", 0.0)), Balance.room_cap,
			"Buy furniture and put it NEAR the desks."],
		["homework", float(split.get("homework", 0.0)), Balance.homework_cap,
			"Set homework, then mark it at your desk."],
		["what you know", float(split.get("known", 0.0)),
			Balance.concept_bonus_cap, "Teach more subjects to learn them."],
	]
	var worst := ""
	var advice := ""
	var worst_share := 2.0
	for part: Array in parts:
		var ceiling := float(part[2])
		if ceiling <= 0.0:
			continue
		var share: float = float(part[1]) / ceiling
		if share < worst_share:
			worst_share = share
			worst = String(part[0])
			advice = String(part[3])
	if worst_share >= 0.9:
		return "[color=#%s]Nothing is holding them back. That is as good as it gets.[/color]" % C_GOOD
	return "[color=#%s]Weakest: %s.[/color] %s" % [C_BAD, worst, advice]


## Ten-commits.md step 3: is the curriculum moving fast enough to finish
## the term, or told about it if not. Same shape as _diagnosis() -- name
## the problem, give the action -- and it escalates rather than repeating
## itself verbatim as the days run out, which is the whole point of
## printing it every day instead of only at the very end.
func _pacing_line(pacing: Dictionary) -> String:
	if bool(pacing.get("on_pace", true)):
		return "[color=#%s]On pace with the curriculum.[/color] Bonus paid." % C_GOOD
	var left := int(pacing.get("days_left", 0))
	if left <= Balance.pace_escalate_days_left:
		return "[color=#%s]Badly behind, and only %d day%s left.[/color] Teach something new tomorrow, or the term ends short of it." \
			% [C_BAD, left, "" if left == 1 else "s"]
	return "[color=#%s]Behind on new material.[/color] Teach a different lesson to unlock more of it." \
		% C_BAD


func show_day_report(report: Dictionary) -> void:
	Sfx.play("grade")
	_open(Mode.REPORT)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 0)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	# The frame's whole inner width: its sentences ("Weakest: the lesson.
	# Teach for longer, and collect the work.") are the screen's point, and
	# at 576px the pixel font wrapped most of them.
	rich.offset_left = 22.0
	rich.offset_right = 618.0

	var avg := float(report.get("average", 0.0))
	title.text = "DAY %d  -  %s  -  %d LEFT" % [
		int(report.get("day", 0)), Game.grade_letter(avg),
		int(report.get("days_left", 0))]

	var split: Dictionary = report.get("split", Game.grade_split())
	var before: Dictionary = report.get("split_before", {})

	var lines: Array[String] = []
	lines.append_array(_grade_rows(split, before))
	lines.append(_diagnosis(split))

	var earned: int = int(report.get("coins", 0))
	var upkeep: int = int(report.get("upkeep", 0))
	var done: int = int(report.get("homework_done", 0))
	var of: int = maxi(1, Game.roster.size())
	lines.append("[color=#%s]+%d coins[/color] [color=#%s]-%d upkeep[/color]   homework [color=#%s]%d of %d[/color]" % [
		C_COIN, earned, C_BAD, upkeep,
		C_GOOD if done * 2 >= of else C_BAD, done, of])
	# Everything from here on is news rather than the grade, and goes to small
	# print if the screen would overflow (see the end of this function).
	var news_from := lines.size()
	if report.has("pacing"):
		lines.append(_pacing_line(report["pacing"]))

	# A craft that resolved TODAY -- coins and days already spent either way,
	# so a fail needs saying just as plainly as a win, or it just vanishes
	# with nothing to show for it (see Game._tick_pending_craft()'s note).
	var cres: Dictionary = report.get("craft_result", {})
	if not cres.is_empty():
		var cid := String(cres.get("lesson_id", ""))
		var cname := String(Curriculum.by_id(cid).get("name", cid))
		var cstyle := Game.craft_style(cid)
		var clabel := "%s — [color=#%s]%s[/color]" % [cname, craft_style_colour(cstyle), cstyle] \
			if cstyle != "" else cname
		if bool(cres.get("success", false)):
			lines.append("[color=#%s]%s came out of the oven -- it teaches easier now.[/color]" % [
				C_GOOD, clabel])
		else:
			lines.append("[color=#%s]%s didn't take. The coins and the days are spent either way.[/color]" % [
				C_BAD, clabel])
	# A craft still in the oven -- it belongs on the same screen as
	# everything else those bought, not buried a tab away in a catalogue
	# nobody has a reason to reopen mid-attempt.
	elif not Game.pending_craft.is_empty():
		var pl := String(Game.pending_craft.get("lesson_id", ""))
		var pdays := int(Game.pending_craft.get("days_left", 0))
		lines.append("[color=#%s]%s is in the oven - %d day%s left.[/color]" % [
			C_KNOW, String(Curriculum.by_id(pl).get("name", pl)),
			pdays, "" if pdays == 1 else "s"])

	var bought: Array = report.get("consumables", [])
	if not bought.is_empty():
		lines.append("[color=#%s]Today: %s[/color]" % [
			DIM, ", ".join(bought)])
	if String(report.get("joined", "")) != "":
		lines.append("[color=#%s]%s has joined the class.[/color]" % [
			C_GOOD, String(report["joined"])])
	# A milestone is the one thing on this screen that is not a number, so
	# it goes last and it goes in gold.
	for id: String in report.get("milestones", []):
		var m := Milestones.by_id(id)
		lines.append("[color=#%s]%s[/color]  [color=#%s]%s[/color]" % [
			C_COIN, String(m.get("name", id)), DIM, String(m.get("blurb", ""))])
	if String(report.get("event", "")) != "":
		lines.append("[color=#%s]Tomorrow: %s[/color] %s" % [
			C_KNOW, String(report["event"]),
			String(report.get("event_blurb", ""))])

	rich.text = "\n".join(lines)
	# MEASURED, not counted (Oct 2026). The fit test counted "\n"s, so a day
	# with the pacing warning, a new child and tomorrow's event -- three
	# sentences that each wrap -- passed at ten "lines" while the last one ran
	# under the footer on screen. When the wrapped text is taller than the box,
	# the news goes to small print a line at a time from the bottom, until it
	# fits; if all of it in small print is still too tall, the stacked bar over
	# the four parts goes (they say the same thing, broken down).
	var k := lines.size() - 1
	while _rich_overflows() and k >= news_from:
		lines[k] = "[font_size=%d]%s[/font_size]" % [UI_SMALL, lines[k]]
		rich.text = _join_rich(lines)
		k -= 1
	if _rich_overflows():
		lines.remove_at(0)
		rich.text = _join_rich(lines)
	_reveal_rich(0.45)
	hint.text = "E - close"


## Lines into one rich text, with each line break that follows a small-print
## line put INSIDE its [font_size] span. Outside it the break is set at full
## size and makes the small line it ends as tall as a full one -- a visible
## gap under the last line of a small paragraph.
func _join_rich(parts: Array[String]) -> String:
	var out := ""
	for i in parts.size():
		var s: String = parts[i]
		if i < parts.size() - 1:
			if s.ends_with("[/font_size]"):
				s = s.substr(0, s.length() - 12) + "
[/font_size]"
			else:
				s += "
"
		out += s
	return out


## True when `rich`'s text, wrapped to its width, is taller than its box --
## the one honest test of whether a screen fits, since a line count cannot see
## a sentence wrap.
func _rich_overflows() -> bool:
	return rich.get_content_height() > int(rich.size.y)


func open_catalogue(start: int = Shop.BUY) -> void:
	_open(Mode.CATALOGUE)
	_sel = 0
	_shop = start
	_render_catalogue()


## The list currently on screen: the catalogue when buying, the room's own
## contents when selling.
func _shop_rows() -> Array:
	if _shop == Shop.BUY:
		var cats := Items.categories()
		if cats.is_empty():
			return Items.order().duplicate()
		_cat = clampi(_cat, 0, cats.size() - 1)
		# Locked items are HIDDEN rather than greyed out. A greyed row you
		# cannot act on is still a row you have to read past every time you
		# open the shop, and there is no useful action attached to it.
		return Items.available_in_category(String(cats[_cat]))
	if _shop == Shop.STAFF:
		# The aide and janitor sit at the top of the same list as the
		# perks, so the screen keeps ONE cursor. A second selection model
		# on one screen is how a UI starts needing a diagram.
		var staff: Array = ["aide", "janitor"]
		staff.append_array(Progress.perk_order())
		return staff
	if _shop == Shop.ROOM:
		return ROOM_ROWS.duplicate()
	if _shop == Shop.IDEAS:
		return RoomTemplates.ids()
	if _shop == Shop.CRAFT:
		if not Game.lesson_crafting_unlocked():
			return []
		Curriculum.ensure_loaded()
		return Curriculum.lessons.map(func(l: Dictionary) -> String: return String(l.get("id", "")))
	# CABINET: the distinct ids you own but have not placed.
	return Game.cabinet_ids()


func _render_catalogue() -> void:
	# The shop is a list of five KINDS of thing at four different prices --
	# exactly what colour is for, and a Label is one colour by definition.
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", UI_SIZE)
	# The shop grew a blurb line and the staff room lists five perks, so the
	# default font 10 (about 6 lines in a 128px body) ran under the hint bar.
	body.add_theme_font_size_override("font_size", UI_SIZE)
	body.add_theme_constant_override("line_spacing", 0)
	var rows := _shop_rows()
	_sel = 0 if rows.is_empty() else clampi(_sel, 0, rows.size() - 1)
	_set_ideas_ui(_shop == Shop.IDEAS)

	var tabs := ""
	if _shop == Shop.BUY:
		var cats := Items.categories()
		for i in cats.size():
			# Every tab in its own colour, so the strip is the key to the
			# rows below it. The one you are on gets the full word and the
			# brackets; the rest get three letters, because they are there
			# to be aimed at rather than read.
			var label := Items.category_label(String(cats[i]))
			var hue := cat_colour(String(cats[i]))
			if i == _cat:
				tabs += "[color=#%s][%s][/color]" % [hue, label]
			else:
				tabs += "[color=#%s] %s [/color]" % [hue, label.substr(0, 3)]
	var heading := "BUY FURNITURE"
	if _shop == Shop.CABINET:
		heading = "YOUR CABINET"
	elif _shop == Shop.STAFF:
		heading = "STAFF ROOM"
	elif _shop == Shop.ROOM:
		heading = "THE ROOM  %dx%d" % [Grid.W, Grid.H]
	elif _shop == Shop.CRAFT:
		heading = "LESSON CRAFTING"
	elif _shop == Shop.IDEAS:
		heading = "ROOM IDEAS"
	title.text = "%s  -  %d coins" % [heading, Game.coins]

	# Show the thing you are buying. You used to be choosing furniture you
	# had never seen, described by a decimal.
	portrait.visible = false
	if _shop == Shop.BUY and not rows.is_empty():
		var art := String(Items.get_def(String(rows[_sel])).get("art", ""))
		if art != "" and ResourceLoader.exists("res://art/%s.png" % art):
			# A whole-number scale, centred, so the pixels stay square: fitting
			# a 30x38 sprite to a 96x140 box by stretching gave uneven pixels.
			portrait.texture = _scaled_whole(load("res://art/%s.png" % art), 96, 140)
			portrait.set_meta("art", art)     # which item this is (the texture may be a scaled copy)
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			portrait.visible = true
	_slot.visible = portrait.visible

	var lines: Array[String] = []
	if _shop == Shop.BUY and tabs != "":
		lines.append(tabs)
	if _shop == Shop.STAFF:
		lines = _render_staff()
	elif _shop == Shop.ROOM:
		lines = _render_room()
	elif _shop == Shop.CRAFT:
		lines = _render_craft(rows)
	elif _shop == Shop.IDEAS:
		lines = _render_ideas(rows)
	elif rows.is_empty():
		lines.append("   The cabinet is empty. Buy something first.")
	elif _shop == Shop.BUY:
		# A window, not the whole list. The Learning category alone has ten
		# items and the body is about eleven lines -- printing them all ran
		# straight under the hint bar.
		var lo := _window_start(rows.size(), LIST_ROWS)
		if lo > 0:
			lines.append("   ...")
		for i in range(lo, mini(rows.size(), lo + LIST_ROWS)):
			var id: String = rows[i]
			var d := Items.get_def(id)
			var price := Game.shop_price(id)
			var afford: bool = Game.can_afford(price)
			var hue := cat_colour(Items.category_of(id))
			# The price is the thing you are actually deciding on, so it
			# carries the yes/no colour rather than the name doing it.
			if String(d.get("cat", "")) == "consumable":
				# No range, no bonus -- it is not placed anywhere, so the
				# worth-bar and reach-words that describe FURNITURE would
				# both crash reading fields a consumable does not have.
				lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%4d[/color] [color=#%s]today only[/color]" % [
					">" if i == _sel else " ", hue if afford else DIM,
					String(d["name"]).substr(0, 13),
					C_GOOD if afford else C_BAD, price, DIM])
			elif Items.is_desk_top(id):
				# Stands on one child's desk (the study folder): it reaches
				# nobody else, so the worth-bar and reach-words -- which
				# describe what a piece does for the desks AROUND it -- would
				# both be wrong. Says where it goes, and when you have all the
				# copies a decision about WHO is worth.
				var cap := Items.max_owned(id)
				var full: bool = cap > 0 and Game.owned_count(id) >= cap
				lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%4d[/color] [font_size=%d][color=#%s]%s[/color][/font_size]" % [
					">" if i == _sel else " ", hue if afford and not full else DIM,
					String(d["name"]).substr(0, 13),
					C_GOOD if afford and not full else C_BAD, price, UI_SMALL, DIM,
					"you have them all" if full else "on one desk, no chatting"])
			else:
				lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%4d[/color] %s %s" % [
					">" if i == _sel else " ", hue if afford else DIM,
					String(d["name"]).substr(0, 13),
					C_GOOD if afford else C_BAD, price,
					_worth_bar(float(d["bonus"])),
					# Small print beside the bar: at full size the row ran
					# under the item's picture on the right.
					"[font_size=%d][color=#%s]%s[/color][/font_size]" % [UI_SMALL, DIM,
						_reach_words(int(d["range"]), float(d["bonus"]))]])
		if lo + LIST_ROWS < rows.size():
			lines.append("   ...")
		# The blurb rides on the HINT bar rather than taking a body line. The
		# tab strip plus four rows is already everything the panel holds, and
		# the blurb was landing on top of the hint text.
		_shop_blurb = String(Items.get_def(rows[_sel]).get("blurb", ""))
	else:
		# CABINET: everything you own and have not placed. Windowed the same
		# way the buy list is -- storage can hold more than the panel shows.
		var lo2 := _window_start(rows.size(), LIST_ROWS)
		if lo2 > 0:
			lines.append("   ...")
		for i in range(lo2, mini(rows.size(), lo2 + LIST_ROWS)):
			var cid := String(rows[i])
			var cn := Game.cabinet_count(cid)
			lines.append(_clip("%s %-13s  x%d   sell %3d" % [
				">" if i == _sel else " ",
				String(Items.get_def(cid).get("name", cid)),
				cn, Game.sell_value(cid)]))
		if lo2 + LIST_ROWS < rows.size():
			lines.append("   ...")
		lines.append("E takes one out to place.  Left sells one for half.")
	rich.text = "\n".join(lines)
	# NO reveal here. The catalogue re-renders on every keypress, so a
	# wipe would restart under your fingers each time you moved the
	# selection. Animate results you are handed, never a list you are
	# steering.
	rich.visible_ratio = 1.0
	var verb := "order"
	var next_tab := "cabinet"
	if _shop == Shop.IDEAS:
		hint.text = "Up/Down browse   Tab buy list   Esc close"
		return
	if _shop == Shop.BUY:
		hint.text = _hint_clip(_shop_blurb) if _shop_blurb != "" 			else "Up/Down pick   Left/Right category   E buy to cabinet   Esc close"
		return
	if _shop == Shop.CABINET:
		hint.text = "Up/Down choose   E place   Left sell   Tab staff room   Esc close"
		return
	if _shop == Shop.STAFF:
		verb = "learn"
		next_tab = "the room"
	elif _shop == Shop.ROOM:
		verb = "build"
		next_tab = "lesson crafting"
	elif _shop == Shop.CRAFT:
		verb = "craft"
		next_tab = "room ideas"
	hint.text = "Up/Down choose   E %s   Tab %s   Esc close" % [verb, next_tab]


## The Ideas tab: the list of ready-made rooms on the left, the selected one
## drawn on the right, and what it is made of and what it would cost beneath.
func _render_ideas(rows: Array) -> Array[String]:
	var lines: Array[String] = []
	for i in rows.size():
		var t := RoomTemplates.get_template(String(rows[i]))
		var name := String(t.get("name", "")).substr(0, 22)
		if i == _sel:
			lines.append("> %s" % name)
		else:
			lines.append("[color=#%s]  %s[/color]" % [DIM, name])
	if rows.is_empty():
		return lines
	var cur := RoomTemplates.get_template(String(rows[_sel]))
	_preview.show_template(cur)
	var names: Dictionary = {}
	for e: Dictionary in RoomTemplates.entries(cur):
		var nm := String(Items.get_def(String(e["id"])).get("name", e["id"]))
		names[nm] = int(names.get(nm, 0)) + 1
	var shown := ""
	var more := 0
	for nm: String in names:
		var piece: String = nm if int(names[nm]) == 1 else "%s x%d" % [nm, int(names[nm])]
		if more == 0 and (shown + ", " + piece).length() <= 48:
			shown = piece if shown == "" else shown + ", " + piece
		else:
			more += 1
	if more > 0:
		shown += " and %d more" % more
	var total := RoomTemplates.entries(cur).size()
	var owned := RoomTemplates.owned_count(cur)
	var left := RoomTemplates.missing_cost(cur)
	# One line each, fitted: three lines is all the space under the picture.
	_info.text = "%s\n[color=#%s]%s[/color]\nYou own %d of its %d pieces. %s" % [
		_fit_or_small(String(cur.get("blurb", "")), _info.size.x), DIM,
		_fit_or_small(shown, _info.size.x), owned, total,
		"That is all of it." if left == 0 else "The rest: [color=#%s]%d[/color] coins." % [C_COIN, left]]
	return lines


## Buying floor space.
##
## Priced per tile of NEW floor and rising with each expansion, so a wider
## room charges more for another row than a narrow one, and the fifth
## expansion costs a great deal more than the first. A bigger classroom is
## meant to be a thing you save for.
func _render_room() -> Array[String]:
	Balance.ensure_loaded()
	var out: Array[String] = []
	out.append("   Your classroom is %d by %d tiles." % [Grid.W, Grid.H])
	out.append("")
	for i in ROOM_ROWS.size():
		var axis := String(ROOM_ROWS[i])
		var label := ""
		var tail := ""
		if axis == "desk":
			label = "Another desk  (%d now)" % Layout.seat_count()
			tail = "%d coins" % Game.desk_cost() if Game.can_buy_desk() 				else "at its limit"
		else:
			label = "One column wider" if axis == "wide" else "One row longer"
			tail = "%d coins" % Game.expand_cost(axis) if Game.can_expand(axis) 				else "at its limit"
		out.append("%s %-22s %s" % [">" if i == _sel else " ", label, tail])
	out.append("")
	if Grid.W > Grid.BASE_W or Grid.H > Grid.BASE_H:
		out.append("   The view follows you now the room is bigger")
		out.append("   than the screen.")
	else:
		out.append("   A bigger room holds more desks -- and the view")
		out.append("   will start to follow you rather than sitting still.")
	return out


## How an item's effect reads in words. The exact number is already
## visible where it matters -- the green desks at placement time.
func _reach_words(reach: int, bonus: float) -> String:
	var strength := "a little"
	if bonus >= 0.13:
		strength = "a great deal"
	elif bonus >= 0.08:
		strength = "well"
	var span := "close by"
	if reach >= 6:
		span = "room-wide"
	elif reach >= 4:
		span = "nearby"
	return "helps %s, %s" % [strength, span]


## One line for the aide or the janitor: hired state, level dots, wage.
## Shared because the two are the same shape end to end -- see
## Game.level_up_staff()'s own comment.
func _staff_row(idx: int, label: String, hired: bool, level: int,
		wage: int, cost: int) -> String:
	Balance.ensure_loaded()
	var status: String
	if not hired:
		status = "%d coins" % cost
	elif level >= Balance.staff_level_max:
		status = "hired, MAX, %d/day" % wage
	else:
		status = "hired, %d/day, next %d" % [wage, Game.staff_level_cost(level)]
	var dots := ""
	if hired:
		dots = " " + _cells(BAR_FULL, level) + _cells(BAR_EMPTY, Balance.staff_level_max - level)
	return "%s [color=#%s]%-17s[/color]%s [color=#%s]%s[/color]" % [
		">" if _sel == idx else " ", C_ROOM, label, dots,
		C_GOOD if hired else C_COIN, status]


## One colour per Game.CRAFT_STYLES entry, so a crafted lesson's own
## flavour reads at a glance the same way a curriculum STRAND's does --
## same hue everywhere that style's name is printed. Cosmetic only, same
## as the styles themselves (see Game.CRAFT_STYLES' own comment); full
## palette + UI-appearance + asset-naming writeup in docs/CRAFT_STYLES.md.
const CRAFT_STYLE_COLOUR := {
	"Visual": "7fd0c9",       # teal
	"Hands-On": "e2a15e",     # orange
	"Discussion": "e296b0",   # rose
	"Story-Based": "9b93e0",  # indigo
	"Game-Based": "c7d96b",   # chartreuse
}


static func craft_style_colour(style: String) -> String:
	return String(CRAFT_STYLE_COLOUR.get(style, "cfcfcf"))


## The staff-room board: what you have learned to do better.
## Craft a lesson you already teach: coins + a few in-game days raise its
## craft_level, which makes that SAME material go down easier next time
## it's taught (see Game.difficulty_mults/craft_work_mult). Windowed like
## BUY, since the curriculum runs to 40 lessons.
func _render_craft(rows: Array) -> Array[String]:
	Balance.ensure_loaded()
	var lines: Array[String] = []
	if not Game.lesson_crafting_unlocked():
		var left := maxi(0, Balance.craft_unlock_day - Game.day)
		lines.append("[color=#%s]Not yet.[/color]" % DIM)
		lines.append("[color=#%s]%d day%s of real teaching left before you can.[/color]" % [
			DIM, left, "" if left == 1 else "s"])
		return lines

	if not Game.pending_craft.is_empty():
		var pl := String(Game.pending_craft.get("lesson_id", ""))
		var pname := String(Curriculum.by_id(pl).get("name", pl))
		var pstyle := Game.craft_style(pl)
		var plabel := "%s — [color=#%s]%s[/color]" % [pname, craft_style_colour(pstyle), pstyle] \
			if pstyle != "" else pname
		var pdays := int(Game.pending_craft.get("days_left", 0))
		lines.append("[color=#%s]%s is in the oven - %d day%s left.[/color]" % [
			C_KNOW, plabel, pdays, "" if pdays == 1 else "s"])
		lines.append("")

	var lo := _window_start(rows.size(), LIST_ROWS)
	if lo > 0:
		lines.append("   ...")
	for i in range(lo, mini(rows.size(), lo + LIST_ROWS)):
		var lesson_id: String = rows[i]
		var d := Curriculum.by_id(lesson_id)
		var level: int = int(Game.lesson_crafts.get(lesson_id, {}).get("craft_level", 0))
		var style := Game.craft_style(lesson_id)
		var cap: int = Balance.craft_level_cap_for_bonus
		var cost := Game.craft_next_cost(lesson_id)
		var afford: bool = Game.can_afford(cost)
		# A crafted lesson's bar tints to its own style's colour rather than
		# the flat C_LESSON every other row uses -- the one bit of UI
		# appearance a style carries today. See docs/CRAFT_STYLES.md.
		lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%s[/color] [color=#%s]%4d[/color]" % [
			">" if i == _sel else " ", C_LESSON,
			String(d.get("name", lesson_id)).substr(0, 13),
			craft_style_colour(style) if level > 0 else DIM,
			_cells(BAR_FULL, mini(level, cap)) + _cells(BAR_EMPTY, maxi(0, cap - level)),
			C_GOOD if afford else C_BAD, cost])
	if lo + LIST_ROWS < rows.size():
		lines.append("   ...")
	return lines


func _render_staff() -> Array[String]:
	Balance.ensure_loaded()
	var lines: Array[String] = []
	lines.append("[color=#%s]Level %d[/color]    %d point%s to spend" % [
		C_KNOW, Game.teacher_level, Game.perk_points_free(),
		"" if Game.perk_points_free() == 1 else "s"])
	lines.append("")

	# rows 0-1: the aide and the janitor, same shape, same controls
	lines.append(_staff_row(0, "Teacher's aide", Game.has_aide,
		Game.aide_level, Balance.aide_wage, Balance.aide_cost))
	lines.append(_staff_row(1, "Janitor", Game.has_janitor,
		Game.janitor_level, Balance.janitor_wage, Balance.janitor_cost))

	# Windowed, not a flat list: this screen already spends 4 rows on the
	# header/aide/janitor before a single perk shows, and eleven perks
	# (six added alongside the roguelike pivot's skill list, reconciled
	# onto this board rather than a second one) blew straight through the
	# panel budget the moment they landed -- caught by counting the real
	# row total, not assumed safe because five perks used to fit.
	const STAFF_PERK_ROWS := 3
	var order := Progress.perk_order()
	var perk_lo := 0
	if order.size() > STAFF_PERK_ROWS:
		perk_lo = clampi((_sel - 2) - STAFF_PERK_ROWS / 2, 0, order.size() - STAFF_PERK_ROWS)
	if perk_lo > 0:
		lines.append("   ...")
	for i in range(perk_lo, mini(order.size(), perk_lo + STAFF_PERK_ROWS)):
		var id: String = order[i]
		var d := Progress.perk_def(id)
		var have := Game.perk_rank(id)
		var cap := Progress.max_rank(id)
		lines.append("%s %-17s [color=#%s]%s[/color]" % [
			">" if i + 2 == _sel else " ", String(d.get("name", id)),
			C_LESSON if have > 0 else DIM,
			_cells(BAR_FULL, have) + _cells(BAR_EMPTY, cap - have)])
	if perk_lo + STAFF_PERK_ROWS < order.size():
		lines.append("   ...")
	lines.append("")
	if _sel == 0 or _sel == 1:
		var hired: bool = Game.has_aide if _sel == 0 else Game.has_janitor
		var maxed: bool = (Game.aide_level if _sel == 0 else Game.janitor_level) \
			>= Balance.staff_level_max
		var blurb := "They collect finished work so you can stay at the front." \
			if _sel == 0 else "They clean the room's mess for you, any time of day."
		lines.append("[color=#%s]%s[/color]" % [DIM, _fit_or_small(
			blurb if not hired
			else ("Fully trained." if maxed else "E again to train them up a level.")
			+ ("" if not hired else "  Left arrow to let them go."), rich.size.x)])
	elif not order.is_empty():
		lines.append("[color=#%s]%s[/color]" % [DIM, _fit_or_small(
			String(Progress.perk_def(order[_sel - 2]).get("blurb", "")), rich.size.x)])
	return lines


## Act on the open file: pay for extra help, or send them up.
func _do_bio_action() -> void:
	if _bio == null:
		return
	match _bio_sel:
		Act.TUITION:
			var e := Game.coach(_bio, "tuition")
			Sfx.play("deny" if e != "" else "confirm")
			show_student(_bio)
		Act.PARENTS:
			var e2 := Game.coach(_bio, "parents")
			Sfx.play("deny" if e2 != "" else "confirm")
			show_student(_bio)
		Act.GRADUATE:
			if not _bio.is_ready_to_graduate():
				Sfx.play("deny")
				return
			var rec := Game.graduate(_bio)
			Sfx.play("grade")
			_bio = null
			_show_graduation(rec)


## A small send-off. It is the one moment in the game where somebody leaves,
## so it gets its own screen rather than a line in the corner.
func _show_graduation(rec: Dictionary) -> void:
	_open(Mode.REPORT)
	title.text = "MOVING UP"
	var lines: Array[String] = [
		"", "   %s has moved up to the next class." % String(rec.get("name", "")),
		"",
		"   You have sent up %d so far." % Game.graduated.size(),
		"   %d coins, and something learned for you too." % int(rec.get("coins", 0)),
	]
	if String(rec.get("replaced_by", "")) != "":
		lines.append("")
		lines.append("   %s has taken the empty desk." % String(rec["replaced_by"]))
	body.text = "\n".join(lines)
	hint.text = "E - close"


## The homework marking game. One verdict per sheet, not per question —
## EduSystems found per-question marking hit 32-120 taps a lesson and had to
## be redesigned to exactly this. Don't rediscover that.
## How long a just-given verdict's check/X stays up before the next sheet
## replaces it -- long enough to actually SEE it happen (the whole point
## of drawing it at all), not so long that marking a full roster drags.
const MARKING_STAMP_SECONDS := 0.25


func open_marking() -> void:
	_marking.clear()
	_marked_right = 0
	_marking_hold = 0.0
	for s: StudentData in Game.roster:
		if s.homework_ready_to_mark():
			_marking.append(s)
	if _marking.is_empty():
		return
	_open(Mode.MARKING)
	body.visible = false
	sheet.visible = true
	_render_sheet()


func _render_sheet() -> void:
	if _marking.is_empty():
		return
	var s: StudentData = _marking[0]
	title.text = "%s  —  %d left" % [s.display_name, _marking.size()]
	sheet.show_sheet(s.hw_sheet)
	hint.text = "Trace a check or an X    or Left/Right"


## Ignoring input while a stamp is still up (rather than queuing it) is
## deliberate: it is what stops a second verdict landing on a sheet that
## has already been popped, if a press arrives mid-countdown.
func _verdict(pass_it: bool) -> void:
	if _marking_hold > 0.0:
		return
	var s: StudentData = _marking.pop_front()
	s.hw_player_verdict = 1 if pass_it else 0
	s.hw_state = StudentData.HW.MARKED
	if pass_it == Questions.sheet_is_good(s.hw_sheet):
		_marked_right += 1
	# The player's own call, stamped on the page -- not a reveal of the
	# truth. See homework_sheet.gd's class comment.
	sheet.stamp(pass_it)
	Sfx.play("confirm" if pass_it else "deny")
	_marking_hold = MARKING_STAMP_SECONDS


## Runs once a stamped verdict's hold has counted down to zero -- see the
## _process() tick below. Split out from _verdict() because the STATE
## change (popping the queue, marking it graded) has to land immediately,
## the same frame the verdict is given, or "a verdict moves on to the next
## sheet" would need to know about a delay it has no reason to care about;
## only the SCREEN change waits.
func _finish_marking_if_ready() -> void:
	if not _marking.is_empty():
		_render_sheet()
		return
	if _player != null and is_instance_valid(_player):
		_player.drop_all_homework()
	title.text = "MARKING DONE"
	body.visible = true
	sheet.visible = false
	body.text = "\n".join([
		"You judged %d of them the way the sheet actually" % _marked_right,
		"deserved.",
		"",
		"A sheet you waved through won't flag its student as",
		"struggling tomorrow — so you won't go and help them.",
	])
	hint.text = "E — close"
	mode = Mode.REPORT


## The optional reward-video poster (scripts/interact/ad_poster.gd).
## Balance.ad_tiers is read fresh every open -- a real ad SDK swapping the
## tiers around later needs nothing changed here.
func show_ads() -> void:
	Balance.ensure_loaded()
	_open(Mode.ADS)
	_ad_sel = 0
	_ad_watching = 0.0
	_ad_tier = -1
	_render_ads()


func _render_ads() -> void:
	if _ad_watching > 0.0:
		title.text = "WATCHING..."
		body.text = "\n".join(["", "   (a real ad SDK isn't connected yet --", "   this is a stand-in for one)"])
		hint.text = ""
		return
	title.text = "WATCH FOR A REWARD"
	var lines: Array[String] = []
	var tiers: Array = Balance.ad_tiers
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		lines.append("%s %ds  —  %d coins" % [
			">" if i == _ad_sel else " ", int(t.get("seconds", 0)),
			int(t.get("reward_coins", 0))])
	lines.append("")
	lines.append("Never pops up on its own. You walked up to this.")
	body.text = "\n".join(lines)
	hint.text = "Up/Down choose   E watch   Esc back"


func _handle_ads_input() -> void:
	var tiers: Array = Balance.ad_tiers
	if _ad_watching > 0.0 or tiers.is_empty():
		return
	if Input.is_action_just_pressed("cancel"):
		Sfx.play("blip")
		close()
	elif Input.is_action_just_pressed("move_down"):
		_ad_sel = (_ad_sel + 1) % tiers.size()
		Sfx.play("blip")
		_render_ads()
	elif Input.is_action_just_pressed("move_up"):
		_ad_sel = (_ad_sel - 1 + tiers.size()) % tiers.size()
		Sfx.play("blip")
		_render_ads()
	elif Game.claim_interact():
		_ad_tier = _ad_sel
		_ad_watching = float((tiers[_ad_sel] as Dictionary).get("wait", 1.0))
		Sfx.play("confirm")
		_render_ads()


func _finish_ad() -> void:
	var tiers: Array = Balance.ad_tiers
	if _ad_tier >= 0 and _ad_tier < tiers.size():
		Game.add_coins(int((tiers[_ad_tier] as Dictionary).get("reward_coins", 0)))
	_ad_tier = -1
	_render_ads()


## Input is POLLED, not handled as events, and that is deliberate.
##
## Input.action_press() — the only way a headless test can drive the game —
## sets an action's pressed state for polling but does NOT synthesize an
## event through _input/_unhandled_input. An event-driven overlay is
## therefore untestable, and this one silently ate every keypress in an
## automated playthrough until it was found. Everything in this project that
## reads input polls, for exactly that reason.
func _handle_input() -> void:
	if mode == Mode.PAUSE:
		return
	if mode == Mode.HAND:
		var n: int = Game.hand.size()
		if n == 0:
			close()
		elif Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			close()
		elif Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % n
			Sfx.play_varied("paper")
			show_hand()
		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + n) % n
			Sfx.play_varied("paper")
			show_hand()
		elif Game.claim_interact():
			Sfx.play("confirm")
			var picked := _sel
			close()
			assignment_chosen.emit(picked)
		return

	if mode == Mode.PATHS:
		var pn: int = Game.term_path_hand.size()
		if pn == 0:
			close()
		elif Input.is_action_just_pressed("cancel"):
			# Backing out without picking keeps whatever path was already
			# active (last term's choice, or the {} default on term 1)
			# rather than silently forcing "ordinary" -- a no-op reads
			# truer than overwriting a choice this screen never asked
			# about. Resolves entirely here, the same way a hire does in
			# the SCHOOL screen below: no lesson starts from this screen,
			# so there is nothing for main.gd to do with it.
			Sfx.play("blip")
			Game.term_path_hand.clear()
			close()
		elif Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % pn
			Sfx.play_varied("paper")
			show_term_paths()
		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + pn) % pn
			Sfx.play_varied("paper")
			show_term_paths()
		elif Game.claim_interact():
			Sfx.play("confirm")
			Game.choose_term_path(_sel)
			close()
		return

	if mode == Mode.SCHOOL:
		if _hiring:
			var na: int = Game.applicants.size()
			if Input.is_action_just_pressed("cancel"):
				_hiring = false
				show_school()
			elif na > 0 and Input.is_action_just_pressed("move_down"):
				_sel = (_sel + 1) % na
				Sfx.play("blip")
				show_hiring()
			elif na > 0 and Input.is_action_just_pressed("move_up"):
				_sel = (_sel - 1 + na) % na
				Sfx.play("blip")
				show_hiring()
			elif na > 0 and Game.claim_interact():
				var err := Game.hire(_hiring_for, _sel)
				Sfx.play("deny" if err != "" else "confirm")
				_hiring = false
				_sel = _hiring_for
				show_school()
			return

		var n: int = Game.rooms.size()
		if Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			close()
		elif n > 0 and Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % n
			Sfx.play("blip")
			show_school()
		elif n > 0 and Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + n) % n
			Sfx.play("blip")
			show_school()
		elif Input.is_action_just_pressed("build"):
			# N is taken; the build key opens a new room from this screen
			var err2 := Game.open_room()
			Sfx.play("deny" if err2 != "" else "confirm")
			show_school()
		elif n > 0 and Game.claim_action("manage"):
			var err3 := Game.furnish_room(_sel)
			Sfx.play("deny" if err3 != "" else "confirm")
			show_school()
		elif n > 0 and _can_watch(_sel) and Input.is_action_just_pressed("watch"):
			Sfx.play("blip")
			show_watch(_sel)
		elif n > 0 and not (Game.rooms[_sel].get("teacher", {}) as Dictionary).is_empty() \
				and Game.claim_action("fire"):
			var err4 := Game.fire(_sel)
			Sfx.play("deny" if err4 != "" else "confirm")
			show_school()
		elif n > 0 and (Game.rooms[_sel].get("teacher", {}) as Dictionary).is_empty() \
				and Game.claim_interact():
			_hiring_for = _sel
			_sel = 0
			show_hiring()
		return

	if mode == Mode.WATCH:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("blip")
			# Your own auto-taught lesson hands off to the ordinary lesson
			# report -- exactly where a manually-played lesson's end would
			# have landed -- rather than back to the school board, which
			# is where watching a DELEGATED room's day always goes.
			if _watch_room == -1:
				show_lesson_report(_watch_own_results)
			else:
				show_school()
		elif Input.is_action_just_pressed("watch"):
			# skip straight to the bell
			_watch_i = maxi(0, _watch_frames.size() - 1)
			_render_watch_frame()
		return

	if mode == Mode.CAREER:
		# Tab flips between the milestones list and the alumni wall, the
		# same key the shop and the student file use for their pages.
		if Input.is_action_just_pressed("menu"):
			_career_page = CAREER_ALUMNI if _career_page == CAREER_MILESTONES else CAREER_MILESTONES
			_alum_open = -1
			_sel = 0
			Sfx.play("blip")
			show_career()
			return

		if _career_page == CAREER_ALUMNI:
			var recs: int = (Game.meta.get("alumni", []) as Array).size()
			if Input.is_action_just_pressed("cancel"):
				Sfx.play("blip")
				if _alum_open >= 0:
					_alum_open = -1
					show_career()
				else:
					close()
			elif _alum_open >= 0:
				pass       # a story page is read-only: only Esc is live
			elif recs == 0:
				pass
			elif Game.claim_interact():
				Sfx.play("blip")
				_alum_open = _sel
				show_career()
			elif Input.is_action_just_pressed("move_down"):
				_sel = (_sel + 1) % recs
				Sfx.play("blip")
				show_career()
			elif Input.is_action_just_pressed("move_up"):
				_sel = (_sel - 1 + recs) % recs
				Sfx.play("blip")
				show_career()
			return

		var n: int = _career_rows().size()
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("blip")
			close()
		elif Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % n
			Sfx.play("blip")
			show_career()
		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + n) % n
			Sfx.play("blip")
			show_career()
		return

	if mode == Mode.OFFICE:
		_handle_office_input()
		return

	if mode == Mode.TROPHIES:
		_handle_trophies_input()
		return

	if mode == Mode.GRADE_BOOK:
		_handle_grade_book_input()
		return

	if mode == Mode.HELP:
		_handle_help_input()
		return

	if mode == Mode.INTRO:
		_handle_intro_input()
		return

	if mode == Mode.MENTOR:
		_handle_mentor_input()
		return

	if mode == Mode.CALLER:
		_handle_caller_input()
		return

	if mode == Mode.ADS:
		_handle_ads_input()
		return

	if mode == Mode.SKIP:
		var most: int = Game.skip_days_available()
		if Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			close()
		elif Input.is_action_just_pressed("move_right"):
			_skip_days = mini(_skip_days + 1, most)
			Sfx.play("blip")
			show_skip()
		elif Input.is_action_just_pressed("move_left"):
			_skip_days = maxi(_skip_days - 1, 1)
			Sfx.play("blip")
			show_skip()
		elif Game.claim_interact():
			_do_skip()
		return

	if mode == Mode.SKIP_REPORT:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("blip")
			close()
		return

	if mode == Mode.SPECIALISM:
		var strands := Curriculum.strands()
		if strands.is_empty():
			close()
		elif Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % strands.size()
			Sfx.play("blip")
			show_specialism()
		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + strands.size()) % strands.size()
			Sfx.play("blip")
			show_specialism()
		elif Game.claim_interact():
			Game.specialism = String(strands[_sel])
			Sfx.play("confirm")
			close()
		return

	if mode == Mode.DASHBOARD:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("blip")
			close()
		elif Input.is_action_just_pressed("menu") 				or Input.is_action_just_pressed("dashboard"):
			_dash = (_dash + 1) % 4
			Sfx.play("blip")
			_render_dashboard()
		elif _dash == Dash.WARDROBE and Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % 2
			Sfx.play("blip")
			_render_dashboard()
		elif _dash == Dash.WARDROBE and Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + 2) % 2
			Sfx.play("blip")
			_render_dashboard()
		elif _dash == Dash.WARDROBE and Input.is_action_just_pressed("move_right"):
			_adjust_wardrobe(1)
		elif _dash == Dash.WARDROBE and Input.is_action_just_pressed("move_left"):
			_adjust_wardrobe(-1)
		return

	if mode == Mode.CURRICULUM:
		var n: int = Curriculum.lessons.size()
		if Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			close()
		elif Game.lesson_crafting_unlocked() and Input.is_action_just_pressed("menu"):
			# The catalogue's craft tab, straight from the book the player
			# already reads lesson material out of -- the noticeboard/cabinet
			# route was the only door in, and nobody stumbles onto Tab
			# four times on a screen that never asked them to press it once.
			Sfx.play("blip")
			open_catalogue(Shop.CRAFT)
		elif Game.claim_interact():
			# The screen DOES something now. It was a list you could only
			# read, which is most of why it felt inert.
			if n > 0:
				Game.chosen_lesson = String(Curriculum.lessons[_sel].get("id", ""))
				if Game.phase == Game.Phase.MORNING:
					Game.subject = Game.pick_subject()
				Sfx.play("confirm")
				show_curriculum()
		elif n > 0 and Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % n
			Sfx.play("blip")
			show_curriculum()
		elif n > 0 and Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + n) % n
			Sfx.play("blip")
			show_curriculum()
		return

	if mode == Mode.TITLE and Game.claim_interact():
		# Leaving the title is where a run actually begins for a human --
		# new_run() itself is called by the tests and the simulator
		# constantly, and an overlay appearing there blocks everything.
		Sfx.play("confirm")
		if Game.specialism == "":
			_sel = 0
			show_specialism()
		else:
			close()
		return

	if mode == Mode.REPORT or mode == Mode.TITLE:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("confirm")
			# The end of term used to be a full stop: term_over was set and
			# nothing anywhere read it, so you closed the exam and day 21,
			# 22, 23 simply kept coming. It is a doorway now.
			if _showing_exam:
				_showing_exam = false
				var info := Game.next_term()
				if bool(info.get("run_over", false)):
					show_run_over(info)
				else:
					show_new_term(info)
				return
			if _showing_run_over:
				_showing_run_over = false
				close()
				Game.new_run()
				show_title()
				return
			if _showing_new_term:
				_showing_new_term = false
				show_term_paths(true)
				return
			close()
		return

	# The class list is no longer "any key closes": E now opens the selected
	# student's file, and Esc or Tab close. That is the one thing a player
	# has to learn, which is why the hint line says it outright.
	if mode == Mode.CLASS_LIST:
		if Input.is_action_just_pressed("cancel") \
				or Input.is_action_just_pressed("menu"):
			Sfx.play("confirm")
			close()
		elif Game.roster.is_empty():
			pass
		elif Input.is_action_just_pressed("move_down"):
			_sel = (_sel + 1) % Game.roster.size()
			Sfx.play("blip")
			_render_class_list()
		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + Game.roster.size()) % Game.roster.size()
			Sfx.play("blip")
			_render_class_list()
		elif Game.claim_interact():
			Sfx.play("confirm")
			show_student(Game.roster[_sel])
		return

	if mode == Mode.STUDENT:
		# The file is a menu now, so E acts on the highlighted row instead of
		# backing out. Esc is the way out -- E used to be both, which is the
		# overloaded-button problem all over again. Tab turns the page between
		# the file and their story; the story page is read-only.
		if Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			_bio = null
			show_class_list(true)      # back to the list, on the same student
		elif Input.is_action_just_pressed("menu"):
			_bio_page = (_bio_page + 1) % 3
			Sfx.play("blip")
			show_student(_bio)
		elif _bio_page == BIO_FILE and Input.is_action_just_pressed("move_down"):
			_bio_sel = (_bio_sel + 1) % Act.COUNT
			Sfx.play("blip")
			show_student(_bio)
		elif _bio_page == BIO_FILE and Input.is_action_just_pressed("move_up"):
			_bio_sel = (_bio_sel - 1 + Act.COUNT) % Act.COUNT
			Sfx.play("blip")
			show_student(_bio)
		elif _bio_page == BIO_FILE and Game.claim_interact():
			_do_bio_action()
		return

	if mode == Mode.CATALOGUE:
		var rows := _shop_rows()
		if Input.is_action_just_pressed("cancel"):
			close()
		elif _shop == Shop.BUY and Input.is_action_just_pressed("move_right"):
			_cat = (_cat + 1) % maxi(1, Items.categories().size())
			_sel = 0
			Sfx.play("blip")
			_render_catalogue()
		elif _shop == Shop.BUY and Input.is_action_just_pressed("move_left"):
			_cat = (_cat - 1 + Items.categories().size()) % maxi(1, Items.categories().size())
			_sel = 0
			Sfx.play("blip")
			_render_catalogue()
		elif (_shop == Shop.CABINET and not rows.is_empty()
				and Input.is_action_just_pressed("move_left")):
			# Left sells one copy for half. A separate key from E (which takes
			# one out to place), so a mash of "place" can never sell by accident.
			var sold_for := Game.sell_from_cabinet(String(rows[_sel]))
			Sfx.play("coins" if sold_for > 0 else "deny")
			_render_catalogue()
		elif (_shop == Shop.STAFF and (_sel == 0 or _sel == 1)
				and Input.is_action_just_pressed("move_left")):
			# Letting go, not levelling -- a separate key from E on purpose,
			# so a mis-timed mash of the hire/train button can never fire
			# somebody by accident.
			var fe := Game.set_aide(false) if _sel == 0 else Game.set_janitor(false)
			Sfx.play("deny" if fe != "" else "blip")
			_render_catalogue()
		elif Input.is_action_just_pressed("menu"):
			_shop = (_shop + 1) % 6      # buy -> cabinet -> staff -> room -> craft -> ideas
			_sel = 0
			Sfx.play("blip")
			_render_catalogue()
		elif Input.is_action_just_pressed("move_up") and not rows.is_empty():
			_sel = (_sel - 1 + rows.size()) % rows.size()
			Sfx.play("blip")
			_render_catalogue()
		elif Input.is_action_just_pressed("move_down") and not rows.is_empty():
			_sel = (_sel + 1) % rows.size()
			Sfx.play("blip")
			_render_catalogue()
		elif Game.claim_interact() and not rows.is_empty():
			if _shop == Shop.ROOM:
				var axis := String(rows[_sel])
				var e := Game.buy_desk() if axis == "desk" 					else Game.expand_room(axis)
				Sfx.play("deny" if e != "" else "coins")
				_render_catalogue()
			elif _shop == Shop.STAFF:
				if _sel == 0 or _sel == 1:
					var which := "aide" if _sel == 0 else "janitor"
					var hired: bool = Game.has_aide if _sel == 0 else Game.has_janitor
					# Not hired yet: E hires. Already hired: E trains them
					# up a level instead -- letting them go is move_left,
					# above, a deliberately different key.
					var se := (Game.set_aide(true) if _sel == 0 else Game.set_janitor(true)) \
						if not hired else Game.level_up_staff(which)
					Sfx.play("deny" if se != "" else "coins")
				else:
					var err := Game.buy_perk(String(rows[_sel]))
					Sfx.play("deny" if err != "" else "confirm")
					if err == "":
						perk_bought.emit()
				_render_catalogue()
			elif _shop == Shop.BUY:
				var id: String = rows[_sel]
				if Items.category_of(id) == "consumable":
					# Bought and used in the same motion -- there is nowhere
					# to place it, and nothing to store.
					var uerr := Game.use_consumable(id)
					Sfx.play("deny" if uerr != "" else "confirm")
					_render_catalogue()
				else:
					# Furniture goes into the cabinet, not straight onto the
					# floor. The shop stays open; you place it from the
					# CABINET tab (or the cabinet itself) when you are ready.
					var berr := Game.buy_to_cabinet(id)
					Sfx.play("deny" if berr != "" else "coins")
					_render_catalogue()
			elif _shop == Shop.CRAFT:
				var ok := Game.commit_lesson_craft(String(rows[_sel]))
				Sfx.play("coins" if ok else "deny")
				_render_catalogue()
			else:
				# CABINET: E takes one copy out and starts placing it (free --
				# it was paid for when it was bought).
				Sfx.play("confirm")
				close()
				item_chosen.emit(String(rows[_sel]))
		return

	if mode == Mode.MARKING:
		if Input.is_action_just_pressed("move_left"):
			_verdict(false)
		elif Input.is_action_just_pressed("move_right"):
			_verdict(true)
