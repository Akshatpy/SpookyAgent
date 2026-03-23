extends MeshInstance3D

var eyes: Array[MeshInstance3D] = []
var mouth: MeshInstance3D
var base_material: StandardMaterial3D
var eye_material: StandardMaterial3D
var mouth_material: StandardMaterial3D

func _ready():
	setup_ghost_face()

func setup_ghost_face():
	# Create materials
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.9, 0.9, 1.0, 0.8) # Ghostly white
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	base_material.emission_enabled = true
	base_material.emission = Color(0.35, 0.05, 0.08, 1)
	base_material.emission_energy_multiplier = 2.4
	
	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.15, 0.0, 0.0, 1) # Dark red eyes
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.0, 0.0, 1) # Glowing blood red
	eye_material.emission_energy_multiplier = 5.0
	
	mouth_material = StandardMaterial3D.new()
	mouth_material.albedo_color = Color(0.1, 0.0, 0.0, 1) # Black mouth
	mouth_material.emission_enabled = true
	mouth_material.emission = Color(0.7, 0.0, 0.0, 1) # Strong red glow
	mouth_material.emission_energy_multiplier = 3.5
	
	# Apply base material
	material_override = base_material
	
	# Create eyes
	create_eyes()
	
	# Create mouth
	create_mouth()

func create_eyes():
	# Left eye
	var left_eye = MeshInstance3D.new()
	var left_eye_sphere = SphereMesh.new()
	left_eye_sphere.radius = 0.15
	left_eye_sphere.radial_segments = 8
	left_eye.mesh = left_eye_sphere
	left_eye.material_override = eye_material
	left_eye.position = Vector3(-0.3, 0.2, 0.4)
	add_child(left_eye)
	eyes.append(left_eye)
	
	# Right eye
	var right_eye = MeshInstance3D.new()
	var right_eye_sphere = SphereMesh.new()
	right_eye_sphere.radius = 0.15
	right_eye_sphere.radial_segments = 8
	right_eye.mesh = right_eye_sphere
	right_eye.material_override = eye_material
	right_eye.position = Vector3(0.3, 0.2, 0.4)
	add_child(right_eye)
	eyes.append(right_eye)

func create_mouth():
	mouth = MeshInstance3D.new()
	var mouth_box = BoxMesh.new()
	mouth_box.size = Vector3(0.8, 0.1, 0.1)
	mouth.mesh = mouth_box
	mouth.material_override = mouth_material
	mouth.position = Vector3(0, -0.2, 0.4)
	add_child(mouth)

func scare_animation():
	# Make eyes glow brighter and pulse
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Eyes glow
	tween.tween_property(eye_material, "emission_energy_multiplier", 12.0, 0.2)
	tween.tween_property(eye_material, "albedo_color", Color(1.0, 0.1, 0.1, 1), 0.2)
	
	# Mouth opens
	if mouth:
		tween.tween_property(mouth, "scale", Vector3(1, 4, 1.3), 0.18)
	
	await tween.finished
	
	# Return to normal
	var return_tween = create_tween()
	return_tween.set_parallel(true)
	return_tween.tween_property(eye_material, "emission_energy_multiplier", 5.0, 0.4)
	return_tween.tween_property(eye_material, "albedo_color", Color(0.15, 0.0, 0.0, 1), 0.4)
	
	if mouth:
		return_tween.tween_property(mouth, "scale", Vector3.ONE, 0.3)
