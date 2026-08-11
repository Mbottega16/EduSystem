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

enum Mode { NONE, REPORT, CATALOGUE, MARKING, TITLE, CLASS_LIST, PAUSE }
enum Shop { BUY, SELL }

signal item_chosen(id: String)

@onready var status: Label = $Status
@onready var prompt: Label = $Prompt
@onready var prompt_box: ColorRect = $PromptBox
@onready var overlay: ColorRect = $Overlay
@onready var title: Label = $Overlay/Title
@onready var body: Label = $Overlay/Body
@onready var hint: Label = $Overlay/Hint

var mode: int = Mode.NONE
var _player: Node = null
var _sel: int = 0
var _shop: int = Shop.BUY

# marking state
var _marking: Array = []       ## StudentData still to be judged
var _marked_right: int = 0
var _shown_hints := {}


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("carrier")
	if mode == Mode.NONE and Input.is_action_just_pressed("menu"):
		show_class_list()
	elif mode == Mode.NONE and Input.is_action_just_pressed("pause"):
		show_pause()
	elif mode == Mode.PAUSE:
		_pause_input()
	_update_status()
	_update_prompt()


func _physics_process(_delta: float) -> void:
	if mode != Mode.NONE:
		_handle_input()


func _update_status() -> void:
	var left: int = maxi(0, Balance.term_days - Game.day + 1)
	var line := "Day %d/%d  %s    %d coins" % [
		Game.day, Balance.term_days, Curriculum.short_name(Game.lesson), Game.coins]
	if Game.phase == Game.Phase.LESSON:
		var room := get_tree().get_first_node_in_group("classroom")
		if room != null:
			line += "    %ds left" % int(ceil(room.lesson_left))
	elif left <= 3:
		line += "    LAST %d DAYS" % left
	if _player != null and is_instance_valid(_player):
		if _player.carrying > 0:
			line += "    carrying %d" % _player.carrying
		if _player.carrying_hw > 0:
			line += "    %d homework" % _player.carrying_hw
	var stuck := 0
	var waiting := 0
	for s: StudentData in Game.roster:
		if s.is_struggling():
			stuck += 1
		if s.has_work_to_collect():
			waiting += 1
	# via a group, not current_scene -- current_scene is not Main when the
	# game is instantiated inside a test or a screenshot harness
	var place := get_tree().get_first_node_in_group("placement")
	if place != null and place.active:
		line += "    this spot helps %d" % place.reach_count()
	if stuck > 0:
		line += "    %d stuck" % stuck
	if waiting > 0:
		line += "    %d ready" % waiting
	status.text = line


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
func show_class_list() -> void:
	_open(Mode.CLASS_LIST)
	title.text = "YOUR CLASS"
	# eight students plus a three-line lesson header does not fit at the
	# default size; the panel is 128px and this needs about 13 rows
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_constant_override("line_spacing", 0)
	var lines: Array[String] = []
	# The objective is the source document's own wording, so a player can
	# see what the lesson is genuinely for rather than just a subject word.
	lines.append("Today: %s  [%s]" % [
		String(Game.lesson.get("name", "")), String(Game.lesson.get("standard", ""))])
	lines.append(_wrap(String(Game.lesson.get("objective", "")), 60, 2))
	lines.append("%-11s %-9s %-6s %s" % ["name", "best at", "avg", "notes"])
	for s: StudentData in Game.roster:
		var notes: Array[String] = []
		if s.aptitude >= 0.65:
			notes.append("quick")
		elif s.aptitude <= 0.4:
			notes.append("needs time")
		if s.diligence >= 0.65:
			notes.append("reliable")
		elif s.diligence <= 0.4:
			notes.append("forgets hw")
		if s.misjudged:
			notes.append("secretly behind")
		lines.append("%-11s %-9s %-6s %s" % [
			s.display_name.split(" ")[0], Curriculum.strand_label(s.favourite),
			"-" if s.grades.is_empty() else Game.grade_letter(s.average_grade()),
			", ".join(notes)])
	body.text = "\n".join(lines)
	hint.text = "E or Esc - close"


