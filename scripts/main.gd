extends Node3D

@export var settings : CinemaSettings

@onready var viewport = %SubViewport

@onready var Acknowl_popup = %AcknowledgementsPopup
@onready var HelpDocs_popup = %HelpDocsPopup

@onready var camera_controller = %CameraController

@onready var full_frame_btn = %FullFrame
@onready var apsc_btn = %APSC
@onready var mft_btn = %MFT

@onready var info_label = %InfoLabel

@onready var camera_content = %CameraContent
@onready var exposure_content = %ExposureContent
@onready var focus_content = %FocusContent
@onready var camera_position_content = %"Position Content"
@onready var lights_content = %LightsContent

@onready var key_light_header = %KeyLightHeader
@onready var fill_light_header = %FillLightHeader
@onready var rim_light_header = %RimLightHeader

@onready var lens_label = %LensLabel
@onready var lens_slider = %LensSlider
@onready var lens_num = %LensNum
@onready var head_target = %Marker3D

@onready var camera_distance_num = %DistanceNum
@onready var camera_distance_slider = %DistanceSlider
@onready var camera_height_slider = %HeightSlider
@onready var camera_height_num = %HeightNum
@onready var camera_x_offset_slider = %LeftRightSlider
@onready var camera_x_offset_num = %LeftRightNum
@onready var auto_look_at_toggle = %LookAtToggle
@onready var camera_yaw_slider = %YawSlider
@onready var camera_yaw_num = %YawNum
@onready var camera_pitch_slider = %PitchSlider
@onready var camera_pitch_num = %PitchNum

@onready var camera_WB_slider = %CameraWBSlider
@onready var camera_WB_num = %Camera_WBNum

@onready var camera_reset = %ResetButton

@onready var overlays = %Overlays

@onready var key_light = %KeyLight
@onready var fill_light = %FillLight
@onready var rim_light = %RimLight
# (The scene's general "daylight" fill, %DirectionalLight3D, is a fixed 5600K
# source, set in the scene.)

@onready var key_angle_slider = %KeyAngleSlider
@onready var key_dist_slider = %KeyDistSlider
@onready var key_height_slider = %KeyHeightSlider
@onready var key_temp_slider = %KeyTempSlider
@onready var key_angle_num = %KeyAngleNum
@onready var key_dist_num = %KeyDistNum
@onready var key_height_num = %KeyHeightNum
@onready var key_temp_num = %KeyTempNum

@onready var fill_angle_slider = %FillAngleSlider
@onready var fill_dist_slider = %FillDistSlider
@onready var fill_height_slider = %FillHeightSlider
@onready var fill_temp_slider = %FillTempSlider
@onready var fill_angle_num = %FillAngleNum
@onready var fill_dist_num = %FillDistNum
@onready var fill_height_num = %FillHeightNum
@onready var fill_temp_num = %FillTempNum

@onready var rim_angle_slider = %RimAngleSlider
@onready var rim_dist_slider = %RimDistSlider
@onready var rim_height_slider = %RimHeightSlider
@onready var rim_temp_slider = %RimTempSlider
@onready var rim_angle_num = %RimAngleNum
@onready var rim_dist_num = %RimDistNum
@onready var rim_height_num = %RimHeightNum
@onready var rim_temp_num = %RimTempNum

@onready var key_int_slider = %KeyIntSlider
@onready var key_int_num = %KeyIntNum
@onready var fill_int_slider = %FillIntSlider
@onready var fill_int_num = %FillIntNum
@onready var rim_int_slider = %RimIntSlider
@onready var rim_int_num = %RimIntNum

@onready var camera = %"POV Cam"
@onready var exposure_controller = %ExposureController
@onready var camera_diagram = %CameraDiagram
@onready var sensor_diagram = %SensorDiagram

var saved_manual_x_offset := 0.0
var saved_manual_height := 1.2
var saved_manual_pitch := 0.0
var saved_manual_yaw := 0.0

var _last_dof_key = null
var idle_animation # AvaIdle (scripts/ava_idle.gd), added in _ready


func _process(_delta):
	update_dof()

