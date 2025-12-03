# HitParticles.gd
extends Node2D

@onready var particles: GPUParticles2D = $Particles

func _ready() -> void:
	particles.emitting = true
	# Wait for particle lifetime, then free
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	queue_free()
