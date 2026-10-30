extends Node

@export var viewport : SubViewport

var current_image : Image
var histogram_bins := []
var brightest_pixel := 0.0
var darkest_pixel := 1.0
var timer := 0.0
var highlights_clipping := false
var shadows_clipping := false
var average_luminance := 0

signal analysis_updated

func _ready():
	add_to_group("monitoring")
	histogram_bins.resize(64)
	for i in range(histogram_bins.size()):
		histogram_bins[i] = 0


func update_image():

	if viewport == null:
		return

	current_image = viewport.get_texture().get_image()



func calculate_histogram():

	if current_image == null:
		return

	histogram_bins.resize(64)

	for i in range(histogram_bins.size()):
		histogram_bins[i] = 0

	brightest_pixel = 0.0
	darkest_pixel = 1.0
	highlights_clipping = brightest_pixel > 0.98
	shadows_clipping = darkest_pixel < 0.02

	for y in range(0, current_image.get_height(), 8):

		for x in range(0, current_image.get_width(), 8):

			var pixel = current_image.get_pixel(x,y)

			var lum = pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722

			brightest_pixel = max(brightest_pixel, lum)
			
			darkest_pixel = min(darkest_pixel, lum)

			var bin = clamp(int(lum * 63), 0, 63)

			histogram_bins[bin] += 1




func _process(delta):

	timer += delta

	if timer > 0.25:

		timer = 0.0

		update_image()
		calculate_histogram()
		emit_signal("analysis_updated")