# Depth of field is the engine's. POV Cam's attributes are a
# CameraAttributesPhysical, a lens on a sensor: set_lens() gives it the focal
# length and the sensor size, and this gives it the aperture and (when focusing
# by hand) the focus distance. With dof_physical_blur_size on, a point at
# distance d, with the lens focused at distance u, blurs as it would through a
# real lens, into a circle on the sensor of diameter
#     blur(d) = f² / (N·(u − f)) · |d − u| / d
# and the engine sizes that circle against the sensor, so the same lens blurs
# more of the picture on a smaller sensor. (dof_legacy_gather keeps the blur
# drawn the way this app's look was tuned; turn it off for the engine's
# newer, more exact drawing, which blurs a little more wide open.)
# The focus plane itself is the engine's autofocus, see camera_controller.gd.
func update_dof():
	var focus_distance = settings.focus_distance
	var aperture = settings.aperture
	var focal_length = settings.focal_length

	# Skip re-pushing the attributes to the renderer when nothing changed
	# since last frame -- on the web/WebGPU target every RenderingServer
	# update crosses the JS/WASM command bridge, so a steady-state frame
	# (nothing being dragged) should cost nothing here. Autofocus moves the
	# focus a fraction of a millimetre every frame as she sways, by itself.
	var key = [snappedf(focus_distance, 0.002), aperture, focal_length, settings.sensor_width, settings.autofocus_enabled]
	if key == _last_dof_key:
		return
	_last_dof_key = key

	var attributes = camera.attributes
	if attributes.exposure_aperture != aperture:
		attributes.exposure_aperture = aperture # the f-number; exposure stays exposure_controller.gd's
	if not settings.autofocus_enabled:
		attributes.frustum_focus_distance = focus_distance # focused by hand

	var u = maxf(focus_distance * 1000.0, focal_length + 1.0) # focus distance in mm
	update_dof_label(u, focal_length, aperture)


# The near and far limits of acceptable sharpness, shown in the Focus panel.
# "Sharp" means a blur smaller than the circle of confusion: 0.03 mm on a
# full-frame sensor, smaller in proportion on a smaller one. Beyond the
# hyperfocal distance everything to infinity is sharp.
const FULL_FRAME_COC_MM := 0.03

func update_dof_label(u_mm: float, f: float, n: float):
	var coc = FULL_FRAME_COC_MM / settings.get_crop_factor()
	var hyperfocal = f + f * f / (n * coc)
	var near = hyperfocal * u_mm / (hyperfocal + (u_mm - f)) / 1000.0
	if u_mm >= hyperfocal:
		%DOFLabel.text = "Sharp from %.1f m to infinity" % near
		return
	var far = hyperfocal * u_mm / (hyperfocal - (u_mm - f)) / 1000.0
	var depth = far - near
	# A shallow zone needs more digits, or it reads "1.5 m to 1.5 m".
	var digits = "%.3f" if depth < 0.05 else ("%.2f" if depth < 0.5 else "%.1f")
	var depth_text = ("%d cm" % maxi(roundi(depth * 100.0), 1)) if depth < 1.0 else ("%.1f m" % depth)
	%DOFLabel.text = ("Sharp from " + digits + " m to " + digits + " m (%s deep)") % [near, far, depth_text]


func _ready():

	settings = load("res://data/default_settings.tres").duplicate(true)

	# Ava only moves by a degree or so (ava_idle.gd), too little for her hair
	# simulation to add anything: without it the hair keeps its groomed shape
	# and follows her head rigidly (godotwebgpu TASKS §2.33). Off, it saves
	# ~0.9 ms of CPU a frame on the web build.
	for hair_sim in $Subject.find_children("*", "MetaHumanHairSimulator", true, false):
		hair_sim.active = false

	# Blinks, breathing and a slight sway, so she doesn't look frozen (the
	# motion is a degree or so, small enough for the hair to follow rigidly).
	idle_animation = preload("res://scripts/ava_idle.gd").new()
	idle_animation.name = "AvaIdle"
	add_child(idle_animation)
	idle_animation.setup($Subject/Ava2/Skeleton3D, head_target)
	idle_animation.state_changed.connect(_on_idle_state_changed)
	_on_idle_state_changed(idle_animation.playing)

	# Phones get a lighter render: smaller shadow maps and no SSAO (the
	# project settings lower subsurface scattering for them too).
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		viewport.positional_shadow_atlas_size = 2048
		%WorldEnvironment.environment.ssao_enabled = false

	setup_display_options()

	ensure_preset_directory()
	refresh_preset_list()
	ensure_screenshot_directory()

	camera_content.visible = true
	exposure_content.visible = true
	focus_content.visible = true
	camera_position_content.visible = true
	lights_content.visible = true

	# Each light starts on or off to match its header checkbox in the scene
	# (only the key light is ticked to begin with).
	_on_keylight_header_toggled(key_light_header.button_pressed)
	_on_fill_light_header_toggled(fill_light_header.button_pressed)
	_on_rim_light_header_toggled(rim_light_header.button_pressed)

	apply_settings()


