extends Node2D

@onready var pause_menu: Control = $CanvasLayer/Ui/PauseMenuBackground
@onready var pause_menu_ui: Control = $CanvasLayer/Ui/PauseMenuUI


@onready var player: CharacterBody2D = $Player  # adjust path if needed

func _ready() -> void:
	player.died.connect(_on_player_died)


func _on_player_died() -> void:
	# Make sure the game isn't paused anymore
	get_tree().paused = false# Defer scene change until after physics step
	call_deferred("_go_to_game_over")


func _go_to_game_over() -> void:
	get_tree().change_scene_to_file("res://Scenes/GameOver.tscn")  # <- use your real path

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause"): # or your custom "pause" action
		_toggle_pause()


func _toggle_pause() -> void:
	var tree := get_tree()
	var now_paused := not tree.paused
	tree.paused = now_paused
	pause_menu.visible = now_paused
	pause_menu_ui.visible = now_paused
	
