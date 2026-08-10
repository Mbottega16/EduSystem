extends Control

## Status strip and interaction prompt.
##
## Polls the player each frame rather than connecting to its signals. The
## player is built at runtime by classroom.gd, so a signal wiring would have
## to care about which of the two _ready() calls happens first; polling two
## labels at 320x176 costs nothing and can't be raced.
##
## The status strip deliberately sits over the top wall band, where nothing
## gameplay-relevant is ever drawn — so the HUD costs no play area at all.

@onready var status: Label = $Status
@onready var prompt: Label = $Prompt
@onready var prompt_box: ColorRect = $PromptBox

var _player: Node = null


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("carrier")
	_update_status()
	_update_prompt()


func _update_status() -> void:
	var carrying := 0
	if _player != null and is_instance_valid(_player):
		carrying = _player.carrying
	var line := "Day %d    %d coins" % [Game.day, Game.coins]
	if carrying > 0:
		line += "    carrying %d" % carrying
	var waiting := 0
	for s: StudentData in Game.roster:
		if s.has_work_to_collect():
			waiting += 1
	if waiting > 0:
		line += "    %d ready to collect" % waiting
	status.text = line


func _update_prompt() -> void:
	var target: Interactable = null
	if _player != null and is_instance_valid(_player):
		target = _player.target
	var showing := target != null and target.can_interact()
	prompt.visible = showing
	prompt_box.visible = showing
	if showing:
		prompt.text = "E  —  %s" % target.prompt_text()
