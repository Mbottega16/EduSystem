class_name BossFight
extends RefCounted

## THE FIGHT. The last day of a boss term is not a lesson -- it is the
## assessment itself, played in the room in real time: the examiner at the
## front, the class sitting the paper, and the teacher walking the room
## while the paper throws questions at it.
##
## It runs in ROUNDS. Each round the paper makes one MOVE against the class
## (the boss card's own `moves` list -- a Reading Paper freezes the slow
## readers, a Number Gauntlet chains freezes along the desks, a Mock
## Election sets the room arguing, a Science Fair puts one child up front
## to present). The teacher answers with the verbs they already have:
##
##   E at a desk   steady a frozen child (the ordinary help verb, reworded)
##   E / voice     settle a child the paper has set off
##   standing near stay with the child who is presenting
##   J             talk the whole room through it (the mass-help, held not
##                 rallied -- a panic button, never the best answer)
##
## MARKS. Every child the paper touches in a round ends it one of three
## ways: RALLIED (dealt with quickly), HELD (dealt with in time), or DROPPED
## (still frozen / still shouting / left alone up front when the question
## moved on). finish() turns the tally into one small per-child nudge on
## the exam they sit that afternoon -- `StudentData.boss_delta`, read by
## Game.exam_score_for(), clamped to `bosses.fight.max_swing` either way.
## The exam is still the child's own record; this is how they held up on
## the day, and the whole swing is about half a letter. The contract sim
## (tools/sim.gd) never sees any of it -- test_boss_fight() scans for that.
##
## PROSE, NEVER NUMBERS: the tally is numbers in here, and words the moment
## it reaches a screen (outcome_word(), composure_word(), question_text()).
##
## DETERMINISM: every pick goes through the rng the caller passes, which is
## Game.rng -- nothing in here calls randi()/randf().
##
## Pure state + a tick(); the room (classroom.gd) drives it, drains
## `events` for floaters and banners, and the HUD reads it for the strip.
## No node, no signal, no autoload dependency beyond Balance/Layout/Game
## lookups, so the whole thing runs headless in the suite.

enum Stage { BREATH, ROUND, DONE }

## The kinds of move a card can list. Anything else in a card's `moves`
## is treated as "freeze" so a typo in balance.json degrades, not crashes.
const KINDS := ["freeze", "chain", "noise", "present"]

## What the paper says as each round opens -- flavour keyed by move and
## strand, cycled by round. Content, not tunables, so it lives here the
## same way DayBeats' lines do. A gauntlet (Open Evening) borrows from the
## "any" pool. No numbers in any of these, on purpose.
const QUESTIONS := {
	"freeze": {
		"ela": ["The long passage.", "A word none of them has met.",
			"What the author meant, in their own words.", "Read it back, alone."],
		"math": ["Seven eights, on the spot.", "The one with the remainder.",
			"A fraction of a fraction.", "Show the working."],
		"science": ["Why the ice floats.", "Name the parts of the flower.",
			"What happens if you take the sun away.", "Predict, then explain."],
		"social": ["Where the river runs.", "Who decides, and why them.",
			"What a fair rule looks like.", "Then and now, side by side."],
		"any": ["The question nobody revised.", "The one that looks easy and is not.",
			"A blank page, and a clock.", "The last question, worth the most."],
	},
	"chain": {
		"ela": ["Spell it -- and the next one, and the next."],
		"math": ["Nobody may freeze. Times tables, round the room."],
		"science": ["The food chain -- each link names the next."],
		"social": ["Every capital, in order, desk by desk."],
		"any": ["Round the room, one after another, no gaps."],
	},
	"noise": {
		"ela": ["Who was right, the hero or the villain?"],
		"math": ["Two answers, and both of them sure."],
		"science": ["Is a tomato a fruit? Argue it."],
		"social": ["Both sides argued, out loud, at once."],
		"any": ["The room takes sides."],
	},
	"present": {
		"ela": ["One reader, the whole room listening."],
		"math": ["One child at the board, showing the method."],
		"science": ["Present the experiment to strangers."],
		"social": ["Make the case, in front of everyone."],
		"any": ["Up front, alone, everybody watching."],
	},
}

var card: Dictionary = {}
var strand: String = "any"
var moves: Array = []
var round: int = 0
var stage: int = Stage.BREATH
## Seconds into the current stage.
var t: float = 0.0

