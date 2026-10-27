extends "res://tools/playdrive.gd"

## Can the real game be recorded off-screen, repeatably, several at a time?
##
## Phase 0 of the content engine (the owner's marketing video work). This boots
## the real scene on a fixed seed, walks to the podium, starts a lesson, lets it
## run, prints a one-line fingerprint and quits. Run it under Godot's movie
## writer to get footage:
##
##   godot --path . --write-movie out.avi --fixed-fps 30 --resolution 640x352 \
##     --position -6000,-6000 --log-file out.log res://tools/clip_probe.tscn -- <seed> <id> <seconds>
##
## `<id>` names this run's scratch save, so two probes can run at once without
## writing the same file. Not a gate and not part of the suite: it records, it
## does not judge. The fingerprint line lets a second run prove it matches the
## first (same seed, same fingerprint, same frames).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed: int = int(args[0]) if args.size() > 0 else 12345
	var id: String = args[1] if args.size() > 1 else "probe"
	var seconds: float = float(args[2]) if args.size() > 2 else 10.0
	# Wall-clock bound: movie writing is slower than real time, never unbounded.
	watchdog(240.0 + seconds * 10.0, "CLIP PROBE FAILED")
	await boot(run_seed, 1.0, id)
	await frames(6)
	if not await walk_to(Layout.PODIUM + Vector2i(0, 1)):
		print("CLIP PROBE: could not walk to the podium")
	await tap("teach")
	if hud.mode == hud.Mode.HAND:
		await tap("interact")
		await frames(4)
	# 60 physics ticks per second of game time, whatever the movie's frame rate.
	await frames(int(seconds * 60.0))
	print("CLIP PROBE DONE seed=%d id=%s fingerprint=%s" % [run_seed, id, _fingerprint()])
	get_tree().quit()


## Where everything stands, as one string. Equal strings on two runs mean the
## run repeated; it is a cheap check, the frame hashes are the real one.
func _fingerprint() -> String:
	var parts: Array[String] = ["day=%d" % Game.day, "phase=%d" % Game.phase,
		"player=%s" % Grid.world_to_tile(player.global_position)]
	for n: Actor in world.students:
		parts.append("%s@%s" % [n.data.display_name if n.data != null else "?",
			Grid.world_to_tile(n.global_position)])
	return " ".join(parts).md5_text().substr(0, 12)
