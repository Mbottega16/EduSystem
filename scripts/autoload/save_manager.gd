extends Node

# SaveManager handles up to 8 JSON save slots in user://saves/
# Each slot is a file "slot_<index>.json" where index is 0-7.
# The data is a dictionary of the entire game state -- Game.to_dict() /
# Game.from_dict(), the same serialization the single autosave uses.
# Wired in via Game.save_to_slot() / Game.load_from_slot(); this file
# stays a plain slot store and never reaches into Game itself.

const MAX_SLOTS = 8
const SAVE_DIR = "user://saves/"

func _ready():
    # Ensure the directory exists
    var dir = DirAccess.open("user://")
    if dir and not dir.dir_exists("saves"):
        dir.make_dir("saves")

func get_slot_path(index: int) -> String:
    return SAVE_DIR + "slot_%d.json" % index

func list_slots() -> Array:
    var slots = []
    for i in range(MAX_SLOTS):
        var path = get_slot_path(i)
        if FileAccess.file_exists(path):
            slots.append({"index": i, "path": path})
    return slots

func save(index: int, data: Dictionary) -> bool:
    if index < 0 or index >= MAX_SLOTS:
        push_error("SaveManager: invalid slot index %d" % index)
        return false
    var f = FileAccess.open(get_slot_path(index), FileAccess.WRITE)
    if f == null:
        push_error("SaveManager: cannot open file for writing")
        return false
    f.store_string(JSON.stringify(data))
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
