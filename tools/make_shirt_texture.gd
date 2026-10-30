extends SceneTree

# Bakes Ava's UniSQ shirt base colors, one per colourway, with the UniSQ logo
# (res/unisq-logo-acronym.svg) single-colour on the chest:
#   Gold   - brand gold, purple logo, as on the UniSQ PowerPoint template
#   Purple - the reverse, brand purple with a gold logo
#   Orchid, Coal - the student merch tees (res/usq-student-merch-tshirt-*.png):
#            white logo, stacked large. Coal is sampled from its photo; orchid
#            is its photo's hue a little more saturated, as the photo's own
#            colour reads grey under the studio lights.
# The first two use the horizontal lockup as drawn in the SVG; the merch tees
# use the stacked one, shield centred above the wordmark, both cut from the
# same SVG at the same scale. scripts/unisq_shirt.gd swaps between them.
# Rerun after changing the logo or its placement:
#
#   <fork editor binary> --headless --path . --script "$PWD/tools/make_shirt_texture.gd"
#
# The shirt's UVs stretch unevenly over the chest (squashed on the upper
# chest, stretched under the bust), so the logo isn't pasted into UV space:
# it's projected flat onto the front of the shirt mesh, like a screen print
# seen face on, and each texel takes the logo where its point on the shirt
# lands. Its anchor is still given as a point in UV space (see the panels in
# scenes/Ava/Maps/Clothes_M_DG_bodyShapeA_Shirt_AO.png: the front panel is
# the bottom-left one, with the deep neckline); its size is in metres.

const LOGO := "res://res/unisq-logo-acronym.svg"
const SHIRT := "res://prefabs/ava.tscn"
const SHIRT_NODE := "Ava_Outfits3"
const SHIRT_SURFACE := 1
const SIZE := 2048
const GOLD := Color("#FFB448")
const PURPLE := Color("#3C2D4D")
const ORCHID := Color("#D7BBC4")
const COAL := Color("#232122")
const WHITE := Color("#FFFFFF")
const MIRROR := false # flips the logo, should it ever come out reading backwards

# Horizontal lockup: a chest print, centred on its anchor.
const CHEST_CENTER := Vector2(0.28, 0.565) # UV
const CHEST_WIDTH := 0.16 # m
# Stacked lockup: a large front print, hung from its top centre.
const STACKED_TOP := Vector2(0.28, 0.555) # UV
const STACKED_WIDTH := 0.15 # m, of the wordmark (the widest part)
# In the SVG's units: the shield is x 0-201.9, the wordmark from x 263 on.
const SHIELD_RIGHT := 202.0
const WORDMARK_LEFT := 262.0
const STACK_GAP := 61.0 # shield to wordmark, as on the merch tees
const LOGO_PX := 1600 # resolution the logo is rasterised at before projecting

var positions: PackedVector3Array
var uvs: PackedVector2Array
var front_tris: Array[int] = [] # first index of each triangle facing forward
var indices: PackedInt32Array

func _initialize():
	_load_shirt()
	bake(GOLD, PURPLE, false, "res://scenes/Ava/Maps/Shirt_UniSQ_Gold_Basecolor.png")
	bake(PURPLE, GOLD, false, "res://scenes/Ava/Maps/Shirt_UniSQ_Purple_Basecolor.png")
	bake(ORCHID, WHITE, true, "res://scenes/Ava/Maps/Shirt_UniSQ_Orchid_Basecolor.png")
	bake(COAL, WHITE, true, "res://scenes/Ava/Maps/Shirt_UniSQ_Coal_Basecolor.png")
	quit()

