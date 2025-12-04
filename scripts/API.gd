extends Node

var API_KEY = ""
var url = "https://api.openai.com/v1/chat/completions" #Needs to be this in order for this to work
var temperature = 0.5
var max_tokens = 1024
var model = "gpt-3.5-turbo"
var messages = []
var request : HTTPRequest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_request_completed)
	
	dialogue_request("Insult me as if you are an evil boss")
	
func dialogue_request(player_dialogue):
	#Adds the user message to the history
	messages.append({
		"role": "user",
		"content" : player_dialogue
			})
			
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY
	]
	#Creates the text/prompt send over with all our info
	var body = JSON.stringify({
		"messages" : messages,
		"temperature" : temperature,
		"max_tokens" : max_tokens,
		"model" : model
	})
	
	#Post means we are sending something over
	var send_request = request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if send_request != OK:
		print("There was an error!")
	
#Reads what was given back, only runs after a request properly done
func _on_request_completed (_result, response_code, _headers, body):
	# Check if the server said "OK" (200)
	if response_code != 200:
		print("Error: API returned code ", response_code)
		return
	
	var json_string = body.get_string_from_utf8()
	var response = JSON.parse_string(json_string)
	
	if response == null:
		print("Error pasrong JSON response")
		return
		
	#response is an array, we only want to get the message from that array
	if response.has("choices") and response["choices"].size > 0:
		var message = response["choices"][0]["message"]["content"]
		print("AI: " + message)
	

## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
