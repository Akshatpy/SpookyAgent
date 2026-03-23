extends Control

var transcript_text: RichTextLabel
var llm_text: RichTextLabel
var ghost_message_panel: Panel
var ghost_message_label: Label
var pause_menu: Control
var resume_button: Button
var main_menu_button: Button
var quit_button: Button
var fuse_counter_label: Label
var transcript_history: Array[String] = []
var llm_history: Array[String] = []
var max_lines = 10
var is_paused = false
var local_player_id := ""
var scare_overlay: ColorRect

var ghost_phrases = [
	"I can hear your heartbeat.",
	"Do not look behind you.",
	"Your breath belongs to me.",
	"Something is crawling in the dark.",
	"I am inside these walls.",
	"Every step you take wakes me.",
	"You are not alone in your skin.",
	"I remember how you scream.",
	"Your name tastes like fear.",
	"When the lights die, I rise."
]

func _ready():
	print("GameUI _ready() called")
	
	# Find UI elements
	transcript_text = $TranscriptPanel/VBoxContainer/TranscriptText
	llm_text = $LLMPanel/VBoxContainer/LLMText
	ghost_message_panel = $GhostMessagePanel
	ghost_message_label = $GhostMessagePanel/GhostMessageLabel
	pause_menu = $PauseMenu
	resume_button = $PauseMenu/VBoxContainer/ResumeButton
	main_menu_button = $PauseMenu/VBoxContainer/MainMenuButton
	quit_button = $PauseMenu/VBoxContainer/QuitButton
	fuse_counter_label = $FuseCounter
	
	# Debug UI elements
	print("TranscriptText found: ", transcript_text != null)
	print("LLMText found: ", llm_text != null)
	print("GhostMessagePanel found: ", ghost_message_panel != null)
	print("PauseMenu found: ", pause_menu != null)
	print("ResumeButton found: ", resume_button != null)
	print("MainMenuButton found: ", main_menu_button != null)
	print("QuitButton found: ", quit_button != null)
	
	if not transcript_text:
		print("ERROR: TranscriptText not found!")
	if not llm_text:
		print("ERROR: LLMText not found!")
	if not ghost_message_panel:
		print("ERROR: GhostMessagePanel not found!")
	if not pause_menu:
		print("ERROR: PauseMenu not found!")

	# Disable center ghost message panel per UX request.
	if ghost_message_panel:
		ghost_message_panel.visible = false
		ghost_message_panel.modulate = Color.TRANSPARENT

	_setup_scare_overlay()
	
	# Connect pause menu buttons
	if resume_button:
		print("Connecting Resume button")
		resume_button.pressed.connect(_on_resume_pressed)
	else:
		print("ERROR: Resume button not found!")
		
	if main_menu_button:
		print("Connecting Main Menu button")
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	else:
		print("ERROR: Main Menu button not found!")
		
	if quit_button:
		print("Connecting Quit button")
		quit_button.pressed.connect(_on_quit_pressed)
	else:
		print("ERROR: Quit button not found!")
	
	# Connect to network messages
	var network = get_node("/root/Network")
	if network:
		network.message_received.connect(_on_network_message)
		local_player_id = network.player_id
		print("GameUI connected to network messages")
	else:
		print("ERROR: Could not find Network node!")
	
	# Connect to fuse collector signals
	var fuse_collector = get_node("../Fuses")
	if fuse_collector:
		fuse_collector.fuse_collected.connect(_on_fuse_collected)
		fuse_collector.all_fuses_collected.connect(_on_all_fuses_collected)

func _input(event):
	if event.is_action_pressed("ui_cancel"): # ESC key
		print("ESC pressed, is_paused: ", is_paused)
		toggle_pause()

func toggle_pause():
	print("toggle_pause called, is_paused: ", is_paused)
	if is_paused:
		resume_game()
	else:
		pause_game()

func pause_game():
	print("pause_game called")
	is_paused = true
	# Don't pause the entire tree, just set game state
	# get_tree().paused = true  # This freezes UI too
	
	if pause_menu:
		pause_menu.visible = true
		var tween = create_tween()
		tween.tween_property(pause_menu, "modulate", Color.WHITE, 0.3)
	else:
		print("ERROR: pause_menu is null!")
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Disable player input instead
	set_process_input(false)

func resume_game():
	print("resume_game called")
	is_paused = false
	# get_tree().paused = false  # This was freezing UI
	
	if pause_menu:
		var tween = create_tween()
		tween.tween_property(pause_menu, "modulate", Color.TRANSPARENT, 0.3)
		
		await tween.finished
		pause_menu.visible = false
	else:
		print("ERROR: pause_menu is null!")
	
	# Release mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Re-enable player input
	set_process_input(true)

func _on_resume_pressed():
	print("Resume button pressed!")
	resume_game()

func _on_main_menu_pressed():
	print("Main Menu button pressed!")
	# get_tree().paused = false  # Remove this
	var tree = get_tree()
	if not tree:
		tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit_pressed():
	print("Quit button pressed!")
	get_tree().quit()