## sid -> {"since": seconds-into-round, "mass": bool} for the children the
## current round has frozen and not yet resolved.
var frozen: Dictionary = {}
## sid -> seconds-into-round for the children the round set off.
var noisy: Dictionary = {}
## The child presenting this round, or -1.
var presenting: int = -1
var present_t: float = 0.0
var _chain_t: float = 0.0

## sid -> {"rallied": int, "held": int, "dropped": int}, the whole fight.
var tally: Dictionary = {}
## Every resolution, in order: [{sid, round, kind, outcome}].
var log: Array = []
## Drained by the room each tick. "breath", "round", "done", and
## "<outcome>:<sid>" for each child the round resolves, "freeze:<sid>" /
## "noise:<sid>" / "present:<sid>" when a move lands on someone.
var events: Array = []

var _roster: Array = []


# ------------------------------------------------------------------ setup

func start(boss_card: Dictionary, roster: Array, _rng: RandomNumberGenerator) -> void:
	Balance.ensure_loaded()
	card = boss_card.duplicate()
	strand = String(card.get("strand", "any"))
	if not QUESTIONS["freeze"].has(strand):
		strand = "any"
	moves = []
	for m in card.get("moves", []):
		var k := String(m)
		moves.append(k if KINDS.has(k) else "freeze")
	if moves.is_empty():
		moves = ["freeze"]
	_roster = roster
	round = 0
	stage = Stage.BREATH
	t = 0.0
	frozen.clear()
	noisy.clear()
	presenting = -1
	present_t = 0.0
	_chain_t = 0.0
	tally.clear()
	log.clear()
	events.clear()
	for s: StudentData in _roster:
		tally[s.id] = {"rallied": 0, "held": 0, "dropped": 0}
	# The first real draw happens in _begin_round(), off the rng tick()
	# is handed -- start() takes one only so every caller passes the same
	# shape and a future "roll the first round early" is a one-line change.
	events.append("breath")


func active() -> bool:
	return stage != Stage.DONE


func total_rounds() -> int:
	return moves.size()


func round_kind() -> String:
	if round < 0 or round >= moves.size():
		return ""
	return String(moves[round])


func boss_name() -> String:
	return String(card.get("name", "the assessment"))


## How long the whole thing runs, for the lesson clock.
func total_seconds() -> float:
	Balance.ensure_loaded()
	return float(moves.size()) \
		* (Balance.fight_round_seconds + Balance.fight_breath_seconds)


## Seconds until the paper is over, counting the current stage.
func seconds_left() -> float:
	Balance.ensure_loaded()
	if stage == Stage.DONE:
		return 0.0
	var per := Balance.fight_round_seconds + Balance.fight_breath_seconds
	var rounds_after: int = maxi(0, moves.size() - round - 1)
	var this_stage: float
	if stage == Stage.BREATH:
		this_stage = maxf(0.0, Balance.fight_breath_seconds - t) \
			+ Balance.fight_round_seconds
	else:
		this_stage = maxf(0.0, Balance.fight_round_seconds - t)
	return this_stage + float(rounds_after) * per


## Seconds left in the round in progress (0 during a breath).
func round_left() -> float:
	Balance.ensure_loaded()
	if stage != Stage.ROUND:
		return 0.0
	return maxf(0.0, Balance.fight_round_seconds - t)


## The banner line for the round about to start / in progress.
func question_text() -> String:
	var kind := round_kind()
	if kind == "":
		return ""
	var pool: Dictionary = QUESTIONS.get(kind, QUESTIONS["freeze"])
	var lines: Array = pool.get(strand, pool["any"])
	if lines.is_empty():
		lines = pool["any"]
	# a round counter is a count of rounds, not a claim about a child --
	# the same sanctioned exception the day counter lives under
	return "Question %d of %d -- %s" % [round + 1, moves.size(),
		String(lines[round % lines.size()])]


# ------------------------------------------------------------------- tick

## Advance the fight. `teacher_tile` is where the teacher is standing, for
## the presenting move. Everything random goes through `rng`.
func tick(delta: float, rng: RandomNumberGenerator, teacher_tile: Vector2i) -> void:
	Balance.ensure_loaded()
	if stage == Stage.DONE:
		return
	t += delta
	if stage == Stage.BREATH:
		if t >= Balance.fight_breath_seconds:
			_begin_round(rng)
		return
	_tick_round(delta, rng, teacher_tile)
	if t >= Balance.fight_round_seconds:
		_end_round()
		round += 1
		t = 0.0
		if round >= moves.size():
			stage = Stage.DONE
			events.append("done")
		else:
			stage = Stage.BREATH
			events.append("breath")


