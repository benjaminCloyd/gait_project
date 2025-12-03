extends CharacterBody2D

signal health_changed(current: int, max_value: int)

# --- STATS / TUNING ---
@export var max_health: int = 50
@export var move_speed: float = 70.0

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 250.0
@export var projectile_damage: int = 8

@export var attack_cooldown: float = 0.8      # seconds between shots
@export var attack_range: float = 70.0       # will shoot when distance <= this
@export var min_distance: float = 40.0       # tries to stay at least this far away
@export var detection_radius: float = 500.0   # starts reacting when player is within this

var health: int
var attack_cooldown_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var jump_velocity: float = -250.0   # how strong the jump is
@export var can_jump_over_obstacles: bool = true

# Player reference (auto-detected via group "Player")
var player: CharacterBody2D = null

@onready var wand: Node2D   = $Wand
@onready var sprite: Node2D = $Sprite2D
@onready var obstacle_check: RayCast2D = $ObstacleCheck
var obstacle_base_target: Vector2

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)
	_find_player()

	if is_instance_valid(obstacle_check):
		obstacle_base_target = obstacle_check.target_position

func _physics_process(delta: float) -> void:
	# Make sure we have a valid player
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null or not is_instance_valid(player):
			return

	# --- attack cooldown timer ---
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# --- gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta

	# --- vector to player ---
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	# --- movement AI (ranged: keep distance) ---
	var dir_x: float = 0.0

	if distance <= detection_radius:
		# Too close: back away
		if distance < min_distance:
			if abs(to_player.x) > 4.0:
				dir_x = -sign(to_player.x)
		# Too far (but still interested): move closer
		elif distance > attack_range:
			if abs(to_player.x) > 4.0:
				dir_x = sign(to_player.x)
		# Between min_distance and attack_range: hold position

	# Apply horizontal movement
	if dir_x != 0.0:
		velocity.x = dir_x * move_speed
		_update_facing(dir_x)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)

	# --- simple jump over obstacles with ray flip ---
	if can_jump_over_obstacles and is_on_floor() and dir_x != 0.0 and is_instance_valid(obstacle_check):
		# Flip the ray to face the direction of travel
		if dir_x > 0.0:
			obstacle_check.target_position = Vector2(
				abs(obstacle_base_target.x),
				obstacle_base_target.y
			)
		else:
			obstacle_check.target_position = Vector2(
				-abs(obstacle_base_target.x),
				obstacle_base_target.y
			)

		# If something is right in front, jump
		if obstacle_check.is_colliding():
			velocity.y = jump_velocity

	# --- attack AI ---
	if distance <= attack_range and attack_cooldown_timer <= 0.0:
		shoot_projectile_at_player()
		attack_cooldown_timer = attack_cooldown

	move_and_slide()

func _update_facing(direction: float) -> void:
	if not is_instance_valid(sprite):
		return

	if direction > 0.0:
		sprite.scale.x = abs(sprite.scale.x)      # face right
	elif direction < 0.0:
		sprite.scale.x = -abs(sprite.scale.x)     # face left


func _find_player() -> void:
	# Player must be in the "Player" group (set this on the Player node in the editor)
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var candidate = players[0]
		if candidate is CharacterBody2D:
			player = candidate


func shoot_projectile_at_player() -> void:
	if projectile_scene == null or player == null or not is_instance_valid(player):
		return

	var projectile := projectile_scene.instantiate() as Area2D
	if projectile == null:
		return

	var spawn_pos: Vector2 = global_position
	if is_instance_valid(wand):
		spawn_pos = wand.global_position

	projectile.global_position = spawn_pos

	var dir: Vector2 = (player.global_position - spawn_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT

	projectile.velocity = dir * projectile_speed
	projectile.shooter  = self
	projectile.damage   = projectile_damage

	get_tree().current_scene.add_child(projectile)


func take_damage(amount: int) -> void:
	health -= amount
	if health < 0:
		health = 0

	emit_signal("health_changed", health, max_health)

	if health == 0:
		die()


func die() -> void:
	# TODO: death animation, loot, etc.
	queue_free()
