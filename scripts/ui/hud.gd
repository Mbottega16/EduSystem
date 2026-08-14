extends Control

## Status strip, interaction prompt, and the full-screen overlays.
##
## The status strip deliberately sits over the top wall band, where nothing
## gameplay-relevant is ever drawn — so the HUD costs no play area at all.
##
## Overlays are rendered as TEXT rather than as widget trees. At 320x176 a
## laid-out list of labels and a "> " selection marker is not merely
## adequate, it is more legible than real controls would be, and it keeps
## the whole UI layer to one script.

enum Mode { NONE, REPORT, CATALOGUE, MARKING, TITLE, CLASS_LIST, PAUSE, STUDENT }
enum Shop { BUY, SELL, STAFF, ROOM }
## The two ways the room can grow. It only ever grows right and down --
## the door is a fixed point on the left wall.
const ROOM_ROWS := ["wide", "tall"]
## Actions offered on a student's own file.
enum Act { TUITION, PARENTS, GRADUATE, COUNT }

signal item_chosen(id: String)
## Long Reach changes the size of the player's pick zone, so it has to
## be rebuilt when a perk is bought.
signal perk_bought()

@onready var status: Label = $Status
@onready var prompt: Label = $Prompt
@onready var prompt_box: ColorRect = $PromptBox
@onready var overlay: ColorRect = $Overlay
@onready var title: Label = $Overlay/Title
@onready var body: Label = $Overlay/Body
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
func _physics_process(_delta: float) -> void:
	if mode == Mode.NONE:
		if Input.is_action_just_pressed("menu"):
			show_class_list()
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
	var bits: Array[String] = ["Day %d/%d" % [Game.day, Balance.term_days]]

	if teaching:
		var room := get_tree().get_first_node_in_group("classroom")
		if room != null:
			bits.append("%ds" % int(ceil(room.lesson_left)))
		if not Game.test_active:
			var pips := int(round(Game.voice * 4.0))
			bits.append("voice %s%s" % ["|".repeat(pips), ".".repeat(4 - pips)])
	else:
		bits.append(Curriculum.short_name(Game.lesson))
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

	status.text = _clip("   ".join(bits))


func _update_prompt() -> void:
	if mode != Mode.NONE:
		prompt.visible = false
		prompt_box.visible = false
		return
	var target: Interactable = null
	if _player != null and is_instance_valid(_player) 			and is_instance_valid(_player.target):
		target = _player.target
	# a timed hint owns the prompt bar while it is up
	if _hint_until > Time.get_ticks_msec() / 1000.0:
		return
	var showing := target != null and target.can_interact()
	prompt.visible = showing
	prompt_box.visible = showing
	if showing:
		# name the key this thing actually listens for -- there are two now,
		# and anything irreversible has to be held rather than tapped
		var hint_key: String = target.key_hint()
		if target.hold_time > 0.0:
			var held: float = 0.0
			if _player != null and is_instance_valid(_player):
				held = _player.hold_progress
			var filled := int(round(held * 8.0))
			prompt.text = "hold %s [%s%s]  %s" % [
				hint_key, "#".repeat(filled), ".".repeat(8 - filled),
				target.prompt_text()]
		else:
			prompt.text = "%s  —  %s" % [hint_key, target.prompt_text()]


# ---------------------------------------------------------------- overlays

func _open(m: int) -> void:
	mode = m
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_constant_override("line_spacing", 4)
	# every mode that wants a portrait turns it back on; this is the
	# single line that stops one screen leaking into the next
	portrait.visible = false
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
	body.text = "\n".join([
		"You are the teacher. Arrows/WASD walk, E does the",
		"prompt at the bottom, Tab shows your class.",
		"Start the lesson at the PODIUM, then walk the room.",
		"A student with a ? is STUCK and their work has",
		"stopped - press E at their desk to get them going.",
		"Collect the work, hand it in at YOUR desk, ring the",
		"BELL. After %d days the class sits an exam." % Balance.term_days,
	])
	hint.text = "E - begin"


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
	var rows := ["Resume", "Sound  %s" % _vol_bar(), "Quit to title"]
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
		_pause_sel = (_pause_sel + 1) % 3
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_up"):
		_pause_sel = (_pause_sel + 2) % 3
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		if _pause_sel == 1:
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
		elif _pause_sel == 2:
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
	Sfx.play("grade")
	# Two children to a line, and the verdict in the title. A full class one
	# per line plus a summary is eleven lines in a panel that holds five --
	# so the single most important sentence of the whole run was the one
	# falling off the bottom.
	title.text = "END OF TERM  -  %s" % String(result.get("letter", "F"))
	var rows: Array = result.get("rows", [])
	var lines: Array[String] = []
	var i := 0
	while i < rows.size():
		var cell := _exam_cell(rows[i])
		if i + 1 < rows.size():
			cell += "  " + _exam_cell(rows[i + 1])
		lines.append(cell)
		i += 2
	lines.append(_clip("%d of %d passed.%s" % [
		int(result.get("passed", 0)), int(result.get("total", 0)),
		"   (cheats were used)" if Game.cheated else ""]))
	body.text = "\n".join(lines)
	hint.text = "E - close.   That is the term."


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


