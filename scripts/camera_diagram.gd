extends Node2D

var current_fov = 40
var camera_distance = 100
var subject_position = Vector2(500, 150)
var key_angle = 45.0
var fill_angle = 135.0
var rim_angle = 180.0

var key_distance = 4.0
var fill_distance = 3.0
var rim_distance = 5.0

func _ready():
	queue_redraw()

func _draw():

	var camera_position = Vector2(
		subject_position.x,
		subject_position.y + camera_distance
	)
	var cone_length = 250.0

	draw_circle(
	camera_position,
	8,
	Color.YELLOW
)

	var half_angle = deg_to_rad(current_fov / 2.0)

	var top_point = camera_position + Vector2(
	sin(-half_angle) * cone_length,
	-cos(-half_angle) * cone_length
)

	var bottom_point = camera_position + Vector2(
		sin(half_angle) * cone_length,
		-cos(half_angle) * cone_length
	)

	draw_line(
		camera_position,
		top_point,
		Color.GREEN,
		4
	)

	draw_line(
		camera_position,
		bottom_point,
		Color.GREEN,
		4
	)

	
	draw_circle(
	subject_position,
	10,
	Color.RED
)

	draw_colored_polygon(
	[
		camera_position,
		top_point,
		bottom_point
	],
	Color(0, 1, 0, 0.2)
)

	draw_light(
	key_angle,
	key_distance,
	Color.YELLOW
)

	draw_light(
		fill_angle,
		fill_distance,
		Color.CYAN
	)

	draw_light(
		rim_angle,
		rim_distance,
		Color.MAGENTA
	)


func draw_light(
	light_angle,
	light_distance,
	color
):

	var angle_rad = deg_to_rad(light_angle)

	var light_position = subject_position + Vector2(
		cos(angle_rad) * light_distance * 40,
		sin(angle_rad) * light_distance * 40
	)

	var cone_length = 40.0
	var cone_width = 20.0

	var direction = (subject_position - light_position).normalized()

	var perpendicular = Vector2(
		-direction.y,
		direction.x
	)

	var left = light_position + perpendicular * cone_width

	var right = light_position - perpendicular * cone_width

	var tip = light_position + direction * cone_length

	draw_colored_polygon(
		[
			left,
			right,
			tip
		],
		color
	)

	draw_circle(
		light_position,
		6,
		color
	)