func sync_sliders_to_data():
	lens_slider.set_value_no_signal(settings.focal_length)
	camera_distance_slider.set_value_no_signal(settings.camera_distance)
	camera_height_slider.set_value_no_signal(settings.camera_height)
	camera_x_offset_slider.set_value_no_signal(settings.camera_x_offset)
	camera_yaw_slider.set_value_no_signal(settings.camera_yaw)
	camera_pitch_slider.set_value_no_signal(settings.camera_pitch)
	camera_WB_slider.set_value_no_signal(settings.white_balance)

	auto_look_at_toggle.set_pressed_no_signal(settings.auto_look_at)
	camera_yaw_slider.editable = !settings.auto_look_at
	camera_pitch_slider.editable = !settings.auto_look_at

	full_frame_btn.set_pressed_no_signal(settings.sensor_width == 36.0)
	apsc_btn.set_pressed_no_signal(settings.sensor_width == 23.6)
	mft_btn.set_pressed_no_signal(settings.sensor_width == 17.3)

	key_angle_slider.set_value_no_signal(settings.key_angle)
	key_dist_slider.set_value_no_signal(settings.key_distance)
	key_height_slider.set_value_no_signal(settings.key_height)
	key_temp_slider.set_value_no_signal(settings.key_temperature)
	key_int_slider.set_value_no_signal(settings.key_intensity)

	fill_angle_slider.set_value_no_signal(settings.fill_angle)
	fill_dist_slider.set_value_no_signal(settings.fill_distance)
	fill_height_slider.set_value_no_signal(settings.fill_height)
	fill_temp_slider.set_value_no_signal(settings.fill_temperature)
	fill_int_slider.set_value_no_signal(settings.fill_intensity)

	rim_angle_slider.set_value_no_signal(settings.rim_angle)
	rim_dist_slider.set_value_no_signal(settings.rim_distance)
	rim_height_slider.set_value_no_signal(settings.rim_height)
	rim_temp_slider.set_value_no_signal(settings.rim_temperature)
	rim_int_slider.set_value_no_signal(settings.rim_intensity)

	camera_WB_num.text = str(int(settings.white_balance)) + "K"
	lens_num.text = str(settings.focal_length) + "mm"


func set_lens(focal_length):

	settings.focal_length = round(focal_length)

	# The field of view comes from the lens and the sensor: the camera's
	# physical attributes work it out (2·atan(sensor height / (2·focal length)))
	# and set camera.fov. The 16:9 picture is a strip across the sensor's full
	# width, so that strip is the sensor size given to the camera.
	var attributes = camera.attributes
	attributes.frustum_focal_length = settings.focal_length
	attributes.sensor_size = Vector2(settings.sensor_width, settings.sensor_width * 9.0 / 16.0)

	# camera.fov is the vertical angle; the studio map shows the horizontal one.
	var aspect = attributes.sensor_size.x / attributes.sensor_size.y
	camera_diagram.current_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(camera.fov) / 2.0) * aspect))
	camera_diagram.queue_redraw()

