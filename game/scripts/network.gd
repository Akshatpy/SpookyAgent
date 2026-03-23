extends Node

signal connected
signal message_received(data: Dictionary)

var socket := WebSocketPeer.new()
var player_id := ""
var server_url := "ws://localhost:8000/ws/"
var was_open := false

func connect_to_server(pid: String):
	player_id = pid
	var err = socket.connect_to_url(server_url + pid)
	if err != OK:
		print("Connection failed: ", err)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not was_open:
			was_open = true
			connected.emit()
		while socket.get_available_packet_count():
			var pkt = socket.get_packet()
			var json = JSON.new()
			json.parse(pkt.get_string_from_utf8())
			message_received.emit(json.get_data())

	elif state == WebSocketPeer.STATE_CLOSED:
		was_open = false
		print("Disconnected from server")

func send(data: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func send_audio(audio_bytes: PackedByteArray):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send(audio_bytes)
