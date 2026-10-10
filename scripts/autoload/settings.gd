extends Node

## Player settings: volumes, key bindings, window. Registered as `Settings`.
##
## Persisted to user://settings.json, separately from the save file — wiping
## your progress should not also throw away your key bindings or turn the
## sound back on.

const PATH := "user://edusystem_settings.json"
## Where settings are read and written: the player's file, except under the
## test suite, which points this at its own (tests/run.gd). The suite rebinds
## keys, writes a corrupt file on purpose and resets everything to defaults,
## and until Oct 2026 it did all of that to the PLAYER's settings every time it
## ran -- the save file was moved off the real one for exactly this reason
## (Game.save_path); the settings never were.
var path := PATH

## Every rebindable action, in the order the controls screen lists them.
## `label` is what the player is shown; the action name is what the code uses.
const ACTIONS := [
	{"action": "move_up", "label": "Walk up"},
	{"action": "move_down", "label": "Walk down"},
	{"action": "move_left", "label": "Walk left"},
	{"action": "move_right", "label": "Walk right"},
	{"action": "interact", "label": "Help / collect / clean up"},
	{"action": "manage", "label": "Bell / shop"},
	{"action": "teach", "label": "Start the lesson"},
	{"action": "quiz", "label": "Quick quiz"},
	{"action": "answer_all", "label": "Answer all"},
	{"action": "homework", "label": "Mark homework"},
	{"action": "grades", "label": "Read the grade book"},
	{"action": "move_desk", "label": "Move a desk"},
	{"action": "voice", "label": "Settle the room"},
	{"action": "call_response", "label": "Class, class! (call them back)"},
	{"action": "build", "label": "Rearrange the room"},
	{"action": "autopilot", "label": "Go to whoever needs me"},
	{"action": "auto_teach", "label": "Auto-teach the lesson"},
	{"action": "skip_days", "label": "Teach on your own for a few days"},
	{"action": "dash", "label": "Dash"},
	{"action": "fullscreen", "label": "Fullscreen"},
	{"action": "menu", "label": "Class list"},
	{"action": "dashboard", "label": "Your dashboard"},
	{"action": "watch", "label": "Watch a delegated room"},
	{"action": "fire", "label": "Let go a hired teacher"},
	{"action": "respond", "label": "Answer what's waiting at your desk"},
	{"action": "pause", "label": "Pause"},
	{"action": "help", "label": "Controls / help"},
]
## Bound, but not offered for rebinding: Escape always means "back out".
const FIXED := ["cancel"]

## Physical keycodes, so the bindings mean the same on a non-QWERTY layout.
const DEFAULTS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_SPACE],
	"manage": [KEY_F],
	# T was already Auto-teach's key (a real, previously-confirmed feature) --
	# L is the nearest free letter, not a perfect mnemonic, but it does not
	# collide with anything.
	"teach": [KEY_L],
	"quiz": [KEY_Q],
	"answer_all": [KEY_J],
	"homework": [KEY_H],
	# U, beside H: the two things you do with the paper on your own desk --
	# mark what came in, read back what you gave. G (for grades) was already
	# letting a hired teacher go.
	"grades": [KEY_U],
	"move_desk": [KEY_M],
	"voice": [KEY_C],
	# Y for "Yes, yes!" -- what the room shouts back. One of the few letters
	# left that is not already a verb.
	"call_response": [KEY_Y],
	"build": [KEY_B],
	"autopilot": [KEY_R],
	"auto_teach": [KEY_T],
	# N for "next days". Its own key, not a mode of auto-teach (T):
	# one hands over the lesson you are stood in, the other hands over
	# whole days, and CLAUDE.md's one-key-per-verb rule exists because
	# two verbs sharing a key is how E stopped meaning anything.
	"skip_days": [KEY_N],
	"dash": [KEY_SHIFT],
	"fullscreen": [KEY_F11],
	"menu": [KEY_TAB],
	"dashboard": [KEY_I],
	"watch": [KEY_V],
	"fire": [KEY_G],
	"respond": [KEY_K],
	"pause": [KEY_P],
	# The in-game controls sheet. "/" because "?" is on it on most
	# layouts, and every letter near the home row is already a verb.
	"help": [KEY_SLASH],
	"cancel": [KEY_ESCAPE],
}

signal changed()

var master_volume: float = 0.8
var sfx_volume: float = 0.9
var music_volume: float = 0.6
var window_scale: int = 3
## On by default since Sept 2026, on request. A settings file written
## before that keeps whatever it says -- FACTORY is only consulted for
## a key that is absent.
var fullscreen: bool = true
var show_hints: bool = true
var bindings: Dictionary = {}


func _ready() -> void:
	# Before the first read: carry a pre-rename settings file across the
	# user:// move (PixelRoom -> EDUSystem). Idempotent, gated by a sentinel.
	Game.migrate_legacy_user_files()
	load_settings()
	apply_all()


## Fullscreen, from anywhere, without walking to the settings page.
##
## In the AUTOLOAD rather than in main.gd or title.gd, because it has to
## work on both and on every dev tool too, and because it is the one verb
## in this game that is about the window rather than about the classroom.
## Handled here and marked handled, so no screen underneath also acts on it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- bindings

## Rebuild the InputMap from `bindings`. Called on boot and after any change,
## so what the controls screen shows is always what the game actually reads.
func apply_bindings() -> void:
	# DEFAULTS, not ACTIONS: ACTIONS is only what the controls screen LISTS.
	# Iterating it here would leave the fixed actions unbound entirely.
	for action: String in DEFAULTS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for code: int in bindings.get(action, DEFAULTS.get(action, [])):
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


