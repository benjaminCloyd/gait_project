extends Node

var API_KEY = ""
var url = "https://api.openai.com/v1/chat/completions"
var temp = 0.5
var MAX_TOKENS = 1024
var headers = ["Conent-type: application/json", "Authorization: Bearer " + API_KEY]
var model = "gpt-5-nano"
var messages = []
var request : HTTPRequest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_complete", _on_request_completed)
	pass # Replace with function body.
	
func dialogue_request(player_dialogue):
	messages.append({
		"role": "user",
		"content" : player_dialogue
			})
	var body = JSON.new().stringify({
		"messages" : messages,
		"temp" : temp,
		"MAX_TOKENS" : MAX_TOKENS,
		"model" : model
	})
	
	var send_request = request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if send_request != OK:
		print("There was an error!")

	pass
	
func _on_request_completed (result, response_code, header, body):
	pass
	

## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
