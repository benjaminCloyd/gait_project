class_name EnvLoader

static func load_env_variable(variable_name: String) -> String:
	var file = FileAccess.open("res://.env", FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line()
			# Skip comments or empty lines
			if line.begins_with("#") or line.strip_edges() == "":
				continue
			
			var parts = line.split("=")
			if parts.size() >= 2:
				var key = parts[0].strip_edges()
				if key == variable_name:
					# Return the value part (and handle if value has = in it)
					return line.substr(key.length() + 1).strip_edges()
	return ""