## Bind `action` to `code`. Returns "" on success, or why it was refused.
## A key already used by something else is taken off that action first —
## silently leaving a key on two actions is how a controls screen lies.
func rebind(action: String, code: int) -> String:
	if code == KEY_ESCAPE and action != "cancel":
		return "Escape is reserved for backing out."
	if code == 0:
		return "That key cannot be bound."
	for other: String in bindings.keys():
		if other == action:
			continue
		var list: Array = bindings[other]
		if list.has(code):
			list.erase(code)
			if list.is_empty():
				# never leave an action unusable
				bindings[other] = DEFAULTS.get(other, []).duplicate()
	bindings[action] = [code]
	apply_bindings()
	save_settings()
	changed.emit()
	return ""


func reset_bindings() -> void:
	bindings.clear()
	for k: String in DEFAULTS:
		bindings[k] = (DEFAULTS[k] as Array).duplicate()
	apply_bindings()
	save_settings()
	changed.emit()


## Human-readable key names for one action, e.g. "W, Up".
func binding_text(action: String) -> String:
	var names: Array[String] = []
	for code: int in bindings.get(action, []):
		names.append(OS.get_keycode_string(code))
	return "unbound" if names.is_empty() else ", ".join(names)


# --------------------------------------------------------------- audio

func apply_audio() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.0001, master_volume)))
		AudioServer.set_bus_mute(master, master_volume <= 0.001)
	# Sfx keeps its own multiplier on Master, as it always has. Music got
	# the separate bus when it arrived, so its volume is a bus fader.
	Sfx.volume_db = linear_to_db(maxf(0.0001, sfx_volume))
	Sfx.enabled = sfx_volume > 0.001
	var music := AudioServer.get_bus_index(Music.BUS)
	if music >= 0:
		AudioServer.set_bus_volume_db(music, linear_to_db(maxf(0.0001, music_volume)))
		AudioServer.set_bus_mute(music, music_volume <= 0.001)
	Music.enabled = music_volume > 0.001


# -------------------------------------------------------------- window

## The size one "x1" of window scale means. This is the VIEWPORT, from
## project.godot -- and it was wrong here for a month: this still said
## 320x176 after the Aug 2026 resolution doubling, so "x3" opened a
## 960x528 window showing a 640x352 viewport at one and a half times
## size. Every pixel edge landed on a half pixel, which is exactly what
## the integer scale in project.godot exists to prevent.
const BASE := Vector2i(640, 352)


## The largest whole scale this monitor can actually show, so "x6" on a
## 1080p screen opens a window you can still find the title bar of.
func max_window_scale() -> int:
	var screen := DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen()).size
	if screen.x <= 0 or screen.y <= 0:
		return 6
	return clampi(mini(screen.x / BASE.x, screen.y / BASE.y), 1, 6)


## True when this process was launched straight into a scene under
## res://tools/ -- the art forge, the Master Forge, a screenshot run.
##
## Those set their own window size and expect to get it. Fullscreen is on
## by DEFAULT for the game now, and DisplayServer.window_set_size() does
## not take a fullscreen window back to windowed, so without this every
## dev tool would open full screen at the game's aspect and ignore the
## size it asked for. Reading the command line is blunt but it is the only
## thing that knows, at autoload time, which scene is about to run.
func _launched_into_a_tool() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			return true
	return false


func apply_window() -> void:
	if fullscreen and not _launched_into_a_tool():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(BASE * clampi(window_scale, 1, max_window_scale()))


## Flip fullscreen and remember it. Bound to a key as well as sitting on
## the settings page, because the settings page is three screens away from
## a lesson and this is the one display setting you change mid-play.
func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_window()
	save_settings()
	changed.emit()


func apply_all() -> void:
	apply_bindings()
	apply_audio()
	apply_window()
	changed.emit()


# ----------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	var b := {}
	for k: String in bindings:
		b[k] = bindings[k]
	return {
		"master_volume": master_volume, "sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"window_scale": window_scale, "fullscreen": fullscreen,
		"show_hints": show_hints, "bindings": b,
	}


## Missing keys fall back to the FACTORY defaults, not to whatever happens
## to be in memory. Defaulting to the current value made from_dict({}) a
## silent no-op, which meant "reset to defaults" reset nothing.
const FACTORY := {
	"master_volume": 0.8, "sfx_volume": 0.9, "music_volume": 0.6,
	"window_scale": 3, "fullscreen": true, "show_hints": true,
}

func from_dict(d: Dictionary) -> void:
	master_volume = clampf(float(d.get("master_volume", FACTORY["master_volume"])), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", FACTORY["sfx_volume"])), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", FACTORY["music_volume"])), 0.0, 1.0)
	window_scale = clampi(int(d.get("window_scale", FACTORY["window_scale"])), 1, 6)
	fullscreen = bool(d.get("fullscreen", FACTORY["fullscreen"]))
	show_hints = bool(d.get("show_hints", FACTORY["show_hints"]))

	bindings.clear()
	var saved: Dictionary = d.get("bindings", {})
	for k: String in DEFAULTS:
		var list: Array = []
		for code in saved.get(k, DEFAULTS[k]):
			list.append(int(code))
		bindings[k] = list if not list.is_empty() else (DEFAULTS[k] as Array).duplicate()


func save_settings() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_settings() -> bool:
	if not FileAccess.file_exists(path):
		from_dict({})
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		from_dict({})
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("settings file is corrupt — using defaults")
		from_dict({})
		return false
	from_dict(parsed as Dictionary)
	return true


func reset_all() -> void:
	from_dict({})
	apply_all()
	save_settings()
