class_name JanitorShift
extends Node2D

## THE JANITOR'S SHIFT (duty "janitor"). Spills and litter lie along the
## corridor; the player cleans each with E -- the same mash a classroom mess
## takes (mess.gd) -- before the clock runs out. Built on the existing mess:
## RoomBuilder.build_mess() places it, and mess.gd pays its tip when done.
## Owned by main.gd, a child of the hallway while it runs, freed after.

signal finished(result: Dictionary)

var _messes: Array[Interactable] = []
var _total: int = 0
var _left_s: float = 0.0
var _running: bool = false


func _ready() -> void:
	add_to_group("duty_shift")


## Put one mess on each of `tiles` (corridor tiles, already chosen) and start
## the clock. `r` is the duty's own generator (Game.duty_rng()).
func start(tiles: Array[Vector2i], r: RandomNumberGenerator) -> void:
	Balance.ensure_loaded()
	for t: Vector2i in tiles:
		var kind: String = "spill" if r.randi_range(0, 2) == 0 else "trash"
		var it := RoomBuilder.build_mess(self, t, kind)
		it.cleaned.connect(_on_cleaned)
		_messes.append(it)
	_total = _messes.size()
	_left_s = Balance.duty_janitor_seconds
	_running = true


func _physics_process(delta: float) -> void:
	if _running:
		tick(delta)


## Public so the suite can run the clock without waiting on frames.
func tick(delta: float) -> void:
	if not _running:
		return
	_left_s = maxf(0.0, _left_s - delta)
	if _left_s <= 0.0:
		_finish()


func seconds_left() -> float:
	return _left_s


func remaining() -> int:
	return _messes.size()


func total() -> int:
	return _total


## The messes still down, for the suite.
func messes() -> Array[Interactable]:
	return _messes


func _on_cleaned(mess: Interactable, _kind: String) -> void:
	_messes.erase(mess)
	if _messes.is_empty():
		_finish()


func _finish() -> void:
	if not _running:
		return
	_running = false
	var cleaned := _total - _messes.size()
	# What is left goes with the shift: a clock running out does not leave
	# the corridor littered for good.
	for m: Interactable in _messes:
		if is_instance_valid(m):
			var body: Node = m.get_parent()
			if body != null:
				body.queue_free()
	_messes.clear()
	finished.emit({"id": "janitor", "done": cleaned, "total": _total,
		"seconds_left": _left_s, "all": cleaned == _total})
