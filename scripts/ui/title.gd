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

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MaterialBox := preload("res://scripts/ui/material_box.gd")

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

var _frame_panel: Panel = null
var _chalk_title: Label = null
var _amber_cursor: Label = null
var _chalk_mat: ShaderMaterial = null
var _chalk_menu_mat: ShaderMaterial = null
var _font_chalk_bold: FontFile = null
var _font_chalk_reg: FontFile = null
var _font_hand: FontFile = null

var _dust: Array[Sprite2D] = []
var _dust_vel: Array[Vector2] = []
var _t: float = 0.0
var _walk_x: float = -20.0
var _walk_frame: int = 0
var _walk_timer: float = 0.0


func _ready() -> void:
	Balance.ensure_loaded()
	_setup_chalk_theme()
	_make_dust()
	_render()
	Music.play("music_title")


func _setup_chalk_theme() -> void:
	_font_chalk_bold = UITheme.load_font("res://fonts/Kalam-Bold.ttf")
	_font_chalk_reg = UITheme.load_font("res://fonts/Kalam-Regular.ttf")
	_font_hand = UITheme.load_font("res://fonts/PatrickHand-Regular.ttf")

	_chalk_mat = UITheme.make_chalk_material(0.08, 0.22)
	_chalk_menu_mat = UITheme.make_chalk_material(0.05, 0.18)

	# Wood frame around the chalkboard
	if _frame_panel == null:
		_frame_panel = Panel.new()
		_frame_panel.size = Vector2(640, 352)
		_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame_panel.add_theme_stylebox_override("panel", UITheme.make_chalkboard_box(8, 0.35))
		add_child(_frame_panel)
		move_child(_frame_panel, 1)

	# Chalk Title: "EDUSystem"
	if _chalk_title == null:
		_chalk_title = Label.new()
		_chalk_title.size = Vector2(640, 52)
		_chalk_title.position = Vector2(0, 6)
		_chalk_title.text = "EDUSystem"
		_chalk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chalk_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chalk_title.add_theme_font_override("font", _font_chalk_bold)
		_chalk_title.add_theme_font_size_override("font_size", 44)
		_chalk_title.add_theme_color_override("font_color", UITheme.CHALK)
		_chalk_title.material = _chalk_mat
		$UI.add_child(_chalk_title)

	# Chalk Cursor in Accent Amber
	if _amber_cursor == null:
		_amber_cursor = Label.new()
		_amber_cursor.size = Vector2(18, 20)
		_amber_cursor.text = ">"
		_amber_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_amber_cursor.add_theme_font_override("font", _font_chalk_bold)
		_amber_cursor.add_theme_font_size_override("font_size", 16)
		_amber_cursor.add_theme_color_override("font_color", UITheme.AMBER)
		_amber_cursor.material = UITheme.make_chalk_material(0.04, 0.1)
		$UI.add_child(_amber_cursor)

	heading.add_theme_font_override("font", _font_chalk_bold)
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", UITheme.CHALK)
	heading.material = _chalk_mat

	menu.add_theme_font_override("font", _font_chalk_reg)
	menu.add_theme_font_size_override("font_size", 16)
	menu.add_theme_constant_override("line_spacing", 0)
	menu.add_theme_color_override("font_color", UITheme.CHALK)
	menu.material = _chalk_menu_mat

	footer.add_theme_font_override("font", _font_hand)
	footer.add_theme_font_size_override("font_size", 16)
	footer.add_theme_color_override("font_color", Color(UITheme.CHALK.r, UITheme.CHALK.g, UITheme.CHALK.b, 0.75))


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

	# the chalk title breathes gently on the board
	if _chalk_title != null and _chalk_title.visible:
		_chalk_title.position.y = 14.0 + sin(_t * 1.3) * 2.0
	logo.visible = false

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


func _go(p: int) -> void:
	page = p
	sel = 0
	message = ""
	_render()
	_animate_transition()


func _animate_transition() -> void:
	if not is_inside_tree():
		return
	menu.modulate.a = 0.0
	var orig_y := menu.offset_top
	menu.offset_top = orig_y + 4.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(menu, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu, "offset_top", orig_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if heading.visible and heading.text != "":
		heading.modulate.a = 0.0
		var h_tw := create_tween()
		h_tw.tween_property(heading, "modulate:a", 1.0, 0.12)


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

	match page:
		Page.MAIN:
			heading.text = ""
			if _chalk_title != null:
				_chalk_title.visible = true
			logo.visible = false
			menu.offset_left = 220.0
			menu.offset_top = 58.0   # adjusted for chalk lettered layout
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
			footer.offset_top = 312.0
			footer.offset_bottom = 336.0
			footer.text = message if message != "" else "Arrows to choose, E to pick"

		Page.SLOTS:
			if _chalk_title != null:
				_chalk_title.visible = false
			heading.text = "SAVE SLOTS"
			logo.visible = false
			menu.offset_left = 60.0
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
			if _chalk_title != null:
				_chalk_title.visible = false
			heading.text = "SLOT %d" % [sel_slot + 1]
			logo.visible = false
			menu.offset_left = 180.0
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
			if _chalk_title != null:
				_chalk_title.visible = false
			heading.text = "ERASE SLOT %d?" % [sel_slot + 1]
			logo.visible = false
			menu.offset_left = 180.0
			menu.offset_top = 80.0
			lines = ["This cannot be undone.", ""]
			for i in rows.size():
				lines.append("%s %s" % [
					">" if i == sel else " ",
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it"])
			footer.text = ""

		Page.SETTINGS:
			if _chalk_title != null:
				_chalk_title.visible = false
			heading.text = "SETTINGS"
			logo.visible = false
			menu.offset_left = 140.0
			menu.offset_top = 70.0
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
			if _chalk_title != null:
				_chalk_title.visible = false
			heading.text = "CONTROLS"
			logo.visible = false
			menu.offset_left = 120.0
			menu.offset_top = 54.0
			var shown_rows := 8
			var lo := 0
			if rows.size() > shown_rows:
				lo = clampi(sel - shown_rows / 2, 0, rows.size() - shown_rows)
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
			if _chalk_title != null:
				_chalk_title.visible = false
			menu.offset_left = 60.0
			menu.offset_top = 68.0
			heading.text = "HOW TO PLAY"
			logo.visible = false
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
			if _chalk_title != null:
				_chalk_title.visible = false
			menu.offset_left = 100.0
			menu.offset_top = 64.0
			heading.text = "CREDITS"
			logo.visible = false
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
			if _chalk_title != null:
				_chalk_title.visible = false
			menu.offset_left = 160.0
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "ERASE SAVE?"
			logo.visible = false
			lines = ["This cannot be undone.", "Your whole career goes with it.", ""]
			for i in rows.size():
				lines.append("%s %s" % [
					">" if i == sel else " ",
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it"])
			footer.text = ""

	menu.text = "\n".join(lines)
	if _amber_cursor != null:
		if not rows.is_empty() and sel >= 0 and sel < rows.size():
			_amber_cursor.visible = true
			var line_h := 25.0
			_amber_cursor.position = Vector2(menu.offset_left, menu.offset_top + sel * line_h - 1.0)
		else:
			_amber_cursor.visible = false
