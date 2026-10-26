extends Node

@onready var main = get_tree().root.find_child("Main", true, false)

var settings:
	get:
		return main.settings

@onready var camera = %"POV Cam"
@onready var subject = %Marker3D

@onready var focus_dist_slider = %FocusDistSlider
@onready var focus_dist_num =  %FocusDistanceNum

var _last_focus_distance = null
var _last_autofocus_enabled = null

func sync_focus_distance_slider():
	if settings.autofocus_enabled:
		settings.focus_distance = get_subject_distance()
		settings.manual_focus_distance = settings.focus_distance

	focus_dist_slider.set_value_no_signal(settings.manual_focus_distance)

func _on_focus_dist_slider_value_changed(value):
	settings.autofocus_enabled = false
	settings.manual_focus_distance = value
	settings.focus_distance = value
	main.update_info_label()

func _on_auto_focus_pressed() -> void:

	settings.autofocus_enabled = true

	settings.manual_focus_distance = get_subject_distance()
	focus_dist_slider.set_value_no_signal(settings.manual_focus_distance)
	main.update_info_label()

func get_subject_distance() -> float:

	return camera.global_position.distance_to(
		subject.global_position
	)

func get_focus_error() -> float:
	return abs(
		get_subject_distance() -
		settings.focus_distance
	)

func _process(_delta):

	# Autofocus follows the subject (her head drifts a little with the idle
	# motion), refocusing once she has moved more than 2 mm, like a camera's AF
	# rather than every frame.
	if settings.autofocus_enabled:
		var distance = get_subject_distance()
		if absf(distance - settings.focus_distance) > 0.002:
			settings.focus_distance = distance

	else: settings.focus_distance = settings.manual_focus_distance

	# focus_distance only actually changes while dragging a camera/focus
	# slider or while autofocus tracks a moving subject; skip rebuilding the
	# labels on every other frame.
	if settings.focus_distance != _last_focus_distance or settings.autofocus_enabled != _last_autofocus_enabled:
		_last_focus_distance = settings.focus_distance
		_last_autofocus_enabled = settings.autofocus_enabled

		focus_dist_num.text = str(
			snapped(settings.focus_distance, 0.1)
		) + "m"
		main.update_info_label()
