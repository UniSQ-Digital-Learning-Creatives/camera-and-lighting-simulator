extends TextureRect

# The monitor: shows what the camera renders. The sensor noise, zebras and
# false colour are all drawn by the engine into the camera's own image (see
# exposure_controller.update_noise and monitoring_controller.gd).

@export var viewport : SubViewport

func _ready():
	texture = viewport.get_texture()
