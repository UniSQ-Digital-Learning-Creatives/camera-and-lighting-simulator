extends SceneTree

# Bakes Ava's UniSQ shirt base colors, one per colourway, with the UniSQ logo
# (res/unisq-logo-acronym.svg) single-colour on the chest:
#   Gold   - brand gold, purple logo, as on the UniSQ PowerPoint template
#   Purple - the reverse, brand purple with a gold logo
#   Orchid, Coal - the student merch tees (res/usq-student-merch-tshirt-*.png):
#            shirt colour sampled from the photos, white logo, stacked large
# The first two use the horizontal lockup as drawn in the SVG; the merch tees
# use the stacked one, shield centred above the wordmark, both cut from the
# same SVG at the same scale. scripts/unisq_shirt.gd swaps between them.
# Rerun after changing the logo or its placement:
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
const ORCHID := Color("#D7C8CD")
const COAL := Color("#232122")
const WHITE := Color("#FFFFFF")
const MIRROR := false # for a mesh whose front panel UVs are mirrored

# Horizontal lockup: a chest print, centred on it.
const CHEST_CENTER := Vector2(0.28, 0.565) # UV
const CHEST_WIDTH := 0.23 # UV
# Stacked lockup: a large front print, hung from its top centre.
const STACKED_TOP := Vector2(0.28, 0.555) # UV
const STACKED_WIDTH := 0.22 # UV, of the wordmark (the widest part)
# In the SVG's units: the shield is x 0-201.9, the wordmark from x 263 on.
const SHIELD_RIGHT := 202.0
const WORDMARK_LEFT := 262.0
const STACK_GAP := 61.0 # shield to wordmark, as on the merch tees

func _initialize():
	bake(GOLD, PURPLE, false, "res://scenes/Ava/Maps/Shirt_UniSQ_Gold_Basecolor.png")
	bake(PURPLE, GOLD, false, "res://scenes/Ava/Maps/Shirt_UniSQ_Purple_Basecolor.png")
	bake(ORCHID, WHITE, true, "res://scenes/Ava/Maps/Shirt_UniSQ_Orchid_Basecolor.png")
	bake(COAL, WHITE, true, "res://scenes/Ava/Maps/Shirt_UniSQ_Coal_Basecolor.png")
	quit()

func bake(shirt: Color, ink: Color, stacked: bool, out: String):
	var logo := _stacked_logo() if stacked else _render_logo(CHEST_WIDTH * SIZE / _svg_width())
	# Single-colour logo: keep the SVG's coverage, paint it all one colour.
	for y in logo.get_height():
		for x in logo.get_width():
			logo.set_pixel(x, y, Color(ink, logo.get_pixel(x, y).a))
	if MIRROR:
		logo.flip_x()

	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(shirt)
	var at: Vector2i
	if stacked:
		at = Vector2i(STACKED_TOP * SIZE) - Vector2i(logo.get_width() / 2, 0)
	else:
		at = Vector2i(CHEST_CENTER * SIZE) - logo.get_size() / 2
	img.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), at)
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("wrote ", out)

# The shield centred above the wordmark, both at the SVG's own scale.
func _stacked_logo() -> Image:
	var scale := STACKED_WIDTH * SIZE / (_svg_width() - WORDMARK_LEFT)
	var full := _render_logo(scale)
	var split := int(round((SHIELD_RIGHT + WORDMARK_LEFT) / 2.0 * scale))
	var shield := full.get_region(Rect2i(0, 0, split, full.get_height()))
	shield = shield.get_region(shield.get_used_rect())
	var wordmark := full.get_region(Rect2i(split, 0, full.get_width() - split, full.get_height()))
	wordmark = wordmark.get_region(wordmark.get_used_rect())

	var gap := int(round(STACK_GAP * scale))
	var w := maxi(shield.get_width(), wordmark.get_width())
	var stack := Image.create_empty(w, shield.get_height() + gap + wordmark.get_height(), false, Image.FORMAT_RGBA8)
	stack.blit_rect(shield, Rect2i(Vector2i.ZERO, shield.get_size()), Vector2i((w - shield.get_width()) / 2, 0))
	stack.blit_rect(wordmark, Rect2i(Vector2i.ZERO, wordmark.get_size()),
			Vector2i((w - wordmark.get_width()) / 2, shield.get_height() + gap))
	return stack

func _render_logo(scale: float) -> Image:
	var logo := Image.new()
	logo.load_svg_from_string(FileAccess.get_file_as_string(LOGO), scale)
	logo.convert(Image.FORMAT_RGBA8)
	return logo

func _svg_width() -> float:
	return _render_logo(1.0).get_width()
