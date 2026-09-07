class_name ForgeTab
extends VBoxContainer

## The shared body of a Master Forge tab that drives a `forge_*.py` script.
##
## The Art, Items and HUD tabs were three near-identical copies of the same
## forty lines: a name box, a Forge button, a TextEdit of `KEY=value` lines,
## and an OS.execute() whose output went to a stdout nobody sees, because
## the forge is launched with `start` and has no console attached. Two of
## the three also called a method that does not exist
## (`add_theme_colors_override`), so those tabs threw on open.
##
## One base class instead, with the three things the copies were missing:
##   - the house palette, one click away (tools/forge_palette_bar.gd)
##   - the script's own output ON SCREEN, not in a console that isn't there
##   - a target dropdown, so you pick a sprite rather than spell it
##
## A subclass sets the four `cfg_*` values and calls `build_tab()`.
##
## The layout is three numbered steps down the tab, because the previous
## one was a flat stack of widgets that never said which came first. It
## also had TWO controls holding the same value -- a dropdown and a text
## box side by side, both called the target -- and nothing on screen said
## which one Forge would actually read. There is one target now: the
## dropdown holds it, and the box beside it filters the list.

const PY_TIMEOUT_NOTE := "python must be on PATH"

## What the subclass configures. Set these before calling build_tab().
var cfg_script: String = ""        ## e.g. "forge_items.py"
var cfg_title: String = ""
var cfg_target_hint: String = ""   ## placeholder for the name box
var cfg_module: String = ""        ## palette group to offer; "" all, "none" hides the bar
var cfg_list_arg: String = ""      ## argument that makes the script list targets
## One sentence on what pressing Forge does. Shown under the title, where
## the tabs used to say nothing at all about what they were for.
var cfg_blurb: String = ""

var targets: OptionButton
var params: TextEdit
var out: RichTextLabel
var bar: ForgePaletteBar

var _filter: LineEdit
var _forge_btn: Button
var _all_targets: Array[String] = []


func build_tab() -> void:
	add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = cfg_title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ForgeTheme.ACCENT)
	add_child(title)
	if cfg_blurb != "":
		var blurb := ForgeTheme.caption(cfg_blurb)
		add_child(blurb)

	_build_step_target()
	_build_step_params()
	_build_step_run()

	_load_targets()


## Step 1 -- what to rebuild.
func _build_step_target() -> void:
	var card := ForgeTheme.card()
	add_child(card)
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(ForgeTheme.heading("1 · Pick what to rebuild"))

	var row := HBoxContainer.new()
	col.add_child(row)

	targets = OptionButton.new()
	targets.custom_minimum_size = Vector2(230, 0)
	targets.tooltip_text = "Everything this forge can rebuild. This is the target Forge will use."
	targets.item_selected.connect(func(_i: int) -> void: _update_forge_btn())
	row.add_child(targets)

	# A FILTER, not a second copy of the target. The old tab had a LineEdit
	# next to this dropdown holding the same kind of value, and whichever
	# you typed into, the other still showed something -- you could not tell
	# by looking which one Forge would read. This one narrows the list and
	# holds nothing.
	_filter = LineEdit.new()
	_filter.placeholder_text = "filter the list — " + cfg_target_hint.to_lower()
	_filter.custom_minimum_size = Vector2(200, 0)
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _apply_filter())
	row.add_child(_filter)

	var refresh := ForgeTheme.secondary(Button.new())
	refresh.text = "Refresh list"
	refresh.tooltip_text = "Ask %s again what it can build" % cfg_script
	refresh.pressed.connect(_load_targets)
	row.add_child(refresh)

	extra_controls(row)


## Step 2 -- how to change it.
func _build_step_params() -> void:
	var card := ForgeTheme.card()
	add_child(card)
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(ForgeTheme.heading("2 · Set what to change"))

	# "none" means this forge's parameters are not colours -- the Audio tab.
	# A bar with every swatch filtered out is worse than no bar: it looks
	# like the palette failed to load.
	if cfg_module != "none":
		bar = ForgePaletteBar.new()
		col.add_child(bar)
		bar.setup(cfg_module)
		bar.param_chosen.connect(set_param)

	params = TextEdit.new()
	params.placeholder_text = ("Parameters, one per line — e.g. pitch=1.2"
		if cfg_module == "none"
		else "Parameters, one per line — the swatches above write these for you")
	params.custom_minimum_size = Vector2(0, 96)
	col.add_child(params)
	col.add_child(ForgeTheme.caption(
		"Leave this empty to rebuild the target exactly as the script would."))