func bake(shirt: Color, ink: Color, stacked: bool, out: String):
	var logo := _stacked_logo() if stacked else _render_logo(LOGO_PX / _svg_width())
	if MIRROR:
		logo.flip_x()

	# The logo's rect on the shirt's front plane (x across, z up), in metres.
	var width := STACKED_WIDTH if stacked else CHEST_WIDTH
	var anchor := _front(STACKED_TOP if stacked else CHEST_CENTER)
	var height := width * logo.get_height() / logo.get_width()
	var top := anchor.y if stacked else anchor.y + height / 2.0
	var left := anchor.x - width / 2.0

	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(shirt)
	for t in front_tris:
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var pa := _xz(positions[a])
		var pb := _xz(positions[b])
		var pc := _xz(positions[c])
		var reach := Rect2(pa, Vector2.ZERO).expand(pb).expand(pc)
		if not reach.intersects(Rect2(left, top - height, width, height)):
			continue
		var ta := uvs[a] * SIZE
		var tb := uvs[b] * SIZE
		var tc := uvs[c] * SIZE
		var box := Rect2(ta, Vector2.ZERO).expand(tb).expand(tc)
		for y in range(floori(box.position.y), ceili(box.end.y) + 1):
			for x in range(floori(box.position.x), ceili(box.end.x) + 1):
				var w := _barycentric(Vector2(x + 0.5, y + 0.5), ta, tb, tc)
				if w.x < -0.001 or w.y < -0.001 or w.z < -0.001:
					continue
				var p := pa * w.x + pb * w.y + pc * w.z
				var lx := (p.x - left) / width * logo.get_width()
				var ly := (top - p.y) / height * logo.get_height()
				var alpha := _alpha_at(logo, lx, ly)
				if alpha > 0.0:
					img.set_pixel(x, y, shirt.lerp(ink, alpha))
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("wrote ", out)

# The shield centred above the wordmark, both at the SVG's own scale.
func _stacked_logo() -> Image:
	var scale := LOGO_PX / (_svg_width() - WORDMARK_LEFT)
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

# Bilinear coverage of the logo at a (fractional) pixel position.
func _alpha_at(logo: Image, x: float, y: float) -> float:
	x -= 0.5
	y -= 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	var top := lerpf(_alpha(logo, x0, y0), _alpha(logo, x0 + 1, y0), fx)
	var bottom := lerpf(_alpha(logo, x0, y0 + 1), _alpha(logo, x0 + 1, y0 + 1), fx)
	return lerpf(top, bottom, fy)

func _alpha(logo: Image, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= logo.get_width() or y >= logo.get_height():
		return 0.0
	return logo.get_pixel(x, y).a

# The shirt in its bind pose: x across the body, y front to back, z up.
func _load_shirt():
	var ava: Node = load(SHIRT).instantiate()
	var mesh: Mesh = (ava.find_child(SHIRT_NODE, true, false) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(SHIRT_SURFACE)
	positions = arrays[Mesh.ARRAY_VERTEX]
	uvs = arrays[Mesh.ARRAY_TEX_UV]
	indices = arrays[Mesh.ARRAY_INDEX]
	ava.free()

	# Forward is whichever way the front panel (around the chest anchor) faces.
	var forward := 0.0
	for t in range(0, indices.size(), 3):
		var centre := (uvs[indices[t]] + uvs[indices[t + 1]] + uvs[indices[t + 2]]) / 3.0
		if centre.distance_to(CHEST_CENTER) < 0.1:
			forward += _normal(t).y
	for t in range(0, indices.size(), 3):
		if _normal(t).y * signf(forward) > 0.2:
			front_tris.append(t)

func _normal(t: int) -> Vector3:
	var a := positions[indices[t]]
	return (positions[indices[t + 1]] - a).cross(positions[indices[t + 2]] - a).normalized()

func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

# Where a UV point lies on the shirt's front plane.
func _front(uv: Vector2) -> Vector2:
	for t in front_tris:
		var w := _barycentric(uv, uvs[indices[t]], uvs[indices[t + 1]], uvs[indices[t + 2]])
		if w.x >= 0.0 and w.y >= 0.0 and w.z >= 0.0:
			return _xz(positions[indices[t]]) * w.x + _xz(positions[indices[t + 1]]) * w.y + _xz(positions[indices[t + 2]]) * w.z
	push_error("UV point %s isn't on the front of the shirt" % uv)
	return Vector2.ZERO

func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var d := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 1e-12:
		return Vector3(-1, -1, -1)
	var u := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
	var v := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
	return Vector3(u, v, 1.0 - u - v)
