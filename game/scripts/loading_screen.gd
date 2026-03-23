extends Control

var progress_bar: ProgressBar
var status_label: Label

var loading_progress = 0.0
var server_connected = false
var connection_timeout = 10.0
var connection_timer: Timer
var is_transitioning := false

var loading_steps = [
	"Connecting to network...",
	"Loading assets...",
	"Initializing game world...",
	"Spawning entities...",
	"Ready!"
]

func _ready():
	print("LoadingScreen _ready() called")
	
	# Find UI elements with error handling
	progress_bar = $VBoxContainer/ProgressBar
	status_label = $VBoxContainer/StatusLabel
	
	if not progress_bar:
		print("ERROR: ProgressBar not found!")
		return
	if not status_label:
		print("ERROR: StatusLabel not found!")
		return
	
	print("LoadingScreen UI elements found")
	start_loading()

func start_loading():
	print("Starting loading sequence")
	loading_progress = 0.0
	progress_bar.value = 0
	status_label.text = "Initializing..."
	
	# Start connection timer
	connection_timer = Timer.new()
	add_child(connection_timer)
	connection_timer.wait_time = connection_timeout
	connection_timer.timeout.connect(_on_connection_timeout)
	connection_timer.start()
	
	# Connect to network
	var network = get_node("/root/Network")
	if network:
		print("Connecting to WebSocket...")
		network.connected.connect(_on_server_connected)
		network.message_received.connect(_on_network_message)
		
		# Start connection
		var player_id = str(randi() % 99999).pad_zeros(5)
		network.connect_to_server(player_id)
		
		print("Waiting for WebSocket connection...")
	else:
		print("ERROR: Could not find Network node!")
		_force_continue()
	
	# Start initial loading animation
	_update_loading()

func _on_server_connected():
	print("WebSocket connected!")
	server_connected = true
	if connection_timer:
		connection_timer.stop()
	
	# Continue with remaining loading steps
	_continue_loading()

func _on_connection_timeout():
	print("WebSocket connection timeout - proceeding anyway")
	server_connected = true # Force continue
	_continue_loading()

func _continue_loading():
	loading_progress = 0.4 # Skip to 40% after connection
	status_label.text = "Waiting for game to start..."
	
	# Wait for game_started message before continuing
	var network = get_node("/root/Network")
	if network:
		# Listen for game_started message
		if not network.message_received.is_connected(_on_game_started):
			network.message_received.connect(_on_game_started)
	
	# Start a timer to check for game start
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = 1.0
	check_timer.timeout.connect(_check_game_started)
	check_timer.start()

func _on_game_started(data: Dictionary):
	if data.get("type") == "game_started":
		print("Game started! Continuing loading...")
		# Disconnect this one-time listener
		var network = get_node("/root/Network")
		if network and network.message_received.is_connected(_on_game_started):
			network.message_received.disconnect(_on_game_started)
		
		# Continue with remaining loading steps
		_finish_loading()

func _check_game_started():
	# Check if we've received game_started, if not, continue waiting
	var network = get_node("/root/Network")
	if network:
		# Send a start game request if we haven't received it
		network.send({"type": "request_game_start"})

func _finish_loading():
	loading_progress = 0.6 # Skip to 60% after game start
	status_label.text = "Finalizing..."
	
	# Quick final loading steps
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.3  # Much faster
	timer.timeout.connect(_update_loading)
	timer.start()

func _update_loading():
	if is_transitioning:
		return

	print("Updating loading progress: ", loading_progress)
	loading_progress += 0.4 # 40% per step
	loading_progress = min(loading_progress, 1.0)
	
	if progress_bar:
		progress_bar.value = loading_progress * 100
	
	# Update status based on progress
	if loading_progress >= 1.0 and status_label:
		is_transitioning = true
		status_label.text = "Complete!"
		
		# Final step - load scene directly
		await get_tree().create_timer(0.5).timeout
		
		var tree = get_tree()
		if not tree:
			tree = Engine.get_main_loop() as SceneTree
		
		if tree:
			print("Changing to Main3D scene...")
			var result = tree.change_scene_to_file("res://scenes/Main3D.tscn")
			print("Main3D scene change result: ", result)
			if result != OK:
				# Allow one more attempt path if scene load failed.
				is_transitioning = false
			return # Stop the loop
	else:
		# Continue loading if not complete
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = 0.3
		timer.timeout.connect(_update_loading)
		timer.start()

func _on_network_message(data: Dictionary):
	if data.get("type") == "game_started":
		_on_game_started(data)

func _force_continue():
	print("Forcing loading to continue")
	server_connected = true
	if connection_timer:
		connection_timer.stop()
	_continue_loading()
