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
	CURRICULUM, SPECIALISM, HAND, CAREER, SCHOOL, DASHBOARD, WATCH, OFFICE, INTRO,
	ADS, PATHS, MENTOR, HELP }
## SELL became CABINET (Sep 2026): buying no longer places on the spot,
## it drops the item in the cabinet; you place it from the cabinet, and
## selling is done from there too. Same five-stop Tab cycle, one label
## and one screen changed.
enum Shop { BUY, CABINET, STAFF, ROOM, CRAFT }
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
## The principal's own corner, for a tutorial tip -- deliberately OUTSIDE
## $Overlay. Overlay is hidden whenever mode == NONE (close()), which is
## exactly when a tip needs to fire: nobody has a screen open, they are
## mid-room and about to do the thing the tip is about.
@onready var mascot_box: ColorRect = $MascotBox
@onready var mascot_portrait: TextureRect = $MascotPortrait
## The dedicated 96x96 busts the Sept 2026 art pass drew (tools/make_art.py
## make_portrait()) -- a face at corner/panel size, not a walk-cycle frame
## stretched up to it. Preloaded like the sheets above rather than loaded
## by string each call, since these two are used every time the mascot box
## or the day's beat shows a face.
const PRINCIPAL_PORTRAIT := preload("res://art/portrait_principal.png")
const PLAYER_PORTRAIT := preload("res://art/portrait_player.png")

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
var _bio_page: int = BIO_FILE
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
	# A new run must not inherit the last one's screen.
	Game.run_started.connect(func() -> void:
		if mode != Mode.TITLE:
			close())
	# Trace an X or a check with the mouse instead of pressing a key -- see
	# homework_sheet.gd's own comment for why stroke COUNT is the signal.
	sheet.gesture_verdict.connect(_verdict)


## Display only. Every INPUT read lives on the physics tick below.
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("carrier")
	_update_status()
	_update_prompt()
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
	if mode == Mode.NONE and not _queued_hint.is_empty():
		var q: Array = _queued_hint
		_queued_hint = []
		principal_says(String(q[0]), String(q[1]))

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
			# The class in a word, not attention as pips: "is the room with
			# me" was the one thing a new player had to add up from bars.
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

	# Lowest priority on purpose -- the first thing _clip_visibly drops when
	# the line is full. Silent otherwise: dash is ready almost all the time,
	# so a bar that is only shown while cooling down is the informative
	# state, not a pip that reads "full" on every frame that matters less.
	if _player != null and is_instance_valid(_player):
		var dash_cd: float = _player.dash_cooldown_fraction()
		if dash_cd > 0.0:
			var ready_pips := int(round((1.0 - dash_cd) * 4.0))
			bits.append("dash %s%s" % ["|".repeat(ready_pips), ".".repeat(4 - ready_pips)])

	# The mass-help skill's own cooldown, same rules: shown only mid-lesson
	# and only while it is actually recharging.
	if teaching and Balance.answer_all_cooldown_seconds > 0.0 and Game.answer_all_cooldown > 0.0:
		var aa_ready := int(round(
			(1.0 - Game.answer_all_cooldown / Balance.answer_all_cooldown_seconds) * 4.0))
		aa_ready = clampi(aa_ready, 0, 4)
		bits.append("answer-all %s%s" % ["|".repeat(aa_ready), ".".repeat(4 - aa_ready)])

	status.text = _clip_visibly("   ".join(bits))


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
		# Fit every live part, taking the room from whichever is longest.
		#
		# Clipping the joined line lopped the tail off the last prompt, so
		# a hold meter could appear with no words after it. Splitting the
		# budget evenly then over-clipped: "E - Quick quiz" needs 14 of its
		# 22 and "hold F [......] End the lesson early" needs 36, and an
		# even split turned the second into "End t.". So the short one keeps
		# what it needs and the long one gets the rest.
		if parts.size() > 1:
			# THE BUG THIS FIXES: budget reserved space for exactly ONE
			# "   " joiner, which was correct back when only two things
			# could ever be live at once (E and F). The key remap made a
			# 3-way collision (E, F and Q at once, say) an ordinary thing,
			# and two joiners need 6 characters, not 3 -- the shortfall
			# was silently eaten by the OUTER _clip() below with no
			# ellipsis, landing wherever the tail happened to fall. Caught
			# by screenshot: "Q - Quick quiz" rendered as "Q - Quick q".
			var budget: int = LINE_CHARS - 3 * (parts.size() - 1)
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
		# Belt and braces: the fitting above should always land inside
		# LINE_CHARS now, but if a future case ever slips past it, make
		# the cut visible rather than silent -- same fix as the status
		# strip's own _clip_visibly() already uses, and the same reason.
		prompt.text = _clip_visibly("   ".join(parts))


