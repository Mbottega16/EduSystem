extends Node2D

## The start page.
##
## A real scene rather than an overlay on top of the game, so it can be the
## project's main scene and the classroom is not built until you actually
## choose to play. That also means "New game" is a clean scene load rather
## than an in-place reset of a running world.
##
## IT IS THE CLASSROOM'S CHALKBOARD (UI overhaul, Nov 2026, the owner's ask:
## "the white text should look like actual words written on the chalkboard").
## The board is the theme's chalkboard material in its wood frame; the title,
## the headings and every row are hand-lettered in chalk (Kalam, through the
## chalk shader). Nothing here names a colour, a font or a size: each label
## wears a variation of res://theme.tres, and UITheme hands out the rest.
##
## Each row is its own label, so a row can sit in two columns (a setting and
## its value, an action and its key) whatever the width of the letters. The
## old screen padded one block of text with spaces, which lines up only in a
## fixed-width font.

enum Page { MAIN, SETTINGS, CONTROLS, HOWTO, CREDITS, CONFIRM_WIPE, SLOTS, SLOT_ACTIONS, CONFIRM_SLOT_DELETE }

const GAME_SCENE := "res://scenes/main.tscn"
const DUST_COUNT := 26

## Every position below is in the game's own 640x352 stage.
const STAGE := Vector2(640, 352)
## Where the first row sits: under the wordmark on the main page, under the
## heading on every other.
const MAIN_TOP := 84.0
const PAGE_TOP := 58.0
## From one row to the next. Nine rows must clear the footer on the main page.
const MAIN_PITCH := 23.0
const ROW_PITCH := 24.0
## From one line of prose to the next (how to play, the credits).
const PROSE_PITCH := 21.0
## Rows of the controls list on the board at once. The list scrolls.
const CONTROLS_SHOWN := 9
## The chalk pointer sits this far left of the row it marks.
const CURSOR_GAP := 22.0
## Seconds per letter while the title is written on.
const WRITE_SECONDS := 0.06
## The wood frame the theme draws round the board: nothing is written on it.
const FRAME := 10.0
## A volume bar: ten chalk ticks.
const BAR_CELLS := 10
const BAR_CELL := Vector2(8, 12)
const BAR_STEP := 12.0

## Where each page's rows sit: the left edge of the names, and of the values
## beside them (0 when the page has one column).
const COLUMNS := {
	Page.MAIN: [238.0, 0.0],
	Page.SETTINGS: [142.0, 348.0],
	Page.CONTROLS: [52.0, 480.0],
	Page.SLOTS: [112.0, 208.0],
	Page.SLOT_ACTIONS: [196.0, 0.0],
	Page.CONFIRM_SLOT_DELETE: [214.0, 0.0],
	Page.CONFIRM_WIPE: [214.0, 0.0],
	Page.HOWTO: [106.0, 0.0],
	Page.CREDITS: [128.0, 0.0],
}

const MAIN_NAMES := {
	"continue": "Continue", "slots": "Save slots", "new": "New term", "howto": "How to play",
	"settings": "Settings", "controls": "Controls",
	"credits": "Credits", "wipe": "Erase save", "quit": "Quit",
}

@onready var board: Panel = $Board/Panel
@onready var tray: Control = $Board/Tray
@onready var root: Control = $UI/Root
@onready var wordmark: Label = $UI/Root/Wordmark
@onready var underline: ColorRect = $UI/Root/Underline
@onready var heading: Label = $UI/Root/Heading
@onready var rows_box: Control = $UI/Root/Rows
@onready var footer: Label = $UI/Root/Footer
@onready var walker: Sprite2D = $Walker

var page: int = Page.MAIN
var sel: int = 0
var sel_slot: int = 0           ## chosen slot (0-7) when viewing slot actions
var rebinding: String = ""      ## action awaiting a key press, "" if none
var message: String = ""