#Label
	var lens_type = ""

	if settings.focal_length <= 24:
		lens_type = "Wide Angle Lens"

	elif settings.focal_length <= 70:
		lens_type = "Standard Lens"

	else:
		lens_type = "Telephoto Lens"

	if settings.sensor_width == 36.0:
		settings.sensor_name = "Full Frame"

	elif settings.sensor_width == 23.6:
		settings.sensor_name = "APS-C"

	elif settings.sensor_width == 17.3:
		settings.sensor_name = "Micro Four Thirds"

	lens_label.text = (
		str(settings.focal_length) + "mm"
		+ "\n" + lens_type
		+ "\nSensor: " + settings.sensor_name
	)
	sensor_diagram.queue_redraw()


# Button code

func _on_24mm_pressed():
	lens_slider.value = 24

func _on_50mm_pressed():
	lens_slider.value = 50

func _on_200mm_pressed():
	lens_slider.value = 200

func _set_sensor(width: float):
	settings.sensor_width = width
	full_frame_btn.set_pressed_no_signal(width == 36.0)
	apsc_btn.set_pressed_no_signal(width == 23.6)
	mft_btn.set_pressed_no_signal(width == 17.3)
	set_lens(settings.focal_length)
	exposure_controller.update_noise() # smaller sensor, noisier pixels
	update_info_label()

func _on_full_frame_pressed():
	_set_sensor(36.0)

func _on_apsc_pressed():
	_set_sensor(23.6)

func _on_mft_pressed():
	_set_sensor(17.3)

func _on_lens_slider_value_changed(value):
	set_lens(value)
	lens_num.text = str(settings.focal_length) +"mm"
	update_info_label()

func get_light_position(subject_position, angle_deg, distance, height):

	var angle_rad = deg_to_rad(angle_deg)

	return Vector3(
	subject_position.x + cos(angle_rad) * distance,
	height,
	subject_position.z + sin(angle_rad) * distance
	)


func update_lights():

	var subject_position = head_target.global_position

	key_light.global_position = get_light_position(
		subject_position,
		settings.key_angle,
		settings.key_distance,
		settings.key_height
	)

	fill_light.global_position = get_light_position(
		subject_position,
		settings.fill_angle,
		settings.fill_distance,
		settings.fill_height
	)

	rim_light.global_position = get_light_position(
		subject_position,
		settings.rim_angle,
		settings.rim_distance,
		settings.rim_height
	)

	key_light.look_at(subject_position)
	fill_light.look_at(subject_position)
	rim_light.look_at(subject_position)

	camera_diagram.key_angle = settings.key_angle
	camera_diagram.fill_angle = settings.fill_angle
	camera_diagram.rim_angle = settings.rim_angle

	camera_diagram.key_distance = settings.key_distance
	camera_diagram.fill_distance = settings.fill_distance
	camera_diagram.rim_distance = settings.rim_distance

	key_height_num.text = str(settings.key_height)
	fill_height_num.text = str(settings.fill_height)
	rim_height_num.text = str(settings.rim_height)
	key_dist_num.text = str(settings.key_distance)
	fill_dist_num.text = str(settings.fill_distance)
	rim_dist_num.text = str(settings.rim_distance)
	key_angle_num.text = str(settings.key_angle)
	fill_angle_num.text = str(settings.fill_angle)
	rim_angle_num.text = str(settings.rim_angle)

	camera_diagram.queue_redraw()
	update_info_label()


func update_light_intensities():
	key_light.light_energy = settings.key_intensity
	fill_light.light_energy = settings.fill_intensity
	rim_light.light_energy = settings.rim_intensity
	key_int_num.text = str(settings.key_intensity)
	fill_int_num.text = str(settings.fill_intensity)
	rim_int_num.text = str(settings.rim_intensity)
	update_info_label()


func _on_key_angle_slider_value_changed(value):

	settings.key_angle = value
	update_lights()


func _on_fill_angle_slider_value_changed(value):

	settings.fill_angle = value
	update_lights()


func _on_rim_angle_slider_value_changed(value):

	settings.rim_angle = value
	update_lights()



func _on_key_dist_value_changed(value: float) -> void:
	settings.key_distance = value
	update_lights()


func _on_fill_dist_value_changed(value: float) -> void:
	settings.fill_distance = value
	update_lights()


