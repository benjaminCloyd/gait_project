extends CharacterBody2D

signal health_changed(current: int, max_value: int)
signal mana_changed(current: int, max_value: int)
signal died

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

# Attack animation timing
@export var attack_fire_frame: int = 3        # frame where projectile spawns (0-based)
@export var attack_anim_duration: float = 1
var attack_anim_timer: float = 0.0

# Hurt animation timing
@export var hurt_anim_duration: float = 0.4
var hurt_anim_timer: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var wand: Node2D = $Wand
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- AUDIO ---
@onready var attack_sound: AudioStreamPlayer = get_node_or_null("AttackSound")
@onready var hit_sound: AudioStreamPlayer    = get_node_or_null("HitSound")
@onready var walk_sound: AudioStreamPlayer   = get_node_or_null("WalkSound")
@onready var jump_sound: AudioStreamPlayer   = get_node_or_null("JumpSound")

# --- ANIMATION STATE FLAGS ---
var is_attacking: bool = false
var is_hurting: bool = false
var is_dead: bool = false
var has_fired_this_attack: bool = false


func _ready() -> void:
	health = max_health
	mana = max_mana
	jumps_left = max_jumps

	emit_signal("health_changed", health, max_health)
	emit_signal("mana_changed", mana, max_mana)

	if is_instance_valid(sprite):
		sprite.play("idle")
		# We only need frame_changed (timers handle end of states)
		sprite.frame_changed.connect(_on_anim_frame_changed)


func _physics_process(delta: float) -> void:
	# --- attack cooldown ---
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# --- attack animation lock timer ---
	if is_attacking:
		attack_anim_timer -= delta
		if attack_anim_timer <= 0.0:
			is_attacking = false
			has_fired_this_attack = false

	# --- hurt animation lock timer ---
	if is_hurting:
		hurt_anim_timer -= delta
		if hurt_anim_timer <= 0.0:
			is_hurting = false

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
	if Input.is_action_just_pressed("move_jump") and jumps_left > 0 and not is_dead:
		velocity.y = JUMP_VELOCITY
		jumps_left -= 1
		_play_jump_sound()

	# --- horizontal movement + sprite flip ---
	var direction := Input.get_axis("move_Left", "move_Right")
	var is_moving_horiz: bool = direction != 0.0

	if is_moving_horiz and not is_dead:
		velocity.x = direction * SPEED
		_update_facing(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	_handle_walk_sound(is_moving_horiz)

	# --- attack input ---
	if Input.is_action_just_pressed("attack") and not is_dead:
		try_attack()

	move_and_slide()
	_update_animation_state()


func _update_facing(direction: float) -> void:
	if not is_instance_valid(sprite):
		return

	if direction > 0.0:
		sprite.scale.x = abs(sprite.scale.x)   # face right
	elif direction < 0.0:
		sprite.scale.x = -abs(sprite.scale.x)  # face left


# ---------- AUDIO HELPERS ----------

func _play_attack_sound() -> void:
	if is_instance_valid(attack_sound):
		attack_sound.play()

func _play_hit_sound() -> void:
	if is_instance_valid(hit_sound):
		hit_sound.play()

func _play_jump_sound() -> void:
	if is_instance_valid(jump_sound):
		jump_sound.play()

func _handle_walk_sound(is_moving_horiz: bool) -> void:
	if not is_instance_valid(walk_sound):
		return

	# footsteps only when moving on the ground
	if is_moving_horiz and is_on_floor() and not is_dead:
		if not walk_sound.playing:
			walk_sound.play()
	else:
		if walk_sound.playing:
			walk_sound.stop()


# ---------- ATTACK & ANIMATION ----------

func try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return

	if projectile_scene == null:
		push_warning("projectile_scene is not assigned on the player!")
		return

	if mana < mana_per_shot:
		return

	# Spend mana
	mana -= mana_per_shot
	if mana < 0:
		mana = 0
	emit_signal("mana_changed", mana, max_mana)

	# Regen + cooldown
	mana_regen_cooldown = mana_regen_delay
	attack_cooldown_timer = attack_cooldown

	# Animation + sound + timers
	is_attacking = true
	has_fired_this_attack = false
	attack_anim_timer = max(attack_anim_duration, 0.01)  # avoid 0-length

	_play_attack_sound()
	_play_anim("attack")


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


# ---------- ANIMATION STATE MACHINE ----------

func _update_animation_state() -> void:
	if not is_instance_valid(sprite):
		return

	# Death overrides everything
	if is_dead:
		_play_anim("death")
		return

	# Hurt / attack are uninterruptible while their timers are running
	if is_hurting:
		_play_anim("hurt")
		return

	if is_attacking:
		_play_anim("attack")
		return

	# Movement / jump / idle
	if not is_on_floor():
		_play_anim("jump")
		return

	# On the ground now
	if abs(velocity.x) > 5.0:
		_play_anim("walk")
	else:
		_play_anim("idle")


func _play_anim(name: String) -> void:
	if not is_instance_valid(sprite):
		return
	if sprite.animation != name:
		sprite.play(name)


# Called every time the frame changes
func _on_anim_frame_changed() -> void:
	if not is_instance_valid(sprite):
		return

	# Only care while attacking
	if not is_attacking:
		return

	if sprite.animation != "attack":
		return

	if has_fired_this_attack:
		return

	# When attack reaches the chosen frame, spawn the projectile
	if sprite.frame == attack_fire_frame:
		shoot_projectile()
		has_fired_this_attack = true


# ---------- DAMAGE / MANA RESTORE ----------

func take_damage(amount: int) -> void:
	if is_dead:
		return

	_play_hit_sound()

	health -= amount
	if health < 0:
		health = 0
	emit_signal("health_changed", health, max_health)

	if health == 0:
		is_dead = true
		_play_anim("death")
		emit_signal("died")
	else:
		is_hurting = true
		hurt_anim_timer = max(hurt_anim_duration, 0.01)
		_play_anim("hurt")


func restore_mana(amount: int) -> void:
	var old_mana := mana
	mana = min(max_mana, mana + amount)
	if mana != old_mana:
		emit_signal("mana_changed", mana, max_mana)
