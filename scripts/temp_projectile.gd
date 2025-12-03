extends Area2D

var velocity: Vector2 = Vector2.ZERO
var shooter: Node = null   # who fired this projectile

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# Optional: despawn if it goes too far away
	if global_position.length() > 5000.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Ignore the shooter (player)
	if body == shooter:
		return

	# Hit anything else -> despawn
	queue_free()
