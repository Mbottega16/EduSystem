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

enum Mode { NONE, REPORT, CATALOGUE, MARKING, TITLE, CLASS_LIST, PAUSE, STUDENT,
	CURRICULUM, SPECIALISM, HAND, CAREER, SCHOOL, DASHBOARD }
enum Shop { BUY, SELL, STAFF, ROOM }
## The dashboard's own three pages, cycled by the same "menu" key the shop
## already cycles its tabs with -- one overview screen for "who am I, what
## do I have", not a fourth thing bolted onto E/F.
enum Dash { OVERVIEW, ITEMS, SKILLS }
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

@onready var status: Label = $Status
@onready var prompt: Label = $Prompt
@onready var prompt_box: ColorRect = $PromptBox
@onready var overlay: ColorRect = $Overlay
@onready var title: Label = $Overlay/Title
@onready var body: Label = $Overlay/Body
## A second body for the one screen that needs COLOUR rather than columns.
## A Label is one colour by definition, and the curriculum is a list of four
## different subjects -- which is exactly the thing colour is for.
@onready var rich: RichTextLabel = $Overlay/Rich
## The reveal running on the rich body, kept so a screen opened twice in
## quick succession cannot leave two of them fighting over visible_ratio.
var _reveal: Tween = null
@onready var hint: Label = $Overlay/Hint
@onready var portrait: TextureRect = $Overlay/Portrait

var mode: int = Mode.NONE
var _player: Node = null
var _sel: int = 0
var _shop: int = Shop.BUY
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


## First visible row so that _sel stays on screen, scrolling only when the
## selection would leave the window.
func _window_start(total: int, shown: int) -> int:
	if total <= shown:
		return 0
	return clampi(_sel - shown / 2, 0, total - shown)

# marking state
var _marking: Array = []       ## StudentData still to be judged
var _marked_right: int = 0
var _shown_hints := {}
## Whose file is open. One field rather than a mode stack: there is
## exactly one transition to remember (class list -> bio -> back).
var _bio: StudentData = null
var _bio_sel: int = 0
## The exam is the one screen whose closing DOES something, so it has to be
## told apart from every other report.
var _showing_exam: bool = false
## The run itself has ended. Closing this one starts a new run rather than
## a new term.
var _showing_run_over: bool = false
## The school screen is showing the hiring list rather than the rooms.
var _hiring: bool = false
## Which room a hire is FOR.
var _hiring_for: int = 0


func _ready() -> void:
	# A new run must not inherit the last one's screen.
	Game.run_started.connect(func() -> void:
		if mode != Mode.TITLE:
			close())


## Display only. Every INPUT read lives on the physics tick below.
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("carrier")
	_update_status()
	_update_prompt()