func _on_rim_dist_value_changed(value: float) -> void:
	settings.rim_distance = value
	update_lights()


func _on_key_height_value_changed(value: float) -> void:
	settings.key_height = value
	update_lights()

func _on_fill_height_value_changed(value: float) -> void:
	settings.fill_height = value
	update_lights()

func _on_rim_height_value_changed(value: float) -> void:
	settings.rim_height = value
	update_lights()

func update_camera_position():

	camera.global_position = Vector3(
		head_target	.global_position.x + settings.camera_x_offset,
		settings.camera_height,
		head_target.global_position.z + settings.camera_distance
	)

	if settings.auto_look_at:
		camera.look_at(head_target.global_position)
	else:
		camera.rotation_degrees = Vector3(
			settings.camera_pitch,
			settings.camera_yaw,
			0
		)

	camera_diagram.camera_distance = settings.camera_distance * 20
	camera_diagram.queue_redraw()
	camera_height_num.text = str(settings.camera_height) +"m"
	camera_distance_num.text = str(settings.camera_distance) + "m"
	camera_yaw_num.text = str(settings.camera_yaw)
	camera_pitch_num.text = str(settings.camera_pitch)
	camera_x_offset_num.text = str(settings.camera_x_offset)
	update_info_label()


func _on_camera_distance_slider_value_changed(value: float) -> void:
	settings.camera_distance = value
	update_camera_position()


func _on_camera_height_slider_value_changed(value: float) -> void:
	settings.camera_height = value
	update_camera_position()

func _on_keytemp_value_changed(value: float) -> void:
	settings.key_temperature = value
	update_white_balance()

func _on_fill_temp_value_changed(value: float) -> void:
	settings.fill_temperature = value
	update_white_balance()

func _on_rim_temp_value_changed(value: float) -> void:
	settings.rim_temperature = value
	update_white_balance()

func _on_camera_left_right_slider_value_changed(value: float) -> void:
	settings.camera_x_offset = value
	update_camera_position()


func _on_look_at_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		saved_manual_x_offset = settings.camera_x_offset
		saved_manual_height = settings.camera_height
		saved_manual_pitch = settings.camera_pitch
		saved_manual_yaw = settings.camera_yaw

	settings.auto_look_at = toggled_on

	if !toggled_on:
		settings.camera_x_offset = saved_manual_x_offset
		settings.camera_height = saved_manual_height
		settings.camera_pitch = saved_manual_pitch
		settings.camera_yaw = saved_manual_yaw

	camera_yaw_slider.editable = !toggled_on
	camera_pitch_slider.editable = !toggled_on

	update_camera_position()


func _on_camera_yaw_slider_value_changed(value: float) -> void:
	settings.camera_yaw = value
	update_camera_position()


func _on_camera_ptich_slider_value_changed(value: float) -> void:
	settings.camera_pitch = value
	update_camera_position()



func _on_camera_wb_slider_value_changed(value: float) -> void:
	settings.white_balance = value
	camera_WB_num.text = str(int(settings.white_balance)) + "K"
	update_white_balance()
	update_info_label()

# Each light has a colour temperature (Light3D.light_temperature, switched on
# with light_temperature_enabled in the scene): the engine tints it with the
# colour of a blackbody at that temperature, at the same brightness. The
# camera's white balance is the engine's own too
# (CameraAttributes.white_balance_temperature): a von Kries adaptation in
# linear light after exposure and before tonemapping, like a camera's raw
# processing. A light that matches the white balance records as neutral, a
# warmer one orange and a cooler one blue.
func update_white_balance():
	key_light.light_temperature = settings.key_temperature
	fill_light.light_temperature = settings.fill_temperature
	rim_light.light_temperature = settings.rim_temperature
	camera.attributes.white_balance_temperature = settings.white_balance
	key_temp_num.text = str(int(settings.key_temperature)) + "K"
	fill_temp_num.text = str(int(settings.fill_temperature)) + "K"
	rim_temp_num.text = str(int(settings.rim_temperature)) + "K"

#Setting Intensity values on lights
func _on_key_int_slider_value_changed(value: float) -> void:
	settings.key_intensity = value
	update_light_intensities()