## What is written on the board right now, top to bottom. One Dictionary a
## line: "text", and optionally "value", "aside", "bar", "option" (its index
## in _rows(), -1 for a line that cannot be chosen), "danger", "prose".
var _lines: Array = []
## Seconds since the title began to be written. INF once it is all there.
var _written: float = INF

var _dust: Array[Sprite2D] = []
var _dust_vel: Array[Vector2] = []
var _t: float = 0.0
var _walk_x: float = -20.0
var _walk_frame: int = 0
var _walk_timer: float = 0.0


func _ready() -> void:
	Balance.ensure_loaded()
	wordmark.material = UITheme.chalk(&"title")
	heading.material = UITheme.chalk(&"title")
	underline.material = UITheme.chalk(&"title")
	underline.color = UITheme.color(&"chalk")
	footer.material = UITheme.chalk(&"text")
	_place_stage()
	get_viewport().size_changed.connect(_place_stage)
	_make_dust()
	# The title is written on, a letter at a time, the first time the board
	# is seen. Coming back to the main page from another does not rewrite it.
	if UITheme.motion:
		_written = 0.0
		wordmark.visible_characters = 0
	_render()
	UITheme.step_in(rows_box, Vector2(UITheme.space(&"motion_slide"), 0))
	Music.play("music_title")


## Centre the stage in a window that is not exactly 20:11, and put the chalk
## and the eraser back on the board's bottom rail, wherever that now is.
func _place_stage() -> void:
	position = ((get_viewport_rect().size - STAGE) * 0.5).floor()
	_dress_tray()


## Three sticks of chalk and the eraser, resting on the bottom rail of the
## frame. Drawn from the palette, like everything else on this screen.
func _dress_tray() -> void:
	for c in tray.get_children():
		tray.remove_child(c)
		c.queue_free()
	var view := get_viewport_rect().size
	var rail := view.y - FRAME
	var right := view.x - FRAME
	var pieces := [
		[right - 150.0, rail - 4.0, 14.0, 4.0, &"chalk"],
		[right - 130.0, rail - 4.0, 10.0, 4.0, &"amber"],
		[right - 114.0, rail - 4.0, 12.0, 4.0, &"terracotta"],
		[right - 84.0, rail - 8.0, 26.0, 6.0, &"wood_dark"],
		[right - 84.0, rail - 2.0, 26.0, 2.0, &"pencil"],
	]
	for p: Array in pieces:
		var r := ColorRect.new()
		r.position = Vector2(p[0], p[1])
		r.size = Vector2(p[2], p[3])
		r.color = UITheme.color(p[4])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tray.add_child(r)


func _make_dust() -> void:
	var tex: Texture2D = load("res://art/dust.png")
	for i in DUST_COUNT:
		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(randf_range(16, 624), randf_range(20, 320))   # doubled Aug 2026
		s.modulate = UITheme.faded(&"chalk", randf_range(0.15, 0.6))
		add_child(s)
		_dust.append(s)
		_dust_vel.append(Vector2(randf_range(-7, 7), randf_range(-11, -3)))


