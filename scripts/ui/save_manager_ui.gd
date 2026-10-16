extends Control
class_name SaveManagerUI

## Visual save-slot picker UI for SaveManager.
## Offers 3 visual save slots showing save name, play time (HH:MM), and last-played timestamp.
## Allows clicking to load a slot and close the UI, and shows empty/locked UI when a slot is empty.

signal slot_loaded(slot_index: int)
signal closed()

const NUM_SLOTS := 3

@onready var title_label: Label = $PanelFrame/VBox/Title
@onready var slot_0: Button = $PanelFrame/VBox/SlotsContainer/Slot0
@onready var slot_1: Button = $PanelFrame/VBox/SlotsContainer/Slot1
@onready var slot_2: Button = $PanelFrame/VBox/SlotsContainer/Slot2
@onready var close_button: Button = $PanelFrame/VBox/BottomBar/CloseButton

var slot_buttons: Array[Button] = []
var _save_mgr: Node = null


func _get_save_mgr() -> Node:
	if _save_mgr != null:
		return _save_mgr
	if is_inside_tree() and get_tree().root.has_node("SaveManager"):
		_save_mgr = get_tree().root.get_node("SaveManager")
		return _save_mgr
	var script_res: Variant = load("res://scripts/autoload/save_manager.gd")
	if script_res is GDScript and (script_res as GDScript).can_instantiate():
		_save_mgr = (script_res as GDScript).new()
		add_child(_save_mgr)
		return _save_mgr
	return null


func _ready() -> void:
	_init_buttons()
	refresh_slots()


func _init_buttons() -> void:
	slot_buttons.clear()
	if slot_0 == null:
		slot_0 = get_node_or_null("PanelFrame/VBox/SlotsContainer/Slot0") as Button
	if slot_1 == null:
		slot_1 = get_node_or_null("PanelFrame/VBox/SlotsContainer/Slot1") as Button
	if slot_2 == null:
		slot_2 = get_node_or_null("PanelFrame/VBox/SlotsContainer/Slot2") as Button
	if close_button == null:
		close_button = get_node_or_null("PanelFrame/VBox/BottomBar/CloseButton") as Button

	var candidates: Array = [slot_0, slot_1, slot_2]
	for i in range(candidates.size()):
		var btn: Button = candidates[i] as Button
		if btn != null:
			slot_buttons.append(btn)
			var callable := _on_slot_pressed.bind(i)
			if not btn.pressed.is_connected(callable):
				btn.pressed.connect(callable)
	if close_button != null and not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)


func refresh_slots() -> void:
	if slot_buttons.is_empty():
		_init_buttons()
	var mgr := _get_save_mgr()
	for i in range(mini(NUM_SLOTS, slot_buttons.size())):
		var btn: Button = slot_buttons[i]
		var meta: Dictionary = mgr.get_slot_metadata(i) if mgr != null and mgr.has_method("get_slot_metadata") else {}
		_update_slot_button(btn, i, meta)


func _update_slot_button(btn: Button, index: int, meta: Dictionary) -> void:
	btn.set_meta("slot_index", index)
	var has_save: bool = bool(meta.get("exists", false))
	btn.set_meta("is_empty", not has_save)
	btn.set_meta("is_locked", not has_save)

	if has_save:
		var sname: String = String(meta.get("save_name", "Slot %d" % (index + 1)))
		var play_time_str: String = String(meta.get("play_time_formatted", "00:00"))
		var timestamp_str: String = String(meta.get("last_played", ""))
		btn.text = "%s\nPlay Time: %s\nLast Played: %s" % [sname, play_time_str, timestamp_str]
		btn.disabled = false
		btn.set_meta("save_name", sname)
		btn.set_meta("play_time", meta.get("play_time", 0.0))
		btn.set_meta("play_time_formatted", play_time_str)
		btn.set_meta("timestamp", meta.get("timestamp", 0))
		btn.set_meta("last_played", timestamp_str)
	else:
		btn.text = "Slot %d\n[Empty]\n--:--" % [index + 1]
		btn.disabled = true
		btn.set_meta("save_name", "Empty Slot")
		btn.set_meta("play_time", 0.0)
		btn.set_meta("play_time_formatted", "--:--")
		btn.set_meta("timestamp", 0)
		btn.set_meta("last_played", "")

	# Also update child labels if they exist
	var name_lbl := btn.get_node_or_null("Margin/Content/SaveName") as Label
	if name_lbl != null:
		name_lbl.text = String(btn.get_meta("save_name", ""))
	var time_lbl := btn.get_node_or_null("Margin/Content/TimeBox/PlayTimeLabel") as Label
	if time_lbl != null:
		time_lbl.text = String(btn.get_meta("play_time_formatted", ""))
	var date_lbl := btn.get_node_or_null("Margin/Content/DateBox/TimestampLabel") as Label
	if date_lbl != null:
		date_lbl.text = String(btn.get_meta("last_played", ""))
	var status_lbl := btn.get_node_or_null("Margin/Content/StatusLabel") as Label
	if status_lbl != null:
		if has_save:
			status_lbl.text = "Day %d" % int(meta.get("day", 1))
		else:
			status_lbl.text = "[Empty / Locked]"


func _on_slot_pressed(index: int) -> void:
	var mgr := _get_save_mgr()
	if mgr == null or not mgr.has_slot(index):
		if is_inside_tree() and get_tree().root.has_node("Sfx"):
			get_tree().root.get_node("Sfx").play("deny")
		return
	load_slot(index)


func load_slot(index: int) -> bool:
	var mgr := _get_save_mgr()
	if mgr == null or not mgr.has_slot(index):
		return false

	var ok := false
	if is_inside_tree() and get_tree().root.has_node("Game"):
		ok = bool(get_tree().root.get_node("Game").load_from_slot(index))
	elif mgr != null and mgr.has_method("load"):
		var d: Dictionary = mgr.load(index)
		ok = not d.is_empty()

	if ok:
		if is_inside_tree() and get_tree().root.has_node("Sfx"):
			get_tree().root.get_node("Sfx").play("confirm")
		slot_loaded.emit(index)
		close()
		if is_inside_tree() and get_tree().current_scene:
			var path: String = get_tree().current_scene.scene_file_path
			if path.contains("title"):
				get_tree().change_scene_to_file("res://scenes/main.tscn")
	return ok


func close() -> void:
	visible = false
	closed.emit()


func get_slot_button(index: int) -> Button:
	if index >= 0 and index < slot_buttons.size():
		return slot_buttons[index]
	return null


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()
