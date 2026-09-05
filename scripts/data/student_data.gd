class_name StudentData
extends RefCounted

## One student's record.
##
## Deliberately a RefCounted and NOT a Node. Keeping the record off the scene
## tree is what lets grading, homework and a whole simulated term be tested
## headlessly with no scene at all.

## Homework lifecycle. NONE until a lesson assigns it.
enum HW { NONE, ASSIGNED, DONE, NOT_DONE, COLLECTED, MARKED }

## In-lesson classwork: assigned at the podium, worked on, collected from the
## desk, handed in at yours.
enum Work { NONE, WORKING, DONE, COLLECTED }

# --- identity ---------------------------------------------------------
var id: int = 0
var display_name: String = ""
var art: String = "student_a"
var seat_index: int = -1

# --- ability. Two numbers on purpose; resist growing this to four. ----
var aptitude: float = 0.5          ## 0..1 — resistance to getting stuck
var diligence: float = 0.5         ## 0..1 — will they do the homework
## The one subject this student is good at. Gives the day's subject a
## reason to exist beyond being a label.
var favourite: String = ""

## How they behave while they work — see scripts/data/traits.gd. Aptitude
## says how well they do it; this says what you have to DO about them.
var trait_id: String = ""

## Messing about. NOT the same as being stuck: a stuck child has stopped
## and wants you, a disruptive one has stopped and is stopping the children
## either side of them as well.
var disrupting: bool = false

## Have they got the materials for today's lesson in front of them?
## True on an ordinary day -- only a materials day (DayEvent "supplies")
## ever sets it false, and then it is the teacher's job to walk round and
## put that right before the bell. A child who starts the lesson without
## their things works slower all day, and the file's third page says so.
var has_supply: bool = true
## A flare-up brewing: seconds left on the warning before they tip over into
## disrupting. 0 means no flare. Catch it with E at their desk in time and
## it is defused; let it run out and `disrupting` takes over. See the flare
## section in balance.json.
var flare_left: float = 0.0
## Copied their way out of being stuck. The work moves, the understanding
## does not -- which is exactly what copying is.
var copied: bool = false

## Seconds this child has been stuck without letting on. A Quiet student
## hides it for a while, which is the whole point of them: you cannot
## triage by scanning for bubbles alone.
var _hidden_for: float = 0.0

# --- per-lesson, reset by reset_lesson() ------------------------------
var work_state: int = Work.NONE
var work_timer: float = 0.0        ## seconds of UNSTUCK work still needed
## How long the sheet they were given actually was. A hard lesson is longer
## work, so progress has to be measured against THIS rather than against the
## global work_seconds -- otherwise a hard lesson could never reach 100% and
## an easy one would sail past it.
var work_total: float = 0.0
var confusion: float = 0.0
var helps_received: int = 0        ## for the report; not a grade input

## What they scored on today's quiz, 0..1, or -1 if none was set. Unlike
## aptitude this is something the PLAYER is allowed to see -- that is the
## entire point of running one.
var quiz_score: float = -1.0
## They came out below the line and nobody has been over it with them yet.
## Actionable: it unlocks a verb at their desk that is not otherwise there.
var quiz_flagged: bool = false

# --- homework, persists across days -----------------------------------
var hw_state: int = HW.NONE
var hw_true_accuracy: float = 0.0  ## hidden from the player
var hw_player_verdict: int = -1    ## -1 unset, 0 "not yet", 1 "got it"
var hw_sheet: Dictionary = {}
## Set when you passed a sheet that did not deserve it. That student is
## secretly behind, so they stall more next lesson — which is exactly what
## the marking screen has always claimed happens.
var misjudged: bool = false

# --- progression --------------------------------------------------
## Students get better simply by being taught. XP STOPS accruing once they
## are well past ready (ready_level + hold_grace): a child kept long after
## they were ready has learned what you can teach them. That is a soft cost
## for holding them back -- they stagnate -- rather than a punishment.
var xp: int = 0
var level: int = 1
var coached: int = 0          ## how many times you have paid for extra help

