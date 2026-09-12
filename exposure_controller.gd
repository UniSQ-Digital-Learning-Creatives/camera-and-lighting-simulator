extends Node

@onready var aperture_label = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/ApertureLabel"
@onready var world_env = $"../WorldEnvironment"
@onready var camera = $"../POV Cam"
@onready var subject = $"../Subject"
@onready var iso_label = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/IsoLabel"
@onready var shutter_label = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/ShutterLabel"
#@onready var exposure_meter = $"../CanvasLayer/Exposure Panel/Control/VBoxContainer/ExposureMeter"
#@onready var pointer = $"../CanvasLayer/Exposure Panel/Control/VBoxContainer/ExposureMeter/Panel/Pointer"
@onready var dof_label = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/DOFLabel"
@onready var focus_dist_label = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/FocusDistLabel"
@onready var focus_status_label = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/Focus Status"
@onready var aperture_indicator = $"../ApertureIndicator"
@onready var main = get_parent()

@onready var aperture_slider = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/ApertureSlider"
@onready var iso_slider = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/ISOSlider"
@onready var shutter_slider = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/ShutterSlider"
@onready var focus_dist_slider = $"../CanvasLayer/CameraPanel/ScrollContainer/MarginContainer/VBoxContainer/FocusDistSlider"

signal focus_distance_change(focus_distance)

var aperture := 8
var shutter_speed := 1.0 / 125.0
var iso := 100
var noise_strength := 0.0
var scene_ev := 13.0
var shutter_index := 7
var focus_distance := 5.0
var manual_focus_distance := 5.0
var autofocus_enabled := true
#var blur_amount = 0.0
var subject_distance = 1

var _last_brightness = null

var dof_data = {
	"aperture": 8,
	"focus_distance": 5.0,
	"focal_length": 50.0,
	"sensor_width": 36.0
}

var shutter_speeds = [
	1.0,       # 1"
	0.5,       # 1/2
	0.25,      # 1/4
	0.125,     # 1/8
	0.0625,    # 1/16
	0.0333,    # 1/30
	0.0167,    # 1/60
	0.008,     # 1/125
	0.004,     # 1/250
	0.002,     # 1/500
	0.001,     # 1/1000
	0.0005,    # 1/2000
	0.00025    # 1/4000
]
var shutter_labels = [
	"1\"",
	"1/2",
	"1/4",
	"1/8",
	"1/15",
	"1/30",
	"1/60",
	"1/125",
	"1/250",
	"1/500",
	"1/1000",
	"1/2000",
	"1/4000"
]

func get_camera_ev() -> float:
	return log((aperture * aperture) / shutter_speed) / log(2.0)
	
func get_final_ev() -> float:
	var camera_ev = get_camera_ev()
	var iso_adjustment = log(iso / 100.0) / log(2.0)

	return camera_ev - iso_adjustment

func get_exposure_difference() -> float:
	return get_final_ev() - scene_ev
	
func get_noise_strength() -> float:
	return clamp(
		(iso - 100.0) / 6300.0,
		0.0,
		1.0
	)
	
func _ready():
	aperture_slider.set_value_no_signal(aperture)
	iso_slider.set_value_no_signal(iso)
	shutter_slider.set_value_no_signal(shutter_index)

	aperture_indicator.set_aperture(aperture)

func sync_focus_distance_slider():
	if autofocus_enabled:
		focus_distance = get_subject_distance()
		manual_focus_distance = focus_distance

	focus_dist_slider.set_value_no_signal(manual_focus_distance)

