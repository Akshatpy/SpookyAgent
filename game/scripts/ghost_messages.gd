extends Control

var message_queue: Array[String] = []
var current_message: String = ""
var message_timer: Timer
var message_label: Label
var panel: Panel

var ghost_phrases = [
	"Leave this place...",
	"They're watching you...",
	"You shouldn't be here...",
	"Turn back now...",
	"I can see you...",
	"Death follows...",
	"The darkness calls...",
	"You're next...",
	"Run while you can...",
	"There's no escape..."
]

func _ready():
	setup_ui()
	message_timer = Timer.new()
	add_child(message_timer)
	message_timer.wait_time = 3.0
	message_timer.timeout.connect(_hide_message)
	
	var network = get_node("/root/Network")
	if network:
		network.message_received.connect(_on_network_message)

func setup_ui():
	panel = Panel.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.modulate = Color.TRANSPARENT
	
	message_label = Label.new()
	panel.add_child(message_label)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.add_theme_color_override("font_color", Color.RED)
	message_label.modulate = Color.TRANSPARENT
	
	panel.visible = false

func show_ghost_message(message: String):
	message_queue.append(message)
	if not message_timer.is_stopped():
		return
	_display_next_message()

func show_random_ghost_message():
	var random_phrase = ghost_phrases[randi() % ghost_phrases.size()]
	show_ghost_message(random_phrase)

func _display_next_message():
	if message_queue.is_empty():
		return
	
	current_message = message_queue.pop_front()
	message_label.text = current_message
	panel.visible = true
	
	var tween = create_tween()
	tween.parallel().tween_property(panel, "modulate", Color(0, 0, 0, 0.8), 0.5)
	tween.parallel().tween_property(message_label, "modulate", Color.WHITE, 0.5)
	
	message_timer.start()

func _hide_message():
	var tween = create_tween()
	tween.parallel().tween_property(panel, "modulate", Color.TRANSPARENT, 0.5)
	tween.parallel().tween_property(message_label, "modulate", Color.TRANSPARENT, 0.5)
	
	await tween.finished
	panel.visible = false
	message_timer.stop()
	
	if not message_queue.is_empty():
		_display_next_message()

func _on_network_message(data: Dictionary):
	match data.get("type"):
		"ghost_voice":
			var phrase = data.get("phrase", "")
			if phrase != "":
				show_ghost_message(phrase)
		"ghost_event":
			var event = data.get("event", "")
			if event == "near_player":
				show_random_ghost_message()
