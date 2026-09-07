extends ForgeTab

## Master Forge, Audio tab -- one sound effect, resynthesised.
##
## The one tab whose parameters are numbers rather than colours, so the
## palette bar has nothing to offer it; everything else it wants is the
## same, which is why it shares tools/forge_tab.gd with the other three.
## Its own additions are Play (hear the result without leaving the tab)
## and the count/variance pair forge_audio.py takes for a batch.

var _player: AudioStreamPlayer


func _ready() -> void:
	cfg_script = "forge_audio.py"
	cfg_title = "Audio — sound effects (forge_audio.py)"
	cfg_target_hint = "Sound name (e.g. stuck)"
	cfg_module = "none"          ## no colour swatches apply to a sound
	cfg_list_arg = "list"
	cfg_blurb = "Resynthesise one sound effect into audio/. Numbers, not colours."
	build_tab()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	log_line("Parameters are numbers: pitch=1.2, attack=0.1, gain=0.8.",
		"#8a929c")
	log_line("count=5 variance=0.1 forges five takes that differ slightly.",
		"#8a929c")


func extra_controls(row: HBoxContainer) -> void:
	var play := ForgeTheme.secondary(Button.new())
	play.text = "Play"
	play.tooltip_text = "Hear the .wav currently on disk"
	play.pressed.connect(_on_play)
	row.add_child(play)


func _on_play() -> void:
	var name := current_target()
	if name == "":
		log_line("Pick a sound first.", "#ffcc66")
		return
	var path := "res://audio/%s.wav" % name
	if not FileAccess.file_exists(path):
		log_line("No audio/%s.wav on disk yet — Forge it first." % name, "#ffcc66")
		return
	# Loaded as a resource, not by hand-stuffing bytes into an
	# AudioStreamWAV: the previous version assumed 16-bit 44100 mono for
	# every file and played the forge's own 22050 output an octave high.
	var stream: Resource = load(path)
	if stream is AudioStream:
		_player.stream = stream as AudioStream
		_player.play()
		log_line("Playing %s.wav" % name)
	else:
		log_line("audio/%s.wav is not imported yet — press Sync & Reimport."
			% name, "#ffcc66")
