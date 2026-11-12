extends Node

## Headless career simulator.
##
##   godot --headless --path . res://tools/careersim.tscn -- [policy|all] [seeds] [max_terms]
##
## Defaults: all, 3, 10. A policy is one of: ideal, good, lazy.
##
## Plays whole RUNS -- term after term, until a term misses its target or
## max_terms is reached -- and prints how long a run lasts for each policy.
## Each day is played by tools/sim.gd's own _play_day() and _shop(), so this
## tool and the term simulator agree on what a day of play is.
##
## WHY THIS EXISTS. The term simulator measures one term at a time. The GDD's
## release phase asks for "balance across a full career rather than a term"
## (GDD section 15, Phase 4). A run that ends on the same term for every
## policy is a balance problem that no single term can show.
##
## READ IT AS A DIRECTION, NOT A MEASUREMENT, as sim.gd asks. Do not tune a
## number to two significant figures against it.

const SIM := preload("res://tools/sim.gd")

const POLICIES := ["ideal", "good", "lazy"]

## The day player. Never added to the tree, so its _ready() never runs.
var _sim: Node = SIM.new()


func _ready() -> void:
	# First: this tool must never write the player's save.
	Game.save_path = "user://edusystem_CAREERSIM_save.json"
	Balance.ensure_loaded()
	var args := OS.get_cmdline_user_args()
	var which: String = String(args[0]) if args.size() > 0 else "all"
	var seeds: int = int(args[1]) if args.size() > 1 else 3
	var max_terms: int = int(args[2]) if args.size() > 2 else 10

	var policies: Array[String] = []
	if which == "all":
		for p: String in POLICIES:
			policies.append(p)
	elif POLICIES.has(which):
		policies.append(which)
	else:
		print("Unknown policy '%s'. Use all, ideal, good or lazy." % which)
		get_tree().quit(1)
		return
	seeds = maxi(1, seeds)
	max_terms = maxi(1, max_terms)

	# Print the engine build, as sim.gd does. A silent version change could
	# move the numbers, and this line is the first thing to check if it does.
	var v := Engine.get_version_info()
	print("Godot %d.%d.%d (%s)" % [v.major, v.minor, v.patch, v.get("status", "")])
	print("\nEDUSystem career simulator - %d seeds, up to %d terms, %d days a term"
		% [seeds, max_terms, Balance.term_days])

	var any_cheated := false
	for policy: String in policies:
		var lengths: Array[int] = []
		var capped := 0
		print("\n--- %s ---" % policy.to_upper())
		for i in seeds:
			var result: Dictionary = _career(policy, 7000 + i, max_terms)
			print(String(result["line"]))
			print(String(result["record"]))
			lengths.append(int(result["terms"]))
			if String(result["ended"]) == "cap":
				capped += 1
			if bool(result["cheated"]):
				any_cheated = true

		var total := 0
		for n: int in lengths:
			total += n
		var mean := float(total) / float(lengths.size())
		print("CAREER %s  runs %d  shortest %d  longest %d  mean %.1f  capped %d" % [
			policy, lengths.size(), lengths.min(), lengths.max(), mean, capped])

	_sim.free()
	Game.delete_save()
	if any_cheated:
		# A reading taken after a cheat is worse than no reading.
		print("")
		print("REFUSING TO REPORT - cheats were used on this run.")
		get_tree().quit(1)
		return
	print("\nCAREER SIM DONE")
	get_tree().quit(0)


## One career: a fresh run, played term after term under one policy.
func _career(policy: String, seed_value: int, max_terms: int) -> Dictionary:
	var buys: bool = bool(SIM.BUYS.get(policy, false))
	Game.wipe_everything()
	Game.new_run(seed_value)

	# A guard against a career that never closes a term. Each term is
	# Balance.term_days days, plus a few spare.
	var guard_limit: int = max_terms * (Balance.term_days + 5)
	var days_played := 0
	var ended := "guard"
	while days_played < guard_limit:
		days_played += 1
		_sim._play_day(policy)
		if buys:
			_sim._shop()
		Game.advance_day()
		if not Game.term_over:
			continue
		var info: Dictionary = Game.next_term()
		if bool(info.get("run_over", false)):
			ended = "missed"
			break
		if Game.term > max_terms:
			ended = "cap"
			break
		_choose_path()

	var terms: int = Game.term_history.size()
	var status := "ended: %s" % ended
	if ended == "missed" and terms > 0:
		var last: Dictionary = Game.term_history[terms - 1]
		status = "ended: missed (%d of %d, needed %d)" % [
			int(last.get("passed", 0)), int(last.get("total", 0)), int(last.get("target", 0))]

	# The term-by-term record: letter, passed/target, and a bang on a miss.
	var parts := PackedStringArray()
	for row: Dictionary in Game.term_history:
		var mark := "" if bool(row.get("met", false)) else "!"
		parts.append("T%d %s %d/%d%s" % [
			int(row.get("term", 0)), String(row.get("letter", "F")),
			int(row.get("passed", 0)), int(row.get("target", 0)), mark])
	var record := "    no term closed" if parts.is_empty() else "    " + "  ".join(parts)

	var line := "  seed %d  terms %d  %s  coins %d  items %d  sent up %d" % [
		seed_value, terms, status, Game.coins, Game.room_items.size(), Game.graduated.size()]
	return {"line": line, "record": record, "terms": terms, "ended": ended,
		"cheated": Game.cheated}


## Picks the term's path as a plain player would: the ordinary term if it is
## on offer, else the first card that is not a boss. A boss needs a fight
## that this tool does not play.
func _choose_path() -> void:
	var hand: Array = Game.term_path_hand
	if hand.is_empty():
		return
	var pick := -1
	for i in hand.size():
		var ordinary: Dictionary = hand[i]
		if String(ordinary.get("id", "")) == "ordinary_term":
			pick = i
			break
	if pick < 0:
		for i in hand.size():
			var card: Dictionary = hand[i]
			if String(card.get("kind", "")) != "boss":
				pick = i
				break
	if pick < 0:
		pick = 0
	Game.choose_term_path(pick)