## ALL input, on ONE clock.
##
## Opening the class list and the pause menu used to be read here in
## _process (the idle tick) while everything else was read in
## _physics_process. Two clocks meant Input.is_action_just_pressed() was
## being asked about two different frames, so a press could be seen by one
## and missed by the other — which is exactly what happened: Tab opened the
## class list in play but never in a test, because the test drives the
## physics tick.
## The wheel and the mouse, for the one screen that is a folder of pages.
##
## _input rather than the physics poll because a wheel notch is an EVENT --
## it has no held state to sample, so polling would miss it entirely.
func _input(e: InputEvent) -> void:
	if mode != Mode.HAND or Game.hand.is_empty():
		return
	var n: int = Game.hand.size()
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var b := (e as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_DOWN:
			_sel = (_sel + 1) % n
			Sfx.play_varied("paper")
			show_hand()
			accept_event()
		elif b == MOUSE_BUTTON_WHEEL_UP:
			_sel = (_sel - 1 + n) % n
			Sfx.play_varied("paper")
			show_hand()
			accept_event()
		elif b == MOUSE_BUTTON_LEFT:
			# clicking the page turns it, the way you would nudge a corner
			_sel = (_sel + 1) % n
			Sfx.play_varied("paper")
			show_hand()
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
	var bits: Array[String] = ["%sDay %d/%d" % [
		"T%d " % Game.term if Game.term > 1 else "",
		Game.day, Balance.term_days]]

	if teaching:
		var room := get_tree().get_first_node_in_group("classroom")
		if room != null:
			bits.append("%ds" % int(ceil(room.lesson_left)))
		# What paper is on the desks. In WORDS: the strip is a Label, so it
		# cannot carry the rarity's colour the way the card screen does.
		if not Game.assignment.is_empty():
			bits.append(Assignments.rarity_name(
				String(Game.assignment.get("rarity", "common"))))
		# A mode you cannot see is a mode you forget is on.
		if _player != null and is_instance_valid(_player) and _player.autopilot:
			bits.append("AUTO%s" % ("" if _player.auto_target_name == ""
				else " " + _player.auto_target_name))
		if not Game.test_active:
			# Attention first: it is the difference between a lesson
			# happening and a lesson not happening, so it outranks the rest.
			var att := int(round(Game.attention * 5.0))
			bits.append("%steaching %s%s" % [
				"" if Game.teaching else "NOT ",
				"|".repeat(att), ".".repeat(5 - att)])
			var pips := int(round(Game.voice * 4.0))
			bits.append("voice %s%s" % ["|".repeat(pips), ".".repeat(4 - pips)])
		# A buff you cannot see is a buff you do not believe in.
		if Game.quiz_focus:
			bits.append("FOCUSED")
	else:
		bits.append("%s %s" % [Curriculum.short_name(Game.lesson),
			"*".repeat(Curriculum.difficulty(Game.lesson))])
		bits.append("%d coins" % Game.coins)
		# What you are actually playing towards. It used to appear for the
		# first time on the screen that judged you by it.
		bits.append("need %d" % Game.term_target())
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
	for st: StudentData in Game.roster:
		if st.disrupting:
			noisy += 1
		# what you can SEE, not what is true -- the strip must never quietly
		# know more about the room than the room is showing you
		if st.is_visibly_struggling():
			stuck += 1
		if st.has_work_to_collect():
			waiting += 1

	# via a group, not current_scene -- current_scene is not Main when the
	# game is instantiated inside a test or a screenshot harness
	var place := get_tree().get_first_node_in_group("placement")
	if place != null and place.active:
		bits.append("helps %d" % place.reach_count())

	# Loudest first: messing about is the one that gets worse while you are
	# somewhere else.
	if noisy > 0:
		bits.append("%d NOISY" % noisy)
	if stuck > 0:
		bits.append("%d stuck" % stuck)
	if waiting > 0:
		bits.append("%d ready" % waiting)

	status.text = _clip("   ".join(bits))


func _update_prompt() -> void:
	if mode != Mode.NONE:
		prompt.visible = false
		prompt_box.visible = false
		return
	# a timed hint owns the prompt bar while it is up
	if _hint_until > Time.get_ticks_msec() / 1000.0:
		return
	if _player == null or not is_instance_valid(_player):
		prompt.visible = false
		prompt_box.visible = false
		return

	# BOTH buttons, always.
	#
	# This used to show one target -- whichever the picker preferred, which
	# was always E. Stand at the noticeboard and it said "Curriculum", so the
	# SHOP, sitting right there on F, was invisible; the game looked like it
	# had lost a feature. Stand by the bell and it said "Curriculum" again
	# while "Ring the bell" went unmentioned on F, which is how the day
	# became impossible to end.
	#
	# One target per button was already true. The bar simply was not saying so.
	# Through offers(), NOT by reading targets directly. Reading a freed node
	# into a typed variable throws "Trying to assign invalid previously freed
	# instance" -- the same fault that once killed every button in the game,
	# reappearing here the moment build mode started selling furniture out
	# from under the cursor. It threw every single frame and buried the test
	# log. offers() is the player's own safe accessor; there is no reason for
	# anything else to reach into targets.
	var parts: Array[String] = []
	for t: Interactable in _player.offers():
		if not t.can_interact():
			continue
		var action: String = t.action_name()
		var key: String = t.key_hint()
		if t.hold_time > 0.0:
			var held: float = _player.hold_progress if _player._holding == action else 0.0
			var filled := int(round(held * 6.0))
			parts.append("hold %s [%s%s] %s" % [
				key, "#".repeat(filled), ".".repeat(6 - filled), t.prompt_text()])
		else:
			parts.append("%s - %s" % [key, t.prompt_text()])

	var showing := not parts.is_empty()
	prompt.visible = showing
	prompt_box.visible = showing
	if showing:
		# Fit BOTH halves, taking the room from whichever is longer.
		#
		# Clipping the joined line lopped the tail off the second prompt, so
		# a hold meter could appear with no words after it. Splitting the
		# budget evenly then over-clipped: "E - Quick quiz" needs 14 of its
		# 22 and "hold F [......] End the lesson early" needs 36, and an
		# even split turned the second into "End t.". So the short one keeps
		# what it needs and the long one gets the rest.
		if parts.size() > 1:
			var budget: int = LINE_CHARS - 3
			var total := 0
			for part: String in parts:
				total += part.length()
			while total > budget:
				var longest := 0
				for i in parts.size():
					if parts[i].length() > parts[longest].length():
						longest = i
				var over: int = total - budget
				var trim: int = mini(over, parts[longest].length() - 8)
				if trim <= 0:
					break
				parts[longest] = parts[longest].substr(
					0, parts[longest].length() - trim - 1) + "."
				total -= trim
		prompt.text = _clip("   ".join(parts))


# ---------------------------------------------------------------- overlays

func _open(m: int) -> void:
	mode = m
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_constant_override("line_spacing", 4)
	# every mode that wants a portrait turns it back on; this is the
	# single line that stops one screen leaking into the next
	portrait.visible = false
	# the same single line that stops one screen leaking into the next
	rich.visible = false
	body.visible = true
	# ...and this one. Closing the exam starts a term; closing anything else
	# must not. show_exam() sets it again straight after this runs, so the
	# flag can only ever be true for the screen that set it.
	_showing_exam = false
	_showing_run_over = false
	_hiring = false
	overlay.visible = true
	if _player != null and is_instance_valid(_player):
		_player.input_locked = true


func close() -> void:
	mode = Mode.NONE
	overlay.visible = false
	if _player != null and is_instance_valid(_player):
		_player.input_locked = false


## The first thing anyone sees. The game used to boot straight into play
## with no explanation of anything at all.
##
## Sized to the panel deliberately: the body is 128px, and at font size 8
## a line is about 20px, so SEVEN lines is the honest limit. Earlier drafts
## ran off the bottom and overlapped the hint bar.
func show_title() -> void:
	_open(Mode.TITLE)
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_constant_override("line_spacing", 1)
	title.text = "P I X E L R O O M"
	# This screen had gone stale. It still described only the original loop,
	# so a player who had just been given traits, disruption, a voice and
	# three assessments was told about none of them and quite reasonably
	# concluded that nothing had changed.
	body.text = "\n".join([
		"You are the teacher. WASD walks. E is the prompt at",
		"the bottom, F the one beside it. Tab: your class.",
		"Teach at the PODIUM, then walk the room:",
		"  amber ? stuck     red ! playing up (it SPREADS)",
		"  blue ? behind     Q settles who can hear you",
		"Collect work, mark homework at YOUR desk, ring the",
		"BELL. Quiz mid-lesson; test a unit you know well.",
		"%d days, then the exam." % Balance.term_days,
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
		"Sound  %s" % _vol_bar(), "Quit to title"]
	var lines: Array[String] = ["", ""]
	for i in rows.size():
		lines.append("      %s %s" % [">" if i == _pause_sel else " ", rows[i]])
	lines.append("")
	lines.append("      Day %d of %d, %s" % [Game.day, Balance.term_days, Game.subject])
	body.text = "\n".join(lines)
	hint.text = "Left/Right changes volume.  E picks."


func _vol_bar() -> String:
	var n := int(round(Settings.sfx_volume * 10.0))
	return "[%s%s]" % ["#".repeat(n), ".".repeat(10 - n)]


func _pause_input() -> void:
	if Input.is_action_just_pressed("move_down"):
		_pause_sel = (_pause_sel + 1) % 5
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_up"):
		_pause_sel = (_pause_sel + 4) % 5
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		if _pause_sel == 3:
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
			show_career()
			return
		elif _pause_sel == 4:
			Game.save_game()
			close()
			get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
			return
	_render_pause()


## A one-off nudge, shown once per run. Silence is the worst teacher.
func hint_once(id: String, text: String) -> void:
	if _shown_hints.has(id) or mode != Mode.NONE or not Settings.show_hints:
		return
	_shown_hints[id] = true
	prompt.visible = true
	prompt_box.visible = true
	prompt.text = text
	_hint_until = Time.get_ticks_msec() / 1000.0 + 4.0


var _hint_until: float = 0.0


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
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)
	_render_dashboard()


func _render_dashboard() -> void:
	Balance.ensure_loaded()
	var lines: Array[String] = []
	var tabs := ["Overview", "Items", "Skills"]
	var strip := ""
	for i in tabs.size():
		strip += "[color=#%s]%s[/color]  " % [
			C_LESSON if i == _dash else DIM, tabs[i]]
	lines.append(strip)
	lines.append("")

	# Only the OVERVIEW page wants the portrait -- _render_dashboard() is
	# called directly when cycling pages (not through _open(), which is
	# the usual place a portrait gets hidden again), so this has to manage
	# it itself or a stale portrait would follow you onto Items/Skills.
	portrait.visible = (_dash == Dash.OVERVIEW)

	match _dash:
		Dash.OVERVIEW:
			lines.append_array(_render_dash_overview())
		Dash.ITEMS:
			lines.append_array(_render_dash_items())
		Dash.SKILLS:
			lines.append_array(_render_dash_skills())

	rich.text = "
".join(lines)
	rich.visible_ratio = 1.0
	hint.text = "Tab - next page    E / Esc - close"


## Who you are, at a glance. The character portrait is the hook for the
## cosmetic slots that are coming -- a hat and a background are asked for
## and explicitly NOT built yet, so the two lines are placeholders that
## read honestly as "not chosen" rather than as a broken feature.
func _render_dash_overview() -> Array[String]:
	var at := AtlasTexture.new()
	at.atlas = load("res://art/player.png")
	at.region = Rect2(0, 0, 16, 24)
	portrait.texture = at   # visibility is handled by _render_dashboard()

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
func _render_dash_skills() -> Array[String]:
	var lines: Array[String] = []
	lines.append("[color=#%s]%d point%s unspent[/color]" % [
		C_COIN, Game.perk_points_free(),
		"" if Game.perk_points_free() == 1 else "s"])
	lines.append("")
	var order := Progress.perk_order()
	for id: String in order:
		var d := Progress.perk_def(id)
		var have := Game.perk_rank(id)
		var cap := Progress.max_rank(id)
		lines.append("[color=#%s]%-17s[/color] [color=#%s]%s[/color]" % [
			C_LESSON if have > 0 else DIM, String(d.get("name", id)),
			C_LESSON if have > 0 else DIM,
			BAR_FULL.repeat(have) + BAR_EMPTY.repeat(cap - have)])
	if order.is_empty():
		lines.append("[color=#%s]No perks defined.[/color]" % DIM)
	return lines


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
	body.add_theme_font_size_override("font_size", 8)
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
	_bio = s
	_open(Mode.STUDENT)
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_constant_override("line_spacing", 1)

	title.text = s.display_name
	if title.text.length() > 22:
		title.text = "%s %s." % [s.first_name(), s.surname().substr(0, 1)]

	# One 16x24 frame of the 5x4 sheet: standing, facing the camera.
	# TextureRect + AtlasTexture rather than a Sprite2D, which would centre
	# itself inside a Control and ignore the layout entirely.
	var at := AtlasTexture.new()
	at.atlas = load("res://art/%s.png" % s.art)
	at.region = Rect2(0, 0, 16, 24)
	portrait.texture = at
	portrait.visible = true

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
	hint.text = "Up/Down choose    E do it    Esc back"


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
	rich.add_theme_constant_override("line_separation", 1)
	rich.add_theme_font_size_override("normal_font_size", 8)

	title.text = "END OF TERM  -  %s" % String(result.get("letter", "F"))

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
	hint.text = _clip("E - begin term %d%s" % [Game.term + 1,
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
	hint.text = _clip("E - close.   %s today.   %s" % [
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
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)

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
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)

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
			"e8dcc2" if lit else DIM, BAR_FULL if lit else BAR_EMPTY]
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
	var hue := Assignments.rarity_colour(rid)
	var lesson := Curriculum.by_id(String(card.get("lesson", "")))

	title.text = "LESSON PLANS  -  %d of %d" % [_sel + 1, n]

	var lines: Array[String] = []
	# the page's own heading, in the rarity's colour
	lines.append("[color=#%s]%s[/color]" % [hue, Assignments.title(card)])
	lines.append("[color=#%s]%s[/color]   [color=#%s]%s[/color]" % [
		hue, Assignments.rarity_name(rid), DIM,
		String(lesson.get("standard", "")) if String(lesson.get("standard", "")) != ""
			else "no citation"])
	lines.append("")
	# what it actually asks of them
	lines.append("[color=#%s]Length[/color]  %s   [color=#%s]pays x%.2f[/color]" % [
		DIM, _difficulty_bar(int(card.get("difficulty", 1))),
		C_COIN, Assignments.pay(rid)])
	var obj := String(lesson.get("objective", ""))
	if obj != "":
		lines.append("[color=#%s]%s[/color]" % [DIM, _wrap(obj, 52, 2)])
	lines.append("")
	# the page edge, so it is obvious there ARE more
	var edge := ""
	for i in n:
		edge += "[color=#%s]%s[/color]" % [
			Assignments.rarity_colour(String(Game.hand[i].get("rarity", "common"))),
			BAR_FULL if i == _sel else BAR_EMPTY]
	lines.append("%s   [color=#%s]turn the page[/color]" % [edge, DIM])

	rich.text = "\n".join(lines)
	_reveal_rich(0.22)
	hint.text = "Scroll / click / Up-Down to turn    E - set this one"


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
	_open(Mode.SCHOOL)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)
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
		lines.append("[color=#%s]furniture %s   %d/day in wages[/color]" % [
			DIM, _furniture_bar(int(sel.get("furniture", 0))), Game.wage_bill()])

	rich.text = "\n".join(lines)
	_reveal_rich(0.3)
	hint.text = _clip("Up/Down room   E hire   F furnish   N new room (%d)   Esc" % [
		Game.room_cost()])


func _furniture_bar(level: int) -> String:
	Balance.ensure_loaded()
	var n: int = clampi(level, 0, Balance.furniture_steps)
	return "[color=#%s]%s[/color][color=#3a3a42]%s[/color]" % [
		C_ROOM, BAR_FULL.repeat(n),
		BAR_EMPTY.repeat(Balance.furniture_steps - n)]


## Who is going. Prose, never numbers -- the same rule the rest of the game
## follows, and the reason a hire reads as a person rather than a stat line.
func show_hiring() -> void:
	_open(Mode.SCHOOL)
	_hiring = true
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)
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
		lines.append("    [color=#%s]%s[/color]" % [
			DIM, String(t.get("blurb", ""))])
	rich.text = "\n".join(lines)
	_reveal_rich(0.25)
	var sel: Dictionary = Game.applicants[_sel] if _sel < Game.applicants.size() else {}
	hint.text = _clip("E hire   Esc back.   %s, but %s" % [
		Staff.strengths(sel), Staff.weakness(sel)])


