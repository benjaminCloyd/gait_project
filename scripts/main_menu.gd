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

#Voice Change Slider, right now we have 1 - 5
func _on_voice_slider_value_changed(value: float) -> void:
	if(value == 1):
		print("V value is 1")
	elif(value == 2):
		print("V value is 2")
	elif(value == 3):
		print("V value is 3")
	elif(value == 4):
		print("V value is 4")
	elif(value == 5):
		print("V value is 5")

#Meaness Change Slider, right now we have 1 - 5
func _on_mean_slider_value_changed(value: float) -> void:
	if(value == 1):
		print("M value is 1")
	elif(value == 2):
		print("M value is 2")
	elif(value == 3):
		print("M value is 3")
	elif(value == 4):
		print("Mvalue is 4")
	elif(value == 5):
		print("Mvalue is 5")
