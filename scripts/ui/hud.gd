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

enum Mode { NONE, REPORT, CATALOGUE, MARKING }
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


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("carrier")
	_update_status()
	_update_prompt()


func _physics_process(_delta: float) -> void:
	if mode != Mode.NONE:
		_handle_input()


func _update_status() -> void:
	var line := "Day %d  %s    %d coins" % [Game.day, Game.subject, Game.coins]
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
	var showing := target != null and target.can_interact()
	prompt.visible = showing
	prompt_box.visible = showing
	if showing:
		prompt.text = "E  —  %s" % target.prompt_text()


# ---------------------------------------------------------------- overlays

func _open(m: int) -> void:
	mode = m
	overlay.visible = true
	if _player != null and is_instance_valid(_player):
		_player.input_locked = true


func close() -> void:
	mode = Mode.NONE
	overlay.visible = false
	if _player != null and is_instance_valid(_player):
		_player.input_locked = false


func show_lesson_report(results: Array) -> void:
	_open(Mode.REPORT)
	title.text = "END OF LESSON - %s" % Game.subject.to_upper()
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
	body.text = "\n".join([
		"Class average    %s" % Game.grade_letter(float(report.get("average", 0.0))),
		"Coins earned     %d" % int(report.get("coins", 0)),
		"Homework done    %d of %d" % [int(report.get("homework_done", 0)), Game.roster.size()],
		"",
		"Tomorrow the class files back in.",
	])
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
	if mode == Mode.REPORT:
		if Input.is_action_just_pressed("cancel") or Game.claim_interact():
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