## YOUR CAREER: every milestone, earned and unearned.
##
## The UNEARNED ones are the point. A list of what you have done is a trophy
## cabinet; a list that also shows what there is to do is a map, and a game
## with no ending needs the map far more than the cabinet.
func show_career() -> void:
	_open(Mode.CAREER)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 1)
	rich.add_theme_font_size_override("normal_font_size", 8)

	var all := Milestones.all()
	title.text = "YOUR CAREER  %d/%d" % [Game.milestones.size(), all.size()]

	# a window, because there are more milestones than the panel holds
	_sel = clampi(_sel, 0, maxi(0, all.size() - 1))
	var lo := _window_start(all.size(), 9)
	var lines: Array[String] = []
	for i in range(lo, mini(all.size(), lo + 9)):
		var m: Dictionary = all[i]
		var id := String(m.get("id", ""))
		var have: bool = Game.milestones.has(id)
		lines.append("%s [color=#%s]%s[/color]" % [
			">" if i == _sel else " ", C_COIN if have else DIM,
			String(m.get("name", id)) if have else "- - -"])
	rich.text = "\n".join(lines)
	_reveal_rich(0.25)

	var sel: Dictionary = all[_sel] if _sel < all.size() else {}
	var earned: bool = Game.milestones.has(String(sel.get("id", "")))
	hint.text = _clip("Esc - close.   %s%s" % [
		"" if earned else "Not yet: ", String(sel.get("blurb", ""))])


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
	rich.add_theme_constant_override("line_separation", 3)
	rich.add_theme_font_size_override("normal_font_size", 8)
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
	Sfx.play("start")
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)

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


