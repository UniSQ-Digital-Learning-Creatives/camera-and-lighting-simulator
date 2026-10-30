extends Node

@onready var main = get_tree().root.find_child("Main", true, false)

var settings:
	get:
		return main.settings

@onready var world_env = %WorldEnvironment
@onready var camera = %"POV Cam"

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

# What an incident light meter held at the subject's face would recommend:
# it adds up the light reaching the face from each light that's on
# (intensity / distance², the falloff Godot's lights use) and reads EV 13 for
# the default rig, the exposure the scene is calibrated to. So dimming or
# moving a light changes the reading, the way it does in a real studio.
# (The fixed room fill and ambient light are left out, as a meter in the
# subject's position would mostly see the studio lights.)
const DEFAULT_KEY_ILLUMINANCE := 0.6457 # 1.5 / (1.5² + (1.9 - 1.63)²): the default key at the default face height

func get_incident_ev() -> float:
	var illuminance := 0.0
	for light in [main.key_light, main.fill_light, main.rim_light]:
		if light.visible:
			illuminance += light.light_energy / maxf(light.global_position.distance_squared_to(main.head_target.global_position), 0.01)
	return scene_ev + log(maxf(illuminance, 1e-4) / DEFAULT_KEY_ILLUMINANCE) / log(2.0)

# The meter reading as shown: how far the camera's exposure is from what the
# meter recommends, in stops. + is brighter (over), - is darker (under).
# Rounded to 1/3 stop, the steps a camera's meter scale shows.
func get_meter_text() -> String:
	var stops = round((get_incident_ev() - get_final_ev()) * 3.0) / 3.0
	if stops == 0.0:
		return "0.0 EV (correct)"
	return "%+.1f EV (%s)" % [stops, "over" if stops > 0.0 else "under"]

# Sensor noise is the engine's (CameraAttributes grain, type Digital): a
# sensor holding 1400 electrons per square micrometre at base ISO (50,000 in a
# 24MP full-frame pixel), with shot and read noise, and the ISO as its gain.
# The camera's attributes know the sensor size (main.set_lens), so at the same
# pixel count a smaller sensor's pixels collect less light and its noise grows
# with the crop factor: APS-C is about 1.2 stops and MFT 2 stops noisier than
# full frame for the same exposure.
# baseline_noise_multiplier (in the default settings) tunes how strong it looks.

# "Exaggerate noise" scales the realistic noise up by this much, for showing it
# on a projector or a small window, where real full-frame noise is subtle.
const NOISE_EXAGGERATION := 8.0

@onready var exaggerate_noise_toggle = %ExaggerateNoise

func update_noise():
	camera.attributes.exposure_sensitivity = settings.iso
	camera.attributes.grain_intensity = settings.baseline_noise_multiplier * (NOISE_EXAGGERATION if settings.exaggerate_noise else 1.0)

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
