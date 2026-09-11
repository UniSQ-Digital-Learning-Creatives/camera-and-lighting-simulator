extends Node2D

var aperture_value := 5.6
var lens_green = Color(0.2, 1.0, 0.4)
var dark_green = Color(0.05, 0.2, 0.08)

func set_aperture(value):
	aperture_value = value
	print("Aperture updated:", value)
	queue_redraw()

func _draw():
	var centre = Vector2.ZERO
	var outer_radius = 50.0

	# Outer ring
	draw_circle(
		centre,
		outer_radius,
		dark_green
	)

	var opening = remap(
		aperture_value,
		1.4,
		22.0,
		35.0,
		6.0
	)

	var blades = 7

	for i in range(blades):
		var angle = TAU * i / blades

		var p1 = centre
		var p2 = centre + Vector2(cos(angle), sin(angle)) * outer_radius
		var p3 = centre + Vector2(cos(angle + 0.4), sin(angle + 0.4)) * opening

		draw_colored_polygon(
			PackedVector2Array([p1, p2, p3]),
			lens_green
		)

	draw_circle(
		centre,
		opening,
		Color.CORNSILK
	)
	
	draw_arc(
		centre,
		outer_radius,
		0,
		TAU,
		64,
		lens_green,
		2.0
	)