## What you have learned to teach, and what is still ahead.
##
## Each row carries the REAL standard code its lesson cites. A concept is a
## component of that standard and shares its code rather than getting a
## made-up one of its own — see the note at the top of data/curriculum.json.
func show_curriculum() -> void:
	_open(Mode.REPORT)

	var known: int = Game.concepts.size()
	# The headline number goes in the TITLE, where nothing can push it off.
	title.text = "CURRICULUM  %d/%d  (+%.0f%%)" % [
		known, Curriculum.concept_count(), Game.concept_bonus() * 100.0]

	# GROUPED BY SUBJECT, not listed by lesson.
	#
	# Ten lesson rows do not fit. The panel holds about six lines whatever
	# font size is asked for -- the game's font is a fixed-size pixel font,
	# so add_theme_font_size_override() on this Label does nothing at all,
	# which is worth knowing before designing another list screen.
	#
	# Four subjects is also the better summary: what you want off this screen
	# is which subject to teach next, not a ten-row audit.
	var got := {}
	var total := {}
	var nearest := {}          # strand -> [lessons still to teach, name]
	for l: Dictionary in Curriculum.lessons:
		var lid := String(l.get("id", ""))
		var strand := String(l.get("strand", ""))
		for c: Dictionary in Curriculum.concepts_of(lid):
			total[strand] = int(total.get(strand, 0)) + 1
			if Game.knows_concept(String(c.get("id", ""))):
				got[strand] = int(got.get(strand, 0)) + 1
			elif not nearest.has(strand):
				nearest[strand] = [
					maxi(1, int(c.get("at", 1)) - Game.times_taught(lid)),
					Curriculum.short_name(l)]

	var lines: Array[String] = []
	for strand: String in Curriculum.strands():
		var tail := "all learned"
		if nearest.has(strand):
			var row: Array = nearest[strand]
			tail = "%s in %d" % [String(row[1]), int(row[0])]
		lines.append("%-11s %d/%-3d %s" % [
			Curriculum.strand_label(strand),
			int(got.get(strand, 0)), int(total.get(strand, 0)), tail])

	if known == 0:
		lines.append("")
		lines.append("Teach a lesson and you start to learn it too.")
	body.text = "
".join(lines)
	hint.text = "E - close"


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


func show_day_report(report: Dictionary) -> void:
	Sfx.play("grade")
	_open(Mode.REPORT)
	# Eleven lines in a five-line panel, once a day had both an arrival and
	# an event. The average and the days left move to the TITLE -- they are
	# the two numbers you actually look for -- and each remaining line does
	# a whole job instead of a third of one.
	title.text = "DAY %d  -  %s  -  %d LEFT" % [
		int(report.get("day", 0)),
		Game.grade_letter(float(report.get("average", 0.0))),
		int(report.get("days_left", 0))]
	var lines: Array[String] = [
		_clip("Earned %d coins, less %d upkeep." % [
			int(report.get("coins", 0)), int(report.get("upkeep", 0))]),
		_clip("Homework: %d of %d came back." % [
			int(report.get("homework_done", 0)), Game.roster.size()]),
	]
	if String(report.get("joined", "")) != "":
		lines.append(_clip("%s has joined the class." % String(report["joined"])))
	if String(report.get("event", "")) != "":
		lines.append(_clip("Tomorrow: %s" % String(report["event"])))
		lines.append(_clip(String(report.get("event_blurb", ""))))
	body.text = "\n".join(lines)
	hint.text = "E — close"


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
		return Progress.perk_order()
	if _shop == Shop.ROOM:
		return ROOM_ROWS.duplicate()
	return Game.room_items.duplicate()


func _render_catalogue() -> void:
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
			# initials for the tabs you are NOT on; the full word only for
			# the one you are, which is the only one you need to read
			var label := Items.category_label(String(cats[i]))
			tabs += ("[%s]" % label) if i == _cat else (" %s " % label.substr(0, 3))
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
			lines.append(_clip("%s %-13s %4d  %-16s%s" % [
				">" if i == _sel else " ", String(d["name"]), int(d["cost"]),
				_reach_words(int(d["range"]), float(d["bonus"])),
				"" if Game.can_afford(int(d["cost"])) else "  too dear"]))
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
	body.text = "\n".join(lines)
	var verb := "order"
	var next_tab := "sell list"
	if _shop == Shop.BUY:
		hint.text = _clip(_shop_blurb) if _shop_blurb != "" 			else "Up/Down pick   Left/Right category   E order   Esc close"
		body.text = "
".join(lines)
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
		var label := "One column wider" if axis == "wide" else "One row longer"
		var tail := ""
		if not Game.can_expand(axis):
			tail = "at its limit"
		else:
			tail = "%d coins" % Game.expand_cost(axis)
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
	var lines: Array[String] = []
	lines.append("Level %d    %d point%s to spend" % [
		Game.teacher_level, Game.perk_points_free(),
		"" if Game.perk_points_free() == 1 else "s"])
	lines.append("")
	var order := Progress.perk_order()
	for i in order.size():
		var id: String = order[i]
		var d := Progress.perk_def(id)
		var have := Game.perk_rank(id)
		var cap := Progress.max_rank(id)
		lines.append("%s %-17s %s" % [
			">" if i == _sel else " ", String(d.get("name", id)),
			"#".repeat(have) + ".".repeat(cap - have)])
	lines.append("")
	if not order.is_empty():
		lines.append(String(Progress.perk_def(order[_sel]).get("blurb", "")))
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
	if mode == Mode.REPORT or mode == Mode.TITLE:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("confirm")
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
				var e := Game.expand_room(String(rows[_sel]))
				Sfx.play("deny" if e != "" else "coins")
				_render_catalogue()
			elif _shop == Shop.STAFF:
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
