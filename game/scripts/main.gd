extends Node

## Entry point — handles lobby and game start.

var network: Node
var player_id := ""
var started := false

func _ready():
	network = get_node("/root/Network")
	network.message_received.connect(_on_message)
	network.connected.connect(_on_connected)

	# Generate a unique player ID
	player_id = str(randi() % 99999).pad_zeros(5)
	network.connect_to_server(player_id)

func _on_start_button_pressed():
	network.send({"type": "start_game"})

func _on_connected():
	if started:
		return
	started = true
	network.send({"type": "start_game"})

func _on_message(data: Dictionary):
	match data.get("type"):
		"game_started":
			print("Game started (network-only test).")
		"state_sync":
			print("Synced with server. Players: ", data.get("state", {}).get("players", {}).keys())
		"speech_transcript":
			print("YOU SAID: ", data.get("text", ""))
		_:
			print("Server message: ", data.get("type"), " payload: ", data)

