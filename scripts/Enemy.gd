extends CharacterBody2D

signal health_changed(current: int, max_value: int)

# --- STATS / TUNING ---
@export var max_health: int = 200
@export var move_speed: float = 70.0

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 250.0
@export var projectile_damage: int = 8

@export var attack_cooldown: float = 0.8      # seconds between shots
@export var attack_range: float = 70.0        # will shoot when distance <= this
@export var min_distance: float = 50.0        # prefers to stay at least this far
@export var detection_radius: float = 500.0   # starts reacting when player is within this

# Ground movement / jumping
@export var jump_velocity: float = -250.0
@export var can_jump_over_obstacles: bool = true

# Flying behaviour
@export var can_fly: bool = false             # if true, use flying + pathfinding

# Line of sight for attacks
@export var require_line_of_sight: bool = true
@export var los_collision_mask: int = 1       # which layers block LOS (walls, etc.)

# Animation timing
@export var hurt_anim_duration: float = 0.25
@export var attack_anim_duration: float = 0.35
@export var death_anim_duration: float = 0.6

# Facing thresholds (tweak in inspector)
@export var facing_velocity_threshold: float = 10.0   # min |velocity.x| to consider flipping
@export var facing_input_threshold: float = 0.2       # min |direction| passed into _update_facing

# Animation “moving vs idle” thresholds (hysteresis)
@export var moving_start_threshold: float = 20.0      # speed where we switch to walk/fly anim
@export var moving_stop_threshold: float = 8.0        # speed where we switch back to idle

var health: int
var attack_cooldown_timer: float = 10.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Player reference (auto-detected via group "Player")
var player: CharacterBody2D = null

# Flying strafe direction (1 = clockwise, -1 = counter-clockwise)
var fly_strafe_dir: float = 1.0

# Animation state timers
var hurt_anim_timer: float = 0.6
var attack_anim_timer: float = 2.6
var is_dead: bool = false

# Facing
var facing_dir: int = 1  # 1 = right, -1 = left

# Smoothed “moving” flag for animations
var _is_moving: bool = false

@onready var wand: Node2D                      = $Wand
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var obstacle_check: RayCast2D         = get_node_or_null("ObstacleCheck")
@onready var audio_player: AudioStreamPlayer   = $AudioStreamPlayer
@onready var nav_agent: NavigationAgent2D      = $NavigationAgent2D

var obstacle_base_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)
	_find_player()

	if obstacle_check:
		obstacle_base_target = obstacle_check.target_position

	if animated_sprite:
		animated_sprite.play("idle")

	if nav_agent:
		nav_agent.target_position = global_position


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Ensure we have a valid player target
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null or not is_instance_valid(player):
			return

	# Timers
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if hurt_anim_timer > 0.0:
		hurt_anim_timer -= delta
	if attack_anim_timer > 0.0:
		attack_anim_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if can_fly:
		_physics_process_flying(delta, to_player, distance)
	else:
		_physics_process_ground(delta, to_player, distance)


# ---------- GROUND VERSION (mostly unchanged) ----------

func _physics_process_ground(delta: float, to_player: Vector2, distance: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var dir_x: float = 0.0

	if distance <= detection_radius:
		if distance < min_distance:
			if abs(to_player.x) > 4.0:
				dir_x = -sign(to_player.x)
		elif distance > attack_range:
			if abs(to_player.x) > 4.0:
				dir_x = sign(to_player.x)

	if dir_x != 0.0:
		velocity.x = dir_x * move_speed
		_update_facing(dir_x)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)

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

	var has_los: bool = not require_line_of_sight or _has_line_of_sight_to_player()
	if distance <= attack_range and attack_cooldown_timer <= 0.0 and has_los:
		shoot_projectile_at_player()
		attack_cooldown_timer = attack_cooldown
		attack_anim_timer = attack_anim_duration
		_play_anim("attack")

	move_and_slide()
	_update_animation_state()


# ---------- FLYING VERSION with NavigationAgent2D ----------

