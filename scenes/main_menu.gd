extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/StartButton.grab_focus()
	$ColorRect.hide()
	$VBoxContainer.show()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
	

func _on_options_button_pressed() -> void:
	$VBoxContainer.hide()
	$ColorRect.show()

func _on_exit_button_pressed() -> void:
	$ColorRect.hide()
	$VBoxContainer.show()