# ---------------------------------------------------------------- overlays

func _open(m: int) -> void:
	mode = m
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_constant_override("line_spacing", 8)
	# every mode that wants a portrait turns it back on; this is the
	# single line that stops one screen leaking into the next
	portrait.visible = false
	portrait_bg.visible = false
	# the same single line that stops one screen leaking into the next
	rich.visible = false
	sheet.visible = false
	body.visible = true
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
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_constant_override("line_spacing", 2)
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
		"  blue ? behind     C settles who can hear you",
		"Collect on E, mark homework on H, ring the BELL",
		"on F. Q for a quick quiz; test a unit you know well.",
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
	"move_desk": "Move a desk. Spread them out; crowding slows them.",
	"voice": "Settle the desks within earshot.",
	"build": "Rearrange the room from a free cursor. Not mid-lesson.",
	"autopilot": "Walk to whoever needs you. Never presses a button.",
	"auto_teach": "Hand the lesson to the simulation. Toggle.",
	"dash": "A burst of speed. Or double-tap a direction.",
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
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	prompt.visible = true
	prompt_box.visible = true
	prompt.text = text
	# The dedicated bust (Sept 2026 art pass), not a cropped sheet frame --
	# a real face at the corner's own size instead of a desk-distance
	# 32x48 walk frame stretched up to it.
	mascot_portrait.texture = PRINCIPAL_PORTRAIT
	mascot_portrait.visible = true
	mascot_box.visible = true
	_hint_until = Time.get_ticks_msec() / 1000.0 + 5.0


## A hint parked until the player is next in free roam (mode NONE). The
## mentor nudge needs this: it fires from Game.day_changed, which lands
## while the day report is still on screen, so principal_says() would just
## no-op. _process() drains this the first frame nothing else is up.
var _queued_hint: Array = []

func queue_hint(id: String, text: String) -> void:
	if _shown_hints.has(id) or not Settings.show_hints:
		return
	_queued_hint = [id, text]


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
	prompt.text = ""
	prompt.visible = true
	prompt_box.visible = true
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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	body.add_theme_font_size_override("font_size", 16)
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
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_constant_override("line_spacing", 2)

	title.text = s.display_name
	if title.text.length() > 22:
		title.text = "%s %s." % [s.first_name(), s.surname().substr(0, 1)]

	# The dedicated bust (Sept 2026 art pass) -- a face, not a walk-cycle
	# frame stretched up to portrait size.
	portrait.texture = load("res://art/portrait_%s.png" % s.art)
	portrait.visible = true

	if _bio_page == BIO_STORY:
		_render_student_story(s)
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
	hint.text = "Tab back to the file    Esc back"


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
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 16)

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


## The paper is over. One line per child, in the colour of how they held
## up, then the room in a word. Nothing here is a grade: the exam is sat
## at the bell, and this morning is what feeds into it.
func show_fight_report(report: Dictionary) -> void:
	_open(Mode.REPORT)
	Sfx.play("grade")
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	header.add_theme_font_size_override("font_size", 20)
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
		name_label.add_theme_font_size_override("font_size", 16)
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
	await _show_yearbook(func() -> void: _show_run_over_report())


