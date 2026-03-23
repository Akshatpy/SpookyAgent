extends Node3D

var fuses_collected := 0
var total_fuses := 4
var fuse_areas: Array[Area3D] = []
var collected_fuses: Array[String] = []

signal fuse_collected(fuse_id: String)
signal all_fuses_collected

func _ready():
	setup_fuses()

func setup_fuses():
	# Get all fuse areas
	for child in get_children():
		if child is Area3D:
			fuse_areas.append(child)
			child.body_entered.connect(_on_fuse_entered)
	
	print("Fuse collector ready with ", fuse_areas.size(), " fuses")

func _on_fuse_entered(body: Node):
	if body.is_in_group("players") and body.is_local_player:
		var fuse_area = get_area_from_body(body)
		if fuse_area and not collected_fuses.has(fuse_area.name):
			collect_fuse(fuse_area)

func get_area_from_body(body: Node) -> Area3D:
	for area in fuse_areas:
		if area.overlaps_body(body):
			return area
	return null

func collect_fuse(fuse_area: Area3D):
	var fuse_id = fuse_area.name
	collected_fuses.append(fuse_id)
	fuses_collected += 1
	
	print("Collected fuse: ", fuse_id, " (", fuses_collected, "/", total_fuses, ")")
	
	# Hide the collected fuse
	fuse_area.visible = false
	fuse_area.set_process(false)
	
	# Play collection effect
	play_collection_effect(fuse_area.global_position)
	
	# Emit signals
	fuse_collected.emit(fuse_id)
	
	if fuses_collected >= total_fuses:
		all_fuses_collected.emit()
		_on_game_won()

func play_collection_effect(pos: Vector3):
	# Create a simple visual effect
	var tween = create_tween()
	
	# You could add particle effects here
	print("Fuse collected at: ", pos)

func _on_game_won():
	print("PLAYER WINS! All fuses collected!")
	
	# Send win message to server
	var network = get_node("/root/Network")
	if network:
		network.send({"type": "player_won", "fuses_collected": fuses_collected})
	
	# Show win message (could be enhanced with UI)
	show_win_message()

func show_win_message():
	# Simple console message for now
	print("🎉 CONGRATULATIONS! You found all fuses and escaped! 🎉")
	
	# You could transition to a win screen here
	# get_tree().change_scene_to_file("res://scenes/WinScreen.tscn")
