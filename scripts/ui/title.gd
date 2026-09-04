extends Node2D

## The start page.
##
## A real scene rather than an overlay on top of the game, so it can be the
## project's main scene and the classroom is not built until you actually
## choose to play. That also means "New game" is a clean scene load rather
## than an in-place reset of a running world.

enum Page { MAIN, SETTINGS, CONTROLS, HOWTO, CREDITS, CONFIRM_WIPE }

const GAME_SCENE := "res://scenes/main.tscn"
const DUST_COUNT := 26

@onready var menu: Label = $UI/Menu
@onready var heading: Label = $UI/Heading
@onready var footer: Label = $UI/Footer
@onready var logo: Sprite2D = $Logo
@onready var walker: Sprite2D = $Walker

var page: int = Page.MAIN
var sel: int = 0
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
	_walk_timer += delta
	if _walk_timer >= 0.14:
		_walk_timer = 0.0
		_walk_frame = (_walk_frame + 1) % 4
	walker.position.x = round(_walk_x)
	walker.frame_coords = Vector2i(_walk_frame, 2)   # facing right


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


# ------------------------------------------------------------- the pages

func _rows() -> Array:
	match page:
		Page.MAIN:
			var m: Array = []
			if Game.has_save():
				m.append("continue")
			m.append_array(["new", "howto", "settings", "controls", "credits"])
			if Game.has_save():
				m.append("wipe")
			m.append("quit")
			return m
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
					Game.delete_save()
					Game.new_run()
				Sfx.play("confirm")
				get_tree().change_scene_to_file(GAME_SCENE)
			"howto": _go(Page.HOWTO)
			"settings": _go(Page.SETTINGS)
			"controls": _go(Page.CONTROLS)
			"credits": _go(Page.CREDITS)
			"wipe": _go(Page.CONFIRM_WIPE)
			"quit": get_tree().quit()
		return

	if page == Page.CONFIRM_WIPE:
		if id == "yes":
			Game.delete_save()
			Game.new_run()
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
			logo.visible = true
			menu.offset_top = 108.0   # doubled Aug 2026
			for i in rows.size():
				var id := String(rows[i])
				var names_main := {
					"continue": "Continue", "new": "New term", "howto": "How to play",
					"settings": "Settings", "controls": "Controls",
					"credits": "Credits", "wipe": "Erase save", "quit": "Quit",
				}
				var text: String = String(names_main.get(id, id))
				if id == "continue":
					text += "   (day %d)" % Game.saved_day()
				lines.append("%s %s" % [">" if i == sel else " ", text])
			footer.text = message if message != "" else "Arrows to choose, E to pick"

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
			var shown_rows := 10
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
			if rows.size() > shown_rows:
				lines.append("")
				lines.append("  %d-%d of %d" % [lo + 1, mini(rows.size(), lo + shown_rows), rows.size()])
			footer.text = message if message != "" else "E to rebind, Esc to go back"

		Page.HOWTO:
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "HOW TO PLAY"
			logo.visible = false
			lines = [
				"Start the lesson at the PODIUM.",
				"A ? means that student is STUCK and their",
				"work has stopped. Walk over, press %s." % Settings.binding_text("interact"),
				"Collect finished work, hand it in at YOUR",
				"desk, then ring the BELL to end the day.",
				"Buy furniture at the NOTICEBOARD - it only",
				"helps the desks in range, shown in green.",
				"A term is %d days, then they sit an exam." % Balance.term_days,
			]
			footer.text = "Esc to go back"

		Page.CREDITS:
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "CREDITS"
			logo.visible = false
			lines = [
				"A small game about paying attention.",
				"",
				"Every image is drawn by tools/make_art.py",
				"Every sound is synthesised by make_audio.py",
				"Nothing here was sourced from anywhere else.",
				"",
				"Built with Godot 4.",
			]
			footer.text = "Esc to go back"

		Page.CONFIRM_WIPE:
			menu.offset_top = 80.0   # doubled Aug 2026
			heading.text = "ERASE SAVE?"
			logo.visible = false
			lines = ["This cannot be undone.", ""]
			for i in rows.size():
				lines.append("%s %s" % [
					">" if i == sel else " ",
					"No, keep it" if String(rows[i]) == "no" else "Yes, erase it"])
			footer.text = ""

	menu.text = "\n".join(lines)
