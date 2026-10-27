@tool
extends MeshInstance3D

# Ava's shirt in UniSQ brand colours. Pick the colourway here; both textures
# are baked by tools/make_shirt_texture.gd.

enum Colourway { GOLD_SHIRT_PURPLE_LOGO, PURPLE_SHIRT_GOLD_LOGO }

const SHIRT_SURFACE := 1
const TEXTURES := {
	Colourway.GOLD_SHIRT_PURPLE_LOGO: preload("res://scenes/Ava/Maps/Shirt_UniSQ_Gold_Basecolor.png"),
	Colourway.PURPLE_SHIRT_GOLD_LOGO: preload("res://scenes/Ava/Maps/Shirt_UniSQ_Purple_Basecolor.png"),
}

@export var colourway := Colourway.GOLD_SHIRT_PURPLE_LOGO:
	set(value):
		colourway = value
		_apply()

func _ready():
	_apply()

func _apply():
	if mesh == null:
		return
	var material := mesh.surface_get_material(SHIRT_SURFACE) as StandardMaterial3D
	if material:
		material.albedo_texture = TEXTURES[colourway]