func _on_fill_int_slider_value_changed(value: float) -> void:
	settings.fill_intensity = value
	update_light_intensities()


func _on_rim_int_slider_value_changed(value: float) -> void:
	settings.rim_intensity = value
	update_light_intensities()

	#Collapsable headings
func _on_camera_header_toggled(toggled_on: bool) -> void:
	camera_content.visible = toggled_on

func _on_exposure_header_toggled(toggled_on: bool) -> void:
	exposure_content.visible = toggled_on

func _on_focus_header_toggled(toggled_on: bool) -> void:
	focus_content.visible = toggled_on

func _on_position_header_toggled(toggled_on: bool) -> void:
	camera_position_content.visible = toggled_on

func _on_lights_header_toggled(toggled_on: bool) -> void:
	lights_content.visible = toggled_on



# Preset and Save Image options
func get_preset_path(preset_name : String) -> String:
	return "user://presets/" + preset_name + ".tres"


func save_preset(preset_name : String):
	ResourceSaver.save(settings.duplicate(true), get_preset_path(preset_name))
	refresh_preset_list()


func _on_save_preset_pressed():
	%PresetNameInput.text = ""
	%PresetNameInput.placeholder_text = ""
	%SavePresetDialog.popup_centered()

	await get_tree().process_frame
	%PresetNameInput.grab_focus()


func get_selected_preset_name() -> String:
	var selected = %PresetMenu.selected

	if selected < 0:
		return ""

	return %PresetMenu.get_item_text(selected)


func _on_load_preset_button_pressed() -> void:
	var preset_name = get_selected_preset_name()

	if preset_name.is_empty():
		return

	load_preset(get_preset_path(preset_name))



func load_preset(path : String):
	var loaded = load(path) as CinemaSettings

	if loaded == null:
		push_warning("Could not load preset: " + path)
		return

	# Every controller reads main.settings, so swapping the whole resource
	# applies every field at once (no list of fields to keep in sync).
	# The baseline noise is a calibration of the noise model, not part of a
	# shot, so it stays as tuned in the defaults whatever a preset saved.
	var baseline_noise = settings.baseline_noise_multiplier
	settings = loaded.duplicate(true)
	settings.baseline_noise_multiplier = baseline_noise
	apply_settings()



func apply_settings():
	sync_sliders_to_data()
	set_lens(settings.focal_length)
	update_camera_position()
	update_lights()
	update_light_intensities()
	update_white_balance()
	exposure_controller.sync_from_settings()
	camera_controller.sync_focus_distance_slider()
	update_info_label()




func reset_to_default():
	load_preset("res://data/default_settings.tres")


func _on_reset_preset_pressed() -> void:
	reset_to_default()

func ensure_preset_directory():

	if !DirAccess.dir_exists_absolute("user://presets"):
		DirAccess.make_dir_absolute(
		"user://presets"
	)


func refresh_preset_list():

	%PresetMenu.clear()

	var dir = DirAccess.open(
		"user://presets"
	)

	if dir == null:
		return

	dir.list_dir_begin()

	while true:

		var file = dir.get_next()

		if file == "":
			break

		if file.ends_with(".tres"):

			%PresetMenu.add_item(
				file.get_basename()
			)

func delete_preset(preset_name : String):
	DirAccess.remove_absolute(get_preset_path(preset_name))
	refresh_preset_list()


func _on_delete_presets_pressed() -> void:
	var preset_name = get_selected_preset_name()

	if preset_name.is_empty():
		return

	delete_preset(preset_name)


func _on_download_image_pressed() -> void:
	save_current_image()

func _on_download_screenshot_pressed() -> void:
	save_screenshot()

func ensure_screenshot_directory():

	if !DirAccess.dir_exists_absolute(
		"user://screenshots"
	):
		DirAccess.make_dir_absolute(
			"user://screenshots"
		)

# "Download Image": the photo the camera records. That's the 3D view (with the
# exposure, depth of field, white balance and noise in it), at the camera's
# full resolution, without the monitoring aids (zebras, false colour) or the
# guide overlays.
func save_current_image():
	var image = await capture_camera_image()
	download_png(image, "camera-sim-photo")


