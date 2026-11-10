class_name UITheme
extends RefCounted

const MaterialBox := preload("res://scripts/ui/material_box.gd")

## Central design system constants and material helpers for EduSystem.
## Palette, typography tokens, and StyleBox factories matching ui-overhaul-plan-2026-11-10.md.

const CHALKBOARD := Color("134E4A")
const CHALK := Color("FDFBF7")
const PAPER := Color("F5F0E1")
const PAPER_BRIGHT := Color("FAFAF8")
const WOOD := Color("C4A77D")
const WOOD_DARK := Color("B5651D")
const SAND := Color("D4C4A8")
const TERRACOTTA := Color("C67B5C")
const OLIVE := Color("6B7B3C")
const AMBER := Color("D97706")
const INK := Color("1A1A1A")
const PENCIL := Color("4A4A4A")
const DESTRUCTIVE := Color("DC2626")

const FONT_CHALK_BOLD := "res://fonts/Kalam-Bold.ttf"
const FONT_CHALK := "res://fonts/Kalam-Regular.ttf"
const FONT_DISPLAY := "res://fonts/PressStart2P-Regular.ttf"
const FONT_BODY := "res://fonts/VT323-Regular.ttf"
const FONT_HAND := "res://fonts/PatrickHand-Regular.ttf"
const FONT_RETRO := "res://fonts/Galmuri9.ttf"

const SHADER_CHALK := "res://shaders/chalk.gdshader"


static func load_font(res_path: String, aa: int = 0) -> FontFile:
	var f := FontFile.new()
	var err := f.load_dynamic_font(res_path)
	if err != OK:
		# Fallback to Galmuri if dynamic load fails
		return load("res://fonts/Galmuri9.ttf") as FontFile
	f.antialiasing = aa
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


static func make_chalkboard_box(frame_px: int = 6, grain_val: float = 0.5) -> MaterialBox:
	var b := MaterialBox.new()
	b.kind = MaterialBox.Kind.CHALKBOARD
	b.fill = CHALKBOARD
	b.mark = CHALK
	b.edge = WOOD
	b.edge_shade = WOOD_DARK
	b.highlight = Color(PAPER_BRIGHT.r, PAPER_BRIGHT.g, PAPER_BRIGHT.b, 0.45)
	b.border = 2
	b.frame = frame_px
	b.corner = 2
	b.grain = grain_val
	return b


static func make_paper_box(shadow_px: int = 4, grain_val: float = 0.5) -> MaterialBox:
	var b := MaterialBox.new()
	b.kind = MaterialBox.Kind.PAPER
	b.fill = PAPER
	b.mark = SAND
	b.edge = SAND
	b.edge_shade = PENCIL
	b.highlight = PAPER_BRIGHT
	b.border = 2
	b.corner = 2
	b.grain = grain_val
	b.shadow = shadow_px
	b.shadow_color = Color(INK.r, INK.g, INK.b, 0.3)
	return b


static func make_wood_box() -> MaterialBox:
	var b := MaterialBox.new()
	b.kind = MaterialBox.Kind.WOOD
	b.fill = WOOD
	b.mark = WOOD_DARK
	b.edge = WOOD_DARK
	b.edge_shade = WOOD_DARK
	b.highlight = Color(PAPER_BRIGHT.r, PAPER_BRIGHT.g, PAPER_BRIGHT.b, 0.5)
	b.border = 2
	b.corner = 2
	b.grain = 0.5
	return b


static func make_chalk_material(grit: float = 0.16, press: float = 0.3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_CHALK)
	mat.set_shader_parameter("grit", grit)
	mat.set_shader_parameter("press", press)
	return mat
