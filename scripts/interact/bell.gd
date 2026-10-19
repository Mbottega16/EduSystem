extends Interactable

## Ends the day. Deliberately across the room from the podium, so calling
## time is a walk rather than a reflex.

signal day_ended(report: Dictionary)

func _init() -> void:
	super()
	uses_key = Key.MANAGE
	hold_time = 0.55      # ending the day is irreversible
signal term_ended(result: Dictionary)
## The last bell of a term needs the final assessment's lessons first.
signal exam_picks_needed()


func _classroom() -> Node:
	var n := get_parent()
	while n != null and not n.has_method("end_day"):
		n = n.get_parent()
	return n


func can_interact() -> bool:
	return Game.phase == Game.Phase.AFTERNOON


func prompt_text() -> String:
	if Game.phase == Game.Phase.LESSON:
		return ""
	if Game.day >= Balance.term_days:
		if not Game.exam_picks_complete():
			return "Choose the exam lessons — LAST DAY OF TERM"
		return "Ring the bell — LAST DAY OF TERM"
	return "Ring the bell — end day %d" % Game.day


func interact(by: Node) -> void:
	var room := _classroom()
	if room == null:
		return
	# The last day of a term: the paper covers one lesson per subject, and
	# you choose them before the bell goes.
	if Game.day >= Balance.term_days and not Game.exam_picks_complete():
		Sfx.play("confirm")
		exam_picks_needed.emit()
		return
	Sfx.play("bell")
	# ...and it SWINGS. The bell was the loudest thing in the room and the
	# one thing that never moved.
	var body := get_parent()
	if body != null:
		for c: Node in body.get_children():
			if c is Sprite2D and (c as Sprite2D).texture != null \
					and (c as Sprite2D).texture.get_height() > 16:
				Fx.wobble(c as Sprite2D)
	var last := Game.day >= Balance.term_days
	var report: Dictionary = room.end_day()
	# Ten-commits.md step 3: coins and XP already land above every desk in
	# step 2 -- the pacing bonus is one flat, whole-class event rather than
	# any child's own growth, so it gets ONE floater here rather than a
	# swarm of identical ones over eight desks.
	if bool((report.get("pacing", {}) as Dictionary).get("on_pace", false)) \
			and room is Node2D:
		var room2d := room as Node2D
		Sfx.play("confirm")
		Fx.puff(room2d, global_position + Vector2(0, -10), Color(0.7, 1.0, 0.8))
		Floater.pop(room2d, global_position + Vector2(0, -36),
			"on pace +%d" % Balance.pace_bonus_coins, Color(0.7, 1.0, 0.8))
	if last:
		term_ended.emit(Game.sit_exam())
	else:
		day_ended.emit(report)
	used.emit(by)