# "Download Screenshot": exactly what's on screen, controls and guides included.
# Reading a picture back from the GPU takes a frame or more (and on the web it
# can't be done any other way), so get_image_awaitable() hands it over when it
# arrives: this frame's picture, or null if it couldn't be read.
func save_screenshot():
	download_png(await get_viewport().get_texture().get_image_awaitable(), "camera-sim-screenshot")


# The engine draws the zebras and false colour into the camera's own image,
# but while monitoring_clean_texture_enabled is on it also keeps a copy of each
# frame from just before they're drawn: that's the photo. It's on only while a
# capture is waiting for its frame (it costs a copy of every frame).
var _captures_waiting := 0

func capture_camera_image() -> Image:
	_captures_waiting += 1
	camera.monitoring_clean_texture_enabled = true
	var image: Image = await camera.get_monitoring_clean_texture().get_image_awaitable()
	_captures_waiting -= 1
	if _captures_waiting == 0:
		camera.monitoring_clean_texture_enabled = false
	return image


func download_png(image: Image, prefix: String):
	if image == null:
		show_message("Couldn't capture the image, please try again.")
		return

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var file_name = prefix + "-" + timestamp + ".png"

	# In the browser, hand the PNG to the browser as a real download (user://
	# is IndexedDB there, which the student can't get at).
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(image.save_png_to_buffer(), file_name, "image/png")
		return

	# On desktop, save it where a download would go.
	var folder = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		folder = ProjectSettings.globalize_path("user://screenshots")
	var path = folder.path_join(file_name)
	if image.save_png(path) == OK:
		show_message("Saved " + file_name + " to " + folder)
	else:
		show_message("Couldn't save " + path)


# A short message above the bottom bar that fades away.
func show_message(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.75)
	background.set_corner_radius_all(4)
	background.set_content_margin_all(8)
	label.add_theme_stylebox_override("normal", background)
	$CanvasLayer.add_child(label)
	# Centred, just above the control panel's bottom edge, whatever the window size.
	var window = get_viewport().get_visible_rect().size
	label.position = Vector2((window.x - label.get_minimum_size().x) / 2, window.y - 70)

	var tween = label.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func _on_save_preset_dialog_confirmed():

	var preset_name = %PresetNameInput.text.strip_edges()

	if preset_name.is_empty():
		return

	if FileAccess.file_exists(get_preset_path(preset_name)):
		_confirm_overwrite(preset_name)
		return

	save_preset(preset_name)


