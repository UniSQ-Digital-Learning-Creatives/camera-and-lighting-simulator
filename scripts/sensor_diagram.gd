extends Control

@onready var main = get_tree().root.find_child("Main", true, false)
@onready var sensor_label = %SensorLabel

var settings:
	get:
		return main.settings

#3:2 ratio
const frame_width = 180/2
const frame_height = 120/2

func _draw():
	var full_rect = Rect2(
		(size.x - frame_width) * 0.5,
		(size.y - frame_height) * 0.5,
		frame_width,
		frame_height
		)
	
	# Full image area
	draw_rect(
	full_rect,
	Color("#555555"),
	false,
	2
	)
	
	var crop_factor = settings.get_crop_factor()
	
	var equivalent_focal_length = (
	settings.focal_length
	* crop_factor
	)
	
	#update the label
	sensor_label.text = (
	settings.sensor_name
	+ " | Crop Factor: "
	+ str(crop_factor)
	+ "x\n"
	+ str(settings.focal_length)
	+ "mm = "
	+ str(round(equivalent_focal_length))
	+ "mm full-frame equiv."
	)
	
	var sensor_rect

	var sensor_w = 36.0
	var sensor_h = 24.0

	if settings.sensor_width == 23.6:
		sensor_w = 23.6
		sensor_h = 15.7
	elif settings.sensor_width == 17.3:
		sensor_w = 17.3
		sensor_h = 13.0

	var width_scale = sensor_w / 36.0
	var height_scale = sensor_h / 24.0

	var sensor_size = Vector2(
		full_rect.size.x * width_scale,
		full_rect.size.y * height_scale
	)

	sensor_rect = Rect2(
		full_rect.get_center() - sensor_size * 0.5,
		sensor_size
	)
	
	# Full-frame reference
	draw_rect(
		full_rect,
		Color("#555555"),
		false,
		2
	)

	# Active sensor fill
	draw_rect(
		sensor_rect,
		Color(0.30, 0.65, 1.0, 0.2),
		true
	)

	# Active sensor outline
	draw_rect(
		sensor_rect,
		Color("#4DA6FF"),
		false,
		3
	)
