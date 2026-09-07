extends ForgeTab

## Master Forge, Items tab -- one furniture or clutter sprite, recoloured.
##
## Was a hand-rolled copy of the same body the Art and HUD tabs had, and
## called `add_theme_colors_override` (no such method), so opening this tab
## threw before it drew anything. It is the base class now; what is left
## here is only what makes this tab this tab.

func _ready() -> void:
	cfg_script = "forge_items.py"
	cfg_title = "Items — furniture and clutter (forge_items.py)"
	cfg_target_hint = "Item name (e.g. stool)"
	cfg_module = "make_items"
	cfg_list_arg = "list"
	cfg_blurb = "Retint one piece of furniture or clutter and rewrite art/."
	build_tab()
	log_line("Pick an item, click a swatch, press Forge.", "#8a929c")
	log_line("A hand-drawn sprite is refused — edit those in the Art tab.",
		"#8a929c")
