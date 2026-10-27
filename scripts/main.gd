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
# The scene's general "daylight" fill; white balanced as a 5600K source.
@onready var sun_light = %DirectionalLight3D
const SUN_TEMPERATURE := 5600.0

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
@onready var viewport_monitor = %TextureRect
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

# Depth of field from the thin-lens model, using the selected lens and sensor.
#
# A point at distance d, with the lens focused at distance u, blurs into a
# circle on the sensor of diameter
#     blur(d) = f² / (N·(u − f)) · |d − u| / d
# so it grows from 0 at the focus plane towards f² / (N·(u − f)) far behind
# it. Godot's bokeh shader has exactly this falloff built in: a negative
# transition switches it to "physical" mode, where it scales its blur radius
# (in pixels) by |d − u| / d on both sides of the focus plane. All that's left
# to work out here is that maximum radius, converted from millimetres on the
# sensor to pixels in the rendered image.
func update_dof():
	var focus_distance = settings.focus_distance
	var aperture = settings.aperture
	var focal_length = settings.focal_length
	var sensor_width = settings.sensor_width

	# Skip re-pushing the DOF attributes resource to the renderer when
	# nothing changed since last frame -- on the web/WebGPU target every
	# RenderingServer update crosses the JS/WASM command bridge, so a
	# steady-state frame (nothing being dragged) should cost nothing here.
	var key = [focus_distance, aperture, focal_length, sensor_width]
	if key == _last_dof_key:
		return
	_last_dof_key = key

	var u = maxf(focus_distance * 1000.0, focal_length + 1.0) # focus distance in mm
	var max_blur_mm = (focal_length * focal_length) / (aperture * (u - focal_length))

	# Blur diameter on the sensor -> blur radius in pixels across the image width.
	var max_blur_px = 0.5 * max_blur_mm / sensor_width * viewport.size.x

	var attributes = camera.attributes
	attributes.dof_blur_far_distance = u / 1000.0
	attributes.dof_blur_near_distance = u / 1000.0
	attributes.dof_blur_far_transition = -1.0
	attributes.dof_blur_near_transition = -1.0
	attributes.dof_blur_amount = max_blur_px / 64.0 # the shader's blur amount is a fraction of a 64px radius

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

	# Horizontal field of view: the camera keeps its width (keep_aspect =
	# KEEP_WIDTH), so the 16:9 frame is a crop of the sensor's full width.
	var fov = rad_to_deg(
		2.0 * atan(settings.sensor_width/ (2.0 * settings.focal_length))
	)

	camera.fov = fov

	camera_diagram.current_fov = fov
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

# Each light gets the colour of its colour temperature, and the camera's white
# balance is the engine's own (CameraAttributes.white_balance_temperature): a
# von Kries adaptation in linear light after exposure and before tonemapping,
# like a camera's raw processing. A light that matches the white balance
# records as neutral, a warmer one orange and a cooler one blue.
func update_white_balance():
	key_light.light_color = CinemaSettings.light_color_for_temperature(settings.key_temperature)
	fill_light.light_color = CinemaSettings.light_color_for_temperature(settings.fill_temperature)
	rim_light.light_color = CinemaSettings.light_color_for_temperature(settings.rim_temperature)
	sun_light.light_color = CinemaSettings.light_color_for_temperature(SUN_TEMPERATURE)
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
	settings = loaded.duplicate(true)
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

# "Download Image": the photo the camera records. That's the 3D view (which
# already has the exposure, depth of field and white balance in it) put
# through the monitor shader for the sensor noise, at the camera's full
# resolution, but with the monitoring aids (zebras, false colour) switched off
# and without the guide overlays, which are drawn separately on top.
func save_current_image():
	var image = await capture_camera_image()
	download_png(image, "camera-sim-photo")


# "Download Screenshot": exactly what's on screen, controls and guides included.
func save_screenshot():
	# Wait for the frame being drawn, so the capture is the current one.
	await RenderingServer.frame_post_draw
	download_png(await read_back(get_viewport().get_texture()), "camera-sim-screenshot")


# An off-screen viewport the size of the camera's, holding a copy of the
# monitor (same shader and noise settings) with the monitoring aids off. It
# only renders when a photo is taken. It's kept, rather than built per photo,
# so its texture stays the same one across the frames a web readback takes.
var _recorder: SubViewport
var _recorder_rect: TextureRect

func capture_camera_image() -> Image:
	if _recorder == null:
		_recorder_rect = TextureRect.new()
		_recorder_rect.texture = viewport.get_texture()
		_recorder = SubViewport.new()
		_recorder.size = viewport.size
		_recorder.disable_3d = true
		_recorder.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_recorder.add_child(_recorder_rect)
		add_child(_recorder)

	var mat = viewport_monitor.material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("zebras_enabled", false)
	mat.set_shader_parameter("false_colour_enabled", false)
	_recorder_rect.material = mat
	_recorder.render_target_update_mode = SubViewport.UPDATE_ONCE

	await RenderingServer.frame_post_draw
	return await read_back(_recorder.get_texture())


# Reads a rendered texture back to the CPU. On the web build that's
# asynchronous: the first read of a texture comes back empty (or zero-filled)
# and its pixels arrive a frame or so later (godotwebgpu TASKS.md §4.2), so
# keep asking for a few frames. Both images are opaque, so a fully
# transparent result means "not here yet". On desktop the first read works.
func read_back(texture: Texture2D) -> Image:
	for attempt in 30:
		var image = texture.get_image()
		if image != null and not image.is_empty() and image.get_pixel(image.get_width() / 2, image.get_height() / 2).a > 0.0:
			return image
		await RenderingServer.frame_post_draw
	return null


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
