extends Node

## THE PHASE 1 GATE, from docs/GDD.md:
##
##   "The two altitudes may not both be fun. The whole design rests on a
##    delegated room being interesting to READ. It might just be a table of
##    letters. Mitigation: Phase 1 exists to answer exactly this, before
##    anything is built on top of it."
##
## So this runs a term of delegated rooms and prints what the player would
## actually see each evening. Two questions, and neither is answerable by
## looking at the code:
##
##   1. Do different teachers produce DIFFERENT, legible outcomes? If a
##      Supply teacher and a Veteran both return "C", hiring is decoration.
##   2. Does a room's result MOVE? If every room reads the same letter every
##      day, the evening board is wallpaper and there is no reason to walk
##      into any of them tomorrow.
##
##   godot --headless --path . res://tools/schoolsim.tscn

const DAYS := 20


func _ready() -> void:
	Balance.ensure_loaded()
	Game.save_path = "user://edusystem_SCHOOLSIM_save.json"
	print("\n============ A TERM OF DELEGATED ROOMS ============")
	print("Does hiring matter, and does the board move?\n")

	_by_archetype()
	_a_term()
	_the_money()

	print("==================================================\n")
	get_tree().quit()


## One room per archetype, same children, same furniture. If these letters
## are all the same, hiring is decoration.
func _by_archetype() -> void:
	print("-- the same class, six different teachers --")
	print("   %-13s %-6s %-6s %-6s %-6s %s" % [
		"teacher", "avg", "letter", "coll", "stuck", "taught"])
	for a: Dictionary in Staff.ARCHETYPES:
		var totals := 0.0
		var coll := 0
		var stuck := 0
		var taught := 0.0
		var runs := 6
		for r in runs:
			Game.new_run(4000 + r)
			var roster := _class_of(6, 4000 + r)
			var res := RoomSim.play_day(roster, a, Balance.room_base + 0.12,
				Game.lesson, Game.rng)
			totals += float(res["average"])
			coll += int(res["collected"])
			stuck += int(res["stuck"])
			taught += float(res["taught"])
		var avg := totals / float(runs)
		print("   %-13s %-6.2f %-6s %-6.1f %-6.1f %.0f%%" % [
			String(a["name"]), avg, Game.grade_letter(avg),
			float(coll) / float(runs), float(stuck) / float(runs),
			taught / float(runs) * 100.0])
	print("")


## A whole term of one school, printed the way the evening board prints it.
func _a_term() -> void:
	Game.new_run(90210)
	Game.coins = 999999
	for i in 3:
		Game.open_room()
	# a good one, a cheap one, and one nobody is teaching -- so the board has
	# something to say rather than three identical rows
	Game.applicants = [Staff.archetype("veteran").duplicate(),
		Staff.archetype("supply").duplicate()]
	Game.applicants[0]["name"] = "Dr Okafor"
	Game.applicants[1]["name"] = "Mr Petrov"
	Game.hire(0, 0)
	Game.hire(1, 0)
	Game.furnish_room(0)
	Game.furnish_room(0)

	print("-- twenty evenings, as the player would read them --")
	print("   day  %-11s %-11s %-11s" % ["Room 2", "Room 3", "Room 4"])
	var seen := {}
	for day in DAYS:
		Game.lesson = Curriculum.pick(Game.rng)
		var rows := Game.resolve_rooms()
		var cells: Array[String] = []
		for r: Dictionary in rows:
			var l := String(r.get("letter", "-"))
			seen[l] = int(seen.get(l, 0)) + 1
			cells.append("%s %s" % [l, "!" if int(r.get("stuck", 0)) > 1 else " "])
		if day % 2 == 0 or day == DAYS - 1:
			print("   %-4d %-11s %-11s %-11s" % [day + 1,
				cells[0] if cells.size() > 0 else "-",
				cells[1] if cells.size() > 1 else "-",
				cells[2] if cells.size() > 2 else "-"])

	print("")
	print("   letters seen across the term: %s" % [seen])
	print("   wage bill: %d/day" % Game.wage_bill())
	Game.delete_save()


## GDD RISK 3: "the economy is tuned for one room. Six rooms multiply every
## sink and leave income per room flat."
##
## So this runs a term of a growing school and prints the money. A school
## that cannot pay its own wages is not a difficulty curve, it is a wall.
func _the_money() -> void:
	print("-- can a school pay for itself? --")
	print("   %-6s %-7s %-7s %-7s %-8s %s" % [
		"rooms", "wages", "upkeep", "earned", "balance", "verdict"])
	for n in range(0, 5):
		Game.new_run(5150)
		Game.coins = 100000
		for i in n:
			Game.open_room()
		# staff every room with the middle of the market
		for i in Game.rooms.size():
			Game.applicants = [Staff.archetype("steady").duplicate()]
			Game.applicants[0]["name"] = "Mr Test %d" % i
			Game.hire(i, 0)
			Game.furnish_room(i)
			Game.furnish_room(i)

		# what a day pays, across the whole school
		var earned := 0.0
		for day in 10:
			Game.lesson = Curriculum.pick(Game.rng)
			var rows := Game.resolve_rooms()
			for r: Dictionary in rows:
				# the same rate the player's own class is paid at
				earned += float(r["average"]) * Balance.coins_per_grade_point 					* float(Balance.school_class_size)
		earned /= 10.0

		var wages := Game.wage_bill()
		var upkeep := Game.room_items.size() * Balance.upkeep_per_item
		var balance := int(earned) - wages - upkeep
		print("   %-6d %-7d %-7d %-7d %-8d %s" % [
			n + 1, wages, upkeep, int(earned), balance,
			"solvent" if balance > 0 else "LOSES MONEY"])
	print("")


func _class_of(n: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for i in n:
		var s := StudentData.new()
		s.id = i + 1
		s.display_name = "Child %d" % i
		s.aptitude = rng.randf_range(0.25, 0.85)
		s.diligence = rng.randf_range(0.25, 0.85)
		s.trait_id = Traits.roll(rng)
		s.seat_index = i
		out.append(s)
	return out
