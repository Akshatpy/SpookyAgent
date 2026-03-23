extends Area2D

var claimed := false

@onready var network = get_node("/root/Network")

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if claimed:
		return
	if body.is_in_group("players"):
		claimed = true
		# MVP: server just counts fuse_found messages to reach 4.
		network.send({"type": "fuse_found"})

