extends Node

@onready var main = get_tree().root.find_child("Main", true, false)

var settings:
	get:
		return main.settings

@onready var world_env = %WorldEnvironment
@onready var texture_rect = %TextureRect

@onready var aperture_slider = %ApertureSlider
@onready var aperture_num = %ApertureNum

@onready var ISO_slider = %ISOSlider
@onready var ISO_num = %ISONum

@onready var shutter_slider = %ShutterSlider
@onready var shutter_num = %ShutterNum

var scene_ev := 13.0
var shutter_index := 7

var _last_brightness = null

func get_camera_ev() -> float:
	return log((settings.aperture * settings.aperture) / settings.shutter_speed) / log(2.0)

func get_final_ev() -> float:
	var camera_ev = get_camera_ev()
	var ISO_adjustment = log(settings.iso / 100.0) / log(2.0)

	return camera_ev - ISO_adjustment

func get_exposure_difference() -> float:
	return get_final_ev() - scene_ev

# Sensor noise model (the shader does the per-pixel part, see zebra.gdshader).
# A full-frame pixel of a ~24MP camera holds about 50,000 electrons at base
# ISO. At the same pixel count a smaller sensor has smaller pixels, so its
# full well shrinks with the sensor's area (1 / crop factor²): APS-C is about
# 1.2 stops and MFT 2 stops noisier than full frame for the same exposure.
const FULL_FRAME_FULL_WELL := 50000.0

# "Exaggerate noise" scales the realistic noise up by this much, for showing it
# on a projector or a small window, where real full-frame noise is subtle.
const NOISE_EXAGGERATION := 4.0

@onready var exaggerate_noise_toggle = %ExaggerateNoise

func update_noise():
	var full_well = FULL_FRAME_FULL_WELL / pow(settings.get_crop_factor(), 2.0)
	var boost = NOISE_EXAGGERATION if settings.exaggerate_noise else 1.0
	texture_rect.set_sensor_noise(settings.iso / 100.0, full_well, boost)

func _on_exaggerate_noise_toggled(toggled_on: bool) -> void:
	settings.exaggerate_noise = toggled_on
	update_noise()

# Puts the sliders, grain and brightness back in line with main.settings.
# Called by main.apply_settings() at startup and after a preset load/reset.
func sync_from_settings():
	shutter_index = settings.get_shutter_index()
	aperture_slider.set_value_no_signal(settings.aperture)
	ISO_slider.set_value_no_signal(settings.iso)
	shutter_slider.set_value_no_signal(shutter_index)
	exaggerate_noise_toggle.set_pressed_no_signal(settings.exaggerate_noise)
	update_noise()
	update_exposure_display()


# aperture/shutter/iso only ever change via slider signals below, never per
# frame -- computing this in _process() every frame (as it used to be) redid
# the same log()/pow() math and rebuilt three label strings ~60x/sec for
# values that were almost always unchanged. Called once from
# sync_from_settings() and once from each relevant slider callback instead.
func update_exposure_display():
	var diff = get_exposure_difference()
	var brightness = pow(2.0, -diff)

	# adjustment_brightness lives on the Environment resource, so writing it
	# pushes a RenderingServer update across the JS/WASM bridge on web;
	# skip the call when exposure hasn't actually changed.
	if _last_brightness == null or absf(brightness - _last_brightness) > 0.0005:
		world_env.environment.adjustment_enabled = true
		world_env.environment.adjustment_brightness = brightness
		_last_brightness = brightness

	ISO_num.text = "ISO " + str(int(settings.iso))

	shutter_num.text = CinemaSettings.shutter_label(shutter_index)

	aperture_num.text = "f/" + str(snapped(settings.aperture, 0.1))

func _on_aperture_slider_value_changed(value):
	settings.aperture = value
	update_exposure_display()
	main.update_info_label()

func _on_iso_slider_value_changed(value):
	settings.iso = value
	update_noise()
	update_exposure_display()
	main.update_info_label()

func _on_shutter_slider_value_changed(value: float) -> void:
	shutter_index = int(value)
	settings.shutter_speed = 1.0 / CinemaSettings.SHUTTER_DENOMINATORS[shutter_index]
	update_exposure_display()
	main.update_info_label()
