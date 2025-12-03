@tool
extends Node2D

@export var light_scale: float = 1.0 : set = set_light_scale

var light: PointLight2D


func _ready() -> void:
	_cache_light()
	set_light_scale(light_scale)


func _cache_light() -> void:
	if light == null:
		light = get_node_or_null("PointLight2D")


func set_light_scale(value: float) -> void:
	light_scale = value
	_cache_light()
	if light:
		light.texture_scale = light_scale
