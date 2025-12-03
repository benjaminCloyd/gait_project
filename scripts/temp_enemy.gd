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
@export var min_distance: float = 50.0       # tries to stay at least this far away
@export var detection_radius: float = 500.0   # starts reacting when player is within this

# Ground movement / jumping
@export var jump_velocity: float = -250.0
@export var can_jump_over_obstacles: bool = true

# Flying behaviour
@export var can_fly: bool = true             # if true, no gravity & full 2D movement

# Line of sight for attacks
@export var require_line_of_sight: bool = true
@export var los_collision_mask: int = 1       # which layers block line of sight (walls, etc.)

var health: int
var attack_cooldown_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Player reference (auto-detected via group "Player")
var player: CharacterBody2D = null

# Flying strafe direction (1 = clockwise, -1 = counter-clockwise)
var fly_strafe_dir: float = 1.0

@onready var wand: Node2D          = $Wand
@onready var sprite: Node2D        = $Sprite2D
@onready var obstacle_check: RayCast2D = get_node_or_null("ObstacleCheck")
var obstacle_base_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)
	_find_player()

	if obstacle_check:
		obstacle_base_target = obstacle_check.target_position


func _physics_process(delta: float) -> void:
	# Ensure we have a valid player target
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null or not is_instance_valid(player):
			return

	# --- timers ---
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if can_fly:
		_physics_process_flying(delta, to_player, distance)
	else:
		_physics_process_ground(delta, to_player, distance)


# ---------- GROUND VERSION (unchanged from before) ----------

func _physics_process_ground(delta: float, to_player: Vector2, distance: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# ----- movement AI (keep distance horizontally) -----
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

	# Simple jump over obstacles
	if can_jump_over_obstacles and is_on_floor() and dir_x != 0.0 and obstacle_check:
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

		if obstacle_check.is_colliding():
			velocity.y = jump_velocity

	# --- attack AI ---
	var has_los := not require_line_of_sight or _has_line_of_sight_to_player()
	if distance <= attack_range and attack_cooldown_timer <= 0.0 and has_los:
		shoot_projectile_at_player()
		attack_cooldown_timer = attack_cooldown

	move_and_slide()


# ---------- FLYING VERSION (new strafing + LOS hunting) ----------

func _physics_process_flying(delta: float, to_player: Vector2, distance: float) -> void:
	var move_dir: Vector2 = Vector2.ZERO
	var to_dir: Vector2 = to_player.normalized()

	# Check LOS once this frame
	var has_los := not require_line_of_sight or _has_line_of_sight_to_player()

	if distance <= detection_radius:
		# 1) Radial movement to maintain distance band
		if distance < min_distance:
			move_dir += -to_dir              # move away
		elif distance > attack_range:
			move_dir += to_dir               # move closer

		# 2) If LOS is blocked, add tangential (sideways) movement to try to peek
		if require_line_of_sight and not has_los:
			# Tangent to the vector pointing to the player (perpendicular)
			var tangent := Vector2(-to_dir.y, to_dir.x) * fly_strafe_dir
			move_dir += tangent * 0.8        # 0.8 = how "wide" the strafe is

			# Occasionally flip strafe direction to avoid circling forever one way
			if randf() < 0.01:
				fly_strafe_dir *= -1.0
	else:
		# Player out of detection radius → idle
		move_dir = Vector2.ZERO

	# Apply movement
	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()
	velocity = move_dir * move_speed

	# Flip sprite based on horizontal movement
	if velocity.x != 0.0:
		_update_facing(sign(velocity.x))

	# --- attack AI ---
	if distance <= attack_range and attack_cooldown_timer <= 0.0 and has_los:
		shoot_projectile_at_player()
		attack_cooldown_timer = attack_cooldown

	move_and_slide()


# ---------- SHARED HELPERS ----------

func _update_facing(direction: float) -> void:
	if not is_instance_valid(sprite):
		return

	if direction > 0.0:
		sprite.scale.x = abs(sprite.scale.x)      # face right
	elif direction < 0.0:
		sprite.scale.x = -abs(sprite.scale.x)     # face left


func _find_player() -> void:
	# Player must be in the "Player" group (set this on your Player node)
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var candidate = players[0]
		if candidate is CharacterBody2D:
			player = candidate


func _has_line_of_sight_to_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	query.collision_mask = los_collision_mask

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		# nothing in the way
		return true

	# If the first thing hit is the player, we have line of sight
	return result.get("collider") == player


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
	# TODO: death animation / loot, etc.
	queue_free()
