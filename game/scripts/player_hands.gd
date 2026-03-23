extends Node3D

var left_hand: MeshInstance3D
var right_hand: MeshInstance3D
var left_fingers: Array[MeshInstance3D] = []
var right_fingers: Array[MeshInstance3D] = []
var hand_material: StandardMaterial3D

func _ready():
	setup_hands()

func setup_hands():
	# Create hand material
	hand_material = StandardMaterial3D.new()
	hand_material.albedo_color = Color(0.8, 0.7, 0.6, 1) # Skin color
	hand_material.roughness = 0.8
	hand_material.metallic = 0.0
	hand_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hand_material.emission_enabled = true
	hand_material.emission = Color(0.08, 0.06, 0.05, 1.0)
	hand_material.emission_energy_multiplier = 0.4
	
	# Create left palm
	left_hand = MeshInstance3D.new()
	var left_hand_mesh = CapsuleMesh.new()
	left_hand_mesh.radius = 0.05
	left_hand_mesh.height = 0.2
	left_hand.mesh = left_hand_mesh
	left_hand.material_override = hand_material
	left_hand.position = Vector3(-0.22, -0.28, -0.45)
	left_hand.rotation_degrees.z = 20.0
	left_hand.scale = Vector3(1.4, 1.4, 1.4)
	add_child(left_hand)
	_create_fingers(left_hand, left_fingers, -1)
	
	# Create right palm
	right_hand = MeshInstance3D.new()
	var right_hand_mesh = CapsuleMesh.new()
	right_hand_mesh.radius = 0.05
	right_hand_mesh.height = 0.2
	right_hand.mesh = right_hand_mesh
	right_hand.material_override = hand_material
	right_hand.position = Vector3(0.22, -0.28, -0.45)
	right_hand.rotation_degrees.z = -20.0
	right_hand.scale = Vector3(1.4, 1.4, 1.4)
	add_child(right_hand)
	_create_fingers(right_hand, right_fingers, 1)

func _create_fingers(parent_hand: MeshInstance3D, finger_store: Array[MeshInstance3D], side_sign: int):
	for i in range(4):
		var finger = MeshInstance3D.new()
		var finger_mesh = CapsuleMesh.new()
		finger_mesh.radius = 0.015
		finger_mesh.height = 0.08
		finger.mesh = finger_mesh
		finger.material_override = hand_material
		finger.position = Vector3(side_sign * 0.03 * float(i - 1), -0.06, 0.07)
		finger.rotation_degrees.x = 90.0
		parent_hand.add_child(finger)
		finger_store.append(finger)

func update_hand_animation(movement_speed: float):
	var t: float = Time.get_ticks_msec() / 1000.0
	var walk_amount: float = clamp(movement_speed / 3.0, 0.0, 1.0)
	var sway: float = sin(t * (2.0 + walk_amount * 6.0)) * (0.02 + 0.03 * walk_amount)
	var bob: float = abs(cos(t * (2.5 + walk_amount * 7.0))) * (0.01 + 0.02 * walk_amount)
	
	if left_hand:
		left_hand.rotation.x = sway * 1.3
		left_hand.position.y = -0.4 + bob
		
	if right_hand:
		right_hand.rotation.x = -sway * 1.3
		right_hand.position.y = -0.4 + bob

	for finger in left_fingers:
		finger.rotation_degrees.z = -10.0 - walk_amount * 15.0
	for finger in right_fingers:
		finger.rotation_degrees.z = 10.0 + walk_amount * 15.0
