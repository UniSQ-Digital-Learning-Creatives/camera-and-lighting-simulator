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
@export var exaggerate_noise := false # teaching aid: 8x the realistic sensor noise

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
@export var key_intensity := 1.5 # with f/8, 1/125, ISO 100: skin correctly exposed

@export_group("Fill Light")
@export var fill_angle := 135.0
@export var fill_distance := 1.5
@export var fill_height := 1.9
@export var fill_temperature := 5600.0
@export var fill_intensity := 0.75 # 1 stop under the key (a 2:1 lighting ratio)

@export_group("Rim Light")
@export var rim_angle := 180.0
@export var rim_distance := 1.5
@export var rim_height := 1.9
@export var rim_temperature := 5600.0
@export var rim_intensity := 2.0


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


# Colour of a light of the given colour temperature, for Light3D.light_color.
# Uses the same blackbody approximation as the engine (Krystek's fit of the
# Planckian locus, ported from Light3D's light_temperature code), because the
# camera's white balance (CameraAttributes.white_balance_temperature) is
# defined against it: a light renders exactly neutral under a white balance of
# its own temperature. Scaled to a luminance of 1, so changing a light's
# temperature changes its colour, not its brightness.
static func light_color_for_temperature(kelvin: float) -> Color:
	var t := clampf(kelvin, 1000.0, 15000.0)
	var t2 := t * t
	var u := (0.860117757 + 1.54118254e-4 * t + 1.28641212e-7 * t2) / (1.0 + 8.42420235e-4 * t + 7.08145163e-7 * t2)
	var v := (0.317398726 + 4.22806245e-5 * t + 4.20481691e-8 * t2) / (1.0 - 2.89741816e-5 * t + 1.61456053e-7 * t2)

	# CIE 1960 uv -> xy -> XYZ with Y = 1 -> linear sRGB.
	var d := 1.0 / (2.0 * u - 8.0 * v + 4.0)
	var x := 3.0 * u * d
	var y := 2.0 * v * d
	var X := x / y
	var Z := (1.0 - x - y) / y
	var r := maxf(3.2404542 * X - 1.5371385 - 0.4985314 * Z, 0.0)
	var g := maxf(-0.9692660 * X + 1.8760108 + 0.0415560 * Z, 0.0)
	var b := maxf(0.0556434 * X - 0.2040259 + 1.0572252 * Z, 0.0)

	var luminance := r * 0.2126 + g * 0.7152 + b * 0.0722
	return Color(r / luminance, g / luminance, b / luminance).linear_to_srgb()