func _show_run_over_report() -> void:
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)

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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)

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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)

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
			C_ROOM if i == _sel else DIM, BAR_FULL if i == _sel else BAR_EMPTY]
	lines.append("%s   [color=#%s]turn the page[/color]" % [edge, DIM])

	rich.text = "\n".join(lines)
	_reveal_rich(0.22)
	hint.text = "Scroll / click / Up-Down to turn    E - start the term this way"


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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	hint.text = _clip("%s  F furnish  %sB new(%d)" % [
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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
		C_ROOM, BAR_FULL.repeat(n), BAR_EMPTY.repeat(20 - n)]


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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 16)

	var rows := _career_rows()
	title.text = "YOUR CAREER  %d/%d   trophies %d/%d" % [
		Game.milestones.size(), Milestones.count(),
		Game.trophies.size(), Trophies.count()]

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
	hint.text = _clip("Esc - close.   %s%s" % [
		"" if bool(sel.get("won", false)) else "Not yet: ", String(sel.get("blurb", ""))])


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
		body.add_theme_font_size_override("font_size", 16)
		body.add_theme_constant_override("line_spacing", 2)
		body.text = "\n".join(INTRO_SLATE)
		hint.text = "E - go on"
		return
	# The slate is gone and stays gone -- the room is visible behind the
	# bubble for the rest of the scene, which is the whole point of a
	# cutscene over a panel that talks ABOUT the room instead.
	overlay.visible = false
	if _sel == -2:
		# The desk-pull. A bubble over the teacher's head; the prompt bar
		# counts down what is left folded up in the cabinet.
		var left: int = Game.desks_in_store
		intro_line_changed.emit("Chairs are stacked.\nDesks are in the cabinet.")
		prompt.text = ("E - pull a desk out  (%d left)" % left) if left > 0 \
			else "E - right then"
		prompt.visible = true
		prompt_box.visible = true
		return
	intro_line_changed.emit("\n".join(INTRO_PAGES[_sel]))
	prompt.text = "E - go on" if _sel < INTRO_PAGES.size() - 1 else "E - right then"
	prompt.visible = true
	prompt_box.visible = true


func _handle_intro_input() -> void:
	if not Game.claim_interact():
		return
	Sfx.play("blip")
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
		"Now the desks. Sit two children side by side",
		"and each works about an eighth slower -- the",
		"price of a crowded table.",
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

const _MENTOR_IDLE := [
	"Still room between the desks, I see. Good.",
	"",
	"Come back when there is a big paper on the way",
	"and I will tell you if the room is ready for it.",
]

## TEACH is the first-visit paged dialogue; READ is the boss-term
## readiness projection; IDLE is the plain revisit line.
enum MentorTalk { TEACH, READ, IDLE }
var _mentor_talk: int = MentorTalk.IDLE


func show_mentor() -> void:
	_open(Mode.MENTOR)
	if not Game.dash_taught:
		_mentor_talk = MentorTalk.TEACH
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


func _render_mentor() -> void:
	overlay.visible = true
	body.visible = true
	rich.visible = false
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_constant_override("line_spacing", 2)
	# The mentor's own bust -- a recolour of the one character model, same
	# as show_student() does for a child.
	portrait.texture = load("res://art/portrait_mentor.png")
	portrait.visible = true
	match _mentor_talk:
		MentorTalk.TEACH:
			_sel = clampi(_sel, 0, MENTOR_PAGES.size() - 1)
			title.text = "THE MENTOR"
			body.text = "\n".join(MENTOR_PAGES[_sel])
			hint.text = "E - go on" if _sel < MENTOR_PAGES.size() - 1 \
				else "E - back to it"
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


func _handle_mentor_input() -> void:
	if not Game.claim_interact():
		return
	Sfx.play("blip")
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
		close()


func show_office() -> void:
	_open(Mode.OFFICE)
	body.visible = false
	rich.visible = true
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
		C_COIN, C_COIN, BAR_FULL.repeat(n), BAR_EMPTY.repeat(20 - n), earned, all.size()])
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
	for i in range(lo, mini(TUTORIALS.size(), lo + shown)):
		lines.append("[color=#%s]%s%s[/color]" % [
			DIM, ">" if i == _sel else " ", TUTORIALS[i]])
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
		show_career()


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
	rich.add_theme_constant_override("line_separation", 6)
	rich.add_theme_font_size_override("normal_font_size", 16)
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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)

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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)

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
	rich.add_theme_constant_override("line_separation", 2)
	rich.add_theme_font_size_override("normal_font_size", 16)

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
	_reveal_rich(0.45)
	hint.text = "E - close"


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
	rich.add_theme_constant_override("line_separation", 4)
	rich.add_theme_font_size_override("normal_font_size", 16)
	# The shop grew a blurb line and the staff room lists five perks, so the
	# default font 10 (about 6 lines in a 128px body) ran under the hint bar.
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_constant_override("line_spacing", 2)
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
	if _shop == Shop.CABINET:
		heading = "YOUR CABINET"
	elif _shop == Shop.STAFF:
		heading = "STAFF ROOM"
	elif _shop == Shop.ROOM:
		heading = "THE ROOM  %dx%d" % [Grid.W, Grid.H]
	elif _shop == Shop.CRAFT:
		heading = "LESSON CRAFTING"
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
	elif _shop == Shop.CRAFT:
		lines = _render_craft(rows)
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
			else:
				lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%4d[/color] %s %s" % [
					">" if i == _sel else " ", hue if afford else DIM,
					String(d["name"]).substr(0, 13),
					C_GOOD if afford else C_BAD, price,
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
	if _shop == Shop.BUY:
		hint.text = _clip(_shop_blurb) if _shop_blurb != "" 			else "Up/Down pick   Left/Right category   E buy to cabinet   Esc close"
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
		dots = " " + BAR_FULL.repeat(level) + BAR_EMPTY.repeat(Balance.staff_level_max - level)
	return "%s [color=#%s]%-17s[/color]%s [color=#%s]%s[/color]" % [
		">" if _sel == idx else " ", C_ROOM, label, dots,
		C_GOOD if hired else C_COIN, status]