# --- lifetime, NEVER reset ---------------------------------------
## Kept apart from the per-lesson counters above on purpose:
## reset_lesson() wipes helps_received every single lesson, so it can
## never answer "how often have I helped this child".
var joined_day: int = 1
var helps_total: int = 0
var hw_set_total: int = 0
var hw_done_total: int = 0

# --- history ----------------------------------------------------------
var grades: Array[float] = []
var last_grade: float = -1.0

## This child's own record: what they were taught, when, and how they did.
## Kept per-student rather than as a class log because it is THEIRS -- it
## travels with them when they are sent up, and it is the thing that makes a
## roster of eight into eight particular children rather than eight rows.
## [{lesson, name, standard, day, grade}]
var transcript: Array = []

## The highlight reel: a handful of things that HAPPENED to this particular
## child -- the first time they got stuck, a grade that jumped, the day the
## quiz caught them out. Stored as {kind, day}, never prose, so the story
## page renders it (and "prose never numbers" stays a display concern).
## Append-only via note_moment(); capped at Balance.moments_cap.
var moments: Array = []
## Consecutive LESSONS graded in their own best subject (ten-commits.md
## step 6) -- reset the moment a lesson in a different strand is taught,
## so it is a streak and not a lifetime total. Only ever read by
## Game.grade_class(), which is also the only place that resets it.
var _favourite_streak: int = 0
## How they held up on the day of the boss assessment: the fight's per-child
## nudge on the exam, set by BossFight.finish() and read by
## Game.exam_score_for(). Zero on any ordinary term. Clamped to
## +-Balance.fight_max_swing before it is ever stored, saved so quitting
## between the paper and the bell does not lose the morning.
var boss_delta: float = 0.0

var _since_stall: float = 0.0


## Every screen shows the first name, and this used to be
## display_name.split(" ")[0] repeated in five places.
func first_name() -> String:
	var parts := display_name.split(" ", false)
	return parts[0] if parts.size() > 0 else display_name


func surname() -> String:
	var parts := display_name.split(" ", false)
	return parts[1] if parts.size() > 1 else ""


func is_struggling() -> bool:
	return confusion > 0.5


## One line in their record. Called once per graded lesson.
func record_result(lesson: Dictionary, grade: float, day: int,
		was_test: bool = false) -> void:
	transcript.append({
		"lesson": String(lesson.get("id", "")),
		"name": String(lesson.get("name", "Lesson")),
		"standard": String(lesson.get("standard", "")),
		"day": day, "grade": grade, "test": was_test,
	})
	# A grade that lands a letter band away from how they had been doing is
	# worth remembering. The caller appends `grade` to `grades` BEFORE this
	# runs, so the "before" picture is every grade except the last.
	if grades.size() >= Balance.moments_grade_min_history + 1:
		var prior := 0.0
		for i in grades.size() - 1:
			prior += grades[i]
		prior /= float(grades.size() - 1)
		if Game.grade_letter(grade) != Game.grade_letter(prior):
			note_moment("grade_jump" if grade > prior else "grade_drop", day)


## Add one moment to the highlight reel. Deliberately dumb: it stores a
## `kind` id and a day, nothing prose, and it caps itself by keeping the
## FIRST entry (their origin beat) plus the most recent ones.
func note_moment(kind: String, day: int) -> void:
	moments.append({"kind": kind, "day": day})
	if moments.size() > Balance.moments_cap:
		moments.remove_at(1)


## Has this child already had a moment of this kind? For the once-only
## beats -- the first stall, the first time the quiz caught them out.
func has_moment(kind: String) -> bool:
	for m: Dictionary in moments:
		if String(m.get("kind", "")) == kind:
			return true
	return false


## Only the tests. A unit result carries more than a day's lesson did, and
## a record you cannot separate the two in is not much of a record.
func tests_taken() -> Array:
	var out: Array = []
	for row: Dictionary in transcript:
		if bool(row.get("test", false)):
			out.append(row)
	return out


## Their best subject BY RESULT rather than by the favourite they were born
## with -- what they turned out to be good at, which is not always the same
## thing. Empty until they have actually sat something.
func best_subject() -> String:
	var totals := {}
	var counts := {}
	for row: Dictionary in transcript:
		var n := String(row.get("name", ""))
		totals[n] = float(totals.get(n, 0.0)) + float(row.get("grade", 0.0))
		counts[n] = int(counts.get(n, 0)) + 1
	var best := ""
	var best_avg := -1.0
	for n: String in totals.keys():
		var avg: float = float(totals[n]) / float(counts[n])
		if avg > best_avg:
			best_avg = avg
			best = n
	return best


