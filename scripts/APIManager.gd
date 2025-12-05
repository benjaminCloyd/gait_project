extends Node

var API_KEY: String = ""
var url: String = ""
# 1. Storage for preloaded insults
var preloaded_insults: Array[String] = []
# 2. Unique delimiter for batch parsing (must not appear in normal text)
const DELIMITER = "###" 


func _ready() -> void:
	# Load key safely
	API_KEY = EnvLoader.load_env_variable("GEMINI_API_KEY")
	
	if API_KEY.is_empty():
		push_error("CRITICAL ERROR: Gemini API Key missing in EnvLoader.")
		return

	url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=" + API_KEY
	
	# Start preloading immediately on startup!
	# The game will continue loading while this waits for the API response.
	await _preload_insults(5) 
	print("✅ Gemini Preloaded: ", preloaded_insults.size(), " insults.")


# --- PRELOADING LOGIC (NEW) ---

func _preload_insults(count: int) -> void:
	var prompt = "Give me exactly " + str(count) + " short, evil boss insults for a player who missed an attack. Separate each insult with the unique delimiter: " + DELIMITER

	# The existing ask_gemini function is great for reuse
	var raw_response = await ask_gemini(prompt)

	if raw_response.begins_with("Error"):
		push_error("Preload Failed: " + raw_response)
		return
		
	# 3. Parse the batch response using the unique delimiter
	var insults = raw_response.split(DELIMITER, false)
	
	# Clean up and add valid insults to the list
	for insult in insults:
		var cleaned_insult = insult.strip_edges()
		# Filter out any empty strings created by leading/trailing delimiters
		if not cleaned_insult.is_empty():
			preloaded_insults.append(cleaned_insult)
			
	await ttsApi.preload_audio_batch(preloaded_insults)
	

# --- USAGE LOGIC (NEW) ---

# Public function for Boss.gd to call when it needs an insult
func get_preloaded_insult() -> String:
	if preloaded_insults.is_empty():
		# Option A: Fallback to a hardcoded response
		print("WARNING: Preloaded insults exhausted. Falling back to default.")
		return "Pathetic display! Is that the best you can muster?"
		
		# Option B: You could queue a new request here, but that defeats the purpose of preloading.

	# Take the first insult from the list
	var insult = preloaded_insults[0]
	preloaded_insults.remove_at(0) # Remove it so it's not reused
	
	# Optionally, if the list is getting low, you could trigger a new preload
	if preloaded_insults.size() <= 1:
		_preload_insults(5) 
	
	
	return insult


# --- EXISTING ask_gemini FUNCTION (REMAINS UNCHANGED) ---

func ask_gemini(prompt_text: String) -> String:
	if API_KEY.is_empty():
		return "Error: No API Key."

	# (The rest of the function body for single requests)
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