## Step 3 -- do it, and read what happened.
func _build_step_run() -> void:
	var card := ForgeTheme.card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(card)
	var col := VBoxContainer.new()
	card.add_child(col)

	var row := HBoxContainer.new()
	col.add_child(row)
	row.add_child(ForgeTheme.heading("3 · Forge it"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var clear := ForgeTheme.secondary(Button.new())
	clear.text = "Clear log"
	clear.pressed.connect(func() -> void: out.text = "")
	row.add_child(clear)

	# The one filled button on the tab. It was previously the same
	# borderless word as "Refresh list" sitting right beside it.
	_forge_btn = ForgeTheme.primary(Button.new())
	_forge_btn.text = "Forge"
	_forge_btn.tooltip_text = "Run %s and rewrite the asset" % cfg_script
	_forge_btn.pressed.connect(_on_forge)
	row.add_child(_forge_btn)

	out = RichTextLabel.new()
	out.bbcode_enabled = true
	out.scroll_following = true
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.custom_minimum_size = Vector2(0, 120)
	out.add_theme_font_size_override("normal_font_size", 12)
	col.add_child(out)


## Subclasses add their own buttons to the target row here. Empty by default.
func extra_controls(_row: HBoxContainer) -> void:
	pass


## The one place anything asks "what am I forging?".
func current_target() -> String:
	if targets == null or targets.selected < 0:
		return ""
	return targets.get_item_text(targets.selected)


func _update_forge_btn() -> void:
	var name := current_target()
	_forge_btn.disabled = name == ""
	_forge_btn.text = "Forge" if name == "" else "Forge  %s" % name


func _apply_filter() -> void:
	var keep := _filter.text.strip_edges().to_lower()
	var was := current_target()
	targets.clear()
	for n: String in _all_targets:
		if keep == "" or keep in n:
			targets.add_item(n)
	# Hold the selection across a filter change when the target still
	# matches, so typing does not silently retarget the Forge button.
	for i in targets.item_count:
		if targets.get_item_text(i) == was:
			targets.select(i)
			break
	if targets.selected < 0 and targets.item_count > 0:
		targets.select(0)
	_update_forge_btn()


## Write `key=hex` into the parameter box, REPLACING any line that already
## sets the same key. Appending instead would leave two lines fighting, and
## the forge scripts apply them in order, so the loser would be invisible.
func set_param(key: String, hex: String) -> void:
	var kept: Array[String] = []
	for line: String in params.text.split("\n"):
		var t := line.strip_edges()
		if t == "" or t.begins_with(key + "="):
			continue
		kept.append(t)
	kept.append("%s=%s" % [key, hex])
	params.text = "\n".join(kept)


func log_line(s: String, colour: String = "") -> void:
	if out == null:
		return
	if colour == "":
		out.append_text(s + "\n")
	else:
		out.append_text("[color=%s]%s[/color]\n" % [colour, s])


## Run the tab's script with the typed arguments and show what it said.
## Blocking on purpose: these scripts take well under a second, and a
## background run would need a poll loop to report anything at all.
func run_script(args: Array) -> int:
	var full: Array = [ProjectSettings.globalize_path("res://tools/" + cfg_script)]
	full.append_array(args)
	var lines: Array = []
	var code := OS.execute("python", full, lines, true)
	for line: String in lines:
		for one: String in line.split("\n"):
			if one.strip_edges() != "":
				log_line(one.strip_edges())
	if code != 0:
		log_line("%s exited %d  (%s)" % [cfg_script, code, PY_TIMEOUT_NOTE], "#f08a8a")
	return code


func _on_forge() -> void:
	var name := current_target()
	if name == "":
		log_line("Pick something to forge first.", "#f0c866")
		return
	var args: Array = [name]
	for line: String in params.text.split("\n", false):
		var p := line.strip_edges()
		if p != "":
			args.append(p)
	log_line("[b]%s %s[/b]" % [cfg_script, " ".join(PackedStringArray(args))], "#8fd0ff")
	if run_script(args) == 0:
		# The seam that bites, named in CLAUDE.md: a PNG on disk that Godot
		# has not imported cannot be loaded. Say so rather than leaving the
		# forge looking like it did nothing.
		log_line("Done. Press Sync & Reimport (top right) for the game to see it.",
			"#84d68f")
		forged.emit(name)


## Emitted after a successful forge, so the shell can refresh anything that
## shows the asset -- the gallery, in the Art tab's case, which otherwise
## kept displaying the pre-forge PNG until you pressed Rescan.
signal forged(target_name: String)


## Ask the script what it can build. Anything that fails leaves the
## dropdown empty and says so, rather than looking like an empty catalogue.
func _load_targets() -> void:
	if cfg_list_arg == "":
		return
	_all_targets.clear()
	var lines: Array = []
	OS.execute("python", [ProjectSettings.globalize_path("res://tools/" + cfg_script),
		cfg_list_arg], lines, true)
	# Every list mode prints ONE name per line. Anything else on a line is
	# prose, and reading names out of prose is how this dropdown once
	# offered "&" and "(make_art)" as sprites you could forge.
	var ok := RegEx.create_from_string("^[a-z0-9_]+$")
	for block: String in lines:
		for line: String in block.split("\n"):
			var w := line.strip_edges()
			if w != "" and ok.search(w) != null:
				_all_targets.append(w)
	_all_targets.sort()
	_apply_filter()
	if _all_targets.is_empty():
		log_line("%s listed nothing. Is python on PATH?" % cfg_script, "#f0c866")
