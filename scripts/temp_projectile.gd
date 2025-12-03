extends Area2D

@export var damage: int = 10      # how much damage this projectile does

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null          # who fired it (player or enemy)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# Optional: despawn if it goes too far away
	if global_position.length() > 5000.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Ignore whoever fired the projectile
	if body == shooter:
		return

	# If the body can take damage, apply it
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Then destroy the projectile
	queue_free()
