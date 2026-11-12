extends Node2D

## The start page.
##
## A real scene rather than an overlay on top of the game, so it can be the
## project's main scene and the classroom is not built until you actually
## choose to play. That also means "New game" is a clean scene load rather
## than an in-place reset of a running world.

enum Page { MAIN, SETTINGS, CONTROLS, HOWTO, CREDITS, CONFIRM_WIPE, SLOTS, SLOT_ACTIONS, CONFIRM_SLOT_DELETE }

const GAME_SCENE := "res://scenes/main.tscn"
const DUST_COUNT := 26

@onready var menu: Label = $UI/Menu
@onready var heading: Label = $UI/Heading
@onready var footer: Label = $UI/Footer
@onready var logo: Sprite2D = $Logo
@onready var walker: Sprite2D = $Walker

var page: int = Page.MAIN
var sel: int = 0
var sel_slot: int = 0           ## chosen slot (0-7) when viewing slot actions
var rebinding: String = ""      ## action awaiting a key press, "" if none
var message: String = ""

var _dust: Array[Sprite2D] = []
var _dust_vel: Array[Vector2] = []
var _t: float = 0.0
var _walk_x: float = -20.0
var _walk_frame: int = 0
var _walk_timer: float = 0.0


func _ready() -> void:
	Balance.ensure_loaded()
	_make_dust()
	_render()
	Music.play("music_title")


func _make_dust() -> void:
	var tex: Texture2D = load("res://art/dust.png")
	for i in DUST_COUNT:
		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(randf_range(16, 624), randf_range(20, 320))   # doubled Aug 2026
		s.modulate.a = randf_range(0.15, 0.6)
		add_child(s)
		_dust.append(s)
		_dust_vel.append(Vector2(randf_range(-7, 7), randf_range(-11, -3)))


func _process(delta: float) -> void:
	_t += delta

	# chalk dust drifting up off the board
	for i in _dust.size():
		var s := _dust[i]
		s.position += _dust_vel[i] * delta
		s.position.x += sin(_t * 0.7 + float(i)) * 12.0 * delta
		if s.position.y < 16.0:
			s.position = Vector2(randf_range(16, 624), 324.0)   # doubled Aug 2026
			s.modulate.a = randf_range(0.15, 0.6)

	# the logo breathes, very slightly
	logo.position.y = 60.0 + sin(_t * 1.3) * 3.0   # doubled Aug 2026

	# a student wanders across the chalk tray, because an empty title screen
	# with no living thing on it reads as a menu, not a game
	_walk_x += 44.0 * delta   # doubled Aug 2026
	if _walk_x > 680.0:
		_walk_x = -40.0
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
	if event is InputEventMouse:
		_mouse(event as InputEventMouse)
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
		_back()
		return
	else:
		return
	_render()


## Esc, or a right click: one page up. The main page has nowhere to go.
func _back() -> void:
	if page == Page.MAIN:
		return
	Sfx.play("blip")
	if page == Page.SLOT_ACTIONS or page == Page.CONFIRM_SLOT_DELETE:
		_go(Page.SLOTS)
	else:
		_go(Page.MAIN)


# ----------------------------------------------------------------- mouse
# The menu is one Label, so a click is mapped to a row by its line. The
# mouse drives exactly the rows the keys do: hovering a row selects it, a
# left click is E on it, the wheel is up/down, a right click is Esc. On a
# page of prose (How to play, Credits) a left click goes back.

const _SLIDERS := ["master", "sfx", "music", "scale"]

var _hit_line0: int = 0   ## the Label line the first clickable row is on
var _hit_row0: int = 0    ## which row that first clickable line shows
var _hit_n: int = 0       ## how many rows are clickable (0 = none)


func _mouse(event: InputEventMouse) -> void:
	var local := menu.make_input_local(event) as InputEventMouse
	var row := _row_at(local.position)
	if event is InputEventMouseMotion:
		if row >= 0 and row != sel and _hover_keeps_window(row):
			sel = row
			Sfx.play("blip")
			_render()
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var rows := _rows()
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			if rows.is_empty():
				return
			sel = (sel + 1) % rows.size()
			Sfx.play("blip")
		MOUSE_BUTTON_WHEEL_UP:
			if rows.is_empty():
				return
			sel = (sel - 1 + rows.size()) % rows.size()
			Sfx.play("blip")
		MOUSE_BUTTON_RIGHT:
			_back()
			return
		MOUSE_BUTTON_LEFT:
			if _hit_n == 0:
				_back()
				return
			if row < 0:
				return
			sel = row
			if page == Page.SETTINGS and _SLIDERS.has(String(rows[row])):
				# the left half of the value turns it down, the right half up
				_adjust(-1 if local.position.x < _value_mid(row) else 1)
			else:
				_activate()
		_:
			return
	_render()