func _physics_process_flying(delta: float, to_player: Vector2, distance: float) -> void:
	var has_los: bool = not require_line_of_sight or _has_line_of_sight_to_player()
	var goal: Vector2 = global_position

	if distance <= detection_radius:
		var from_player: Vector2 = global_position - player.global_position
		var from_player_len: float = from_player.length()

		var from_player_dir: Vector2
		if from_player_len > 0.0:
			from_player_dir = from_player / from_player_len
		else:
			from_player_dir = Vector2.RIGHT

		var desired_radius: float = clamp(from_player_len, min_distance, attack_range)

		if distance > attack_range:
			desired_radius = attack_range
			goal = player.global_position + from_player_dir * desired_radius
		elif distance < min_distance:
			desired_radius = max(min_distance, attack_range)
			goal = player.global_position + from_player_dir * desired_radius
		else:
			goal = global_position

		# If LOS is blocked, orbit around the player to find a clearer angle
		if require_line_of_sight and not has_los:
			var tangent: Vector2 = Vector2(-from_player_dir.y, from_player_dir.x) * fly_strafe_dir
			var orbit_radius: float = desired_radius
			goal = player.global_position + tangent.normalized() * orbit_radius
			if randf() < 0.01:
				fly_strafe_dir *= -1.0
	else:
		goal = global_position

	var move_dir: Vector2 = Vector2.ZERO

	if nav_agent != null:
		if nav_agent.target_position.distance_to(goal) > 4.0:
			nav_agent.target_position = goal

		var next_point: Vector2 = nav_agent.get_next_path_position()
		var to_next: Vector2 = next_point - global_position
		if to_next.length() > 1.0:
			move_dir = to_next.normalized()
	else:
		# Fallback if nav_agent missing
		if distance <= detection_radius:
			if distance > attack_range:
				move_dir = to_player.normalized()
			elif distance < min_distance:
				move_dir = -to_player.normalized()

	if move_dir != Vector2.ZERO:
		velocity = move_dir * move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta)

	# Flip sprite only if moving horizontally fast enough
	if abs(velocity.x) > facing_velocity_threshold:
		_update_facing(sign(velocity.x))

	if distance <= attack_range and attack_cooldown_timer <= 0.0 and has_los:
		shoot_projectile_at_player()
		attack_cooldown_timer = attack_cooldown
		attack_anim_timer = attack_anim_duration
		_play_anim("attack")

	move_and_slide()
	_update_animation_state()


# ---------- ANIMATION HELPERS ----------

func _update_facing(direction: float) -> void:
	if not is_instance_valid(animated_sprite):
		return

	# Ignore tiny values (prevents jitter)
	if abs(direction) < facing_input_threshold:
		return

	if direction > 0.0 and facing_dir != 1:
		facing_dir = 1
		animated_sprite.scale.x = abs(animated_sprite.scale.x)      # face right
	elif direction < 0.0 and facing_dir != -1:
		facing_dir = -1
		animated_sprite.scale.x = -abs(animated_sprite.scale.x)     # face left


func _update_animation_state() -> void:
	if not is_instance_valid(animated_sprite) or is_dead:
		return

	# Hurt / attack take priority and are non-jittery
	if hurt_anim_timer > 0.0:
		_play_anim("hurt")
		return

	if attack_anim_timer > 0.0:
		_play_anim("attack")
		return

	# --- Smooth "moving vs idle" using hysteresis ---
	var speed: float
	if can_fly:
		speed = velocity.length()
	else:
		speed = abs(velocity.x)

	if _is_moving:
		if speed < moving_stop_threshold:
			_is_moving = false
	else:
		if speed > moving_start_threshold:
			_is_moving = true

	if _is_moving:
		_play_anim("walk")   # for flying you can swap this to "fly" if you have it
	else:
		_play_anim("idle")


func _play_anim(name: String) -> void:
	if not is_instance_valid(animated_sprite):
		return
	if animated_sprite.animation != name:
		animated_sprite.play(name)


# ---------- TARGETING / LOS / PROJECTILES ----------

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var candidate: Node = players[0]
		if candidate is CharacterBody2D:
			player = candidate as CharacterBody2D


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

	var projectile: Area2D = projectile_scene.instantiate() as Area2D
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
	projectile.Insult   = true   # your custom property

	get_tree().current_scene.add_child(projectile)


# ---------- DAMAGE / DEATH ----------

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	if health < 0:
		health = 0

	emit_signal("health_changed", health, max_health)

	if health == 0:
		die()
	else:
		hurt_anim_timer = hurt_anim_duration


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_play_anim("death")
	await get_tree().create_timer(death_anim_duration).timeout
	queue_free()
