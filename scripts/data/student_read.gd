class_name StudentRead

## What is acting on one child, in words -- the ONE builder behind both
## places the game says it.
##
## This used to live inside hud.gd's _render_student_acting(). The game knew
## exactly why a child was doing badly and would only tell you if you walked
## to a screen, opened their file and pressed Tab twice; the room itself
## never said a word. Pulling the builder out here lets a desk speak the
## same sentence the file page would print, derived from the same conditions
## in the same pass -- so the page and the room can never disagree about a
## child. That is the whole reason this is one function and not two.
##
## Prose, never numbers (CLAUDE.md). Every sentence names an influence and
## none of them prints its value; a test compiles [0-9] against the page.
## Keep it that way -- a page of decimals about a child is exactly what that
## rule exists to prevent.

# The sentences a desk can say out loud live here as constants rather than
# as literals at their append site, because two readers now share them: the
# file page prints them, and the room speaks one of them. A test asserts on
# these names, so re-wording one cannot silently break the read.
const NOTHING_TO_WORK_WITH := "They have nothing in front of them to work with."
const GOING_OFF := "They are going off right now, and it will spread."
const PLAYING_UP := "They have stopped working and are playing up."
const STUCK := "They are stuck, and their work is not moving at all."
const QUIZ_CAUGHT := "The quiz caught them out on this."

## Nothing pressing. Matches StudentData.attention_rank()'s own convention,
## where zero means the child is fine -- except that here LOWER is more
## urgent and this sentinel sits above every real rank.
const RANK_NONE := 99


## Everything acting on `s`, split the way the file page shows it.
##
## Returns a Dictionary of:
##   against  Array[String]  what is holding them back, in category order
##   helping  Array[String]  what is going for them
##   urgent   String         the one sentence a desk should say out loud, or
##                           "" when nothing needs doing. ALWAYS one of the
##                           strings already in `against` -- never a
##                           sentence of its own, which is what stops the
##                           room and the file from drifting apart.
##
## `against` keeps hud.gd's original category order (what they brought, the
## day, the room, where you are, this minute, what you have spent) rather
## than being sorted by urgency. That order is what the page has always
## shown, and it reads like a teacher thinking rather than a queue.
static func acting_on(s: StudentData) -> Dictionary:
	var against: Array[String] = []
	var helping: Array[String] = []

	# Candidates for the spoken read, as {rank, text}. Collected as we go so
	# each condition is still evaluated exactly once, then reduced at the
	# bottom. Lower rank wins; ties go to whichever was appended first.
	var candidates: Array[Dictionary] = []

	# --- what they brought with them ---
	if s.trait_id != "":
		against.append("%s. %s" % [Traits.name_of(s.trait_id), Traits.blurb(s.trait_id)])

	# --- the day itself ---
	var ev := String(Game.event.get("id", "none"))
	if ev != "none":
		against.append(String(Game.event.get("blurb", "")))

	# --- the room they are sitting in ---
	var strand := Game.lesson_strand()
	var suited := ""
	for placed: Dictionary in Game.room_items:
		var def := Items.get_def(String(placed.get("id", "")))
		if String(def.get("strand", "")) == strand and strand != "":
			suited = String(def.get("name", ""))
			break
	if suited != "":
		helping.append("The %s is out, and it suits today's subject." % suited)
	elif strand != "":
		against.append("Nothing in the room is set out for today's subject.")
	if not s.has_supply:
		# Rank 0, above even a flare-up. Not this file's opinion: it is what
		# desk_station.action() already does, and for the reason its own
		# comment gives -- a child with nothing in front of them cannot get
		# started at all, where a child kicking off at least had something
		# to stop doing. The desk is what the player is about to press E on,
		# so the read follows the desk's priority.
		against.append(NOTHING_TO_WORK_WITH)
		candidates.append({"rank": 0, "text": NOTHING_TO_WORK_WITH})
	if Game.cluster_rate_mult(s) < 1.0:
		against.append("Their desk is hemmed in by the others, so they work slower.")

	# --- where YOU are, right now ---
	if s.seat_index >= 0:
		if Game.calm_multiplier_at(s.seat_index) < 1.0:
			helping.append("You are near enough to keep them settled.")
		else:
			against.append("You are too far away to steady them from here.")

	# --- what they are doing this minute ---
	if s.flaring():
		against.append(GOING_OFF)
		candidates.append({"rank": 1, "text": GOING_OFF})
	elif s.disrupting:
		against.append(PLAYING_UP)
		candidates.append({"rank": 1, "text": PLAYING_UP})
	if s.is_struggling():
		against.append(STUCK)
		# The PAGE says it as soon as it is true. The ROOM waits for
		# is_visibly_struggling(), because a Quiet child sits on it for a few
		# seconds and that delay is the thing that stops scanning the room
		# from being the whole of the job. Same sentence, and the file is
		# still where you go to find out early -- speaking it here on
		# is_struggling() would hand over exactly what the trait withholds.
		if s.is_visibly_struggling():
			candidates.append({"rank": 2, "text": STUCK})
	if s.copied:
		against.append("They have copied their way past it, so the gap is hidden.")
	if s.quiz_flagged:
		against.append(QUIZ_CAUGHT)
		# rank 3, same slot StudentData.attention_rank() gives quiz_flagged
		candidates.append({"rank": 3, "text": QUIZ_CAUGHT})
	if s.hw_state == StudentData.HW.ASSIGNED:
		against.append("Last night's homework is still not handed in.")

	# --- what you have already spent on them ---
	if s.coached > 0:
		helping.append("You have paid for extra help for them before.")

	var urgent := ""
	var best := RANK_NONE
	for c: Dictionary in candidates:
		var rank: int = int(c.get("rank", RANK_NONE))
		if rank < best:
			best = rank
			urgent = String(c.get("text", ""))

	return {"against": against, "helping": helping, "urgent": urgent}


## The one sentence a desk should say, or "" when that desk is fine.
##
## A convenience over acting_on() for the room, which does not need the
## whole page. Deliberately goes through the same builder rather than
## re-deriving the conditions -- a second copy of this logic is exactly the
## drift this file exists to prevent.
static func urgent_line(s: StudentData) -> String:
	if s == null:
		return ""
	return String(acting_on(s).get("urgent", ""))