static func strand_colour(strand: String) -> String:
	return String(STRAND_COLOUR.get(strand, "cfcfcf"))


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
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)

	var lessons := Curriculum.lessons
	if lessons.is_empty():
		return
	_sel = clampi(_sel, 0, lessons.size() - 1)
	title.text = "WHAT YOU CAN TEACH"

	var lines: Array[String] = []
	# What you are teaching next, and what you trained in -- the two things
	# this screen is now FOR.
	var next_id := Game.chosen_lesson if Game.chosen_lesson != "" 		else String(Game.lesson.get("id", ""))
	lines.append("[color=#%s]You teach %s[/color]   [color=#%s]%s[/color]" % [
		C_LESSON, Curriculum.short_name(Curriculum.by_id(next_id)),
		DIM, "trained in %s" % Curriculum.strand_label(Game.specialism)
			if Game.specialism != "" else "no speciality"])
	var known: int = Game.concepts.size()
	if known == 0:
		lines.append("[color=#%s]Teach a subject and you get better at teaching it.[/color]"
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
		lines.append("[color=#%s]Knowing your subjects %s.[/color]" % [
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
		lines.append("%s%s [color=#%s]%s[/color] %s %s [color=#%s]%s[/color]" % [
			"*" if mine else " ",
			">" if i == _sel else " ",
			hue if taught else DIM,
			Curriculum.short_name(l).rpad(11),
			_difficulty_bar(Curriculum.difficulty(l)),
			_mastery_bar(got, total, hue),
			DIM, _mastery_words(l, got, total)])

	rich.text = "\n".join(lines)
	_reveal_rich(0.3)

	# The selected subject, and what teaching it AGAIN would buy you. Naming
	# the next concept is worth more than restating the objective: it is the
	# thing the player is deciding about.
	var std := String(lessons[_sel].get("standard", ""))
	hint.text = _clip("%s%s   E - teach this next" % [
		std, "" if std == "" else "  "])


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
		hue, BAR_FULL.repeat(level), BAR_TRACK, BAR_EMPTY.repeat(5 - level)]


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
		hue, BAR_FULL.repeat(n), BAR_TRACK, BAR_EMPTY.repeat(width - n)]


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
		C_LESSON, BAR_FULL.repeat(n), BAR_TRACK, BAR_EMPTY.repeat(5 - n)]




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
	"comfort": "f2a0b5",     # rose
	"decor": "d0a3e8",       # violet
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
				BAR_FULL.repeat(n)]
			used += n
	if used < width:
		out += "[color=#%s]%s[/color]" % [BAR_TRACK, BAR_EMPTY.repeat(width - used)]
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


