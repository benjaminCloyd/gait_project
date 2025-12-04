extends Node

# Load key from .env (or paste strictly for testing)
var API_KEY = EnvLoader.load_env_variable("GEMINI_API_KEY")
var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=" + API_KEY

# This function can be awaited! 
# It creates a temporary node, sends the message, returns the text, and cleans up.
func ask_gemini(prompt_text: String) -> String:
	# 1. Create a temporary HTTP Request node for this specific call
	var new_request = HTTPRequest.new()
	add_child(new_request)
	
	# 2. Prepare the data
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"contents": [{ "parts": [{ "text": prompt_text }] }]
	})
	
	# 3. Send the request
	var error = new_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		new_request.queue_free() # Clean up if failed
		return "Error: Could not send request."
	
	# 4. WAIT for the response (The magic 'await' keyword)
	var response = await new_request.request_completed
	
	# response is an array: [result, response_code, headers, body]
	var response_code = response[1]
	var json_body = response[3]
	
	# 5. Parse result
	var result_text = "Error"
	if response_code == 200:
		var json = JSON.parse_string(json_body.get_string_from_utf8())
		if json and json.has("candidates"):
			result_text = json["candidates"][0]["content"]["parts"][0]["text"]
	else:
		result_text = "Server Error: " + str(response_code)

	# 6. Delete the temporary node and return the text
	new_request.queue_free()
	return result_text
