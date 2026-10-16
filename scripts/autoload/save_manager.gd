extends Node

# SaveManager handles up to 8 JSON save slots in user://saves/
# Each slot is a file "slot_<index>.json" where index is 0-7.
# The data is a dictionary of the entire game state -- Game.to_dict() /
# Game.from_dict(), the same serialization the single autosave uses.
# Wired in via Game.save_to_slot() / Game.load_from_slot(); this file
# stays a plain slot store and never reaches into Game itself.

const MAX_SLOTS = 8
const SAVE_DIR = "user://saves/"

var play_time: float = 0.0

func _ready():
    # Ensure the directory exists
    var dir = DirAccess.open("user://")
    if dir and not dir.dir_exists("saves"):
        dir.make_dir("saves")

func _process(delta: float) -> void:
    play_time += delta

func format_play_time(seconds: float) -> String:
    var total_seconds := int(maxf(0.0, seconds))
    var hours := total_seconds / 3600
    var minutes := (total_seconds % 3600) / 60
    return "%02d:%02d" % [hours, minutes]

func format_timestamp(unix_time: int) -> String:
    if unix_time <= 0:
        return ""
    var dt := Time.get_datetime_dict_from_unix_time(unix_time)
    return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func get_slot_path(index: int) -> String:
    return SAVE_DIR + "slot_%d.json" % index

func list_slots() -> Array:
    var slots = []
    for i in range(MAX_SLOTS):
        var path = get_slot_path(i)
        if FileAccess.file_exists(path):
            slots.append({"index": i, "path": path})
    return slots

func has_slot(index: int) -> bool:
    if index < 0 or index >= MAX_SLOTS:
        return false
    return FileAccess.file_exists(get_slot_path(index))

func get_slot_metadata(index: int) -> Dictionary:
    if index < 0 or index >= MAX_SLOTS or not has_slot(index):
        return {
            "index": index,
            "exists": false,
            "empty": true,
            "locked": true,
            "save_name": "Empty Slot",
            "play_time": 0.0,
            "play_time_formatted": "--:--",
            "timestamp": 0,
            "timestamp_formatted": "",
            "last_played": "",
            "day": 0,
            "coins": 0,
            "term": 0,
            "subject": "",
        }
    var path := get_slot_path(index)
    var d: Dictionary = self.load(index)
    var timestamp: int = int(d.get("timestamp", 0))
    if timestamp <= 0:
        timestamp = FileAccess.get_modified_time(path)
    
    var last_played: String = String(d.get("last_played", ""))
    if last_played == "" and timestamp > 0:
        last_played = format_timestamp(timestamp)
    
    var play_secs: float = float(d.get("play_time", d.get("playtime", 0.0)))
    var play_formatted: String = format_play_time(play_secs)
    
    var sname: String = String(d.get("save_name", d.get("name", "")))
    if sname == "":
        var day_num := int(d.get("day", 1))
        sname = "Slot %d (Day %d)" % [index + 1, day_num]
        
    return {
        "index": index,
        "exists": true,
        "empty": false,
        "locked": false,
        "save_name": sname,
        "play_time": play_secs,
        "play_time_formatted": play_formatted,
        "timestamp": timestamp,
        "timestamp_formatted": last_played,
        "last_played": last_played,
        "day": int(d.get("day", 1)),
        "coins": int(d.get("coins", 0)),
        "term": int(d.get("term", 1)),
        "subject": String(d.get("subject", "general")),
    }

func save(index: int, data: Dictionary) -> bool:
    if index < 0 or index >= MAX_SLOTS:
        push_error("SaveManager: invalid slot index %d" % index)
        return false
    var f = FileAccess.open(get_slot_path(index), FileAccess.WRITE)
    if f == null:
        push_error("SaveManager: cannot open file for writing")
        return false
    var to_save: Dictionary = data.duplicate()
    if not to_save.has("timestamp"):
        to_save["timestamp"] = int(Time.get_unix_time_from_system())
    if not to_save.has("last_played"):
        to_save["last_played"] = format_timestamp(int(to_save["timestamp"]))
    if not to_save.has("play_time"):
        to_save["play_time"] = int(play_time)
    if not to_save.has("save_name"):
        var day_num := int(to_save.get("day", 1))
        to_save["save_name"] = "Slot %d (Day %d)" % [index + 1, day_num]
    f.store_string(JSON.stringify(to_save))
    f.close()
    return true

func load(index: int) -> Dictionary:
    var result = {}
    if index < 0 or index >= MAX_SLOTS:
        push_error("SaveManager: invalid slot index %d" % index)
        return result
    var path = get_slot_path(index)
    if not FileAccess.file_exists(path):
        push_error("SaveManager: slot %d does not exist" % index)
        return result
    var f = FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_error("SaveManager: cannot open file for reading")
        return result
    var txt = f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(txt)
    # JSON.parse_string() (Godot 4) returns the parsed value directly, or
    # null on failure -- it does NOT return a .error/.result object (that
    # was Godot 3's JSON.parse()). A save slot's contents are always a
    # dictionary of game state.
    if not (parsed is Dictionary):
        push_error("SaveManager: failed to parse JSON in slot %d" % index)
        return result
    result = parsed
    if result.has("play_time"):
        play_time = float(result.get("play_time", play_time))
    return result

func delete_slot(index: int) -> bool:
    var path = get_slot_path(index)
    if FileAccess.file_exists(path):
        # Two bugs, not one, until a test actually exercised this (nothing
        # had, until test_save_slots()):
        # 1. remove_absolute() wants a real OS path, not user://'s virtual
        #    one -- Game.delete_save() already gets this right.
        # 2. remove_absolute() returns an Error (OK == 0), not a bool --
        #    returning it bare made a SUCCESSFUL delete report false,
        #    since GDScript's int->bool coercion treats 0 as false.
        return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
    return false
