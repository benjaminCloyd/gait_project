extends MarginContainer


@export var player_path: NodePath

@onready var health_bar: TextureProgressBar = $VBoxContainer/HealthBar
@onready var mana_bar: TextureProgressBar   = $VBoxContainer/ManaBar

var player: Node


func _ready() -> void:
	player = get_node(player_path)

	# Initialize bars from player stats
	health_bar.max_value = player.max_health
	health_bar.value     = player.health

	mana_bar.max_value   = player.max_mana
	mana_bar.value       = player.mana

	# Connect to player signals
	player.health_changed.connect(_on_player_health_changed)
	player.mana_changed.connect(_on_player_mana_changed)


func _on_player_health_changed(current: int, max: int) -> void:
	health_bar.max_value = max
	health_bar.value     = current


func _on_player_mana_changed(current: int, max: int) -> void:
	mana_bar.max_value = max
	mana_bar.value     = current
