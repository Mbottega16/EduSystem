extends Node

## Player settings: volumes, key bindings, window. Registered as `Settings`.
##
## Persisted to user://settings.json, separately from the save file — wiping
## your progress should not also throw away your key bindings or turn the
## sound back on.

const PATH := "user://pixelroom_settings.json"

## Every rebindable action, in the order the controls screen lists them.
## `label` is what the player is shown; the action name is what the code uses.
const ACTIONS := [
	{"action": "move_up", "label": "Walk up"},
	{"action": "move_down", "label": "Walk down"},
	{"action": "move_left", "label": "Walk left"},
	{"action": "move_right", "label": "Walk right"},
	{"action": "interact", "label": "Help / collect"},
	{"action": "manage", "label": "Lesson / bell / shop"},
	{"action": "voice", "label": "Settle the room"},
	{"action": "build", "label": "Rearrange the room"},
	{"action": "autopilot", "label": "Go to whoever needs me"},
	{"action": "sprint", "label": "Hurry"},
	{"action": "menu", "label": "Class list"},
	{"action": "dashboard", "label": "Your dashboard"},
	{"action": "watch", "label": "Watch a delegated room"},
	{"action": "pause", "label": "Pause"},
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
	"voice": [KEY_Q],
	"build": [KEY_B],
	"autopilot": [KEY_R],
	"sprint": [KEY_SHIFT],
	"menu": [KEY_TAB],
	"dashboard": [KEY_I],
	"watch": [KEY_V],
	"pause": [KEY_P],
	"cancel": [KEY_ESCAPE],
}

signal changed()

var master_volume: float = 0.8
var sfx_volume: float = 0.9
var window_scale: int = 3
var fullscreen: bool = false
var show_hints: bool = true
var bindings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_all()


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
	# Sfx keeps its own multiplier because there is no separate bus yet;
	# routing every sound through one autoload makes that a one-line change
	# if music ever arrives.
	Sfx.volume_db = linear_to_db(maxf(0.0001, sfx_volume))
	Sfx.enabled = sfx_volume > 0.001


# -------------------------------------------------------------- window

func apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(320, 176) * window_scale)


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
		"window_scale": window_scale, "fullscreen": fullscreen,
		"show_hints": show_hints, "bindings": b,
	}


## Missing keys fall back to the FACTORY defaults, not to whatever happens
## to be in memory. Defaulting to the current value made from_dict({}) a
## silent no-op, which meant "reset to defaults" reset nothing.
const FACTORY := {
	"master_volume": 0.8, "sfx_volume": 0.9,
	"window_scale": 3, "fullscreen": false, "show_hints": true,
}

func from_dict(d: Dictionary) -> void:
	master_volume = clampf(float(d.get("master_volume", FACTORY["master_volume"])), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", FACTORY["sfx_volume"])), 0.0, 1.0)
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
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_settings() -> bool:
	if not FileAccess.file_exists(PATH):
		from_dict({})
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
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