## End of term. The whole run, scored.
func show_exam(result: Dictionary) -> void:
	_open(Mode.REPORT)
	Sfx.play("grade")
	title.text = "END OF TERM EXAM"
	var lines: Array[String] = []
	for r: Dictionary in result.get("rows", []):
		var s: StudentData = r["student"]
		lines.append("  %-12s %s    %s" % [
			s.display_name.split(" ")[0], String(r["letter"]),
			"passed" if bool(r["passed"]) else "did not pass"])
	lines.append("")
	lines.append("  %d of %d passed.   Class grade: %s" % [
		int(result.get("passed", 0)), int(result.get("total", 0)),
		String(result.get("letter", "F"))])
	body.text = "\n".join(lines)
	hint.text = "E - close.   That is the term."


func show_lesson_report(results: Array) -> void:
	_open(Mode.REPORT)
	title.text = "%s  (%s)" % [
		String(Game.lesson.get("name", Game.subject)).to_upper(),
		String(Game.lesson.get("standard", ""))]
	# Plain English, not the raw floats this used to print. A player should
	# be able to see WHY a grade happened and what to do differently.
	var lines: Array[String] = []
	for r: Dictionary in results:
		var s: StudentData = r["student"]
		lines.append("%-11s %s   %s" % [
			s.display_name.split(" ")[0], String(r["letter"]), _why(s)])
	lines.append("")
	lines.append("Class average: %s" % Game.grade_letter(Game.class_average()))
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
	title.text = "DAY %d DONE" % int(report.get("day", 0))
	var lines: Array[String] = [
		"Class average    %s" % Game.grade_letter(float(report.get("average", 0.0))),
		"Coins earned     %d" % int(report.get("coins", 0)),
		"Upkeep           -%d" % int(report.get("upkeep", 0)),
		"Homework done    %d of %d" % [int(report.get("homework_done", 0)), Game.roster.size()],
	]
	if String(report.get("joined", "")) != "":
		lines.append("")
		lines.append("%s has joined the class." % String(report["joined"]))
	lines.append("")
	if String(report.get("event", "")) != "":
		lines.append("Tomorrow: %s" % String(report["event"]))
		lines.append("  %s" % String(report.get("event_blurb", "")))
	lines.append("")
	lines.append("%d days left in the term." % int(report.get("days_left", 0)))
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
		return Items.order().duplicate()
	return Game.room_items.duplicate()


func _render_catalogue() -> void:
	var rows := _shop_rows()
	_sel = 0 if rows.is_empty() else clampi(_sel, 0, rows.size() - 1)

	title.text = "%s  -  %d coins" % [
		"BUY FURNITURE" if _shop == Shop.BUY else "SELL FURNITURE", Game.coins]

	var lines: Array[String] = []
	if rows.is_empty():
		lines.append("   Nothing to sell - the room is bare.")
	elif _shop == Shop.BUY:
		for i in rows.size():
			var id: String = rows[i]
			var d := Items.get_def(id)
			lines.append("%s %-13s %4d   +%.2f within %d%s" % [
				">" if i == _sel else " ", String(d["name"]), int(d["cost"]),
				float(d["bonus"]), int(d["range"]),
				"" if Game.can_afford(int(d["cost"])) else "   too dear"])
		lines.append("")
		lines.append(String(Items.get_def(rows[_sel]).get("blurb", "")))
		lines.append("Place it well and the green desks are the ones it helps.")
	else:
		for i in rows.size():
			var placed: Dictionary = rows[i]
			var pid := String(placed["id"])
			lines.append("%s %-13s  back %3d   at %d,%d" % [
				">" if i == _sel else " ",
				String(Items.get_def(pid).get("name", pid)),
				Game.sell_value(pid), placed["tile"].x, placed["tile"].y])
		lines.append("")
		lines.append("Selling gives back half.")
		lines.append("To MOVE something, walk up to it instead.")
	body.text = "\n".join(lines)
	hint.text = "Up/Down choose   E %s   Tab %s   Esc close" % [
		"order" if _shop == Shop.BUY else "sell",
		"sell list" if _shop == Shop.BUY else "buy list"]


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
	if mode == Mode.REPORT or mode == Mode.TITLE or mode == Mode.CLASS_LIST:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
			Sfx.play("confirm")
			close()
		return

	if mode == Mode.CATALOGUE:
		var rows := _shop_rows()
		if Input.is_action_just_pressed("cancel"):
			close()
		elif Input.is_action_just_pressed("menu"):
			_shop = Shop.SELL if _shop == Shop.BUY else Shop.BUY
			_sel = 0
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
			if _shop == Shop.BUY:
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
