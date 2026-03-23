extends CharacterBody3D

var target_position: Vector3 = Vector3.ZERO
var speed := 4.2
var current_action := "idle"
var hover_height := 1.8
var spawn_offset_applied := false

var local_player: Node = null

@onready var haunt_area: Area3D = $HauntRadius
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var ghost_face = $MeshInstance3D

func _ready() -> void:
	var network: Node = get_node("/root/Network")
	network.message_received.connect(_on_message)

	for n in get_tree().get_nodes_in_group("players"):
		if "is_local_player" in n and n.is_local_player:
			local_player = n
			break

	if haunt_area:
		haunt_area.body_entered.connect(_on_body_entered)

	# Spawn the ghost a bit above the ground for a floating feel.
	if not spawn_offset_applied:
		global_position.y += 1.2
		spawn_offset_applied = true

func _physics_process(delta: float) -> void:
	if target_position != Vector3.ZERO:
		var chase_target := target_position + Vector3(0, hover_height, 0)
		var dist := global_position.distance_to(chase_target)
		if dist > 0.5:
			var direction := (chase_target - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO

	# Optional visual flicker (scale instead of alpha)
	if mesh:
		var target_scale := 0.9 if current_action == "idle" else 1.0
		mesh.scale = mesh.scale.lerp(Vector3.ONE * target_scale, delta * 2.0)
		var pulse := sin(Time.get_ticks_msec() * 0.01) * 0.08
		mesh.position.y = pulse

func _on_message(data: Dictionary) -> void:
	match data.get("type"):
		"ghost_update":
			var ghost_data: Dictionary = data.get("ghost", {})
			current_action = ghost_data.get("action", "idle")

			if current_action == "move_to" and local_player:
				target_position = local_player.global_position
			elif current_action == "idle":
				target_position = Vector3.ZERO

		"ghost_voice":
			print("GHOST SAYS:", data.get("phrase", ""))
			# Trigger scare animation when ghost speaks
			if ghost_face and ghost_face.has_method("scare_animation"):
				ghost_face.scare_animation()

		"ghost_event":
			print("GHOST EVENT:", data.get("event", ""))
			# Trigger scare animation for events
			if data.get("event") == "near_player" and ghost_face and ghost_face.has_method("scare_animation"):
				ghost_face.scare_animation()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and body.is_local_player:
		print("Ghost is near YOU")
		var network: Node = get_node("/root/Network")
		if network:
			network.send({"type": "ghost_proximity", "player_id": body.player_id})
