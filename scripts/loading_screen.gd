extends Control

func _ready():
	load_game()


func load_game() -> void:
	# Show something to the user (spinner, text)
	$VBoxContainer/Label.text = "Loading..."

	# Buffer insults based on selected sliders
	await APIManager._preload_insults(5)

	# When done → load actual game
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
