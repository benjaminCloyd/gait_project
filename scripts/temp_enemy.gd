extends CharacterBody2D

signal health_changed(current: int, max_value: int)

# ---------- STATES ----------
enum EnemyState { NORMAL, ATTACK, HURT, DEAD }
var state: int = EnemyState.NORMAL

# ---------- STATS / TUNING ----------
@export var max_health: int = 50
@export var move_speed: float = 70.0

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 250.0
@export var projectile_damage: int = 8

@export var attack_cooldown: float = 0.8      # seconds between shots
@export var attack_range: float = 70.0       # will shoot when distance <= this
@export var min_distance: float = 50.0       # prefers to stay at least this far
@export var detection_radius: float = 500.0   # starts reacting when player is within this

# Ground movement / jumping
@export var jump_velocity: float = -250.0
@export var can_jump_over_obstacles: bool = true

# Flying behaviour
@export var can_fly: bool = false             # if true, no gravity & full 2D movement

# Line of sight for attacks
@export var require_line_of_sight: bool = true
@export var los_collision_mask: int = 1       # which layers block LOS (walls, etc.)

var health: int
var attack_cooldown_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Player reference (auto-detected via group "Player")
var player: CharacterBody2D = null

# Flying strafe direction (1 = clockwise, -1 = counter-clockwise)
var fly_strafe_dir: float = 1.0

@onready var wand: Node2D                 = $Wand
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var obstacle_check: RayCast2D    = get_node_or_null("ObstacleCheck")
var obstacle_base_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)
	_find_player()

	if obstacle_check:
		obstacle_base_target = obstacle_check.target_position

	if animated_sprite:
		animated_sprite.play("idle")
		# Make sure attack / hurt / death are NOT looped in the editor
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if state == EnemyState.DEAD:
		return

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

	_update_animation_state()


# ---------- GROUND VERSION ----------

func _physics_process_ground(delta: float, to_player: Vector2, distance: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	var dir_x: float = 0.0

	if distance <= detection_radius:
		# Too close: back away
		if distance < min_distance:
			if abs(to_player.x) > 4.0:
				dir_x = -sign(to_player.x)
		# Too far: move closer
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

	# Jump over obstacles
	if can_jump_over_obstacles and is_on_floor() and dir_x != 0.0 and obstacle_check:
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

	# Attack only if we’re in NORMAL state
	var has_los := not require_line_of_sight or _has_line_of_sight_to_player()
	if state == EnemyState.NORMAL and distance <= attack_range and attack_cooldown_timer <= 0.0 and has_los:
		_do_attack()

	move_and_slide()


# ---------- FLYING VERSION ----------

func _physics_process_flying(_delta: float, to_player: Vector2, distance: float) -> void:
	var move_dir: Vector2 = Vector2.ZERO
	var to_dir: Vector2 = to_player.normalized()

	var has_los := not require_line_of_sight or _has_line_of_sight_to_player()

	if distance <= detection_radius:
		# Radial movement to keep distance band
		if distance < min_distance:
			move_dir += -to_dir
		elif distance > attack_range:
			move_dir += to_dir

		# If LOS blocked, strafe around to find angle
		if require_line_of_sight and not has_los:
			var tangent := Vector2(-to_dir.y, to_dir.x) * fly_strafe_dir
			move_dir += tangent * 0.8
			if randf() < 0.01:
				fly_strafe_dir *= -1.0
	else:
		move_dir = Vector2.ZERO

	if move_dir != Vector2.ZERO:
		move_dir = move_dir.normalized()
	velocity = move_dir * move_speed

	if velocity.x != 0.0:
		_update_facing(sign(velocity.x))

	# Attack only if we’re in NORMAL state
	if state == EnemyState.NORMAL and distance <= attack_range and attack_cooldown_timer <= 0.0 and has_los:
		_do_attack()

	move_and_slide()


# ---------- ATTACK / ANIM STATE ----------

func _do_attack() -> void:
	shoot_projectile_at_player()
	attack_cooldown_timer = attack_cooldown

	state = EnemyState.ATTACK
	_play_anim("attack")  # will restart attack anim every time


func _on_animation_finished() -> void:
	if not is_instance_valid(animated_sprite):
		return

	var anim_name := animated_sprite.animation
	# print("Enemy anim finished: ", anim_name)  # uncomment for debugging

	match anim_name:
		"attack":
			if state == EnemyState.ATTACK:
				state = EnemyState.NORMAL
		"hurt":
			if state == EnemyState.HURT:
				state = EnemyState.NORMAL
		"death":
			# death is final
			if state == EnemyState.DEAD:
				queue_free()


func _update_animation_state() -> void:
	if not is_instance_valid(animated_sprite):
		return

	# Don't override attack/hurt/death animations
	if state == EnemyState.ATTACK or state == EnemyState.HURT or state == EnemyState.DEAD:
		return

	var moving: bool = false
	if can_fly:
		moving = velocity.length() > 5.0
	else:
		moving = abs(velocity.x) > 5.0 and is_on_floor()

	if moving:
		_play_anim("walk")
	else:
		_play_anim("idle")


func _play_anim(name: String) -> void:
	if not is_instance_valid(animated_sprite):
		return
	animated_sprite.play(name)


func _update_facing(direction: float) -> void:
	if not is_instance_valid(animated_sprite):
		return

	if direction > 0.0:
		animated_sprite.scale.x = abs(animated_sprite.scale.x)
	elif direction < 0.0:
		animated_sprite.scale.x = -abs(animated_sprite.scale.x)


# ---------- TARGETING / LOS / PROJECTILES ----------

func _find_player() -> void:
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
		return true

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


# ---------- DAMAGE / DEATH ----------

func take_damage(amount: int) -> void:
	if state == EnemyState.DEAD:
		return

	health -= amount
	if health < 0:
		health = 0

	emit_signal("health_changed", health, max_health)

	if health == 0:
		state = EnemyState.DEAD
		velocity = Vector2.ZERO
		_play_anim("death")
	else:
		state = EnemyState.HURT
		_play_anim("hurt")