func _confirm_overwrite(preset_name : String):
	var dialog = ConfirmationDialog.new()
	dialog.title = "Overwrite preset?"
	dialog.dialog_text = "A preset called \"%s\" already exists.\nReplace it?" % preset_name
	dialog.ok_button_text = "Replace"
	dialog.confirmed.connect(save_preset.bind(preset_name))
	dialog.visibility_changed.connect(func(): if !dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


# Reset camera settings only
func _on_reset_button_pressed() -> void:
	reset_camera_position()


func reset_camera_position():
	var defaults = load("res://data/default_settings.tres") as CinemaSettings

	if defaults == null:
		return

	settings.camera_distance = defaults.camera_distance
	settings.camera_height = defaults.camera_height
	settings.camera_x_offset = defaults.camera_x_offset

	settings.camera_yaw = defaults.camera_yaw
	settings.camera_pitch = defaults.camera_pitch

	settings.auto_look_at = defaults.auto_look_at
	apply_settings()

# Subject animation buttons
func _on_play_animation_pressed() -> void:
	idle_animation.play()

func _on_pause_animation_pressed() -> void:
	idle_animation.pause()

func _on_reset_animation_pressed() -> void:
	idle_animation.reset_pose()

func _on_swap_shirt_pressed() -> void:
	var shirt = $Subject/Ava2/Skeleton3D/Ava_Outfits3 # scripts/unisq_shirt.gd
	shirt.colourway = (shirt.colourway + 1) % shirt.Colourway.size()

# Play and Pause show which one is in effect.
func _on_idle_state_changed(is_playing: bool):
	%PlayAnimation.set_pressed_no_signal(is_playing)
	%PauseAnimation.set_pressed_no_signal(not is_playing)

#Help and Attribution buttons
func _on_attribution_button_pressed() -> void:
	Acknowl_popup.show()

func _on_popup_window_close_requested() -> void:
	Acknowl_popup.hide()

func _on_help_button_pressed() -> void:
	HelpDocs_popup.show()

func _on_help_docs_popup_close_requested() -> void:
	HelpDocs_popup.hide()

# Turning a light on/off also enables/disables its sliders, and dims them
# while it's off (a disabled slider looks the same as a live one in this theme).
func _set_light_enabled(light: Light3D, sliders: Array, content: Control, on: bool):
	light.visible = on
	for slider in sliders:
		slider.editable = on
	content.modulate.a = 1.0 if on else 0.4
	if is_node_ready():
		update_info_label()

func _on_keylight_header_toggled(toggled_on: bool) -> void:
	_set_light_enabled(key_light, [key_angle_slider, key_dist_slider, key_height_slider, key_temp_slider, key_int_slider], %KeylightContent, toggled_on)
	camera_diagram.show_key_light = toggled_on
	camera_diagram.queue_redraw()

func _on_fill_light_header_toggled(toggled_on: bool) -> void:
	_set_light_enabled(fill_light, [fill_angle_slider, fill_dist_slider, fill_height_slider, fill_temp_slider, fill_int_slider], %FilllightContent, toggled_on)
	camera_diagram.show_fill_light = toggled_on
	camera_diagram.queue_redraw()

func _on_rim_light_header_toggled(toggled_on: bool) -> void:
	_set_light_enabled(rim_light, [rim_angle_slider, rim_dist_slider, rim_height_slider, rim_temp_slider, rim_int_slider], %RimlightContent, toggled_on)
	camera_diagram.show_rim_light = toggled_on
	camera_diagram.queue_redraw()


func _on_safe_areas_toggled(toggled_on: bool) -> void:
	overlays.show_action_safe = toggled_on
	overlays.queue_redraw()

func _on_rule_of_thirds_checkbox_toggled(toggled_on: bool) -> void:
	overlays.show_grid = toggled_on
	overlays.queue_redraw()

func _on_title_safe_toggled(toggled_on: bool) -> void:
	overlays.show_title_safe = toggled_on
	overlays.queue_redraw()


# The one place the info box gets written. The Camera and Exposure
# controllers call main.update_info_label() too, and the text itself comes
# from CinemaSettings.get_summary().
func update_info_label():
	info_label.text = settings.get_summary() + "\nMeter: " + exposure_controller.get_meter_text()


# Display: fullscreen. The whole UI, monitor included, scales to fit the
# window. The camera renders at 720p in a window and 1080p in fullscreen,
# where the monitor is big enough for the extra sharpness to show. Phones
# stay at 720p: their GPUs can't spare it, and the screen is small anyway.
const WINDOWED_RENDER_SIZE := Vector2i(1280, 720)
const FULLSCREEN_RENDER_SIZE := Vector2i(1920, 1080)

func setup_display_options():
	get_tree().root.size_changed.connect(_on_window_resized)

func _on_fullscreen_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	%FullscreenButton.text = "Exit Fullscreen" if toggled_on else "Fullscreen"
	var handheld = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	viewport.size = FULLSCREEN_RENDER_SIZE if toggled_on and not handheld else WINDOWED_RENDER_SIZE

func _on_window_resized():
	# Esc (or the browser) can leave fullscreen without the button. A browser
	# may resize the page before it reports the change, so look a moment later.
	await get_tree().create_timer(0.3).timeout
	var fullscreen = is_canvas_fullscreen()
	if %FullscreenButton.button_pressed != fullscreen:
		%FullscreenButton.button_pressed = fullscreen # runs the toggled handler

# Fullscreen, whether the app's or the page's: when the app is iframed into a
# page on another site, that page's own Fullscreen button puts the iframe in
# fullscreen and tells the app (the web export's html/embed_fullscreen option),
# and the engine reports it as fullscreen too. Leaving fullscreen from the app
# then asks the page to leave.
func is_canvas_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
