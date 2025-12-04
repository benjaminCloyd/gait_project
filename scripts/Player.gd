extends CharacterBody2D

signal health_changed(current: int, max_value: int)
signal mana_changed(current: int, max_value: int)

const SPEED := 100.0
const JUMP_VELOCITY := -300.0

# --- STATS ---
@export var max_health: int = 100
@export var max_mana: int = 50
@export var mana_per_shot: int = 5

# --- JUMP SETTINGS ---
@export var max_jumps: int = 2  # 2 = double jump, 1 = normal, 3 = triple, etc.
var jumps_left: int = 0

# mana regen settings
@export var mana_regen_rate: float = 5.0      # mana per second
@export var mana_regen_delay: float = 1.5     # seconds after last spell before regen starts

var health: int
var mana: int

var mana_regen_cooldown: float = 0.0
var _mana_regen_buffer: float = 0.0

# --- ATTACK / PROJECTILE ---
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var attack_cooldown: float = 0.3
@export var projectile_damage: int = 10
var attack_cooldown_timer: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var wand: Node2D   = $Wand
@onready var sprite: Node2D = $AnimatedSprite2D   # change this path if your sprite node is named differently


func _ready() -> void:
	health = max_health
	mana = max_mana
	jumps_left = max_jumps

	emit_signal("health_changed", health, max_health)
	emit_signal("mana_changed", mana, max_mana)


func _physics_process(delta: float) -> void:
	# --- attack cooldown ---
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# --- mana regen cooldown / tick ---
	if mana_regen_cooldown > 0.0:
		mana_regen_cooldown -= delta
	elif mana < max_mana:
		_mana_regen_buffer += mana_regen_rate * delta
		if _mana_regen_buffer >= 1.0:
			var gained := int(_mana_regen_buffer)
			_mana_regen_buffer -= gained
			var old_mana := mana
			mana = min(max_mana, mana + gained)
			if mana != old_mana:
				emit_signal("mana_changed", mana, max_mana)

	# --- gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# On the ground: reset jumps
		jumps_left = max_jumps

	# --- jump / double jump ---
	if Input.is_action_just_pressed("move_jump") and jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1

	# --- horizontal movement + sprite flip ---
	var direction := Input.get_axis("move_Left", "move_Right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		_update_facing(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	# --- attack input ---
	if Input.is_action_just_pressed("attack"):
		try_attack()

	move_and_slide()


func _update_facing(direction: float) -> void:
	if not is_instance_valid(sprite):
		return

	if direction > 0.0:
		sprite.scale.x = abs(sprite.scale.x)   # face right
	elif direction < 0.0:
		sprite.scale.x = -abs(sprite.scale.x)  # face left


func try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return

	if projectile_scene == null:
		push_warning("projectile_scene is not assigned on the player!")
		return

	if mana < mana_per_shot:
		return

	mana -= mana_per_shot
	if mana < 0:
		mana = 0
	emit_signal("mana_changed", mana, max_mana)

	mana_regen_cooldown = mana_regen_delay
	attack_cooldown_timer = attack_cooldown

	shoot_projectile()


func shoot_projectile() -> void:
	var projectile := projectile_scene.instantiate() as Area2D
	if projectile == null:
		return

	var spawn_pos: Vector2 = global_position
	if is_instance_valid(wand):
		spawn_pos = wand.global_position

	projectile.global_position = spawn_pos

	var dir: Vector2 = (get_global_mouse_position() - spawn_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

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
		# TODO: death handling
		pass


func restore_mana(amount: int) -> void:
	var old_mana := mana
	mana = min(max_mana, mana + amount)
	if mana != old_mana:
		emit_signal("mana_changed", mana, max_mana)
