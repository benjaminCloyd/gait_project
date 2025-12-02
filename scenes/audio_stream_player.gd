extends AudioStreamPlayer

func _ready() -> void:
	# Uses the built-in `autoplay` property of AudioStreamPlayer
	if autoplay and stream and not playing:
		play()


func change_music(new_stream: AudioStream, play_immediately: bool = true) -> void:
	stream = new_stream
	if play_immediately:
		play()