func average_grade() -> float:
	if grades.is_empty():
		return 0.0
	var total := 0.0
	for g: float in grades:
		total += g
	return total / float(grades.size())


func reset_lesson() -> void:
	work_state = Work.NONE
	work_timer = 0.0
	work_total = 0.0
	confusion = 0.0
	helps_received = 0
	quiz_score = -1.0
	quiz_flagged = false
	disrupting = false
	flare_left = 0.0
	copied = false
	_since_stall = 0.0
	_hidden_for = 0.0


## Have a word. Returns false if they were behaving, so this can never
## become a second Help you spam at everybody.
func settle() -> bool:
	Balance.ensure_loaded()
	if not disrupting:
		return false
	disrupting = false
	confusion = 0.0
	_since_stall = 0.0
	_hidden_for = 0.0
	helps_received += 1
	helps_total += 1
	add_xp(Balance.dis_settle_xp)
	return true


## Is a flare-up brewing at this desk right now?
func flaring() -> bool:
	return flare_left > 0.0


## Got there in time. Returns false if there was nothing to catch, so it can
## never become a second verb you mash at everybody. A small XP nudge for
## the child; the coin tip is paid by the caller (it is a Game concern).
func defuse() -> bool:
	Balance.ensure_loaded()
	if flare_left <= 0.0:
		return false
	flare_left = 0.0
	_since_stall = 0.0
	add_xp(Balance.flare_defuse_xp)
	return true


## Lean over and copy the desk next door.
##
## The point of this is that it LOOKS like the problem solved itself. The
## work moves and the "?" goes away, so a player watching bubbles sees a
## child who sorted themselves out -- and then the quiz, the homework and
## the test all quietly disagree, because copying is not understanding.
func copy_from(other: StudentData) -> bool:
	if not is_struggling() or other == null:
		return false
	if other.work_fraction() <= work_fraction():
		return false
	confusion = 0.0
	_since_stall = 0.0
	_hidden_for = 0.0
	copied = true
	work_timer = maxf(0.0, work_timer - 2.0)
	return true


# ---------------------------------------------------------------- quiz

## How well they understand TODAY'S lesson, right now. Built from what the
## game already knows rather than from a new hidden stat: their aptitude,
## how far into the work they have actually got, whether this is their
## subject, and whether you waved through a homework sheet that was secretly
## wrong. That last one is what makes a quiz able to catch a bad marking
## call before it becomes a bad grade.
func understanding(strand: String) -> float:
	Balance.ensure_loaded()
	var u := aptitude * 0.65 + work_fraction() * 0.35
	if favourite != "" and favourite == strand:
		u += Balance.quiz_affinity_bonus
	if misjudged:
		u -= Balance.quiz_misjudged_penalty
	if is_struggling():
		u -= 0.15
	if copied:
		# The work got done. That is not the same as knowing it, and this is
		# where the difference finally shows up.
		u -= 0.25
	return clampf(u, 0.05, 0.98)


## Sit today's quiz. Returns the number right; the questions are rolled
## against understanding(), so the score is a genuine reading of a hidden
## state rather than a second dice roll with no meaning behind it.
func take_quiz(rng: RandomNumberGenerator, strand: String) -> int:
	Balance.ensure_loaded()
	var u := understanding(strand)
	var right := 0
	for i in Balance.quiz_questions:
		if rng.randf() < u:
			right += 1
	quiz_score = float(right) / float(maxi(1, Balance.quiz_questions))
	quiz_flagged = quiz_score < Balance.quiz_flag_below
	if quiz_flagged and not has_moment("quiz_caught"):
		note_moment("quiz_caught", Game.day)
	# Retrieval practice: being asked is itself a small piece of learning,
	# for everyone, whether or not they got it right.
	work_timer = maxf(0.0, work_timer - Balance.quiz_retrieval_seconds)
	return right


