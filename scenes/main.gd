extends Node2D

@onready var pause_menu: Control = $CanvasLayer/Ui/PauseMenuBackground
@onready var pause_menu_ui: Control = $CanvasLayer/Ui/PauseMenuUI


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause"): # or your custom "pause" action
		_toggle_pause()


func _toggle_pause() -> void:
	var tree := get_tree()
	var now_paused := not tree.paused
	tree.paused = now_paused
	pause_menu.visible = now_paused
	pause_menu_ui.visible = now_paused
	
