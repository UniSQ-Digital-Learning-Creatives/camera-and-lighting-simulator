extends Control

@onready var monitoring = (
	get_tree().get_first_node_in_group("monitoring")
)

var scale_factor := 1

func _ready():
	
	if monitoring != null:
		monitoring.analysis_updated.connect(queue_redraw)

func _draw():
	
	if monitoring == null:
		print("No monitoring")
		return
	
	var histogram_data = monitoring.histogram_bins
	var hist_width = size.x * scale_factor
	var x_offset = (size.x - hist_width) / 2.0
	var width_per_bin = hist_width / histogram_data.size()
	var max_value = 1
	
	for value in histogram_data:
		max_value = max(max_value, value)
	
	var y_offset = (size.y - size.y * scale_factor) / 2.0
	
	# Background
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0,0,0,0.5)
	)
	
	# Border Colour: red when highlights clip, blue when shadows crush
	var border_colour = Color(1, 1, 1, 0.25)

	if monitoring.highlights_clipping:
		border_colour = Color.RED
	elif monitoring.shadows_clipping:
		border_colour = Color.DODGER_BLUE

	# Border
	draw_rect(
		Rect2(Vector2.ZERO, size),
		border_colour,
		false,
		1.0
	)
	
	# Histogram Bars
	for i in range(histogram_data.size() ):
		
		var colour = Color.WHITE
		
		if i < 5:
			colour = Color.DODGER_BLUE
		
		if i > histogram_data.size() - 6:
			colour = Color.RED
		
		var height = (float(histogram_data[i]) / max_value) * size.y * scale_factor
		
		draw_rect(
			Rect2(
				x_offset + i * width_per_bin,
				size.y - height,
				width_per_bin,
				height
			),
			colour
		)
	
	
		
	
	
