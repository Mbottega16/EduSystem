extends Node

## Music and ambience. Registered as the `Music` autoload, right after Sfx.
##
## Sfx is the second half of the game's feedback -- "something just happened
## over there". This is the other thing audio does: it tells you where you
## ARE. The title theme on the start screen, a classroom that sounds
## occupied while you play, the assessment track when the term is on the
## line, and a sting either way when it ends. Every track is written by
## tools/make_audio.py, the same way every sound and every image is.
##
## Two players carry the bed and crossfade between tracks; a third plays a
## one-shot sting over the top without touching the bed. All three sit on
## the "Music" bus (default_bus_layout.tres), so Settings.music_volume can
## move them without moving the effects, which stay on Master.
##
## Loops: every bed is an exact sample count with nothing faded at the seam,
## and the loop points are set HERE, on a duplicate of the loaded stream --
## so the .import files stay exactly as Godot writes them and nobody has to
## hand-edit a loop_end after regenerating the audio.
##
## Cues come from LISTENING, not from editing the game flow: run_started and
## term_began put the classroom bed under play. The title screen and the
## main scene each ask for their own bed in _ready(). The boss-fight track
## and the two stings are exposed for the fight code to call:
##   Music.play("music_fight")   Music.sting("music_win")   Music.sting("music_lose")

const BUS := "Music"
## Not balance. A fade length or a trim is presentation, not a gameplay
## number, so these are consts here rather than entries in balance.json.
const DEFAULT_FADE := 1.0
const BED_DB := 0.0
const STING_DB := 0.0
## The linear floor a fade goes to: linear_to_db(0.0) is -inf.
const SILENT := 0.0001
## The bed that plays under ordinary lessons.
const ROOM := "music_room"

## Off means silent and STAYS silent: play() still records `current`, so
## turning the volume back up in Settings resumes the right track.
var enabled: bool = true:
	set(v):
		if v == enabled:
			return
		enabled = v
		if not v:
			_silence()
		elif current != "":
			var t := current
			current = ""
			play(t, DEFAULT_FADE)
## Trim on the bed players, on top of the bus. Stings use STING_DB instead.
var volume_db: float = BED_DB
## The track the bed is on (or fading to); "" when stopped.
var current: String = ""
## How many times a bed actually started. Lets a test prove that playing
## the track already playing is a no-op rather than a restart.
var starts: int = 0

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _live: AudioStreamPlayer      ## whichever of _a / _b carries `current`
var _sting: AudioStreamPlayer
var _beds: Dictionary = {}        ## name -> looping AudioStreamWAV, or null
var _oneshots: Dictionary = {}    ## name -> non-looping stream, or null
var _fades: Dictionary = {}       ## player -> Tween, so a new fade kills the old


func _ready() -> void:
	# Keep going under the pause screen: silence there reads as a bug.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	_a = _make_player()
	_b = _make_player()
	_sting = _make_player()
	_live = _a
	# Listening, not wiring: the game does not need to know music exists.
	Game.run_started.connect(func() -> void: play(ROOM))
	Game.term_began.connect(func(_term: int) -> void: play(ROOM))


## Crossfade the bed to `track`. Playing the track already playing is a
## no-op: a scene re-entering must not restart the music under itself.
func play(track: String, fade_seconds: float = DEFAULT_FADE) -> void:
	if track == current:
		return
	current = track
	if not enabled or _live == null:
		return
	var stream := _bed(track)
	if stream == null:
		return
	var outgoing := _live
	var incoming := _b if _live == _a else _a
	_live = incoming
	starts += 1
	_fade(outgoing, 0.0, fade_seconds, true)
	incoming.stream = stream
	_set_level(SILENT if fade_seconds > 0.0 else 1.0, incoming)
	incoming.play()
	_fade(incoming, 1.0, fade_seconds, false)


func stop(fade_seconds: float = DEFAULT_FADE) -> void:
	current = ""
	if _live == null:
		return
	_fade(_a, 0.0, fade_seconds, true)
	_fade(_b, 0.0, fade_seconds, true)


## A one-shot over the bed, on its own player, so it neither interrupts the
## bed nor gets cut by a crossfade.
func sting(name: String) -> void:
	if not enabled or _sting == null:
		return
	var stream := _oneshot(name)
	if stream == null:
		return
	_sting.stream = stream
	_sting.volume_db = STING_DB
	_sting.play()


# ----------------------------------------------------------------- inside

## The layout file is the source of truth; this is the fallback, so a
## missing layout degrades to "music on its own bus" rather than "music on
## no bus". Either way the bus feeds Master.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, &"Master")


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	add_child(p)
	return p


## Fade a player's level (0..1 of volume_db) to `to` over `secs`, then stop
## it if asked. Linear amplitude, not dB: a fade that is linear in dB spends
## half its time inaudible, which reads as a gap between tracks rather than
## a crossfade.
func _fade(p: AudioStreamPlayer, to: float, secs: float, stop_after: bool) -> void:
	var old: Tween = _fades.get(p)
	if old != null and old.is_valid():
		old.kill()
	if secs <= 0.0 or not p.playing:
		_set_level(to, p)
		if stop_after:
			p.stop()
		return
	var from := clampf(db_to_linear(p.volume_db - volume_db), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_method(_set_level.bind(p), from, to, secs)
	if stop_after:
		tw.tween_callback(p.stop)
	_fades[p] = tw


func _set_level(level: float, p: AudioStreamPlayer) -> void:
	p.volume_db = volume_db + linear_to_db(maxf(SILENT, level))


func _silence() -> void:
	for p: AudioStreamPlayer in [_a, _b, _sting]:
		if p == null:
			continue
		var old: Tween = _fades.get(p)
		if old != null and old.is_valid():
			old.kill()
		p.stop()


## A looping copy of the WAV. Duplicated, so the resource Godot cached
## stays exactly as imported; loop_end is the sample count, so the loop is
## the whole file, which is how make_audio.py wrote it.
func _bed(name: String) -> AudioStream:
	if _beds.has(name):
		return _beds[name]
	var src := _load(name)
	var s: AudioStream = src
	if src is AudioStreamWAV:
		var w: AudioStreamWAV = (src as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		s = w
	_beds[name] = s
	return s


func _oneshot(name: String) -> AudioStream:
	if _oneshots.has(name):
		return _oneshots[name]
	var s := _load(name)
	_oneshots[name] = s
	return s


func _load(name: String) -> AudioStream:
	var path := "res://audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		push_warning("no such track: %s" % name)
		return null
	return load(path) as AudioStream
