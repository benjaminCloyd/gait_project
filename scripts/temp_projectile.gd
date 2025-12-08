extends Area2D

@export var damage: int = 10
@export var hit_particles_scene: PackedScene


var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null
var Insult: bool = false

@onready var trail_particles: CPUParticles2D = $TrailParticles
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	if is_instance_valid(trail_particles):
		trail_particles.emitting = true

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# Optional: despawn if it goes too far away
	if global_position.length() > 5000.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if $PointLight2D.visible:
		# Ignore the shooter
		if body == shooter:
			return
		velocity=Vector2.ZERO
		_spawn_hit_particles()
		$Sprite2D.visible=false
		$GPUParticles2D.visible=false
		$TrailParticles.visible=false
		$PointLight2D.visible=false
		# Deal damage if possible
		if body.has_method("take_damage"):
			body.take_damage(damage)
			
			
			if Insult:
				ttsApi.play_next_preloaded_insult(audio_player)
				await audio_player.finished

		# Spawn hit particles at the collision point
		
		# Remove projectile
		
		queue_free()


func _spawn_hit_particles() -> void:
	if hit_particles_scene == null:
		return

	var tree := get_tree()
	if tree == null:
		return

	var hit := hit_particles_scene.instantiate()
	if hit is Node2D:
		hit.global_position = global_position

	var parent: Node = tree.current_scene
	if parent == null:
		parent = get_parent()

	if parent != null:
		parent.add_child(hit)
