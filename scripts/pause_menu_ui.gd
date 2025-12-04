extends MarginContainer




func _on_texture_button_pressed() -> void:
	get_tree().current_scene._toggle_pause()
