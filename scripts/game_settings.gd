extends Node

var tts_explicit: bool = false
var mean_level: int = 3

func _ready():
	load_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "tts_explicit", tts_explicit)
	config.set_value("audio", "mean_level", mean_level)
	config.save("user://settings.cfg")
	print("Settings saved!")

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		tts_explicit = config.get_value("audio", "tts_explicit", false)
		mean_level = config.get_value("audio", "mean_level", 3)
		print("Settings loaded!")