func _on_fuse_collected(fuse_id: String):
	print("UI: Fuse collected: ", fuse_id)
	update_fuse_counter()

func _on_all_fuses_collected():
	print("UI: All fuses collected!")
	show_win_screen()

func update_fuse_counter():
	if fuse_counter_label:
		var fuse_collector = get_node("../Fuses")
		if fuse_collector:
			var collected = fuse_collector.fuses_collected
			var total = fuse_collector.total_fuses
			fuse_counter_label.text = "Fuses: %d/%d" % [collected, total]

func show_win_screen():
	# Show a big win message
	var win_panel = Panel.new()
	add_child(win_panel)
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_panel.modulate = Color(0, 0.2, 0, 0.9)
	
	var win_label = Label.new()
	win_panel.add_child(win_label)
	win_label.text = "🎉 YOU WIN! 🎉\nAll Fuses Collected!"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_label.add_theme_font_size_override("font_size", 48)
	win_label.modulate = Color.YELLOW
	
	# Auto-return to main menu after 5 seconds
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_network_message(data: Dictionary):
	match data.get("type"):
		"speech_transcript":
			var text = data.get("text", "")
			var speaker_id = str(data.get("player_id", ""))
			if local_player_id == "" and speaker_id != "":
				local_player_id = speaker_id
			if text != "" and (local_player_id == "" or speaker_id == local_player_id):
				add_transcript_line("You: " + text)
		"ghost_voice":
			var phrase = data.get("phrase", "")
			if phrase != "":
				add_llm_line("Ghost: " + phrase)
			# Center ghost message popup intentionally disabled.
		"ghost_event":
			var event = data.get("event", "")
			if event == "near_player":
				_play_scare_flicker()
		"llm_response": # This might not be used, but just in case
			var response = data.get("response", "")
			if response != "":
				add_llm_line("AI: " + response)

func add_transcript_line(text: String):
	# Guard against same line arriving twice back-to-back.
	if transcript_history.size() > 0 and transcript_history[-1] == text:
		return
	transcript_history.append(text)
	if transcript_history.size() > max_lines:
		transcript_history.pop_front()
	
	update_transcript_display()

func add_llm_line(text: String):
	if llm_history.size() > 0 and llm_history[-1] == text:
		return
	llm_history.append(text)
	if llm_history.size() > max_lines:
		llm_history.pop_front()
	
	update_llm_display()

func update_transcript_display():
	if not transcript_text:
		return
	
	var content = ""
	for line in transcript_history:
		content += line + "\n"
	
	transcript_text.text = content
	# Auto-scroll to bottom
	await get_tree().process_frame
	transcript_text.scroll_to_line(transcript_history.size() - 1)

func update_llm_display():
	if not llm_text:
		return
	
	var content = ""
	for line in llm_history:
		content += line + "\n"
	
	llm_text.text = content
	# Auto-scroll to bottom
	await get_tree().process_frame
	llm_text.scroll_to_line(llm_history.size() - 1)

func show_ghost_message(message: String):
	if not ghost_message_panel or not ghost_message_label:
		return
	
	ghost_message_label.text = message
	ghost_message_panel.visible = true
	
	var tween = create_tween()
	tween.parallel().tween_property(ghost_message_panel, "modulate", Color(0.2, 0, 0, 0.9), 0.5)
	tween.parallel().tween_property(ghost_message_label, "modulate", Color.RED, 0.5)
	
	await get_tree().create_timer(3.0).timeout
	
	var fade_tween = create_tween()
	fade_tween.parallel().tween_property(ghost_message_panel, "modulate", Color.TRANSPARENT, 0.5)
	fade_tween.parallel().tween_property(ghost_message_label, "modulate", Color.TRANSPARENT, 0.5)
	
	await fade_tween.finished
	ghost_message_panel.visible = false

func show_random_ghost_message():
	var random_phrase = ghost_phrases[randi() % ghost_phrases.size()]
	show_ghost_message(random_phrase)

func _to_scary_phrase(raw_phrase: String) -> String:
	var cleaned := raw_phrase.strip_edges()
	if cleaned == "":
		return ghost_phrases[randi() % ghost_phrases.size()]
	if not cleaned.ends_with("..."):
		cleaned += "..."
	return "[color=#ff4d4d]%s[/color]" % cleaned

func _setup_scare_overlay():
	scare_overlay = ColorRect.new()
	add_child(scare_overlay)
	scare_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scare_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare_overlay.color = Color(0.4, 0.0, 0.0, 0.0)

func _play_scare_flicker():
	if not scare_overlay:
		return
	var t := create_tween()
	t.tween_property(scare_overlay, "color:a", 0.18, 0.05)
	t.tween_property(scare_overlay, "color:a", 0.02, 0.08)
	t.tween_property(scare_overlay, "color:a", 0.12, 0.04)
	t.tween_property(scare_overlay, "color:a", 0.0, 0.12)
