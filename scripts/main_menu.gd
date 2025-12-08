extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/StartButton.grab_focus()
	$ColorRect.hide()
	$VBoxContainer.show()

	# Load the saved explicit setting into the checkbox
	if has_node("ColorRect/ExplicitCheckBox"):
		$ColorRect/ExplicitCheckBox.button_pressed = GameSettings.tts_explicit
	
	# Load the saved meanness level into the slider
	if has_node("ColorRect/MeanSlider"):
		$ColorRect/MeanSlider.value = GameSettings.mean_level


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")



func _on_quit_button_pressed() -> void:
	get_tree().quit()
	

func _on_options_button_pressed() -> void:
	$VBoxContainer.hide()
	$ColorRect.show()

func _on_exit_button_pressed() -> void:
	$ColorRect.hide()
	$VBoxContainer.show()




func _on_explicit_check_box_toggled(toggled_on: bool) -> void:
	GameSettings.tts_explicit = toggled_on

#Meaness Change Slider, right now we have 1 - 5
func _mean_slider_value_changed(value: float) -> void:
	GameSettings.mean_level = int(value)
