extends Area2D

@export var damage: int = 10                    # how much damage it does
@export var hit_particles_scene: PackedScene    # assign HitParticles.tscn in the Inspector

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null                        # who fired it (player/enemy)

@onready var trail_particles: CPUParticles2D = $TrailParticles


func _ready() -> void:
	# Make sure trail is on
	if is_instance_valid(trail_particles):
		trail_particles.emitting = true

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# Optional: despawn if it goes too far away
	if global_position.length() > 5000.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Ignore the shooter
	if body == shooter:
		return

	# Deal damage if possible
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Spawn hit particles at the collision point
	_spawn_hit_particles()

	# Remove projectile
	queue_free()


func _spawn_hit_particles() -> void:
	if hit_particles_scene == null:
		return

	var hit = hit_particles_scene.instantiate()
	if hit is Node2D:
		hit.global_position = global_position

	get_tree().current_scene.add_child(hit)