func _process(delta):

	#var subject_distance = camera_distance

	#blur_amount = (
	#	abs(subject_distance - focus_distance)
	#	* (10.0 / aperture)
	#	* (focal_length / 50.0)
	#)

	#blur_amount = clamp(blur_amount, 0.0, 20.0)


	if autofocus_enabled:
		focus_distance = camera.global_position.distance_to(
		subject.global_position
	)
	else: focus_distance = manual_focus_distance
	

	var diff = get_exposure_difference()
	#var noise = get_noise_strength()
	var meter_value = clamp(diff, -3.0, 3.0)
	var brightness = pow(2.0,-diff)

	# adjustment_brightness lives on the Environment resource, so writing it
	# pushes a RenderingServer update across the JS/WASM bridge on web;
	# skip the call on frames where exposure hasn't actually changed.
	if _last_brightness == null or absf(brightness - _last_brightness) > 0.0005:
		world_env.environment.adjustment_enabled = true
		world_env.environment.adjustment_brightness = brightness
		_last_brightness = brightness

	#pointer.position.x = 150 + meter_value * 50
	

	var focus_mode = "AUTO" if autofocus_enabled else "MANUAL"

	focus_dist_label.text = (
		"Mode: " + focus_mode
		+ "\nFocus: "
		+ str(snapped(focus_distance, 0.1))
		+ "m"
		+ "\nSubject: "
		+ str(snapped(subject_distance, 0.1))
		+ "m"
	)
	
	
	
	
	

	#focus_dist_label.text = (
		#"Focus: "
		#+ str(snapped(focus_distance, 0.1))
		#+ "m"
		#+ "\nSubject: "
		#+ str(snapped(subject_distance, 0.1))
		#+ "m"
	#)
	#
	#exposure_meter.text = ("-3  -2  -1   0  +1  +2  +3\n" +"Exposure: " + str(snapped(diff, 0.1))
	#)
#
	iso_label.text = "ISO " + str(int(iso))
	
	shutter_label.text = shutter_labels[shutter_index]
#
	aperture_label.text = (
		"f/" + str(snapped(aperture, 0.1))
		+ "\nEV Difference: "
		+ str(snapped(diff, 0.1))
	)
	#
	#if abs(diff) < 0.5: pointer.modulate = Color.GREEN
	#elif abs(diff) < 1.5: pointer.modulate = Color.ORANGE
	#else: pointer.modulate = Color.RED
	#
	#var dof = get_dof_strength()
#
	#if dof < 0.2:
		#dof_label.text = "Depth of Field: Very Deep"
#
	#elif dof < 0.4:
		#dof_label.text = "Depth of Field: Deep"
#
	#elif dof < 0.6:
		#dof_label.text = "Depth of Field: Moderate"
#
	#elif dof < 0.8:
		#dof_label.text = "Depth of Field: Shallow"
#
	#else:
		#dof_label.text = "Depth of Field: Very Shallow"
		#
	#dof_data["aperture"] = aperture
	#dof_data["focus_distance"] = focus_distance
	#dof_data["focal_length"] = main.current_focal_length
	#dof_data["sensor_width"] = main.sensor_width
	#
	#var error = get_focus_error()
#
	#if error < 0.25:
		#focus_status_label.text = "Focus: Sharp"
#
	#elif error < 1.0:
		#focus_status_label.text = "Focus: Slightly Soft"
#
	#elif error < 3.0:
		#focus_status_label.text = "Focus: Soft"
#
	#else:
		#focus_status_label.text = "Focus: Out of Focus"


func _on_aperture_slider_value_changed(value):
	aperture = value
	aperture_indicator.set_aperture(value)

func _on_iso_slider_value_changed(value):
	iso = value

func _on_shutter_slider_value_changed(value: float) -> void:
	shutter_index = int(value)
	shutter_speed = shutter_speeds[shutter_index]

func get_dof_strength() -> float:

	var aperture_factor = remap(
		aperture,
		22.0,
		1.4,
		0.0,
		1.0
	)

	var focal_factor = remap(
		main.current_focal_length,
		24.0,
		200.0,
		0.0,
		1.0
	)

	var distance_factor = remap(
	get_subject_distance(),
	10.0,
	1.0,
	0.0,
	1.0
)


	return clamp(
		(aperture_factor * 0.5)
		+ (focal_factor * 0.3)
		+ (distance_factor * 0.2),
		0.0,
		1.0
	)

func _on_focus_dist_slider_value_changed(value):
	autofocus_enabled = false
	manual_focus_distance = value
	focus_distance = value
	print("Focus slider:",value)


func _on_auto_focus_pressed() -> void:

	autofocus_enabled = true

	manual_focus_distance = camera.global_position.distance_to(
			subject.global_position
		)

func get_subject_distance() -> float:

	return camera.global_position.distance_to(
		subject.global_position
	)
	
func get_focus_error() -> float:

	var subject_distance = get_subject_distance()

	return abs(
		subject_distance -
		focus_distance
	)
