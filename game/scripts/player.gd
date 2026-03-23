extends CharacterBody2D

@export var is_local_player := true
var speed := 120.0
var player_id := ""

@onready var network = get_node("/root/Network")

func _ready():
	# Mark this CharacterBody2D as a player for Area2D triggers (fuses/haunt).
	add_to_group("players")
	if is_local_player:
		if has_node("Camera2D"):
			$Camera2D.make_current()
		network.message_received.connect(_on_message)

func _physics_process(_delta):
	if not is_local_player:
		return

	var input := Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		input.x += 1
	if Input.is_action_pressed("ui_left"):
		input.x -= 1
	if Input.is_action_pressed("ui_down"):
		input.y += 1
	if Input.is_action_pressed("ui_up"):
		input.y -= 1

	velocity = input.normalized() * speed
	move_and_slide()

	# Throttle later if needed; MVP sends every physics frame.
	network.send({
		"type": "position_update",
		"position": {
			"x": global_position.x / 32,
			"y": global_position.y / 32
		}
	})

func _on_message(data: Dictionary):
	match data.get("type"):
		"player_eliminated":
			if data.get("player_id") == player_id:
				print("YOU WERE ELIMINATED")
		"game_over":
			print("GAME OVER — winner: ", data.get("winner"))
