class_name RoomSim
extends RefCounted

## One day in a room you are not standing in.
##
## THE PROMISE THIS KEEPS: a delegated room is resolved by RUNNING THE
## LESSON — the same work model, stall model, disruption model and grading
## the player is subject to — with a hired teacher's policy driving the
## decisions the player would otherwise make with their feet.
##
## It would have been far easier to write a formula. `grade = teacher_skill
## * 0.7 + furniture * 0.3` would produce plausible numbers, and every one of
## them would be a lie: the player could not have produced them by playing,
## and no amount of tuning would make the two agree. Running the model means
## a hired teacher is beatable, and beating them means something.
##
## It is also why the balance contract still covers the school layer. The
## contract is measured from simulated play; delegated rooms ARE simulated
## play; so a room you never enter is held to the same three rows as one you
## teach yourself.
##
## Ticked at a coarse step rather than 1/60. A day resolves instantly and
## nobody is watching the animation, so the only thing that matters is that
## the numbers land in the same place — see STEP.

## Seconds per tick. Coarse enough to resolve a day instantly, fine enough
## that a stall (which needs `stall_grace_seconds` to arm) still happens.
const STEP := 0.25


## Play one lesson in a delegated room and return what happened.
##
## `roster` is the room's own children, `teacher` is a Staff policy, and
## `room_value` is what that room's furniture is worth to a desk — the
## delegated equivalent of Game.room_score().
static func play_day(roster: Array, teacher: Dictionary, room_value: float,
		lesson: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	Balance.ensure_loaded()
	if roster.is_empty():
		return {"average": 0.0, "letter": "F", "collected": 0, "stuck": 0,
			"noisy": 0, "taught": 0.0, "history": []}

	# NOBODY IS NOBODY. An empty teacher dict used to default `teaches` to
	# true, so an unstaffed room quietly taught itself and read almost the
	# same as a staffed one -- which makes hiring optional and contradicts
	# the whole point of a wage bill. A room with no teacher does nothing:
	# the children sit there and the grade is the room alone.
	var staffed: bool = not teacher.is_empty()
	var reaction := float(teacher.get("reaction", 5.0))
	var teaches: bool = staffed and bool(teacher.get("teaches", true))
	var collects: bool = staffed and bool(teacher.get("collects", false))
	var settles: bool = staffed and bool(teacher.get("settles", false))
	var quizzes: bool = staffed and bool(teacher.get("quizzes", false))

	for s: StudentData in roster:
		s.reset_lesson()
		s.assign_work()

	# The same trade the player lives with: every trip to a desk is time not
	# spent at the front, and work only advances while somebody is teaching.
	var away := 0.0
	var taught := 0.0
	## Attention is STATE, ticked up and down, exactly as Game.tick_attention
	## does for the player. It was briefly computed from cumulative sums
	## instead, which made a Supply teacher indistinguishable from an empty
	## room -- their long trips read as "attention 0" rather than "attention
	## draining", so nothing they did ever counted.
	var attention := 0.0
	var stuck_since := {}
	var noisy_since := {}
	var quizzed := false
	var t := 0.0
	var length := Balance.lesson_seconds

	# One frame a second of simulated time, cheap enough to build every
	# call whether or not anyone watches. WATCHING A DELEGATED ROOM reads
	# this back and plays it as an animation, so the frame IS the day --
	# not a decorative guess at what one might have looked like.
	var history: Array = []

	while t < length:
		t += STEP
		away = maxf(0.0, away - STEP)
		var at_front: bool = teaches and away <= 0.0
		if at_front:
			taught += STEP

		if at_front:
			attention = minf(1.0, attention + Balance.teach_fill * STEP)
		else:
			attention = maxf(0.0, attention - Balance.teach_decay * STEP)
		var rate: float = maxf(Balance.teach_floor, attention)

		if quizzes and not quizzed and t > length * 0.4:
			quizzed = true
			for s: StudentData in roster:
				s.take_quiz(rng, String(lesson.get("strand", "math")))
			away = maxf(away, reaction)

		for s: StudentData in roster:
			s.tick_work(STEP, rng, rate)

			if s.disrupting:
				if not settles:
					continue
				if not noisy_since.has(s.id):
					noisy_since[s.id] = t
				elif t - float(noisy_since[s.id]) >= reaction:
					s.settle()
					away = maxf(away, reaction)
					noisy_since.erase(s.id)
				continue
			noisy_since.erase(s.id)

			if s.is_struggling():
				if not stuck_since.has(s.id):
					stuck_since[s.id] = t
				elif t - float(stuck_since[s.id]) >= reaction:
					s.help()
					away = maxf(away, reaction)
					stuck_since.erase(s.id)
			else:
				stuck_since.erase(s.id)
				if s.quiz_flagged and quizzes:
					s.resolve_quiz()

		if fmod(t, 1.0) < STEP:
			var faces: Array = []
			for s: StudentData in roster:
				var state := "working"
				if s.disrupting:
					state = "disrupting"
				elif s.is_struggling():
					state = "stuck"
				elif s.work_fraction() >= 1.0:
					state = "done"
				faces.append({"name": s.display_name, "state": state})
			history.append({"t": t, "at_front": at_front, "faces": faces})

	# marking up
	var total := 0.0
	var collected := 0
	var stuck := 0
	var noisy := 0
	for s: StudentData in roster:
		if collects and s.has_work_to_collect():
			s.collect_work()
			collected += 1
		if s.is_struggling():
			stuck += 1
		if s.disrupting:
			noisy += 1
		total += grade_for(s, room_value)

	var avg: float = total / float(roster.size())
	return {
		"average": avg, "letter": Game.grade_letter(avg),
		"collected": collected, "stuck": stuck, "noisy": noisy,
		"taught": taught / maxf(0.01, length), "history": history,
	}


## The same grade model the player is graded by, with the room's own value
## standing in for Game.room_score(). Deliberately calls nothing on Game
## except the letter bands, so a delegated room cannot accidentally read the
## PLAYER's furniture.
static func grade_for(s: StudentData, room_value: float) -> float:
	Balance.ensure_loaded()
	var lesson_part: float = s.work_fraction() * Balance.lesson_cap
	if s.work_state != StudentData.Work.COLLECTED:
		lesson_part *= Balance.uncollected_penalty
	var hw := 0.0
	if s.hw_state == StudentData.HW.MARKED:
		hw = Balance.homework_cap * s.hw_true_accuracy
	return clampf(room_value + lesson_part + hw + Game.concept_bonus(), 0.0, 1.0)