func show_day_report(report: Dictionary) -> void:
	Sfx.play("grade")
	_open(Mode.REPORT)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 1)
	rich.add_theme_font_size_override("normal_font_size", 8)

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
	_reveal_rich(0.45)
	hint.text = "E - close"


func open_catalogue() -> void:
	_open(Mode.CATALOGUE)
	_sel = 0
	_shop = Shop.BUY
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
		# The aide sits at the top of the same list as the perks, so the
		# screen keeps ONE cursor. A second selection model on one screen is
		# how a UI starts needing a diagram.
		var staff: Array = ["aide"]
		staff.append_array(Progress.perk_order())
		return staff
	if _shop == Shop.ROOM:
		return ROOM_ROWS.duplicate()
	return Game.room_items.duplicate()


func _render_catalogue() -> void:
	# The shop is a list of five KINDS of thing at four different prices --
	# exactly what colour is for, and a Label is one colour by definition.
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 8)
	# The shop grew a blurb line and the staff room lists five perks, so the
	# default font 10 (about 6 lines in a 128px body) ran under the hint bar.
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_constant_override("line_spacing", 1)
	var rows := _shop_rows()
	_sel = 0 if rows.is_empty() else clampi(_sel, 0, rows.size() - 1)

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
	if _shop == Shop.SELL:
		heading = "SELL FURNITURE"
	elif _shop == Shop.STAFF:
		heading = "STAFF ROOM"
	elif _shop == Shop.ROOM:
		heading = "THE ROOM  %dx%d" % [Grid.W, Grid.H]
	title.text = "%s  -  %d coins" % [heading, Game.coins]

	# Show the thing you are buying. You used to be choosing furniture you
	# had never seen, described by a decimal.
	portrait.visible = false
	if _shop == Shop.BUY and not rows.is_empty():
		var art := String(Items.get_def(String(rows[_sel])).get("art", ""))
		if art != "" and ResourceLoader.exists("res://art/%s.png" % art):
			portrait.texture = load("res://art/%s.png" % art)
			portrait.visible = true

	var lines: Array[String] = []
	if _shop == Shop.BUY and tabs != "":
		lines.append(tabs)
	if _shop == Shop.STAFF:
		lines = _render_staff()
	elif _shop == Shop.ROOM:
		lines = _render_room()
	elif rows.is_empty():
		lines.append("   Nothing to sell - the room is bare.")
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
			var afford: bool = Game.can_afford(int(d["cost"]))
			var hue := cat_colour(Items.category_of(id))
			# The price is the thing you are actually deciding on, so it
			# carries the yes/no colour rather than the name doing it.
			lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%4d[/color] %s %s" % [
				">" if i == _sel else " ", hue if afford else DIM,
				String(d["name"]).substr(0, 13),
				C_GOOD if afford else C_BAD, int(d["cost"]),
				_worth_bar(float(d["bonus"])),
				"[color=#%s]%s[/color]" % [DIM,
					_reach_words(int(d["range"]), float(d["bonus"]))]])
		if lo + LIST_ROWS < rows.size():
			lines.append("   ...")
		# The blurb rides on the HINT bar rather than taking a body line. The
		# tab strip plus four rows is already everything the panel holds, and
		# the blurb was landing on top of the hint text.
		_shop_blurb = String(Items.get_def(rows[_sel]).get("blurb", ""))
	else:
		# The sell list is windowed too. A full room is far more items than
		# the panel holds, and it used to print every one of them.
		var lo2 := _window_start(rows.size(), LIST_ROWS)
		if lo2 > 0:
			lines.append("   ...")
		for i in range(lo2, mini(rows.size(), lo2 + LIST_ROWS)):
			var placed: Dictionary = rows[i]
			var pid := String(placed["id"])
			lines.append(_clip("%s %-13s  back %3d   at %d,%d" % [
				">" if i == _sel else " ",
				String(Items.get_def(pid).get("name", pid)),
				Game.sell_value(pid), placed["tile"].x, placed["tile"].y]))
		if lo2 + LIST_ROWS < rows.size():
			lines.append("   ...")
		lines.append("Selling gives back half. To MOVE one, walk to it.")
	rich.text = "\n".join(lines)
	# NO reveal here. The catalogue re-renders on every keypress, so a
	# wipe would restart under your fingers each time you moved the
	# selection. Animate results you are handed, never a list you are
	# steering.
	rich.visible_ratio = 1.0
	var verb := "order"
	var next_tab := "sell list"
	if _shop == Shop.BUY:
		hint.text = _clip(_shop_blurb) if _shop_blurb != "" 			else "Up/Down pick   Left/Right category   E order   Esc close"
		return
	if _shop == Shop.SELL:
		verb = "sell"
		next_tab = "staff room"
	elif _shop == Shop.STAFF:
		verb = "learn"
		next_tab = "the room"
	elif _shop == Shop.ROOM:
		verb = "build"
		next_tab = "buy list"
	hint.text = "Up/Down choose   E %s   Tab %s   Esc close" % [verb, next_tab]


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