## Go over the quiz with them. Only worth anything to a child the quiz
## actually flagged -- which is what stops this being a second, better
## "help" you would spam at everybody.
func resolve_quiz() -> bool:
	Balance.ensure_loaded()
	if not quiz_flagged:
		return false
	quiz_flagged = false
	confusion = 0.0
	work_timer = maxf(0.0, work_timer - Balance.quiz_resolve_seconds)
	helps_received += 1
	helps_total += 1
	add_xp(Balance.stu_xp_per_help)
	return true


# ---------------------------------------------------------------- work

## Hand them a piece of work. Only a seated student can be given any.
func assign_work() -> bool:
	Balance.ensure_loaded()
	if work_state != Work.NONE:
		return false
	# A hard lesson is longer work. Read once, when the work is handed out,
	# so moving a desk mid-lesson cannot retroactively change how long the
	# sheet in front of them was.
	work_state = Work.WORKING
	work_total = Balance.work_seconds * float(Game.difficulty_mults(seat_index)[0])
	work_timer = work_total
	_since_stall = 0.0
	confusion = 0.0
	return true


## How much of it they have actually done, 0..1. This is the number the
## grade is built on, which is why helping matters: a stuck student's timer
## is frozen, so their fraction stops rising until you reach them.
func work_fraction() -> float:
	Balance.ensure_loaded()
	if work_state == Work.NONE:
		return 0.0
	if work_state != Work.WORKING:
		return 1.0
	# Falls back to the global length when work_total was never set, which
	# is any state built by hand rather than by assign_work(). Without the
	# fallback such a student reads as 0% done forever, and anything keyed
	# off progress -- a copier looking for somebody further ahead, an
	# inspector judging the lesson -- silently stops working.
	var total: float = work_total if work_total > 0.0 else Balance.work_seconds
	return clampf(1.0 - work_timer / maxf(0.01, total), 0.0, 1.0)


## Advance their work by `delta`. Returns true on the single frame they
## finish, so the caller can react once.
##
## The stall is rolled CONTINUOUSLY rather than scheduled once up front.
## The old version rolled a single stall moment in assign_work and cleared
## it when it fired, so a student could get stuck at most once per lesson —
## which quietly made the teacher's whole contribution a one-shot.
## `rate` is how fast the class is working, 0..1, which is the teacher's
## attention. At zero the timer does not move at all: the lesson does not
## happen unless somebody teaches it.
func tick_work(delta: float, rng: RandomNumberGenerator = null,
		rate: float = 1.0) -> bool:
	Balance.ensure_loaded()
	if work_state != Work.WORKING:
		return false
	if disrupting:
		return false                      # not doing a stroke until settled
	if is_struggling():
		# Count how long they have sat there without letting on. A Quiet
		# child withholds the "?" for a few seconds, which is what stops
		# scanning the room for bubbles from being the whole of the job.
		_hidden_for += delta
		return false                      # frozen until someone helps

	work_timer -= delta * rate
	if work_timer <= 0.0:
		work_timer = 0.0
		work_state = Work.DONE
		return true

	# a short grace after starting or being helped, so they never stall
	# again the instant you walk away — that reads as the game cheating
	_since_stall += delta
	if rng != null and _since_stall >= Balance.stall_grace_seconds:
		if rng.randf() < stall_chance() * delta:
			confusion = 1.0
			_since_stall = 0.0
			_hidden_for = 0.0
			if not has_moment("got_stuck"):
				note_moment("got_stuck", Game.day)
	return false


## Per-second chance of getting stuck. Brighter students stall less, and a
## student whose homework you waved through is secretly behind.
func stall_chance() -> float:
	Balance.ensure_loaded()
	var c := Balance.stall_chance_per_second * (1.4 - 0.8 * aptitude)
	if misjudged:
		c *= 1.6
	if favourite != "" and favourite == Game.lesson_strand():
		c *= (1.0 - Balance.affinity_bonus)      # on a good day for them
	c *= Game.event_stall_multiplier()
	# ...and a hard lesson trips them up more often, less so at a desk with
	# something useful within reach.
	c *= float(Game.difficulty_mults(seat_index)[1])
	c *= Traits.value(trait_id, "stall_mult", 1.0)
	# Just been made to think. This is what a quiz BUYS, and the reason it
	# is worth eleven seconds of a forty-five second lesson.
	if Game.quiz_focus:
		c *= Balance.quiz_focus_mult
	# Calm Presence: students near you get stuck less often. This perk has
	# been purchasable since perks existed and did nothing at all --
	# Progress.calm_multiplier() had no caller anywhere in scripts/.
	c *= Game.calm_multiplier_at(seat_index)
	# Somebody chatty at the next desk drags this one off task too. It is
	# the reason a seating plan is a decision rather than decoration.
	c *= neighbour_stall_multiplier()
	return c


