extends "res://tools/playterm.gd"

## Record the whole-term bot, at normal speed, as a named teacher, in segments.
##
## The content engine's long-run recorder. playterm.gd already plays real days through
## the real buttons; this runs it at speed 1 (so the footage moves like the game) and
## quits after a fixed amount of GAME time, so each recording is a segment of a few
## minutes that can be converted and deleted before the next one starts.
##
##   godot --path . --write-movie out.avi --fixed-fps 30 --resolution 640x352 \
##     --position -6000,-6000 --log-file out.log res://tools/clip_term.tscn -- \
##     <seed> <id> <teacher name> <game seconds>
##
## `<id>` names the scratch save, so recorders at the same time do not share a file.
## Not a gate and not in the suite. It prints CLIP TERM DONE when the segment ends.

var _limit_frames := 0
var _frames := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed: int = int(args[0]) if args.size() > 0 else 777
	var id: String = args[1] if args.size() > 1 else "term"
	var teacher: String = args[2] if args.size() > 2 else ""
	var seconds: float = float(args[3]) if args.size() > 3 else 300.0
	_limit_frames = int(seconds * 60.0)
	# Movie writing is slower than real time; this bounds a hung run, not a slow one.
	watchdog(seconds * 6.0 + 600.0, "CLIP TERM FAILED")
	await boot(run_seed, 1.0, id)
	Game.teacher_name = teacher
	await _play()
	_finish()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _limit_frames > 0 and _frames >= _limit_frames:
		_finish()


func _finish() -> void:
	if _limit_frames < 0:
		return
	_limit_frames = -1
	print("CLIP TERM DONE teacher=%s day=%d term=%d frames=%d" % [
		Game.teacher_name, Game.day, Game.term, _frames])
	get_tree().quit()