func _begin_round(rng: RandomNumberGenerator) -> void:
	stage = Stage.ROUND
	t = 0.0
	frozen.clear()
	noisy.clear()
	presenting = -1
	present_t = 0.0
	_chain_t = 0.0
	match round_kind():
		"freeze":
			for s: StudentData in _pick(rng, Balance.fight_freeze_count, {}):
				_freeze(s)
		"chain":
			for s: StudentData in _pick(rng, 1, {}):
				_freeze(s)
		"noise":
			for s: StudentData in _pick(rng, Balance.fight_noise_count, {}):
				_set_off(s)
		"present":
			for s: StudentData in _pick(rng, 1, {}):
				presenting = s.id
				events.append("present:%d" % s.id)
	events.append("round")


func _tick_round(delta: float, rng: RandomNumberGenerator, teacher_tile: Vector2i) -> void:
	# --- frozen children who have been steadied ---
	for sid: int in frozen.keys():
		var s := _by_id(sid)
		if s == null:
			frozen.erase(sid)
			continue
		if not s.is_struggling():
			var row: Dictionary = frozen[sid]
			var quick: bool = (t - float(row["since"])) <= Balance.fight_quick_seconds
			_resolve(s, "held" if bool(row["mass"]) or not quick else "rallied")
			frozen.erase(sid)

	# --- the chain spreads along the desks while anyone is still frozen ---
	if round_kind() == "chain" and not frozen.is_empty():
		_chain_t += delta
		if _chain_t >= Balance.fight_chain_spread_seconds:
			_chain_t = 0.0
			var candidates: Array = []
			for sid: int in frozen.keys():
				var s := _by_id(sid)
				if s == null:
					continue
				for m: StudentData in Game.neighbours_of(s):
					if not frozen.has(m.id) and not m.is_struggling() \
							and not candidates.has(m):
						candidates.append(m)
			if not candidates.is_empty():
				_freeze(candidates[rng.randi_range(0, candidates.size() - 1)])

	# --- children the paper set off, now settled ---
	for sid: int in noisy.keys():
		var s := _by_id(sid)
		if s == null:
			noisy.erase(sid)
			continue
		if not s.disrupting:
			var quick: bool = (t - float(noisy[sid])) <= Balance.fight_quick_seconds
			_resolve(s, "rallied" if quick else "held")
			noisy.erase(sid)

	# --- the presenter needs the teacher near; the audience gets restless ---
	if presenting >= 0:
		var p := _by_id(presenting)
		if p != null and p.seat_index >= 0:
			var seat := Layout.seat(p.seat_index)
			var dist: int = absi(seat.x - teacher_tile.x) + absi(seat.y - teacher_tile.y)
			if dist <= Balance.fight_present_radius:
				present_t += delta
		for s: StudentData in _roster:
			if s.id == presenting or s.seat_index < 0 or s.disrupting:
				continue
			if rng.randf() < Balance.fight_restless_per_second * delta:
				_set_off(s)


func _end_round() -> void:
	# whoever is still frozen when the question moves on has dropped it
	for sid: int in frozen.keys():
		var s := _by_id(sid)
		if s != null:
			s.unfreeze()
			_resolve(s, "dropped")
	frozen.clear()
	for sid: int in noisy.keys():
		var s := _by_id(sid)
		if s != null:
			s.disrupting = false
			_resolve(s, "dropped")
	noisy.clear()
	if presenting >= 0:
		var p := _by_id(presenting)
		if p != null:
			if present_t >= Balance.fight_present_rally_seconds:
				_resolve(p, "rallied")
			elif present_t >= Balance.fight_present_seconds:
				_resolve(p, "held")
			else:
				_resolve(p, "dropped")
		presenting = -1
		present_t = 0.0


## J -- the mass-help. Everyone frozen right now is talked through it: they
## count as HELD, never rallied. Called by Game.run_answer_all() before it
## clears the confusion, so the tick above sees the flag.
func mass_steady() -> void:
	for sid: int in frozen.keys():
		frozen[sid]["mass"] = true


# ---------------------------------------------------------------- reading

## Marks kept over marks resolved so far, 0..1. Before anything has been
## resolved the room is, by definition, steady.
func composure() -> float:
	var kept := 0
	var all := 0
	for sid in tally:
		var row: Dictionary = tally[sid]
		kept += int(row["rallied"]) + int(row["held"])
		all += int(row["rallied"]) + int(row["held"]) + int(row["dropped"])
	if all == 0:
		return 1.0
	return float(kept) / float(all)