## What the desks either side are doing to this child's concentration.
##
## Read from the LIVE seating, so moving a desk changes it immediately and
## the effect of a rearrangement is visible in the same lesson.
func neighbour_stall_multiplier() -> float:
	Balance.ensure_loaded()
	var mult := 1.0
	for other: StudentData in Game.neighbours_of(self):
		mult *= Traits.value(other.trait_id, "neighbour_stall_mult", 1.0)
		if other.disrupting:
			mult *= Balance.dis_neighbour_stall_mult
	return mult


## Is this child visibly stuck, or hiding it?
##
## The "?" bubble is the game's scan-the-room signal, and a Quiet student
## withholding it for a few seconds is what stops scanning being the whole
## of the job -- you have to actually know your class.
## How long they have been stuck, whether or not they are showing it.
func stuck_seconds() -> float:
	return _hidden_for


## Does this child need the teacher at their desk right now?
##
## The same priority the desk itself uses, so autopilot walks you to the
## thing you would have chosen: settle first (it spreads), then unstick
## (their work is frozen), then the quiz flag, then collect.
##
## Zero means they are fine. Lower is more urgent.
func attention_rank() -> int:
	# A flare-up outranks even a disruption: it is the one on a clock, and
	# catching it stops a disruption from ever happening.
	if flaring():
		return 1
	if disrupting:
		return 1
	if is_visibly_struggling():
		return 2
	if quiz_flagged:
		return 3
	if has_work_to_collect():
		return 4
	return 0


func is_visibly_struggling() -> bool:
	if not is_struggling():
		return false
	if disrupting:
		return false          # the room shows the louder problem instead
	return _hidden_for >= Traits.value(trait_id, "hide_seconds", 0.0)


## Award XP and apply any levels it earns. Returns levels gained.
func add_xp(amount: int) -> int:
	Balance.ensure_loaded()
	if amount <= 0 or is_capped():
		return 0
	xp += amount
	var gained := 0
	while level < Balance.stu_max_level and xp >= xp_for_next_level():
		level += 1
		gained += 1
		# a level is a nudge, not a transformation
		aptitude = clampf(aptitude + Balance.stu_aptitude_step, 0.0, 1.0)
		diligence = clampf(diligence + Balance.stu_diligence_step, 0.0, 1.0)
	return gained


func xp_for_next_level() -> int:
	Balance.ensure_loaded()
	return level * Balance.stu_xp_per_level


## They have stopped getting anything out of your class.
func is_capped() -> bool:
	Balance.ensure_loaded()
	return level >= mini(Balance.stu_max_level,
		Balance.stu_ready_level + Balance.stu_hold_grace)


## Ready to be sent up. YOUR call when -- this only says they could be.
func is_ready_to_graduate() -> bool:
	Balance.ensure_loaded()
	return level >= Balance.stu_ready_level


## How well prepared they would leave, 0..1. Feeds the payout, so seeing a
## child all the way through is worth more than sending them the moment they
## qualify.
func readiness() -> float:
	Balance.ensure_loaded()
	var span := maxi(1, Balance.stu_max_level - Balance.stu_ready_level)
	return clampf(float(level - Balance.stu_ready_level) / float(span), 0.0, 1.0)


## What the next coaching session costs this particular child. Rises per
## purchase, so the decision is WHO to invest in rather than levelling
## everyone flat.
func coaching_cost(base: int) -> int:
	Balance.ensure_loaded()
	return int(round(float(base) * pow(Balance.coach_cost_growth, float(coached))))


func can_be_coached() -> bool:
	Balance.ensure_loaded()
	return coached < Balance.coach_max_per_student


