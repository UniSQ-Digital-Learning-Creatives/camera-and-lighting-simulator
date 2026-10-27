extends SceneTree

# Renders the boot splash (UI/splash.png) after the UniSQ PowerPoint template's
# "Title Slide with border and background" layout (res/usq-brand-powerpoint.pptx,
# slide 7): the bold gold background, the plum border along the right and
# bottom edges with its curved inner corner, the plum University of Southern
# Queensland logo top left (res/unisq-logo-full-plum.svg, the template's own),
# and the app's name in the title slot. Positions and sizes are the
# template's, in its EMUs. Needs a real display (--headless only gives the
# dummy renderer):
#
#   <fork editor binary> --path . --script "$PWD/tools/make_splash.gd"
#
# The image is the app window's aspect (1656x968) and the splash is set to
# cover the screen, so the border stays on the edges; the template's 16:9
# layout is scaled by height and the border anchored to the bottom right.
#
# The web build's HTML loading screen doesn't use the image as is: CSS in the
# Web export preset's html/head_include draws the border along the browser
# window's edges and shows only the image's logo-and-title corner, so the
# layout holds at any window shape. That CSS is kept in
# tools/web_head_include.html; paste it into the preset's Head Include. Keep
# its numbers in step with these.

const OUT := "res://UI/splash.png"
const SIZE := Vector2i(2484, 1452) # 1.5x the window
const LOGO := "res://res/unisq-logo-full-plum.svg"
const FONT := "res://UI/fonts/OpenSans-Bold.ttf"
const TITLE := "Camera Studio Simulator"
const GOLD := Color("#FFB448") # bg2
const PLUM := Color("#3C2D4D") # accent1 / tx2

# The template, in EMUs (slide 12192000 x 6858000).
const SLIDE_W := 12192000.0
const SLIDE_H := 6858000.0
const LOGO_POS := Vector2(407988, 392059)
const LOGO_W := 2340000.0
const TITLE_POS := Vector2(407987, 1989552)
const TITLE_SIZE := Vector2(7920000, 1440000) # text sits on its bottom edge
const TITLE_PT := 56.0
const EMU_PER_PT := 12700.0
# The border's outline: right band from x 11369675, bottom band from
# y 6477000, joined by one cubic Bézier.
const BORDER_X := 11369675.0
const BORDER_Y := 6477000.0
const CURVE := [Vector2(10274935, 6477000), Vector2(10879581, 6477000),
		Vector2(11369675, 5986908), Vector2(11369675, 5382260)]

var viewport: SubViewport
var frames := 0

func _initialize():
	var s := SIZE.y / SLIDE_H # EMU -> px, by height
	var dx := SIZE.x - SLIDE_W * s # the bottom-right anchored border shifts this far

	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.msaa_2d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var bg := ColorRect.new()
	bg.color = GOLD
	bg.size = SIZE
	viewport.add_child(bg)

	var curve := Curve2D.new()
	curve.add_point(CURVE[0] * s + Vector2(dx, 0), Vector2.ZERO, (CURVE[1] - CURVE[0]) * s)
	curve.add_point(CURVE[3] * s + Vector2(dx, 0), (CURVE[2] - CURVE[3]) * s)
	var outline := PackedVector2Array([Vector2(BORDER_X * s + dx, 0), Vector2(SIZE.x, 0),
			Vector2(SIZE.x, SIZE.y), Vector2(0, SIZE.y), Vector2(0, BORDER_Y * s)])
	outline.append_array(curve.tessellate(6, 2))
	var border := Polygon2D.new()
	border.color = PLUM
	border.polygon = outline
	border.antialiased = true
	viewport.add_child(border)

	var svg := FileAccess.get_file_as_string(LOGO)
	var probe := Image.new()
	probe.load_svg_from_string(svg, 1.0)
	var logo_img := Image.new()
	logo_img.load_svg_from_string(svg, LOGO_W * s / probe.get_width())
	var logo := TextureRect.new()
	logo.texture = ImageTexture.create_from_image(logo_img)
	logo.position = LOGO_POS * s
	viewport.add_child(logo)

	var title := Label.new()
	title.text = TITLE
	title.label_settings = LabelSettings.new()
	title.label_settings.font = load(FONT)
	title.label_settings.font_size = roundi(TITLE_PT * EMU_PER_PT * s)
	title.label_settings.font_color = PLUM
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.position = TITLE_POS * s
	title.size = TITLE_SIZE * s
	viewport.add_child(title)

func _process(_delta) -> bool:
	frames += 1
	if frames == 10:
		viewport.get_texture().get_image().save_png(OUT)
		print("wrote ", OUT)
		return true
	return false
