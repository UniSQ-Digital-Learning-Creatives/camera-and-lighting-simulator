extends Node

@onready var main = get_tree().root.find_child("Main", true, false)
@onready var texture_rect = %TextureRect
@onready var zebra_slider = %ZebraSlider
@onready var zebra_num = %ZebraNum

# The histogram is worked out from a small copy of the camera image, scaled
# down on the GPU: reading that back is 1/100th of the data of the full
# 1280x720 image, and the loop below only has to visit 9,216 pixels.
# 128 wide on purpose: on the web build a row of a GPU readback must be a
# multiple of 256 bytes (128 px x 4 bytes = 512). At 96 px wide (384 bytes)
# the WebGPU readback came back garbled and the histogram showed nonsense.
const ANALYSIS_SIZE := Vector2i(128, 72)
var _analysis: SubViewport

var histogram_bins = []
var brightest_pixel := 0.0
var darkest_pixel := 1.0
var timer := 0.0
var highlights_clipping := false
var shadows_clipping := false

signal analysis_updated


func _ready():
	add_to_group("monitoring")
	histogram_bins.resize(64)
	for i in range(histogram_bins.size()):
		histogram_bins[i] = 0
	_on_zebra_slider_value_changed(zebra_slider.value)

	var small = TextureRect.new()
	small.texture = %SubViewport.get_texture()
	# Draw the camera image opaque: on the web build its alpha comes back as
	# ~0, and a plain TextureRect would blend it into the grey clear colour
	# (the same quirk the monitor shader works around).
	var opaque = Shader.new()
	opaque.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0); }\n"
	small.material = ShaderMaterial.new()
	small.material.shader = opaque
	small.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	small.stretch_mode = TextureRect.STRETCH_SCALE
	small.size = ANALYSIS_SIZE
	_analysis = SubViewport.new()
	_analysis.size = ANALYSIS_SIZE
	_analysis.disable_3d = true
	_analysis.render_target_update_mode = SubViewport.UPDATE_ONCE
	_analysis.add_child(small)
	add_child(_analysis)

func calculate_histogram():
	# This reads the copy rendered at the previous update, so the histogram
	# lags a quarter of a second, and it suits the web build, where a readback
	# always returns an earlier frame (godotwebgpu TASKS §4.2).
	var image = _analysis.get_texture().get_image()
	_analysis.render_target_update_mode = SubViewport.UPDATE_ONCE

	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var data := image.get_data()
	if data.size() < 4 or data[3] == 0:
		return # a web readback that hasn't arrived yet (zero-filled)

	histogram_bins.fill(0)
	brightest_pixel = 0.0
	darkest_pixel = 1.0

	for i in range(0, data.size(), 4):
		var lum = (data[i] * 0.2126 + data[i + 1] * 0.7152 + data[i + 2] * 0.0722) / 255.0

		brightest_pixel = max(brightest_pixel, lum)

		darkest_pixel = min(darkest_pixel, lum)

		var bin = clamp(int(lum * 63), 0, 63)

		histogram_bins[bin] += 1

	highlights_clipping = brightest_pixel > 0.98
	shadows_clipping = darkest_pixel < 0.02

func _on_zebra_toggle_toggled(toggled_on):
	texture_rect.set_zebras_enabled(toggled_on)

func _on_zebra_slider_value_changed(value):
	texture_rect.set_zebra_threshold(value / 100.0)
	zebra_num.text = str(int(value)) + "%"

func _on_false_colour_toggle_toggled(toggled_on):
	texture_rect.set_false_colour_enabled(toggled_on)

func _process(delta):

	timer += delta

	if timer > 0.25:

		timer = 0.0

		calculate_histogram()
		analysis_updated.emit()
