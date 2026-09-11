extends Node3D


@onready var label = $CanvasLayer/CameraPanel/MarginContainer/VBoxContainer/LensLabel
@onready var lens_slider = $CanvasLayer/CameraPanel/MarginContainer/VBoxContainer/lensSlider
@onready var subject = $Subject
@onready var camera_distance_label = $CanvasLayer/CameraPanel/MarginContainer/VBoxContainer/CameraDistanceLabel

@onready var camera_distance_slider = $CanvasLayer/CameraPanel/MarginContainer/VBoxContainer/CameraDistanceSlider
@onready var camera_height_slider = $CanvasLayer/CameraPanel/MarginContainer/VBoxContainer/CameraHeightSlider

@onready var key_angle_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Key Angle Group/KeyAngleSlider"
@onready var key_dist_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Key Dist Group/KeyDist"
@onready var key_height_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Key Height Group/KeyHeight"
@onready var key_temp_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Key Temp Group/Keytemp"

@onready var fill_angle_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Fill Angle Group/FillAngleSlider"
@onready var fill_dist_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Fill Dist Group/FillDist"
@onready var fill_height_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Fill Height Group/FillHeight"
@onready var fill_temp_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Fill Temp Group/Fill Temp"

@onready var rim_angle_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Rim Angle Group/RimAngleSlider"
@onready var rim_dist_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Rim Dist Group/RimDist"
@onready var rim_height_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Rim Height Group/RimHeight"
@onready var rim_temp_slider = $"CanvasLayer/LightingPanel/MarginContainer/VBoxContainer/Rim Temp Group/Rim Temp"

@onready var camera = $"POV Cam"
@onready var pov_camera_render = $MainViewport/POVCameraRender
@onready var exposure_controller = $ExposureController


@onready var main_view_texture_rect = $CanvasLayer/MainViewTextRect
@onready var main_viewport = $MainViewport

var camera_distance := 5.0
var camera_height := 0.4
var sensor_width = 36.0
var current_focal_length = 50
var camera_angle = 90


# Lighting variables

var key_angle = 45.0
var fill_angle = 135.0
var rim_angle = 180.0

var key_distance = 1.5
var fill_distance = 1.5
var rim_distance = 1.5

var key_height = 0.8
var fill_height = 0.8
var rim_height = 0.8

var key_temperature = 5600.0
var fill_temperature = 5600.0
var rim_temperature = 5600.0

func _process(_delta):
	pov_camera_render.global_transform = camera.global_transform
	pov_camera_render.fov = camera.fov
	update_dof()

func update_dof():
	var attributes = camera.attributes

	var focus_distance = exposure_controller.focus_distance
	var aperture = exposure_controller.aperture

	attributes.dof_blur_near_distance = focus_distance
	attributes.dof_blur_far_distance = focus_distance

	var transition = remap(aperture, 1.4, 22.0, 0.15, 2.5)
	attributes.dof_blur_near_transition = transition
	attributes.dof_blur_far_transition = transition

	attributes.dof_blur_amount = remap(aperture, 1.4, 22.0, 0.5, 0.05)

func _ready():
	main_view_texture_rect.texture = main_viewport.get_texture()

	camera_distance = camera.global_position.distance_to(subject.global_position)

	set_lens(current_focal_length)
	update_lights()
	update_camera_position()

	camera_distance_label.text = (
		"Camera Distance: "
		+ str(snapped(camera_distance, 0.1))
		+ "m"
	)

	sync_sliders_to_data()
	exposure_controller.sync_focus_distance_slider()

	print("POV Cam: ", $"POV Cam".global_position)
	print("Render Cam: ", $MainViewport/POVCameraRender.global_position)


func sync_sliders_to_data():
	lens_slider.set_value_no_signal(current_focal_length)
	camera_distance_slider.set_value_no_signal(camera_distance)
	camera_height_slider.set_value_no_signal(camera_height)

	key_angle_slider.set_value_no_signal(key_angle)
	key_dist_slider.set_value_no_signal(key_distance)
	key_height_slider.set_value_no_signal(key_height)
	key_temp_slider.set_value_no_signal(key_temperature)

	fill_angle_slider.set_value_no_signal(fill_angle)
	fill_dist_slider.set_value_no_signal(fill_distance)
	fill_height_slider.set_value_no_signal(fill_height)
	fill_temp_slider.set_value_no_signal(fill_temperature)

	rim_angle_slider.set_value_no_signal(rim_angle)
	rim_dist_slider.set_value_no_signal(rim_distance)
	rim_height_slider.set_value_no_signal(rim_height)
	rim_temp_slider.set_value_no_signal(rim_temperature)


func set_lens(focal_length):
	
	current_focal_length = round(focal_length)
	
	var fov = rad_to_deg(
		2.0 * atan(sensor_width / (2.0 * focal_length))
	)
	
	print("Focal:", focal_length, " FOV:", fov)
	print("Sensor: ", sensor_width, " FOV:", fov)
	
	var sensor_name = ""

	camera.fov = fov
	
	$CameraDiagram.current_fov = fov
	$CameraDiagram.queue_redraw()


