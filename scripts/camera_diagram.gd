extends Control

@export var scale_factor := 0.4
@onready var scene_map_label = %SceneMapLabel
@onready var main = get_tree().root.find_child("Main", true, false)

var settings:
	get:
		return main.settings
		
var current_fov = 40
var camera_distance = 100
var subject_position = Vector2.ZERO
var key_angle = 45.0
var fill_angle = 135.0
var rim_angle = 180.0

var key_distance = 4.0
var fill_distance = 3.0
var rim_distance = 5.0

var show_key_light := true
var show_fill_light := false
var show_rim_light := false

func _ready():
	queue_redraw()

func _draw():
	#var camera_distance = size.y * 0.25
	update_label()

	subject_position = Vector2 (
		size.x / 2,
		size.y / 10
	)

	var camera_position = Vector2 (
		subject_position.x,
		subject_position.y + camera_distance
	)

	var cone_length = 250.0 * scale_factor

	draw_circle(
	camera_position,
	8 * scale_factor,
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
		Color("#4DA6FF"),
		4 * scale_factor
	)

	draw_line(
		camera_position,
		bottom_point,
		Color("#4DA6FF"),
		4 * scale_factor
	)

	
	draw_circle(
	subject_position,
	10 * scale_factor,
	Color.RED
)

	draw_colored_polygon(
		PackedVector2Array([
			camera_position,
			top_point,
			bottom_point
		]),
		Color(0.30, 0.65, 1.0, 0.2),
	)
		

	if show_key_light:
		draw_light(
			key_angle,
			key_distance,
			Color.YELLOW
		)

	if show_fill_light:
		draw_light(
			fill_angle,
			fill_distance,
			Color.CYAN
		)

	if show_rim_light:
		draw_light(
			rim_angle,
			rim_distance,
			Color.MAGENTA
		)


func update_label():

	scene_map_label.text = (
		"FOV: "
		+ str(round(current_fov))
		+ "°"
		+ "\nDistance: "
		+ str(snapped(settings.camera_distance, 0.1))
		+ "m"
	)

func draw_light(
	light_angle,
	light_distance,
	color
):

	var angle_rad = deg_to_rad(light_angle)

	var light_position = subject_position + Vector2(
		cos(angle_rad) * light_distance * 40 * scale_factor,
		sin(angle_rad) * light_distance * 40 * scale_factor
	)

	var cone_length = 40.0 * scale_factor
	var cone_width = 20.0 * scale_factor

	var direction = (subject_position - light_position).normalized()

	var perpendicular = Vector2(
		-direction.y,
		direction.x
	)

	var left = light_position + perpendicular * cone_width

	var right = light_position - perpendicular * cone_width

	var tip = light_position + direction * cone_length

	draw_colored_polygon(
		PackedVector2Array([
			left,
			right,
			tip
		]),
		color
	)

	draw_circle(
		light_position,
		6 * scale_factor,
		color
	)
