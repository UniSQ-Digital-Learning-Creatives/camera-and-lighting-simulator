extends Node

@onready var camera = %"POV Cam"
@onready var zebra_slider = %ZebraSlider
@onready var zebra_num = %ZebraNum

# The histogram is the engine's: the camera counts the brightness levels of
# its picture on the GPU (Camera3D's monitoring histogram) and hands the counts
# over 4 times a second. It counts the picture from before the zebras and false
# colour are drawn on it, so it always shows the photo itself. The engine
# could also draw it over the picture; here only the panel draws it
# (histogram.gd), so monitoring_histogram_draw is off.
var histogram_bins = []
var highlights_clipping := false
var shadows_clipping := false

signal analysis_updated


func _ready():
	add_to_group("monitoring")
	histogram_bins.resize(64)
	histogram_bins.fill(0)
	_on_zebra_slider_value_changed(zebra_slider.value)

	camera.monitoring_histogram_enabled = true
	camera.monitoring_histogram_draw = false
	camera.monitoring_histogram_update_interval = 0.25
	camera.monitoring_histogram_updated.connect(calculate_histogram)

func calculate_histogram():
	# How many pixels have each of the 256 levels of brightness (Rec. 709
	# luma, the brightness as displayed, 0 black to 255 white).
	var levels = camera.get_monitoring_histogram()
	if levels.is_empty():
		return # (on the web the first counts take a few frames to arrive)

	# The panel shows 64 bars, 4 levels each.
	histogram_bins.fill(0)
	for level in range(levels.size()):
		histogram_bins[int(level / 4.0)] += levels[level]

	# Clipping: any pixel brighter than 98% (levels 250-255) or darker than
	# 2% (levels 0-5).
	highlights_clipping = false
	shadows_clipping = false
	for level in range(250, 256):
		if levels[level] > 0:
			highlights_clipping = true
	for level in range(0, 6):
		if levels[level] > 0:
			shadows_clipping = true

	analysis_updated.emit()

func _on_zebra_toggle_toggled(toggled_on):
	camera.monitoring_zebras_enabled = toggled_on

# The zebra level is a video level in IRE (percent of full brightness).
func _on_zebra_slider_value_changed(value):
	camera.monitoring_zebras_level = value
	zebra_num.text = str(int(value)) + "%"

func _on_false_colour_toggle_toggled(toggled_on):
	camera.monitoring_false_color_enabled = toggled_on