## The room, in a word. Thresholds from balance.json, never a number shown.
func composure_word() -> String:
	Balance.ensure_loaded()
	var c := composure()
	if c >= Balance.fight_composure_steady:
		return "steady"
	if c >= Balance.fight_composure_wobbling:
		return "wobbling"
	if c >= Balance.fight_composure_cracking:
		return "cracking"
	return "gone"


## One child's fight, in a phrase.
func outcome_word(s: StudentData) -> String:
	var row: Dictionary = tally.get(s.id, {"rallied": 0, "held": 0, "dropped": 0})
	var r := int(row["rallied"])
	var h := int(row["held"])
	var d := int(row["dropped"])
	if r + h + d == 0:
		return "sat it quietly"
	if d == 0 and r > 0:
		return "rose to it"
	if d == 0:
		return "held steady"
	if r + h >= d:
		return "wobbled, held"
	return "lost it"


func counts() -> Dictionary:
	var out := {"rallied": 0, "held": 0, "dropped": 0}
	for sid in tally:
		for k: String in out:
			out[k] += int(tally[sid][k])
	return out


## Close the book: turn the tally into each child's boss_delta and hand
## back the report the HUD shows. Idempotent -- a second call rebuilds the
## same report from the same tally.
func finish() -> Dictionary:
	Balance.ensure_loaded()
	var rows: Array = []
	for s: StudentData in _roster:
		var row: Dictionary = tally.get(s.id, {"rallied": 0, "held": 0, "dropped": 0})
		var delta: float = Balance.fight_rally_mark * float(row["rallied"]) \
			- Balance.fight_drop_mark * float(row["dropped"])
		s.boss_delta = clampf(delta, -Balance.fight_max_swing, Balance.fight_max_swing)
		if int(row["rallied"]) >= 2 and int(row["dropped"]) == 0 \
				and not s.has_moment("rose_to_paper"):
			s.note_moment("rose_to_paper", Game.day)
		elif int(row["dropped"]) >= 2 and not s.has_moment("froze_on_paper"):
			s.note_moment("froze_on_paper", Game.day)
		rows.append({"student": s, "word": outcome_word(s),
			"rallied": int(row["rallied"]), "held": int(row["held"]),
			"dropped": int(row["dropped"])})
	var c := counts()
	return {
		"boss": boss_name(), "boss_id": String(card.get("id", "")),
		"strand": strand, "rounds": moves.size(),
		"rows": rows, "composure": composure_word(),
		"rallied": c["rallied"], "held": c["held"], "dropped": c["dropped"],
	}


# ---------------------------------------------------------------- helpers

func _by_id(sid: int) -> StudentData:
	for s: StudentData in _roster:
		if s.id == sid:
			return s
	return null


func _freeze(s: StudentData) -> void:
	if s == null or frozen.has(s.id):
		return
	s.freeze()
	frozen[s.id] = {"since": t, "mass": false}
	events.append("freeze:%d" % s.id)


func _set_off(s: StudentData) -> void:
	if s == null or noisy.has(s.id) or s.disrupting:
		return
	s.disrupting = true
	noisy[s.id] = t
	events.append("noise:%d" % s.id)


func _resolve(s: StudentData, outcome: String) -> void:
	if not tally.has(s.id):
		tally[s.id] = {"rallied": 0, "held": 0, "dropped": 0}
	tally[s.id][outcome] = int(tally[s.id][outcome]) + 1
	log.append({"sid": s.id, "round": round, "kind": round_kind(), "outcome": outcome})
	events.append("%s:%d" % [outcome, s.id])


## `n` seated children, weighted toward the ones who find the work hardest
## -- the same shape as StudentData.stall_chance() -- drawn without
## replacement through the run's own rng. `exclude` is sid -> true.
func _pick(rng: RandomNumberGenerator, n: int, exclude: Dictionary) -> Array:
	var pool: Array = []
	for s: StudentData in _roster:
		if s.seat_index >= 0 and not exclude.has(s.id) and not s.is_struggling():
			pool.append(s)
	var out: Array = []
	for i in mini(n, pool.size()):
		var total := 0.0
		for s: StudentData in pool:
			total += 1.4 - 0.8 * s.aptitude
		if total <= 0.0:
			break
		var pick := rng.randf() * total
		var chosen: int = pool.size() - 1
		for j in pool.size():
			pick -= 1.4 - 0.8 * (pool[j] as StudentData).aptitude
			if pick <= 0.0:
				chosen = j
				break
		out.append(pool[chosen])
		pool.remove_at(chosen)
	return out
