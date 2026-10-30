extends SceneTree

# Bakes Ava's shorts base color as faded blue denim: indigo warp over a pale
# weft in a right-hand twill, slubby threads, a soft stonewash mottle, lighter
# where the fabric is exposed and darker in its folds (from the AO map), and
# copper topstitching along the garment's stitch lines (from the stitch mask).
# Rerun after changing any of the constants:
#
#   <fork editor binary> --headless --path . --script "$PWD/tools/make_shorts_texture.gd"

const MAPS := "res://scenes/Ava/Maps/Clothes_M_DG_bodyShapeA_Short_"
const OUT := "res://scenes/Ava/Maps/Shorts_Denim_Basecolor.png"
const SIZE := 2048
const INDIGO := Color("#2E4A6E") # warp
const WEFT := Color("#B9C3CF")
const THREAD := Color("#C9893E") # topstitching
const TWILL_PITCH := 4 # px per twill line
const WEFT_SHOW := 0.22 # how much weft shows between the twill lines
const FADE := 0.3 # stonewash: how far the mottle lightens toward the weft

func _initialize():
	var ao := _load_map("AO")
	var stitch := _load_map("StitchMask")

	var mottle := FastNoiseLite.new()
	mottle.seed = 7
	mottle.frequency = 0.004
	mottle.fractal_octaves = 4
	var slub := FastNoiseLite.new() # thicker, lighter stretches along each warp thread
	slub.seed = 11
	slub.noise_type = FastNoiseLite.TYPE_VALUE
	slub.frequency = 0.05

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var column_tone := PackedFloat32Array() # warp threads vary a little in dye
	for x in SIZE:
		column_tone.append(rng.randf_range(-0.035, 0.035))

	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var twill := float((x + y) % TWILL_PITCH) / TWILL_PITCH
			var c := INDIGO.lerp(WEFT, WEFT_SHOW * smoothstep(0.55, 1.0, twill))
			c = c.lightened(column_tone[x] + 0.05 * maxf(slub.get_noise_2d(x, y * 0.15), 0.0))
			# Stonewash: exposed (high AO) fabric is worn lighter, folds stay dark.
			var exposure := ao.get_pixel(x, y).r
			var wash := FADE * (0.5 + 0.5 * mottle.get_noise_2d(x, y)) * exposure
			c = c.lerp(WEFT, wash).darkened(0.25 * (1.0 - exposure))
			c = c.lerp(THREAD, stitch.get_pixel(x, y).r)
			img.set_pixel(x, y, c)
	img.save_png(OUT)
	print("wrote ", OUT)
	quit()

func _load_map(map: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(MAPS + map + ".png"))
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return img
