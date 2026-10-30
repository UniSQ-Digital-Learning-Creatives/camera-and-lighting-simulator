extends Control

@onready var main = get_tree().root.find_child("Main", true, false)

var settings:
	get:
		return main.settings


var aperture_value := 5.6
var lens_col = Color('#317bc4')
var fill_col = Color('#2d3641')
var scale_factor := 0.6

func set_aperture(value):
	aperture_value = value
	queue_redraw()

func _process(_delta):
	
	if settings == null:
		print("Settings is NULL")
		return

	if aperture_value != settings.aperture:
		aperture_value = settings.aperture
		queue_redraw()
		
func _draw():

	var centre = size / 2
	var outer_radius = 50.0 * scale_factor

	# Outer ring
	draw_circle(
		centre,
		outer_radius,
		fill_col
	)

	var opening = remap(
		aperture_value,
		1.4,
		22.0,
		35.0,
		6.0
	) * scale_factor

	var blades = 7

	for i in range(blades):
		var angle = TAU * i / blades

		var p1 = centre
		var p2 = centre + Vector2(cos(angle), sin(angle)) * outer_radius
		var p3 = centre + Vector2(cos(angle + 0.4), sin(angle + 0.4)) * opening

		draw_colored_polygon(
			PackedVector2Array([p1, p2, p3]),
			lens_col
		)

	draw_circle(
		centre,
		opening,
		Color("#ddeeff")
	)
	
	draw_arc(
		centre,
		outer_radius,
		0,
		TAU,
		64,
		lens_col,
		2.0
	)
	
	
