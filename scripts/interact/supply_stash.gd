extends Interactable

## The treat shelf (learning-system-plan.md): three jars of treats a teacher
## carries to a child's desk, with no hotbar -- you walk to it, take one, walk
## to the desk and hand it over (desk_treat.gd). Since Oct 2026 it is its own
## shelf on the back wall, between the second window and the shop: the treats
## used to be drawn floating round the locker's shoulders, where nobody could
## tell what they were for. It is well clear of the podium, whose four verbs
## already fill the badge row.
##
## One press takes the first treat, the next swaps it for the one after, and
## after the last you put it back. Free to take and free to put back: it is
## paid for when it is handed over, so nothing here can cost a lesson or a
## coin. Its own key (SUPPLY) because one verb lives at two landmarks -- the
## cupboard and the desk -- which is exactly what a shared key cannot say.


func _init() -> void:
	super()
	uses_key = Key.SUPPLY


func can_interact() -> bool:
	return Game.treats_available()


func prompt_text() -> String:
	var ids := Game.stash_ids()
	if ids.is_empty():
		return ""
	var i := ids.find(Game.carried)
	if i < 0:
		return "Take a %s from the shelf" % Game.treat_name(String(ids[0]))
	if i >= ids.size() - 1:
		return "Put the %s back" % Game.treat_name(Game.carried)
	return "Swap the %s for a %s" % [Game.treat_name(Game.carried),
		Game.treat_name(String(ids[i + 1]))]


func interact(by: Node) -> void:
	var now := Game.cycle_carried()
	Sfx.play("blip" if now == "" else "paper")
	used.emit(by)
