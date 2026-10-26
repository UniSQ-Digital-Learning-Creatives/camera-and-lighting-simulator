extends Resource
class_name CinemaSettings

# Camera
@export_group("Camera")
@export var camera_distance := 5.0
@export var camera_height := 1.63
@export var camera_x_offset := 0.0
@export var camera_yaw := 0.0
@export var camera_pitch := 0.0
@export var auto_look_at := true

# Lens
@export_group("Lens")
@export var sensor_name := "Full Frame"
@export var sensor_width := 36.0
@export var focal_length := 50.0

# Exposure
@export_group("Exposure")
@export var aperture := 8.0
@export var shutter_speed := 1.0 / 125.0
@export var iso := 100
@export var white_balance := 5600.0
@export var exaggerate_noise := false # teaching aid: 4x the realistic sensor noise

# Focus
@export_group("Focus")
@export var focus_distance := 5.00
@export var autofocus_enabled := true
@export var manual_focus_distance := 1.00

# Lighting
@export_group("Key Light")
@export var key_angle := 45.0
@export var key_distance := 1.5
@export var key_height := 1.9
@export var key_temperature := 5600.0
@export var key_intensity := 5.0

@export_group("Fill Light")
@export var fill_angle := 135.0
@export var fill_distance := 1.5
@export var fill_height := 1.9
@export var fill_temperature := 5600.0
@export var fill_intensity := 2.5

@export_group("Rim Light")
@export var rim_angle := 180.0
@export var rim_distance := 1.5
@export var rim_height := 1.9
@export var rim_temperature := 5600.0
@export var rim_intensity := 5.0


# Shutter speeds the shutter slider steps through, as 1/denominator seconds.
const SHUTTER_DENOMINATORS := [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000]


static func shutter_label(index: int) -> String:
	var d: int = SHUTTER_DENOMINATORS[index]
	return "1\"" if d == 1 else "1/" + str(d)


# Index of the listed shutter speed closest to the stored one, so presets saved
# with slightly different float rounding still land on the right step.
func get_shutter_index() -> int:
	var best := 0
	for i in SHUTTER_DENOMINATORS.size():
		if absf(1.0 / SHUTTER_DENOMINATORS[i] - shutter_speed) < absf(1.0 / SHUTTER_DENOMINATORS[best] - shutter_speed):
			best = i
	return best


func get_crop_factor() -> float:
	if sensor_width == 23.6:
		return 1.5
	elif sensor_width == 17.3:
		return 2.0
	return 1.0


# The text in the overlay info box. Lives here because it is built purely from
# these settings, so every controller shows the same thing through
# main.update_info_label() instead of keeping its own copy.
func get_summary() -> String:
	return (
		"Camera: %s | %.0fmm\n" % [sensor_name, focal_length]
		+ "Exposure: f/%.1f | %s s | ISO %d\n" % [aperture, shutter_label(get_shutter_index()), iso]
		+ "WB: %dK\n" % int(white_balance)
		+ "Focus: %.1fm" % focus_distance
	)


# Approximate colour of a black-body light source (Tanner Helland's fit).
# Returns an sRGB colour; 6600K comes out as pure white.
static func kelvin_to_color(kelvin: float) -> Color:
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


# The colour a light of `light_kelvin` records as once the camera's white
# balance is set to `camera_kelvin`: the light's colour divided by the colour
# the camera treats as white, per channel in linear light (a von Kries
# adaptation, which is what a camera's white balance gains do). A light that
# matches the white balance comes out neutral. The result is scaled to keep
# its luminance, so changing white balance shifts colour, not exposure.
static func white_balanced_color(light_kelvin: float, camera_kelvin: float) -> Color:
	var light := kelvin_to_color(light_kelvin).srgb_to_linear()
	var white := kelvin_to_color(camera_kelvin).srgb_to_linear()
	var c := Color(light.r / maxf(white.r, 0.001), light.g / maxf(white.g, 0.001), light.b / maxf(white.b, 0.001))
	var luminance := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	c = Color(c.r / luminance, c.g / luminance, c.b / luminance)
	return c.linear_to_srgb()
