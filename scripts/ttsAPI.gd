extends Node

var api_key: String = ""
# Standard Google Cloud Text-to-Speech endpoint
var tts_url := "https://texttospeech.googleapis.com/v1/text:synthesize"

var tts_request: HTTPRequest

# Google Cloud TTS Voice names look like "en-US-Standard-A", "en-GB-Neural2-B", etc.
# See list: https://cloud.google.com/text-to-speech/docs/voices
var voice_name := "en-US-Standard-A" 
var language_code := "en-US"


func _ready():
	api_key = EnvLoader.load_env_variable("GEMINI_TTS_API_KEY") # Make sure to update your env key name if needed
	
	if api_key.is_empty():
		push_error("TTS ERROR: No API key found.")
		return

	tts_request = HTTPRequest.new()
	add_child(tts_request)


func speak_text(text_to_speak: String, player: AudioStreamPlayer) -> bool:
	if api_key.is_empty():
		return false
	
	if text_to_speak.is_empty():
		push_error("TTS ERROR: Empty text.")
		return false

	var final_url = tts_url + "?key=" + api_key
	var headers = ["Content-Type: application/json"]

	# Standard Google Cloud TTS JSON Payload
	var body = JSON.stringify({
		"input": {
			"text": text_to_speak
		},
		"voice": {
			"languageCode": language_code,
			"name": voice_name
		},
		"audioConfig": {
			"audioEncoding": "MP3" # We can request MP3 directly here!
		}
	})
	
	var err = tts_request.request(final_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_error("Google Cloud TTS request failed.")
		return false

	var response = await tts_request.request_completed
	var code = response[1]
	var raw_body = response[3]

	if code != 200:
		push_error("Google Cloud TTS HTTP Error: " + str(code))
		print("Error Body: ", raw_body.get_string_from_utf8())
		return false

	var json = JSON.parse_string(raw_body.get_string_from_utf8())
	if not json:
		push_error("TTS JSON parse error.")
		return false

	if not "audioContent" in json:
		push_error("TTS Error: No audio content in response.")
		return false

	# Extract the audio (Note: Field is 'audioContent', not 'inlineData' like Gemini)
	var audio_base64 = json["audioContent"]
	var audio_data = Marshalls.base64_to_raw(audio_base64)

	# Create MP3 Stream (Works natively with Google Cloud TTS)
	var stream = AudioStreamMP3.new()
	stream.data = audio_data

	player.stream = stream
	player.play()

	return true