func _process(delta: float) -> void:
	_t += delta

	# the title being written on: one more letter every WRITE_SECONDS
	if _written != INF:
		_written += delta
		var shown := int(_written / WRITE_SECONDS)
		if shown >= wordmark.text.length():
			_written = INF
			wordmark.visible_characters = -1
			_rule_under(heading.text)
		else:
			wordmark.visible_characters = shown

	# chalk dust drifting up off the board
	for i in _dust.size():
		var s := _dust[i]
		s.position += _dust_vel[i] * delta
		s.position.x += sin(_t * 0.7 + float(i)) * 12.0 * delta
		if s.position.y < 16.0:
			s.position = Vector2(randf_range(16, 624), 324.0)   # doubled Aug 2026
			s.modulate.a = randf_range(0.15, 0.6)

	# a student wanders across the foot of the board, because an empty title
	# screen with no living thing on it reads as a menu, not a game
	_walk_x += 44.0 * delta   # doubled Aug 2026
	if _walk_x > 680.0 + position.x:
		_walk_x = -40.0 - position.x
	# The walker is a character sheet like any other: a 15-wide one carries the
	# pack's six-frame walk (Actor.WALK_CYCLE_FULL), a 9-wide one the old four.
	var cols := int(walker.texture.get_width() / Actor.CELL_W)
	var full: bool = cols >= Actor.FULL_SHEET_COLS
	if walker.hframes != cols:
		walker.hframes = cols
	_walk_timer += delta
	var step_time: float = Actor.FRAME_TIME_FULL if full else Actor.FRAME_TIME
	if _walk_timer >= step_time:
		_walk_timer = 0.0
		_walk_frame = (_walk_frame + 1) % (Actor.WALK_CYCLE_FULL.size() if full else 4)
	walker.position.x = round(_walk_x)
	var col: int = Actor.WALK_CYCLE_FULL[_walk_frame] if full else _walk_frame
	walker.frame_coords = Vector2i(col, 2)   # facing right


# ----------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if rebinding != "":
		_capture_rebind(event)
		return
	if not event.is_pressed() or event.is_echo():
		return

	var rows := _rows()
	if Input.is_action_just_pressed("move_down") and not rows.is_empty():
		sel = (sel + 1) % rows.size()
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_up") and not rows.is_empty():
		sel = (sel - 1 + rows.size()) % rows.size()
		Sfx.play("blip")
	elif Input.is_action_just_pressed("move_left"):
		_adjust(-1)
	elif Input.is_action_just_pressed("move_right"):
		_adjust(1)
	elif Input.is_action_just_pressed("interact"):
		_activate()
	elif Input.is_action_just_pressed("cancel"):
		if page == Page.MAIN:
			return
		Sfx.play("blip")
		if page == Page.SLOT_ACTIONS or page == Page.CONFIRM_SLOT_DELETE:
			_go(Page.SLOTS)
		else:
			_go(Page.MAIN)
		return
	else:
		return
	_render()


