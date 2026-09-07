extends ForgeTab

## Master Forge, Art tab -- one character, item or tile set, regenerated.
##
## Sits beside the sprite editor (tools/curator.tscn) in the same tab: this
## half changes a sprite by its palette, that half by hand. Offers the WHOLE
## house palette rather than one module's, because forge_art.py reaches the
## character colours and the shared item colours both.

func _ready() -> void:
	cfg_script = "forge_art.py"
	cfg_title = "Art — characters, items, tiles"
	cfg_target_hint = "Sprite name"
	cfg_module = ""
	cfg_list_arg = ""          # the gallery is the target; nothing to list
	cfg_blurb = ("Recolour a generated sprite by its palette, then rewrite art/. "
		+ "The gallery on the right is the target — pick there.")
	build_tab()
	log_line("Character keys: hair, hair_style, glasses, skin, pattern.",
		"#8a929c")
	log_line("Hand-drawn sprites are refused here — select one in the gallery "
		+ "and press Edit sprite instead.", "#8a929c")


## The gallery beside this tab is the picker. See ForgeTab.set_external_target,
## wired to the curator in master_forge.gd.
func uses_external_target() -> bool:
	return true
