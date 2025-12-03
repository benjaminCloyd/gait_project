extends Node2D

@export var light_scale: float = 1.0 : set = set_light_scale

@onready var light: PointLight2D = $PointLight2D


func _ready() -> void:
	# Apply the exported value when the scene loads
	set_light_scale(light_scale)


func set_light_scale(value: float) -> void:
	light_scale = value
	if is_instance_valid(light):
		light.texture_scale = light_scale
