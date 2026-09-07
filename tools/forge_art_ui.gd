extends ForgeTab

## Master Forge, Art tab -- one character, item or tile set, regenerated.
##
## Sits beside the sprite editor (tools/curator.tscn) in the same tab: this
## half changes a sprite by its palette, that half by hand. Offers the WHOLE
## house palette rather than one module's, because forge_art.py reaches the
## character colours and the shared item colours both.

func _ready() -> void:
	cfg_script = "forge_art.py"
	cfg_title = "Art — characters, items, tiles (forge_art.py)"
	cfg_target_hint = "Sprite name (e.g. child1)"
	cfg_module = ""
	cfg_list_arg = "names"
	cfg_blurb = ("Recolour a generated sprite and rewrite art/. "
		+ "To draw one by hand, use the gallery on the right instead.")
	build_tab()
	log_line("Character keys: hair, hair_style, glasses, skin, pattern.",
		"#8a929c")
	log_line("A hand-drawn sprite is refused — edit it in the browser to "
		+ "the right instead.", "#8a929c")
