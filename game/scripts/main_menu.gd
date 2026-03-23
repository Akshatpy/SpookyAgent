extends Control

var start_button: Button
var options_button: Button
var quit_button: Button

func _ready():
	print("MainMenu _ready() called")
	
	# Try to find buttons with error handling
	start_button = $VBoxContainer/StartButton
	options_button = $VBoxContainer/OptionsButton
	quit_button = $VBoxContainer/QuitButton
	
	if not start_button:
		print("ERROR: StartButton not found!")
		return
	if not options_button:
		print("ERROR: OptionsButton not found!")
		return
	if not quit_button:
		print("ERROR: QuitButton not found!")
		return
	
	print("Buttons found successfully")
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	print("Signal connections completed")

func _on_start_pressed():
	print("Start button pressed!")
	
	# Use Engine.get_main_loop() as fallback
	var tree = get_tree()
	if not tree:
		tree = Engine.get_main_loop() as SceneTree
	
	if tree:
		print("Changing scene to LoadingScreen...")
		var result = tree.change_scene_to_file("res://scenes/LoadingScreen.tscn")
		print("Scene change result: ", result)
	else:
		print("ERROR: Could not get SceneTree!")

func _on_options_pressed():
	print("Options not implemented yet")

func _on_quit_pressed():
	print("Quit button pressed")
	var tree = get_tree()
	if not tree:
		tree = Engine.get_main_loop() as SceneTree
	
	if tree:
		tree.quit()
	else:
		print("ERROR: Could not get SceneTree to quit!")