## The staff-room board: what you have learned to do better.
func _render_staff() -> Array[String]:
	Balance.ensure_loaded()
	var lines: Array[String] = []
	lines.append("[color=#%s]Level %d[/color]    %d point%s to spend" % [
		C_KNOW, Game.teacher_level, Game.perk_points_free(),
		"" if Game.perk_points_free() == 1 else "s"])
	lines.append("")

	# row 0: the aide
	var hired: bool = Game.has_aide
	lines.append("%s [color=#%s]%-17s[/color] [color=#%s]%s[/color]" % [
		">" if _sel == 0 else " ", C_ROOM, "Teacher's aide",
		C_GOOD if hired else C_COIN,
		"hired, %d/day" % Balance.aide_wage if hired
			else "%d coins" % Balance.aide_cost])

	var order := Progress.perk_order()
	for i in order.size():
		var id: String = order[i]
		var d := Progress.perk_def(id)
		var have := Game.perk_rank(id)
		var cap := Progress.max_rank(id)
		lines.append("%s %-17s [color=#%s]%s[/color]" % [
			">" if i + 1 == _sel else " ", String(d.get("name", id)),
			C_LESSON if have > 0 else DIM,
			BAR_FULL.repeat(have) + BAR_EMPTY.repeat(cap - have)])
	lines.append("")
	if _sel == 0:
		lines.append("[color=#%s]%s[/color]" % [DIM,
			"They collect finished work so you can stay at the front."
			if not hired else "E again to let them go."])
	elif not order.is_empty():
		lines.append("[color=#%s]%s[/color]" % [DIM,
			String(Progress.perk_def(order[_sel - 1]).get("blurb", ""))])
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
func open_marking() -> void:
	_marking.clear()
	_marked_right = 0
	for s: StudentData in Game.roster:
		if s.homework_ready_to_mark():
			_marking.append(s)
	if _marking.is_empty():
		return
	_open(Mode.MARKING)
	_render_sheet()