func has_work_to_collect() -> bool:
	return work_state == Work.DONE


func collect_work() -> bool:
	if work_state != Work.DONE:
		return false
	work_state = Work.COLLECTED
	return true


## Unstick them. Returns false if they were fine, so mashing E at a happy
## student does nothing.
func help() -> bool:
	if not is_struggling():
		return false
	confusion = 0.0
	_since_stall = 0.0
	_hidden_for = 0.0
	helps_received += 1
	helps_total += 1
	# A child who asks about everything gets more out of being answered.
	add_xp(int(round(float(Balance.stu_xp_per_help)
		* Traits.value(trait_id, "help_xp_mult", 1.0))))
	return true


## The paper has frozen them. Visible AT ONCE, whatever their trait: a
## Quiet child hides an ordinary stall for a few seconds, but a freeze in
## an exam hall is the whole room's business. Same state as being stuck
## (confusion), so the desk's ordinary help verb is what steadies them.
func freeze() -> void:
	confusion = 1.0
	_since_stall = 0.0
	_hidden_for = 1000.0


## The question moved on without them. NOT help(): nobody came, so no
## XP and no help counted -- the record stays honest about what happened.
func unfreeze() -> void:
	confusion = 0.0
	_since_stall = 0.0
	_hidden_for = 0.0


# ------------------------------------------------------------ homework

func homework_ready_to_mark() -> bool:
	return hw_state == HW.COLLECTED


## Did the player judge this sheet the way it deserved?
func verdict_was_right() -> bool:
	if hw_player_verdict < 0 or hw_sheet.is_empty():
		return false
	return (hw_player_verdict == 1) == Questions.sheet_is_good(hw_sheet)


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "art": art,
		"seat_index": seat_index, "aptitude": aptitude, "diligence": diligence,
		"hw_state": hw_state, "hw_true_accuracy": hw_true_accuracy,
		"hw_player_verdict": hw_player_verdict, "misjudged": misjudged,
		"favourite": favourite, "trait": trait_id,
		"disrupting": disrupting, "flare_left": flare_left, "copied": copied,
		"joined_day": joined_day, "helps_total": helps_total,
		"xp": xp, "level": level, "coached": coached,
		"hw_set_total": hw_set_total, "hw_done_total": hw_done_total,
		"grades": grades, "last_grade": last_grade,
		"transcript": transcript,
		"moments": moments,
		"favourite_streak": _favourite_streak,
		"boss_delta": boss_delta,
	}


static func from_dict(d: Dictionary) -> StudentData:
	var s := StudentData.new()
	s.id = int(d.get("id", 0))
	s.display_name = String(d.get("display_name", ""))
	s.art = String(d.get("art", "student_a"))
	s.seat_index = int(d.get("seat_index", -1))
	s.aptitude = float(d.get("aptitude", 0.5))
	s.diligence = float(d.get("diligence", 0.5))
	s.hw_state = int(d.get("hw_state", HW.NONE))
	s.hw_true_accuracy = float(d.get("hw_true_accuracy", 0.0))
	s.hw_player_verdict = int(d.get("hw_player_verdict", -1))
	s.misjudged = bool(d.get("misjudged", false))
	s.favourite = String(d.get("favourite", ""))
	s.trait_id = String(d.get("trait", ""))
	s.disrupting = bool(d.get("disrupting", false))
	s.flare_left = float(d.get("flare_left", 0.0))
	s.copied = bool(d.get("copied", false))
	s.joined_day = int(d.get("joined_day", 1))
	s.xp = int(d.get("xp", 0))
	s.level = int(d.get("level", 1))
	s.coached = int(d.get("coached", 0))
	s.helps_total = int(d.get("helps_total", 0))
	s.hw_set_total = int(d.get("hw_set_total", 0))
	s.hw_done_total = int(d.get("hw_done_total", 0))
	s.last_grade = float(d.get("last_grade", -1.0))
	s.grades.assign(d.get("grades", []))
	s.transcript = d.get("transcript", []).duplicate()
	s.moments = d.get("moments", []).duplicate()
	s._favourite_streak = int(d.get("favourite_streak", 0))
	s.boss_delta = float(d.get("boss_delta", 0.0))
	return s