## Swallow the raw key press and turn it into a binding.
func _capture_rebind(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed():
		return
	var key := event as InputEventKey
	var code: int = key.physical_keycode
	if code == 0:
		code = key.keycode
	var err := Settings.rebind(rebinding, code)
	message = err if err != "" else ""
	Sfx.play("deny" if err != "" else "confirm")
	rebinding = ""
	get_viewport().set_input_as_handled()
	_render()


## Turn to another page. The rows arrive with the system's stepped entrance.
func _go(p: int) -> void:
	page = p
	sel = 0
	message = ""
	_render()
	UITheme.step_in(rows_box, Vector2(UITheme.space(&"motion_slide"), 0))


# ------------------------------------------------------------- the pages

func _rows() -> Array:
	match page:
		Page.MAIN:
			var m: Array = []
			if Game.has_save():
				m.append("continue")
			m.append("slots")
			m.append_array(["new", "howto", "settings", "controls", "credits"])
			if Game.has_save():
				m.append("wipe")
			m.append("quit")
			return m
		Page.SLOTS:
			var s: Array = []
			for i in SaveManager.MAX_SLOTS:
				s.append("slot_%d" % i)
			s.append("back")
			return s
		Page.SLOT_ACTIONS:
			var act: Array = []
			if Game.has_slot(sel_slot):
				act.append("load")
			else:
				act.append("new")
			if Game.has_save():
				act.append("save_current")
			if Game.has_slot(sel_slot):
				act.append("delete")
			act.append("back")
			return act
		Page.CONFIRM_SLOT_DELETE:
			return ["no", "yes"]
		Page.SETTINGS:
			return ["master", "sfx", "music", "scale", "fullscreen", "hints", "back"]
		Page.CONTROLS:
			var c: Array = []
			for entry: Dictionary in Settings.ACTIONS:
				c.append(entry["action"])
			c.append_array(["reset", "back"])
			return c
		Page.CONFIRM_WIPE:
			return ["no", "yes"]
	return ["back"]


func _activate() -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	var id := String(rows[sel])

	if page == Page.MAIN:
		match id:
			"continue", "new":
				if id == "new":
					Game.start_new_run_keep_career()
				Sfx.play("confirm")
				get_tree().change_scene_to_file(GAME_SCENE)
			"slots": _go(Page.SLOTS)
			"howto": _go(Page.HOWTO)
			"settings": _go(Page.SETTINGS)
			"controls": _go(Page.CONTROLS)
			"credits": _go(Page.CREDITS)
			"wipe": _go(Page.CONFIRM_WIPE)
			"quit": get_tree().quit()
		return

	if page == Page.SLOTS:
		if id == "back":
			_go(Page.MAIN)
			return
		sel_slot = int(id.trim_prefix("slot_"))
		_go(Page.SLOT_ACTIONS)
		return

	if page == Page.SLOT_ACTIONS:
		match id:
			"load":
				if Game.load_from_slot(sel_slot):
					Sfx.play("confirm")
					get_tree().change_scene_to_file(GAME_SCENE)
				else:
					message = "Failed to load slot."
					_go(Page.SLOTS)
			"new":
				Game.start_new_run_keep_career()
				Game.save_to_slot(sel_slot)
				Sfx.play("confirm")
				get_tree().change_scene_to_file(GAME_SCENE)
			"save_current":
				if Game.save_to_slot(sel_slot):
					message = "Saved autosave to Slot %d." % [sel_slot + 1]
					Sfx.play("confirm")
				else:
					message = "Failed to save."
					Sfx.play("deny")
				_go(Page.SLOTS)
			"delete":
				_go(Page.CONFIRM_SLOT_DELETE)
			"back":
				_go(Page.SLOTS)
		return

	if page == Page.CONFIRM_SLOT_DELETE:
		if id == "yes":
			Game.delete_slot(sel_slot)
			Sfx.play("confirm")
			message = "Slot %d erased." % [sel_slot + 1]
		_go(Page.SLOTS)
		return

	if page == Page.CONFIRM_WIPE:
		if id == "yes":
			Game.delete_save()
			Game.wipe_everything()
			Sfx.play("confirm")
			message = "Save erased."
		_go(Page.MAIN)
		return

	if page == Page.SETTINGS:
		match id:
			"fullscreen":
				Settings.fullscreen = not Settings.fullscreen
				Settings.apply_window()
			"hints":
				Settings.show_hints = not Settings.show_hints
			"back":
				_go(Page.MAIN)
				return
		Settings.save_settings()
		Sfx.play("confirm")
		return

	if page == Page.CONTROLS:
		if id == "back":
			_go(Page.MAIN)
		elif id == "reset":
			Settings.reset_bindings()
			message = "Controls reset."
			Sfx.play("confirm")
		else:
			rebinding = id
			message = "Press a key for %s..." % _label_for(id)
			Sfx.play("blip")
		return

	_go(Page.MAIN)


## Left/right on a settings row.
func _adjust(dir: int) -> void:
	if page != Page.SETTINGS:
		return
	var id := String(_rows()[sel])
	match id:
		"master":
			Settings.master_volume = clampf(Settings.master_volume + 0.1 * dir, 0.0, 1.0)
			Settings.apply_audio()
			Sfx.play("blip")
		"sfx":
			Settings.sfx_volume = clampf(Settings.sfx_volume + 0.1 * dir, 0.0, 1.0)
			Settings.apply_audio()
			Sfx.play("blip")
		"music":
			Settings.music_volume = clampf(Settings.music_volume + 0.1 * dir, 0.0, 1.0)
			Settings.apply_audio()
			Sfx.play("blip")
		"scale":
			Settings.window_scale = clampi(Settings.window_scale + dir, 1, 6)
			Settings.fullscreen = false
			Settings.apply_window()
		"fullscreen":
			Settings.fullscreen = dir > 0
			Settings.apply_window()
		"hints":
			Settings.show_hints = dir > 0
	Settings.save_settings()


func _label_for(action: String) -> String:
	for entry: Dictionary in Settings.ACTIONS:
		if String(entry["action"]) == action:
			return String(entry["label"])
	return action


# --------------------------------------------------------------- drawing

## One line that can be chosen: row `i` of _rows().
func _option(i: int, text: String, value: String = "") -> Dictionary:
	return {"text": text, "value": value, "option": i}


## One line that is only read.
func _plain(text: String, prose: bool = false) -> Dictionary:
	return {"text": text, "option": -1, "prose": prose}


## Everything written on the board, as plain text, one line a row. What a
## screen reader would say, and what the suite reads.
func page_text() -> String:
	var out: Array[String] = []
	for line: Dictionary in _lines:
		var s := String(line.get("text", ""))
		for key: String in ["aside", "value"]:
			if String(line.get(key, "")) != "":
				s += "  " + String(line[key])
		out.append(s)
	return "\n".join(out)


func _render() -> void:
	var rows := _rows()
	var lines: Array = []
	var top := PAGE_TOP
	var pitch := ROW_PITCH
	var note := ""
	var head := ""

	match page:
		Page.MAIN:
			top = MAIN_TOP
			pitch = MAIN_PITCH
			for i in rows.size():
				var id := String(rows[i])
				var line := _option(i, String(MAIN_NAMES.get(id, id)))
				if id == "continue":
					line["aside"] = "day %d" % Game.saved_day()
				line["danger"] = id == "wipe"
				lines.append(line)
			note = message if message != "" else "Arrows to choose, E to pick"

		Page.SLOTS:
			head = "Save slots"
			for i in rows.size():
				var row_id := String(rows[i])
				if row_id == "back":
					lines.append(_option(i, "Back"))
					continue
				var slot_idx := int(row_id.trim_prefix("slot_"))
				var what := "empty"
				if Game.has_slot(slot_idx):
					var info := Game.slot_info(slot_idx)
					what = "Day %d, term %d, %s, %d coins" % [
						info.get("day", 1),
						info.get("term", 1),
						String(info.get("subject", "general")).capitalize(),
						info.get("coins", 0)
					]
					# A long subject and a large purse run off the board: the
					# subject is the part a save can be told apart without.
					var room: float = STAGE.x - FRAME - float(UITheme.space(&"space_s")) 						- float(COLUMNS[Page.SLOTS][1])
					if UITheme.text_width(what, &"ChalkRow") > room:
						what = "Day %d, term %d, %d coins" % [
							info.get("day", 1), info.get("term", 1), info.get("coins", 0)]
				lines.append(_option(i, "Slot %d" % [slot_idx + 1], what))
			note = message if message != "" else "Arrows to choose, E to select, Esc to go back"

		Page.SLOT_ACTIONS:
			head = "Slot %d" % [sel_slot + 1]
			top = PAGE_TOP + ROW_PITCH
			var action_names := {
				"load": "Load this slot",
				"new": "Start new game in this slot",
				"save_current": "Copy autosave to this slot",
				"delete": "Erase this slot",
				"back": "Back to slots",
			}
			for i in rows.size():
				var aid := String(rows[i])
				var line := _option(i, String(action_names.get(aid, aid)))
				line["danger"] = aid == "delete"
				lines.append(line)
			note = "E to pick, Esc to go back"

		Page.CONFIRM_SLOT_DELETE:
			head = "Erase slot %d?" % [sel_slot + 1]
			top = PAGE_TOP + ROW_PITCH
			lines = [_plain("This cannot be undone."), _plain("")]
			for i in rows.size():
				var line := _option(i,
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it")
				line["danger"] = String(rows[i]) == "yes"
				lines.append(line)

		Page.SETTINGS:
			head = "Settings"
			top = PAGE_TOP + ROW_PITCH
			var names := {
				"master": "Master volume", "sfx": "Sound effects",
				"music": "Music",
				"scale": "Window size", "fullscreen": "Fullscreen",
				"hints": "Show hints", "back": "Back",
			}
			var volumes := {
				"master": Settings.master_volume, "sfx": Settings.sfx_volume,
				"music": Settings.music_volume,
			}
			var vals := {
				"scale": "x%d" % Settings.window_scale,
				"fullscreen": "on" if Settings.fullscreen else "off",
				"hints": "on" if Settings.show_hints else "off",
			}
			for i in rows.size():
				var id := String(rows[i])
				var line := _option(i, String(names[id]), String(vals.get(id, "")))
				if volumes.has(id):
					# a bar of ten chalk ticks, and the figure beside it: a
					# number from 0 to 1 means nothing at a glance
					line["bar"] = float(volumes[id])
					line["value"] = "%d%%" % int(round(float(volumes[id]) * 100.0))
				lines.append(line)
			note = "Left/Right to change, Esc to go back"

		Page.CONTROLS:
			head = "Controls"
			# Windowed, the same way Career/Office page past a list longer
			# than the panel: the list is longer than the board is tall.
			var lo := 0
			if rows.size() > CONTROLS_SHOWN:
				lo = clampi(sel - CONTROLS_SHOWN / 2, 0, rows.size() - CONTROLS_SHOWN)
			for i in range(lo, mini(rows.size(), lo + CONTROLS_SHOWN)):
				var id := String(rows[i])
				if id == "back" or id == "reset":
					lines.append(_option(i, "Back" if id == "back" else "Reset to defaults"))
				else:
					var line := _option(i, _label_for(id), Settings.binding_text(id))
					if rebinding == id:
						line["value"] = "press a key..."
						line["waiting"] = true
					lines.append(line)
			var prompt := message if message != "" else "E to rebind, Esc to go back"
			if rows.size() > CONTROLS_SHOWN:
				note = "%s  (%d-%d of %d)" % [
					prompt, lo + 1, mini(rows.size(), lo + CONTROLS_SHOWN), rows.size()]
			else:
				note = prompt

		Page.HOWTO:
			head = "How to play"
			top = PAGE_TOP + 8.0
			for s: String in [
				"Start the lesson at the PODIUM.",
				"A ? means that student is STUCK and their work",
				"has stopped. Walk over, press %s." % Settings.binding_text("interact"),
				"Collect finished work, hand it in at YOUR desk.",
				"The INTERCOM, top left, ends the day.",
				"Buy furniture at the CORKBOARD. It only helps",
				"the desks in range, shown in green.",
				"A term is %d days, then they sit an exam." % Balance.term_days,
			]:
				lines.append(_plain(s, true))
			note = "Esc to go back"

		Page.CREDITS:
			head = "Credits"
			for s: String in [
				"A small game about paying attention.",
				"",
				"Pixel art by LimeZu (limezu.itch.io):",
				"Modern Interiors, Modern Office, Modern UI",
				"The rest is drawn by tools/make_art.py",
				"Every sound is synthesised by make_audio.py",
				"Furniture: 0_mem0ry. Flags, weather: Pixel-boy",
				"Lettering: Kalam, Patrick Hand, Galmuri by",
				"Lee Minseo, VT323, Press Start 2P (SIL OFL)",
				"",
				"Built with Godot 4.",
			]:
				lines.append(_plain(s, true))
			note = "Esc to go back"

		Page.CONFIRM_WIPE:
			head = "Erase save?"
			top = PAGE_TOP + ROW_PITCH
			lines = [_plain("This cannot be undone."),
				_plain("Your whole career goes with it."), _plain("")]
			for i in rows.size():
				var line := _option(i,
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it")
				line["danger"] = String(rows[i]) == "yes"
				lines.append(line)

	_lines = lines
	wordmark.visible = page == Page.MAIN
	heading.text = head
	heading.visible = head != ""
	_rule_under(head)
	footer.text = note
	_write(lines, top, pitch)


## The chalk rule: under the wordmark on the main page, under the heading on
## every other. Ruled by hand, so it is not quite level.
func _rule_under(head: String) -> void:
	if head == "":
		underline.position = Vector2(214, 78)
		underline.size = Vector2(212, 4)
		underline.visible = _written == INF
	else:
		var w := UITheme.text_width(head, &"ChalkHeading") + float(UITheme.space(&"space_l")) * 2.0
		underline.position = Vector2(roundf((STAGE.x - w) * 0.5), 52)
		underline.size = Vector2(w, 2)
		underline.visible = true
	underline.pivot_offset = underline.size * 0.5
	underline.rotation = -0.012


## Put `lines` on the board: one label a row, a second for its value, the
## chalk pointer beside the chosen one.
func _write(lines: Array, top: float, pitch: float) -> void:
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	var cols: Array = COLUMNS[page]
	var x: float = cols[0]
	var value_x: float = cols[1]
	var row_font := UITheme.font(&"chalk")
	var ascent := row_font.get_ascent(UITheme.size(&"chalk"))
	var y := top
	for line: Dictionary in lines:
		var text := String(line.get("text", ""))
		var prose := bool(line.get("prose", false))
		var chosen: bool = int(line.get("option", -1)) >= 0 and int(line["option"]) == sel
		if text != "":
			var voice := &"ChalkProse" if prose else (&"ChalkRowSelected" if chosen else &"ChalkRow")
			_chalk(voice, text, Vector2(x, y))
			var end_x := x + UITheme.text_width(text, voice)
			if chosen:
				_chalk(&"ChalkRowSelected", ">", Vector2(x - CURSOR_GAP, y))
			if bool(line.get("danger", false)):
				# the one mark a way out that cannot be undone carries: a
				# line of red chalk under it. The words stay white, to be read.
				_stroke(Rect2(x, y + ascent + 3.0, end_x - x, 2.0), &"destructive")
			if String(line.get("aside", "")) != "":
				var drop := ascent - row_font.get_ascent(UITheme.size(&"chalk_small"))
				_chalk(&"ChalkNote", String(line["aside"]),
					Vector2(end_x + float(UITheme.space(&"space_m")), y + roundf(drop)))
			var value := String(line.get("value", ""))
			if line.has("bar"):
				_bar(Vector2(value_x, y + ascent - BAR_CELL.y), float(line["bar"]))
				_chalk(&"ChalkRow", value, Vector2(value_x + BAR_STEP * BAR_CELLS + 8.0, y))
			elif value != "":
				_chalk(&"ChalkRowSelected" if bool(line.get("waiting", false)) else &"ChalkRow",
					value, Vector2(value_x, y))
		y += PROSE_PITCH if prose else pitch


## One piece of chalk writing, on the board at `at`.
func _chalk(voice: StringName, text: String, at: Vector2) -> Label:
	var l := UITheme.label(voice, text, at)
	l.material = UITheme.chalk(&"text")
	rows_box.add_child(l)
	return l


## A stroke of chalk: a rule, or one tick of a bar.
func _stroke(r: Rect2, token: StringName, alpha: float = 1.0) -> void:
	var c := ColorRect.new()
	c.position = r.position.round()
	c.size = r.size.round()
	c.color = UITheme.faded(token, alpha)
	c.material = UITheme.chalk(&"text")
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_box.add_child(c)


## A level from 0 to 1 as ten chalk ticks: the ones reached drawn firmly,
## the rest faint, as if rubbed out.
func _bar(at: Vector2, v: float) -> void:
	var filled := int(round(v * float(BAR_CELLS)))
	for i in BAR_CELLS:
		_stroke(Rect2(at.x + float(i) * BAR_STEP, at.y, BAR_CELL.x, BAR_CELL.y),
			&"chalk", 1.0 if i < filled else 0.25)
