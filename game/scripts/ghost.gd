extends CharacterBody2D

## Ghost — driven by server broadcasts.
## MVP: chase the local player when the server targets that player's id.

var target_position: Vector2 = Vector2.ZERO
var speed := 60.0
var current_action := "idle"

var local_player: Node = null

@onready var haunt_area: Area2D = $HauntRadius
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var network: Node = get_node("/root/Network")
	network.message_received.connect(_on_message)

	# Cache the local player so we can chase it when targeted.
	for n in get_tree().get_nodes_in_group("players"):
		if "is_local_player" in n and n.is_local_player:
			local_player = n
			break

	# Optional haunt warning.
	if haunt_area:
		haunt_area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Simple movement toward the current target position.
	if target_position != Vector2.ZERO:
		var dist := global_position.distance_to(target_position)
		if dist > 2.0:
			var direction := (target_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO

	# Flicker sprite alpha as a tiny "idle" cue.
	if sprite:
		var target_alpha := 0.7 if current_action == "idle" else 1.0
		sprite.modulate.a = lerp(sprite.modulate.a, target_alpha, delta * 2.0)

func _on_message(data: Dictionary) -> void:
	match data.get("type"):
		"ghost_update":
			var ghost_data: Dictionary = data.get("ghost", {})
			current_action = ghost_data.get("action", "idle")

			# FREE/dev-mode MVP: when server says "move_to", chase the local player.
			if current_action == "move_to" and local_player:
				target_position = local_player.global_position
			elif current_action == "idle":
				target_position = Vector2.ZERO

		"ghost_event":
			var event_name: String = str(data.get("event", ""))
			print("GHOST EVENT:", event_name)
		"ghost_voice":
			var phrase := str(data.get("phrase", ""))
			print("GHOST SAYS:", phrase)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players") and "is_local_player" in body and body.is_local_player:
		print("Ghost is near YOU")