## The staff-room board: what you have learned to do better.
## Craft a lesson you already teach: coins + a few in-game days raise its
## craft_level, which makes that SAME material go down easier next time
## it's taught (see Game.difficulty_mults/craft_work_mult). Windowed like
## BUY, since the curriculum runs to 40 lessons.
func _render_craft(rows: Array) -> Array[String]:
	Balance.ensure_loaded()
	var lines: Array[String] = []
	if not Game.lesson_crafting_unlocked():
		lines.append("[color=#%s]Not yet. Get a few days of real teaching[/color]" % DIM)
		lines.append("[color=#%s]behind you first.[/color]" % DIM)
		return lines

	if not Game.pending_craft.is_empty():
		var pl := String(Game.pending_craft.get("lesson_id", ""))
		var pname := String(Curriculum.by_id(pl).get("name", pl))
		var pdays := int(Game.pending_craft.get("days_left", 0))
		lines.append("[color=#%s]%s is in the oven - %d day%s left.[/color]" % [
			C_KNOW, pname, pdays, "" if pdays == 1 else "s"])
		lines.append("")

	var lo := _window_start(rows.size(), LIST_ROWS)
	if lo > 0:
		lines.append("   ...")
	for i in range(lo, mini(rows.size(), lo + LIST_ROWS)):
		var lesson_id: String = rows[i]
		var d := Curriculum.by_id(lesson_id)
		var level: int = int(Game.lesson_crafts.get(lesson_id, {}).get("craft_level", 0))
		var cap: int = Balance.craft_level_cap_for_bonus
		var cost := Game.craft_next_cost(lesson_id)
		var afford: bool = Game.can_afford(cost)
		lines.append("%s [color=#%s]%-13s[/color] [color=#%s]%s[/color] [color=#%s]%4d[/color]" % [
			">" if i == _sel else " ", C_LESSON,
			String(d.get("name", lesson_id)).substr(0, 13),
			C_LESSON if level > 0 else DIM,
			BAR_FULL.repeat(mini(level, cap)) + BAR_EMPTY.repeat(maxi(0, cap - level)),
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
			BAR_FULL.repeat(have) + BAR_EMPTY.repeat(cap - have)])
	if perk_lo + STAFF_PERK_ROWS < order.size():
		lines.append("   ...")
	lines.append("")
	if _sel == 0 or _sel == 1:
		var hired: bool = Game.has_aide if _sel == 0 else Game.has_janitor
		var maxed: bool = (Game.aide_level if _sel == 0 else Game.janitor_level) \
			>= Balance.staff_level_max
		var blurb := "They collect finished work so you can stay at the front." \
			if _sel == 0 else "They clean the room's mess for you, any time of day."
		lines.append("[color=#%s]%s[/color]" % [DIM,
			blurb if not hired
			else ("Fully trained." if maxed else "E again to train them up a level.")
			+ ("" if not hired else "  Left arrow to let them go.")])
	elif not order.is_empty():
		lines.append("[color=#%s]%s[/color]" % [DIM,
			String(Progress.perk_def(order[_sel - 2]).get("blurb", ""))])
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
	hint.text = "Trace a check or an X on the page          Left/Right also work"


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

	if mode == Mode.HELP:
		_handle_help_input()
		return

	if mode == Mode.INTRO:
		_handle_intro_input()
		return

	if mode == Mode.MENTOR:
		_handle_mentor_input()
		return

	if mode == Mode.ADS:
		_handle_ads_input()
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
			_bio_page = BIO_STORY if _bio_page == BIO_FILE else BIO_FILE
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
			_shop = (_shop + 1) % 5      # buy -> cabinet -> staff -> room -> craft
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
