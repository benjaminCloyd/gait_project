extends MarginContainer

@export var player_path: NodePath
@export var enemy_path: NodePath

@onready var health_bar: TextureProgressBar      = $"HBoxContainer/Player Bars/HealthBar"
@onready var mana_bar: TextureProgressBar        = $"HBoxContainer/Player Bars/ManaBar"
@onready var health_bar_boss: TextureProgressBar = $HBoxContainer/MarginContainer/HealthBarBoss

var player: Node
var enemy: Node   # <-- you were missing this


func _ready() -> void:
	player = get_node(player_path)
	enemy  = get_node(enemy_path)

	# Initialize player bars
	health_bar.max_value = player.max_health
	health_bar.value     = player.health

	mana_bar.max_value   = player.max_mana
	mana_bar.value       = player.mana

	# Initialize boss bar from enemy stats
	health_bar_boss.max_value = enemy.max_health
	health_bar_boss.value     = enemy.health

	# Connect to player signals
	player.health_changed.connect(_on_player_health_changed)
	player.mana_changed.connect(_on_player_mana_changed)

	# Connect to enemy health signal (boss bar)
	enemy.health_changed.connect(_on_enemy_health_changed)


func _on_player_health_changed(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	health_bar.value     = current


func _on_player_mana_changed(current: int, max_value: int) -> void:
	mana_bar.max_value = max_value
	mana_bar.value     = current


func _on_enemy_health_changed(current: int, max_value: int) -> void:
	health_bar_boss.max_value = max_value
	health_bar_boss.value     = current
