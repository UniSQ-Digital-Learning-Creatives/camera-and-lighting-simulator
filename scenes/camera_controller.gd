extends Node

# Focus. Auto Focus is the engine's: the camera (POV Cam, autofocus_mode
# Continuous, autofocus_target %Marker3D) keeps the lens on her face as she
# moves, by moving its depth of field's focus plane (main.update_dof). Dragging
# Distance switches it to Manual and sets that distance by hand.

@onready var main = get_tree().root.find_child("Main", true, false)

var settings:
	get:
		return main.settings

@onready var camera = %"POV Cam"

@onready var focus_dist_slider = %FocusDistSlider
@onready var focus_dist_num =  %FocusDistanceNum

var _last_focus_distance = null
var _last_autofocus_enabled = null

# Puts the camera's focus back in line with main.settings (startup, preset load).
func sync_focus_distance_slider():
	if settings.autofocus_enabled:
		camera.autofocus_mode = Camera3D.AUTOFOCUS_MODE_CONTINUOUS
	else:
		camera.autofocus_mode = Camera3D.AUTOFOCUS_MODE_MANUAL
	focus_dist_slider.set_value_no_signal(settings.manual_focus_distance)

func _on_focus_dist_slider_value_changed(value):
	settings.autofocus_enabled = false
	settings.manual_focus_distance = value
	camera.autofocus_mode = Camera3D.AUTOFOCUS_MODE_MANUAL
	main.update_info_label()

func _on_auto_focus_pressed() -> void:
	settings.autofocus_enabled = true
	camera.autofocus_mode = Camera3D.AUTOFOCUS_MODE_CONTINUOUS
	main.update_info_label()

func _process(_delta):
	if settings.autofocus_enabled:
		settings.focus_distance = camera.get_autofocus_distance()
	else:
		settings.focus_distance = settings.manual_focus_distance

	# Autofocus moves the focus a little every frame as she sways; only rebuild
	# the labels once it has moved by more than 2 mm (or the mode changed).
	if _last_focus_distance == null or absf(settings.focus_distance - _last_focus_distance) > 0.002 or settings.autofocus_enabled != _last_autofocus_enabled:
		_last_focus_distance = settings.focus_distance
		_last_autofocus_enabled = settings.autofocus_enabled

		if settings.autofocus_enabled:
			settings.manual_focus_distance = settings.focus_distance
			focus_dist_slider.set_value_no_signal(settings.focus_distance)
		focus_dist_num.text = str(
			snapped(settings.focus_distance, 0.1)
		) + "m"
		main.update_info_label()
