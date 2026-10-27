extends SceneTree

# Bakes Ava's UniSQ shirt base colors, one per colourway: brand gold with the
# UniSQ logo (res/unisq-logo-acronym.svg) in brand purple on the chest - as on
# the UniSQ PowerPoint template - and the reverse, purple with a gold logo.
# The logo is single-colour in both. scripts/unisq_shirt.gd swaps between
# them. Rerun after changing the logo or its placement:
#
#   <fork editor binary> --headless --path . --script "$PWD/tools/make_shirt_texture.gd"
#
# Placement is in the shirt's UV space (see the panels in
# scenes/Ava/Maps/Clothes_M_DG_bodyShapeA_Shirt_AO.png): the front panel is
# the bottom-left one, with the deep neckline.

const LOGO := "res://res/unisq-logo-acronym.svg"
const SIZE := 2048
const GOLD := Color("#FFB448")
const PURPLE := Color("#3C2D4D")
const LOGO_CENTER := Vector2(0.28, 0.565) # UV
const LOGO_WIDTH := 0.23 # UV
const MIRROR := false # for a mesh whose front panel UVs are mirrored

func _initialize():
	bake(GOLD, PURPLE, "res://scenes/Ava/Maps/Shirt_UniSQ_Gold_Basecolor.png")
	bake(PURPLE, GOLD, "res://scenes/Ava/Maps/Shirt_UniSQ_Purple_Basecolor.png")
	quit()

func bake(shirt: Color, ink: Color, out: String):
	var svg := FileAccess.get_file_as_string(LOGO)
	var probe := Image.new()
	probe.load_svg_from_string(svg, 1.0)
	var logo := Image.new()
	logo.load_svg_from_string(svg, LOGO_WIDTH * SIZE / probe.get_width())
	logo.convert(Image.FORMAT_RGBA8)
	# Single-colour logo: keep the SVG's coverage, paint it all one colour.
	for y in logo.get_height():
		for x in logo.get_width():
			logo.set_pixel(x, y, Color(ink, logo.get_pixel(x, y).a))
	if MIRROR:
		logo.flip_x()

	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(shirt)
	var at := Vector2i(LOGO_CENTER * SIZE) - logo.get_size() / 2
	img.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), at)
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("wrote ", out)
