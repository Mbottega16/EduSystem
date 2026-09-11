extends Node

# ModLoader scans the 'res://mods/' folder for .gd scripts that expose a
# `register(game: Node)` function. It keeps a dictionary of discovered mods
# and whether they are enabled. The enabled state is persisted via SaveManager
# (or a simple user://mods_state.json) so that the UI can toggle them.

const MODS_DIR = "res://mods/"

# Dictionary of mod_name -> { script: Ref<Script>, enabled: bool }
var mods: Dictionary = {}

func _ready():
    _scan_mods()
    _load_enabled_state()
    # Register enabled mods immediately
    for name in mods.keys():
        if mods[name].enabled:
            _register_mod(name)

func _scan_mods() -> void:
    var dir = DirAccess.open(MODS_DIR)
    if dir == null:
        push_error("ModLoader: cannot open mods directory")
        return
    dir.list_dir_begin(true, true) # skip hidden, skip navigation
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".gd"):
            var mod_path = MODS_DIR + file_name
            var script = load(mod_path)
            if script:
                var mod_name = file_name.get_basename()
                mods[mod_name] = { "script": script, "enabled": false }
        file_name = dir.get_next()
    dir.list_dir_end()

func _load_enabled_state() -> void:
    var path = "user://mods_state.json"
    if not FileAccess.file_exists(path):
        return
    var f = FileAccess.open(path, FileAccess.READ)
    if f:
        var txt = f.get_as_text()
        f.close()
        var parsed = JSON.parse_string(txt)
        # JSON.parse_string() (Godot 4) returns the parsed value directly, or
        # null on failure -- there's no .error/.result wrapper (that was
        # Godot 3's JSON.parse()).
        if parsed is Dictionary:
            var state: Dictionary = parsed
            for name in state.keys():
                if mods.has(name):
                    mods[name].enabled = bool(state[name])

func _save_enabled_state() -> void:
    var path = "user://mods_state.json"
    var f = FileAccess.open(path, FileAccess.WRITE)
    if f:
        var state = {}
        for name in mods.keys():
            state[name] = mods[name].enabled
        f.store_string(JSON.stringify(state))
        f.close()

func enable_mod(name: String) -> void:
    if not mods.has(name):
        push_error("ModLoader: unknown mod %s" % name)
        return
    if not mods[name].enabled:
        mods[name].enabled = true
        _register_mod(name)
        _save_enabled_state()

func disable_mod(name: String) -> void:
    if not mods.has(name):
        push_error("ModLoader: unknown mod %s" % name)
        return
    if mods[name].enabled:
        mods[name].enabled = false
        # No automatic unregister – mods should clean up via signals if needed.
        _save_enabled_state()

func _register_mod(name: String) -> void:
    var script = mods[name].script
    if script and script.has_method("register"):
        script.call("register", get_node("/root/Game"))
    else:
        push_warning("ModLoader: mod %s has no register(game) function" % name)

func get_mods() -> Dictionary:
    return mods
