"""One-shot: wire audio + idle bob + juice."""
import io
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def edit(rel, pairs):
    p = os.path.join(ROOT, rel)
    s = io.open(p, encoding="utf-8").read()
    for old, new in pairs:
        assert old in s, rel + " MISSING:\n" + old[:150]
        s = s.replace(old, new, 1)
    io.open(p, "w", encoding="utf-8").write(s)
    print("patched", rel)


edit("project.godot", [
    ('Game="*res://scripts/autoload/game.gd"',
     'Game="*res://scripts/autoload/game.gd"\nSfx="*res://scripts/autoload/sfx.gd"'),
])

# --- idle bob + footsteps on the actor ----------------------------------
edit("scripts/actors/actor.gd", [
    ('var _cycle_pos := 0\nvar _frame_timer := 0.0',
     '''var _cycle_pos := 0
var _frame_timer := 0.0
## Phase offset so a room full of seated people does not breathe in unison.
var idle_phase := 0.0
var _step_side := false'''),

    ('''	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer -= FRAME_TIME
		_cycle_pos = (_cycle_pos + 1) % WALK_CYCLE.size()
	_set_frame(WALK_CYCLE[_cycle_pos])''',
     '''	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer -= FRAME_TIME
		_cycle_pos = (_cycle_pos + 1) % WALK_CYCLE.size()
		# a footfall on each of the two stepping frames
		if WALK_CYCLE[_cycle_pos] % 2 == 1:
			_step_side = not _step_side
			on_step()
	_set_frame(WALK_CYCLE[_cycle_pos])'''),

    ('''func _set_frame(f: int) -> void:''',
     '''## Overridden by the player so only the teacher's own footsteps are heard —
## eight students walking in at once would be a stampede.
func on_step() -> void:
	pass


## A slow breath while seated. Eight identical frozen poses was the dominant
## image of the game and read as a room of mannequins; this is two lines and
## fixes most of that.
func idle_bob(delta: float) -> void:
	if not seated or sprite == null:
		return
	idle_phase += delta
	var lift := -12.0 + sin(idle_phase * 1.9) * 0.6
	sprite.position.y = lift


func _set_frame(f: int) -> void:'''),
])

edit("scripts/actors/student.gd", [
    ('''func _physics_process(delta: float) -> void:
	if data != null and data.work_state == StudentData.Work.WORKING:
		queue_redraw()''',
     '''func _physics_process(delta: float) -> void:
	idle_bob(delta)
	if data != null and data.work_state == StudentData.Work.WORKING:
		queue_redraw()'''),

    ('''func bind(d: StudentData) -> void:
	data = d''',
     '''func bind(d: StudentData) -> void:
	data = d
	idle_phase = float(d.id) * 0.9      # so they don't breathe in unison'''),

    ('''func set_bubble(on: bool) -> void:
	if bubble != null:
		bubble.visible = on''',
     '''func set_bubble(on: bool) -> void:
	if bubble == null or bubble.visible == on:
		return
	bubble.visible = on
	if on:
		# a small pop, and a sound, because a boolean toggle thirty tiles
		# away in a static frame is genuinely easy to miss
		Sfx.play_varied("stuck")
		bubble.scale = Vector2(0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(bubble, "scale", Vector2.ONE, 0.18) \\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)'''),
])

edit("scripts/actors/player.gd", [
    ('''func carry_work(n: int) -> void:''',
     '''## Only the teacher's footsteps are audible.
func on_step() -> void:
	Sfx.play_varied("step", 0.12)


func carry_work(n: int) -> void:'''),
])

# --- sounds on the verbs -------------------------------------------------
edit("scripts/interact/desk_station.gd", [
    ('''		Action.HELP:
			if s.help():
				used.emit(by)''',
     '''		Action.HELP:
			if s.help():
				Sfx.play("help")
				used.emit(by)'''),
    ('''			if s.collect_work():
				show_paper(false)''',
     '''			if s.collect_work():
				Sfx.play_varied("paper")
				show_paper(false)'''),
    ('''			s.hw_state = StudentData.HW.COLLECTED
			if by != null and by.has_method("carry_homework"):''',
     '''			s.hw_state = StudentData.HW.COLLECTED
			Sfx.play_varied("paper")
			if by != null and by.has_method("carry_homework"):'''),
])

edit("scripts/interact/podium.gd", [
    ('''	if Game.phase == Game.Phase.MORNING:
		lesson_started.emit(room.start_lesson())''',
     '''	if Game.phase == Game.Phase.MORNING:
		Sfx.play("start")
		lesson_started.emit(room.start_lesson())'''),
])

edit("scripts/interact/bell.gd", [
    ('''	day_ended.emit(room.end_day())''',
     '''	Sfx.play("bell")
	day_ended.emit(room.end_day())'''),
])

edit("scripts/interact/marking_desk.gd", [
    ('''		handed_in += c.carrying
		c.drop_all_work()''',
     '''		handed_in += c.carrying
		Sfx.play("paper")
		c.drop_all_work()'''),
])

edit("scripts/autoload/game.gd", [
    ('''func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)''',
     '''func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	if amount > 0 and is_inside_tree():
		Sfx.play("coins")
	coins_changed.emit(coins)'''),
])

edit("scripts/ui/hud.gd", [
    ('''		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + rows.size()) % rows.size()
			_render_catalogue()''',
     '''		elif Input.is_action_just_pressed("move_up"):
			_sel = (_sel - 1 + rows.size()) % rows.size()
			Sfx.play("blip")
			_render_catalogue()'''),
    ('''		elif Input.is_action_just_pressed("move_down") and not rows.is_empty():
			_sel = (_sel + 1) % rows.size()
			_render_catalogue()''',
     '''		elif Input.is_action_just_pressed("move_down") and not rows.is_empty():
			_sel = (_sel + 1) % rows.size()
			Sfx.play("blip")
			_render_catalogue()'''),
    ('''			if _shop == Shop.BUY:
				var id: String = rows[_sel]
				if Game.can_afford(Items.cost(id)):
					close()
					item_chosen.emit(id)''',
     '''			if _shop == Shop.BUY:
				var id: String = rows[_sel]
				if Game.can_afford(Items.cost(id)):
					Sfx.play("confirm")
					close()
					item_chosen.emit(id)
				else:
					Sfx.play("deny")'''),
    ('''func show_day_report(report: Dictionary) -> void:
	_open(Mode.REPORT)''',
     '''func show_day_report(report: Dictionary) -> void:
	Sfx.play("grade")
	_open(Mode.REPORT)'''),
])

edit("scripts/world/placement.gd", [
    ('''	elif Game.claim_interact():
		if is_valid():
			placed.emit(item_id, tile)
			finish()''',
     '''	elif Game.claim_interact():
		if is_valid():
			Sfx.play("confirm")
			placed.emit(item_id, tile)
			finish()
		else:
			Sfx.play("deny")'''),
    ('''	elif _repeat <= 0.0:
		move_by(d)
		_repeat = 0.14''',
     '''	elif _repeat <= 0.0:
		move_by(d)
		Sfx.play("blip")
		_repeat = 0.14'''),
])
print("done")
