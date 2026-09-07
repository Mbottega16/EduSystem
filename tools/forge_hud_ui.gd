extends ForgeTab

## Master Forge, HUD tab -- the screen furniture in tools/make_ui.py.
##
## Today that is the curriculum/lesson-plan book: its boards, its paper and
## its ink. Same base as the Art and Items tabs; see tools/forge_tab.gd for
## why all three stopped being their own copy of it.

func _ready() -> void:
	cfg_script = "forge_ui.py"
	cfg_title = "HUD — the book and other screen furniture (forge_ui.py)"
	cfg_target_hint = "UI piece (e.g. book_open)"
	cfg_module = "make_ui"
	cfg_list_arg = "list"
	cfg_blurb = "Redraw a piece of screen furniture — the lesson-plan book and its parts."
	build_tab()
	log_line("book_open redraws the spread. The four page-flip frames come "
		+ "from python tools/make_ui.py.", "#8a929c")