# Label Code

	if focal_length <= 24:
		label.text = "24mm\nWide Angle Lens"

	elif focal_length == 50:
		label.text = "50mm\nStandard Lens"

	elif focal_length == 200:
		label.text = "200mm\nTelephoto Lens"
		
	if sensor_width == 36.0:
		sensor_name = "Full Frame"

	elif sensor_width == 23.6:
		sensor_name = "APS-C"

	elif sensor_width == 17.3:
		sensor_name = "Micro Four Thirds"
		
	label.text = str(current_focal_length) + "mm"
	
	label.text += "\nSensor: " + sensor_name


# Button code

func _on_24mm_pressed():
	lens_slider.value = 24

func _on_50mm_pressed():
	lens_slider.value = 50

func _on_200mm_pressed():
	lens_slider.value = 200

func _on_full_frame_pressed():
	sensor_width = 36.0
	
	$SensorDiagram.sensor_width = sensor_width
	$SensorDiagram.queue_redraw()
	
	set_lens(current_focal_length)

func _on_apsc_pressed():

	sensor_width = 23.6

	$SensorDiagram.sensor_width = sensor_width
	$SensorDiagram.queue_redraw()

	set_lens(current_focal_length)

func _on_mft_pressed():
	sensor_width = 17.3
	
	$SensorDiagram.sensor_width = sensor_width
	$SensorDiagram.queue_redraw()
	
	set_lens(current_focal_length)

func _on_lens_slider_value_changed(value):
	set_lens(value)
	print("Lens changed:", value)

func get_light_position(subject_position, angle_deg, distance, height):

	var angle_rad = deg_to_rad(angle_deg)

	return subject_position + Vector3(
		cos(angle_rad) * distance,
		height,
		sin(angle_rad) * distance
	)

func update_lights():

	var subject_position = subject.global_position

	$KeyLight.position = get_light_position(
		subject_position,
		key_angle,
		key_distance,
		key_height
	)

	$FillLight.position = get_light_position(
		subject_position,
		fill_angle,
		fill_distance,
		fill_height
	)

	$RimLight.position = get_light_position(
		subject_position,
		rim_angle,
		rim_distance,
		rim_height
	)

	$KeyLight.look_at(subject_position)
	$FillLight.look_at(subject_position)
	$RimLight.look_at(subject_position)
	
	$CameraDiagram.key_angle = key_angle
	$CameraDiagram.fill_angle = fill_angle
	$CameraDiagram.rim_angle = rim_angle

	$CameraDiagram.key_distance = key_distance
	$CameraDiagram.fill_distance = fill_distance
	$CameraDiagram.rim_distance = rim_distance

	$CameraDiagram.queue_redraw()


func _on_key_angle_slider_value_changed(value):

	key_angle = value
	update_lights()


func _on_fill_angle_slider_value_changed(value):

	fill_angle = value
	update_lights()


func _on_rim_angle_slider_value_changed(value):

	rim_angle = value
	update_lights()



func _on_key_dist_value_changed(value: float) -> void:
	#print("Key distance:", value)

	key_distance = value
	update_lights()


func _on_fill_dist_value_changed(value: float) -> void:
	#print("Fill distance:", value)

	fill_distance = value
	update_lights()


func _on_rim_dist_value_changed(value: float) -> void:
	#print("Rim distance:", value)

	rim_distance = value
	update_lights()


func _on_key_height_value_changed(value: float) -> void:
	key_height = value
	update_lights()

func _on_fill_height_value_changed(value: float) -> void:
	fill_height = value
	update_lights()

func _on_rim_height_value_changed(value: float) -> void:
	rim_height = value
	update_lights()

func update_camera_position():

	var angle_rad = deg_to_rad(camera_angle)

	camera.global_position = subject.global_position + Vector3(
		cos(angle_rad) * camera_distance,
		camera_height,
		sin(angle_rad) * camera_distance
	)

	camera.rotation_degrees.x = 0
	camera.rotation_degrees.y = camera_angle - 90
	camera.rotation_degrees.z = 0

	$CameraDiagram.camera_distance = camera_distance * 20
	$CameraDiagram.queue_redraw()


func _on_camera_distance_slider_value_changed(value: float) -> void:

	camera_distance = value

	update_camera_position()

	camera_distance_label.text = (
		"Camera Distance: "
		+ str(snapped(camera_distance, 0.1))
		+ "m"
	)


func _on_camera_height_slider_value_changed(value: float) -> void:
	camera_height = value
	print("Camera height: ", camera_height)
	
	update_camera_position()

func kelvin_to_color(kelvin: float) -> Color:
	var temp = kelvin / 100.0

	var r
	var g
	var b

	if temp <= 66:
		r = 255
		g = clamp(99.47 * log(temp) - 161.12, 0, 255)

		if temp <= 19:
			b = 0
		else:
			b = clamp(138.52 * log(temp - 10) - 305.04, 0, 255)
	else:
		r = clamp(329.70 * pow(temp - 60, -0.133), 0, 255)
		g = clamp(288.12 * pow(temp - 60, -0.0755), 0, 255)
		b = 255

	return Color(r / 255.0, g / 255.0, b / 255.0)

func _on_keytemp_value_changed(value: float) -> void:
	key_temperature = value
	$KeyLight.light_color = kelvin_to_color(value)


func _on_fill_temp_value_changed(value: float) -> void:
	fill_temperature = value
	$FillLight.light_color = kelvin_to_color(value)


func _on_rim_temp_value_changed(value: float) -> void:
	rim_temperature = value
	$RimLight.light_color = kelvin_to_color(value)
