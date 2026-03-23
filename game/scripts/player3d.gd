extends CharacterBody3D

@export var is_local_player := true
var speed := 5.0
var player_id := ""

@onready var network = get_node("/root/Network")
@onready var camera = $Camera3D

var mouse_sensitivity := 0.002

func _ready():
	add_to_group("players")

	if is_local_player:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if camera:
			camera.current = true
		network.message_received.connect(_on_message)

func _input(event):
	if not is_local_player:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)

func _physics_process(_delta):
	if not is_local_player:
		return

	var direction = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x

	velocity = direction.normalized() * speed
	move_and_slide()

	network.send({
		"type": "position_update",
		"position": {
			"x": global_position.x,
			"y": global_position.z
		}
	})

func _on_message(data: Dictionary):
	match data.get("type"):
		"player_eliminated":
			if data.get("player_id") == player_id:
				print("YOU WERE ELIMINATED")

		"game_over":
			print("GAME OVER — winner:", data.get("winner"))