## The row under a point in the menu Label's own coordinates, or -1.
func _row_at(p: Vector2) -> int:
	if _hit_n <= 0 or p.x < -16.0 or p.x > menu.size.x or p.y < 0.0:
		return -1
	var line_h: float = menu.get_line_height() \
		+ menu.get_theme_constant("line_spacing")
	if line_h <= 0.0:
		return -1
	var k := int(p.y / line_h) - _hit_line0
	if k < 0 or k >= _hit_n:
		return -1
	return _hit_row0 + k


## The x where a settings row's value is split into "down" and "up".
func _value_mid(row: int) -> float:
	var lines := menu.text.split("\n")
	var li := _hit_line0 + row - _hit_row0
	if li < 0 or li >= lines.size():
		return menu.size.x / 2.0
	var line := lines[li]
	var font := menu.get_theme_font("font")
	var fs := menu.get_theme_font_size("font_size")
	# "%s %-15s %s": the value starts after the marker, the name and a space
	var name_w := font.get_string_size(line.substr(0, 18), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var all_w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return (name_w + all_w) / 2.0


## The controls list is a window that follows the selection; hovering a row
## that would slide the window would put a different row under the pointer,
## so hover only moves within the window (a click or the wheel still does).
func _hover_keeps_window(row: int) -> bool:
	if page != Page.CONTROLS:
		return true
	return _controls_lo(row) == _controls_lo(sel)


const _CONTROLS_SHOWN := 10

func _controls_lo(at: int) -> int:
	var n := _rows().size()
	if n <= _CONTROLS_SHOWN:
		return 0
	return clampi(at - _CONTROLS_SHOWN / 2, 0, n - _CONTROLS_SHOWN)


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


func _go(p: int) -> void:
	page = p
	sel = 0
	message = ""
	_render()


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


## A 10-step bar, because a number from 0 to 1 means nothing at a glance.
func _bar(v: float) -> String:
	var filled := int(round(v * 10.0))
	return "[%s%s] %3d%%" % ["#".repeat(filled), ".".repeat(10 - filled), int(round(v * 100.0))]


# --------------------------------------------------------------- drawing

func _render() -> void:
	var rows := _rows()
	var lines: Array[String] = []
	# where the clickable rows sit in the Label: by default line i is row i
	_hit_line0 = 0
	_hit_row0 = 0
	_hit_n = rows.size()

	match page:
		Page.MAIN:
			heading.text = ""
			logo.visible = true
			menu.offset_top = 100.0   # adjusted to fit rows comfortably
			for i in rows.size():
				var id := String(rows[i])
				var names_main := {
					"continue": "Continue", "slots": "Save slots", "new": "New term", "howto": "How to play",
					"settings": "Settings", "controls": "Controls",
					"credits": "Credits", "wipe": "Erase save", "quit": "Quit",
				}
				var text: String = String(names_main.get(id, id))
				if id == "continue":
					text += "   (day %d)" % Game.saved_day()
				lines.append("%s %s" % [">" if i == sel else " ", text])
			footer.text = message if message != "" else "Arrows to choose, E to pick"

		Page.SLOTS:
			heading.text = "SAVE SLOTS"
			logo.visible = false
			menu.offset_top = 58.0
			for i in rows.size():
				var row_id := String(rows[i])
				if row_id == "back":
					lines.append("%s Back" % [">" if i == sel else " "])
				else:
					var slot_idx := int(row_id.trim_prefix("slot_"))
					var label := ""
					if Game.has_slot(slot_idx):
						var info := Game.slot_info(slot_idx)
						label = "Slot %d: Day %d  (Term %d, %s, %d coins)" % [
							slot_idx + 1,
							info.get("day", 1),
							info.get("term", 1),
							String(info.get("subject", "general")).capitalize(),
							info.get("coins", 0)
						]
					else:
						label = "Slot %d: [Empty]" % [slot_idx + 1]
					lines.append("%s %s" % [">" if i == sel else " ", label])
			footer.text = message if message != "" else "Arrows to choose, E to select, Esc to go back"

		Page.SLOT_ACTIONS:
			heading.text = "SLOT %d" % [sel_slot + 1]
			logo.visible = false
			menu.offset_top = 80.0
			var action_names := {
				"load": "Load this slot",
				"new": "Start new game in this slot",
				"save_current": "Copy autosave to this slot",
				"delete": "Erase this slot",
				"back": "Back to slots",
			}
			for i in rows.size():
				var aid := String(rows[i])
				lines.append("%s %s" % [">" if i == sel else " ", action_names.get(aid, aid)])
			footer.text = "E to pick, Esc to go back"

		Page.CONFIRM_SLOT_DELETE:
			heading.text = "ERASE SLOT %d?" % [sel_slot + 1]
			logo.visible = false
			menu.offset_top = 80.0
			lines = ["This cannot be undone.", ""]
			_hit_line0 = lines.size()
			for i in rows.size():
				lines.append("%s %s" % [
					">" if i == sel else " ",
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it"])
			footer.text = ""

		Page.SETTINGS:
			heading.text = "SETTINGS"
			logo.visible = false
			menu.offset_top = 80.0   # doubled Aug 2026
			var vals := {
				"master": _bar(Settings.master_volume),
				"sfx": _bar(Settings.sfx_volume),
				"music": _bar(Settings.music_volume),
				"scale": "x%d" % Settings.window_scale,
				"fullscreen": "on" if Settings.fullscreen else "off",
				"hints": "on" if Settings.show_hints else "off",
				"back": "",
			}
			var names := {
				"master": "Master volume", "sfx": "Sound effects",
				"music": "Music",
				"scale": "Window size", "fullscreen": "Fullscreen",
				"hints": "Show hints", "back": "Back",
			}
			for i in rows.size():
				var id := String(rows[i])
				lines.append("%s %-15s %s" % [
					">" if i == sel else " ", String(names[id]), String(vals[id])])
			footer.text = "Left/Right to change, Esc to go back"

		Page.CONTROLS:
			heading.text = "CONTROLS"
			logo.visible = false
			menu.offset_top = 64.0   # doubled Aug 2026
			# Windowed, the same way Career/Office page past a list longer
			# than the panel -- confirmed necessary by screenshot, not
			# assumed: this Label does not scroll, and three more actions
			# (quiz, homework, move_desk, added when the whole key scheme
			# changed) pushed the flat list into the footer's own row.
			var shown_rows := _CONTROLS_SHOWN
			var lo := _controls_lo(sel)
			_hit_row0 = lo
			_hit_n = mini(rows.size(), lo + shown_rows) - lo
			for i in range(lo, mini(rows.size(), lo + shown_rows)):
				var id := String(rows[i])
				if id == "back" or id == "reset":
					lines.append("%s %s" % [
						">" if i == sel else " ",
						"Back" if id == "back" else "Reset to defaults"])
				else:
					var shown := "press a key..." if rebinding == id \
						else Settings.binding_text(id)
					lines.append("%s %-13s %s" % [
						">" if i == sel else " ", _label_for(id), shown])
			var prompt := message if message != "" else "E to rebind, Esc to go back"
			if rows.size() > shown_rows:
				footer.text = "%s  (%d-%d of %d)" % [
					prompt, lo + 1, mini(rows.size(), lo + shown_rows), rows.size()]
			else:
				footer.text = prompt

		Page.HOWTO:
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "HOW TO PLAY"
			logo.visible = false
			_hit_n = 0
			lines = [
				"Start the lesson at the PODIUM.",
				"A ? means that student is STUCK and their",
				"work has stopped. Walk over, press %s." % Settings.binding_text("interact"),
				"Collect finished work, hand it in at YOUR",
				"desk. The INTERCOM, top left, ends the day.",
				"Buy furniture at the CORKBOARD - it only",
				"helps the desks in range, shown in green.",
				"A term is %d days, then they sit an exam." % Balance.term_days,
			]
			footer.text = "Esc to go back"

		Page.CREDITS:
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "CREDITS"
			logo.visible = false
			_hit_n = 0
			lines = [
				"A small game about paying attention.",
				"",
				"Pixel art by LimeZu (limezu.itch.io):",
				"Modern Interiors, Modern Office, Modern UI",
				"The rest is drawn by tools/make_art.py",
				"Every sound is synthesised by make_audio.py",
				"Text in Galmuri by Lee Minseo (SIL OFL)",
				"Furniture: 0_mem0ry. Flags, weather: Pixel-boy",
				"",
				"Built with Godot 4.",
			]
			footer.text = "Esc to go back"

		Page.CONFIRM_WIPE:
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "ERASE SAVE?"
			logo.visible = false
			lines = ["This cannot be undone.", "Your whole career goes with it.", ""]
			_hit_line0 = lines.size()
			for i in rows.size():
				lines.append("%s %s" % [
					">" if i == sel else " ",
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it"])
			footer.text = ""

	menu.text = "\n".join(lines)
