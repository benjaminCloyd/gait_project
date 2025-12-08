extends Node

var API_KEY: String = ""
var url: String = ""
const DELIMITER = "###" 

# Flag to prevent multiple simultaneous refill requests
var is_loading: bool = false

func _ready() -> void:
	API_KEY = EnvLoader.load_env_variable("GEMINI_API_KEY")
	
	if API_KEY.is_empty():
		push_error("CRITICAL ERROR: Gemini API Key missing.")
		return

	url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=" + API_KEY
	
	# --- NEW: CONNECT TO TTS SIGNAL ---
	# Assuming 'ttsApi' is the AutoLoad name for tts.gd
	if ttsApi.has_signal("buffer_low"):
		ttsApi.buffer_low.connect(_on_tts_buffer_low)
	
	# Initial load
	await _preload_insults(5) 
	print("✅ Gemini Initial Preload Complete")


# Triggered when TTS says it is running out of audio
func _on_tts_buffer_low():
	if not is_loading:
		print("API: Received low buffer signal. Refilling...")
		_preload_insults(3) # Fetch 3 more


func _preload_insults(count: int) -> void:
	is_loading = true
	var prompt = "Give me exactly " + str(count) + " short, evil boss insults for a player who missed an attack. Separate each insult with the unique delimiter: " + DELIMITER

	var raw_response = await ask_gemini(prompt)

	if raw_response.begins_with("Error"):
		push_error("Preload Failed: " + raw_response)
		is_loading = false
		return
		
	var insults_raw = raw_response.split(DELIMITER, false)
	
	# Create a temporary batch for THIS request only
	var new_batch_to_convert: Array[String] = []
	
	for insult in insults_raw:
		var cleaned_insult = insult.strip_edges()
		if not cleaned_insult.is_empty():
			new_batch_to_convert.append(cleaned_insult)
			
	# Send ONLY the new batch to TTS
	if not new_batch_to_convert.is_empty():
		await ttsApi.preload_audio_batch(new_batch_to_convert)
	
	is_loading = false


func ask_gemini(prompt_text: String) -> String:
	if API_KEY.is_empty():
		return "Error: No API Key."

	var new_request = HTTPRequest.new()
	add_child(new_request)
	
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"contents": [{ "parts": [{ "text": prompt_text }] }]
	})
	
	var error = new_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		new_request.queue_free()
		return "Error: Could not create request."
	
	var response = await new_request.request_completed
	
	var response_code = response[1]
	var json_body = response[3]
	var result_text: String = "..."
	
	if response_code == 200:
		var json = JSON.parse_string(json_body.get_string_from_utf8())
		if json and json.has("candidates"):
			result_text = json["candidates"][0]["content"]["parts"][0]["text"]
	else:
		result_text = "Server Error: " + str(response_code)

	new_request.queue_free()
	return result_text
