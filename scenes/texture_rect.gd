
extends TextureRect

@export var viewport : SubViewport

func _ready():
	texture = viewport.get_texture()

func set_zebras_enabled(enabled: bool):

	var mat = material as ShaderMaterial

	mat.set_shader_parameter(
		"zebras_enabled",
		enabled
	)

func set_zebra_threshold(value: float):

	var mat = material as ShaderMaterial

	mat.set_shader_parameter(
		"zebra_threshold",
		value
	)

func set_false_colour_enabled(enabled: bool):

	var mat = material as ShaderMaterial

	mat.set_shader_parameter(
		"false_colour_enabled",
		enabled
	)

func set_sensor_noise(iso_gain: float, full_well: float, boost: float):

	var mat = material as ShaderMaterial

	mat.set_shader_parameter("iso_gain", iso_gain)
	mat.set_shader_parameter("full_well", full_well)
	mat.set_shader_parameter("noise_boost", boost)
