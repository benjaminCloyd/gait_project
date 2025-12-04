extends Node

var API_KEY = ""
var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=" + API_KEY
var request : HTTPRequest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_request_completed)
	
	dialogue_request("Insult me as if you are an evil boss")
	
func dialogue_request(player_dialogue):
	var headers = ["Content-Type: application/json"]
	
	var body = JSON.stringify({
		"contents": [{
			"parts": [{
				"text" : player_dialogue
			}]
		}]
	})
	
	#Post means we are sending something over
	var send_request = request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if send_request != OK:
		print("There was an error!")
	
#Reads what was given back, only runs after a request properly done
func _on_request_completed (_result, response_code, _headers, body):
	var json_string = body.get_string_from_utf8()
	
	# Check for HTTP Errors (200 = OK)
	if response_code != 200:
		print("Error: API returned code ", response_code)
		print("Details: ", json_string)
		return

	# Parse the JSON
	var response = JSON.parse_string(json_string)
	
	if response == null:
		print("Error: Could not parse the JSON response.")
		return

	# Extract the text
	if response.has("candidates") and response["candidates"].size() > 0:
		var content = response["candidates"][0]["content"]["parts"][0]["text"]
		print("BOSS: " + content)
	else:
		print("Unexpected response format: ", response)
	

## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