func _render_sheet() -> void:
	if _marking.is_empty():
		return
	var s: StudentData = _marking[0]
	title.text = "%s  —  %d left" % [s.display_name, _marking.size()]
	var lines: Array[String] = []
	for it: Dictionary in s.hw_sheet.get("items", []):
		# The tells are what you actually learn to read. They agree with the
		# truth most of the time, but not always — so this stays a judgement
		# rather than becoming a lookup.
		var tells := "%s, %s" % [
			"neat" if bool(it["neat"]) else "rushed",
			"working shown" if bool(it["working"]) else "no working"]
		lines.append("   %-10s = %-6s   %s" % [String(it["q"]), String(it["shown"]), tells])
	lines.append("")
	lines.append("   Does this deserve a pass?")
	body.text = "\n".join(lines)
	hint.text = "Left — Not yet          Got it — Right"


func _verdict(pass_it: bool) -> void:
	var s: StudentData = _marking.pop_front()
	s.hw_player_verdict = 1 if pass_it else 0
	s.hw_state = StudentData.HW.MARKED
	if pass_it == Questions.sheet_is_good(s.hw_sheet):
		_marked_right += 1
	if _marking.is_empty():
		if _player != null and is_instance_valid(_player):
			_player.drop_all_homework()
		title.text = "MARKING DONE"
		body.text = "\n".join([
			"You judged %d of them the way the sheet actually" % _marked_right,
			"deserved.",
			"",
			"A sheet you waved through won't flag its student as",
			"struggling tomorrow — so you won't go and help them.",
		])
		hint.text = "E — close"
		mode = Mode.REPORT
		return
	_render_sheet()


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
		elif n > 0 and Game.claim_interact():
			_hiring_for = _sel
			_sel = 0
			show_hiring()
		return

	if mode == Mode.CAREER:
		var n: int = Milestones.count()
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
			_dash = (_dash + 1) % 3
			Sfx.play("blip")
			_render_dashboard()
		return

	if mode == Mode.CURRICULUM:
		var n: int = Curriculum.lessons.size()
		if Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			close()
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
		# overloaded-button problem all over again.
		if Input.is_action_just_pressed("cancel"):
			Sfx.play("blip")
			_bio = null
			show_class_list(true)      # back to the list, on the same student
		elif Input.is_action_just_pressed("move_down"):
			_bio_sel = (_bio_sel + 1) % Act.COUNT
			Sfx.play("blip")
			show_student(_bio)
		elif Input.is_action_just_pressed("move_up"):
			_bio_sel = (_bio_sel - 1 + Act.COUNT) % Act.COUNT
			Sfx.play("blip")
			show_student(_bio)
		elif Game.claim_interact():
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
		elif Input.is_action_just_pressed("menu"):
			_shop = (_shop + 1) % 4      # buy -> sell -> staff -> the room
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
				if _sel == 0:
					# hiring, or letting them go
					var ae := Game.set_aide(not Game.has_aide)
					Sfx.play("deny" if ae != "" else "coins")
				else:
					var err := Game.buy_perk(String(rows[_sel]))
					Sfx.play("deny" if err != "" else "confirm")
					if err == "":
						perk_bought.emit()
				_render_catalogue()
			elif _shop == Shop.BUY:
				var id: String = rows[_sel]
				if Game.can_afford(Items.cost(id)):
					Sfx.play("confirm")
					close()
					item_chosen.emit(id)
				else:
					Sfx.play("deny")
			else:
				Game.sell_item(rows[_sel]["tile"])
				Sfx.play("coins")
				_render_catalogue()
		return

	if mode == Mode.MARKING:
		if Input.is_action_just_pressed("move_left"):
			_verdict(false)
		elif Input.is_action_just_pressed("move_right"):
			_verdict(true)
