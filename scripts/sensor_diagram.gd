extends Node2D

var sensor_width = 36.0

func _draw():

	# Full image area
	draw_rect(
		Rect2(50, 50, 300, 200),
		Color.WHITE,
		false,
		2
	)

	var sensor_rect

	if sensor_width == 36.0:
		sensor_rect = Rect2(50, 50, 300, 200)

	elif sensor_width == 23.6:
		sensor_rect = Rect2(90, 77, 220, 146)

	else:
		sensor_rect = Rect2(120, 95, 160, 110)

	draw_rect(
		sensor_rect,
		Color.GREEN,
		false,
		3
	)

	draw_circle(
		Vector2(200, 150),
		10,
		Color.RED
	)
