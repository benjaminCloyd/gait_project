extends Node

var api_key: String = ""
var tts_url := "https://texttospeech.googleapis.com/v1/text:synthesize"
var voice_name := "en-US-Standard-A" 
var language_code := "en-US"

# Storage for the preloaded audio files
var preloaded_streams: Array[AudioStreamMP3] = []

func _ready():
	api_key = EnvLoader.load_env_variable("GEMINI_TTS_API_KEY") 
	
	if api_key.is_empty():
		push_error("TTS ERROR: No API key found.")

# --- 1. PRELOAD FUNCTION ---
# Call this from APIManager with the list of text strings
func preload_audio_batch(text_list: Array[String]) -> void:
	print("TTS: Starting preload of ", text_list.size(), " items...")
	
	for text in text_list:
		# We await each generation so we don't spam the API limit
		var stream = await _generate_audio_stream(text)
		
		if stream != null:
			preloaded_streams.append(stream)
			print("TTS: Preloaded audio for -> ", text.left(20), "...")
		else:
			push_error("TTS: Failed to generate audio for: " + text)
			
	print("TTS: Preload complete. Total streams: ", preloaded_streams.size())


# --- 2. PLAYBACK FUNCTION ---
# Call this from Boss.gd when you want to speak instantly
func play_next_preloaded_insult(player: AudioStreamPlayer) -> bool:
	if preloaded_streams.is_empty():
		push_error("TTS Warning: No preloaded streams available!")
		return false
		
	# Pop the first stream off the array
	var stream = preloaded_streams.pop_front()
	
	if is_instance_valid(player):
		player.stream = stream
		player.play()
		return true
	return false


# --- 3. INTERNAL HELPER (The Heavy Lifting) ---
# This does the API call and decoding, returning the raw Stream object
func _generate_audio_stream(text_to_speak: String) -> AudioStreamMP3:
	if api_key.is_empty() or text_to_speak.is_empty():
		return null

	# Create a temporary request node for this specific file
	# (Prevents "Request in progress" errors during loops)
	var new_request = HTTPRequest.new()
	add_child(new_request)

	var final_url = tts_url + "?key=" + api_key
	var headers = ["Content-Type: application/json"]

	var body = JSON.stringify({
		"input": { "text": text_to_speak },
		"voice": { "languageCode": language_code, "name": voice_name },
		"audioConfig": { "audioEncoding": "MP3" }
	})
	
	var err = new_request.request(final_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		new_request.queue_free()
		return null

	# Wait for response
	var response = await new_request.request_completed
	var code = response[1]
	var raw_body = response[3]
	
	# Cleanup the node immediately
	new_request.queue_free()

	if code != 200:
		print("TTS Error: ", raw_body.get_string_from_utf8())
		return null

	var json = JSON.parse_string(raw_body.get_string_from_utf8())
	if not json or not "audioContent" in json:
		return null

	# Decode Base64 to MP3
	var audio_base64 = json["audioContent"]
	var audio_data = Marshalls.base64_to_raw(audio_base64)

	var stream = AudioStreamMP3.new()
	stream.data = audio_data
	return stream

# --- 4. LEGACY SUPPORT ---
# If you still want to speak immediately without preloading, this wrapper works:
func speak_text_immediately(text_to_speak: String, player: AudioStreamPlayer):
	var stream = await _generate_audio_stream(text_to_speak)
	if stream and is_instance_valid(player):
		player.stream = stream
		player.play()
