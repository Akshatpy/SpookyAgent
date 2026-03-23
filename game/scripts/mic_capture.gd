extends Node

var capture_effect: AudioEffectCapture
var send_timer := 0.0
const SEND_INTERVAL := 0.25
const MIN_RMS_ENERGY := 0.010
const MIN_PEAK_ENERGY := 0.030
var network: Node
var mic_player: AudioStreamPlayer
var mic_started := false
var accumulated := PackedFloat32Array()  # ← our own buffer

func _ready():
	network = get_node("/root/Network")
	network.connected.connect(_on_network_connected)

	var mic_bus_idx = AudioServer.get_bus_index("Mic")
	if mic_bus_idx == -1:
		print("WARNING: No 'Mic' bus found")
		return

	AudioServer.set_bus_mute(mic_bus_idx, true)

	capture_effect = AudioServer.get_bus_effect(mic_bus_idx, 0)
	if capture_effect == null:
		print("WARNING: No AudioEffectCapture at slot 0")
		return

	var mic_input = AudioStreamMicrophone.new()
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = mic_input
	mic_player.bus = "Mic"
	mic_player.volume_db = 0.0
	add_child(mic_player)
	mic_player.play()

	await get_tree().create_timer(1.0).timeout
	mic_started = true
	send_timer = 0.0

func _on_network_connected():
	var mix_rate := int(AudioServer.get_mix_rate())
	network.send({"type": "audio_config", "sample_rate": mix_rate})

func _process(delta):
	if capture_effect == null or not mic_started:
		return

	# Drain whatever Godot's audio thread left and append to OUR buffer
	var available := capture_effect.get_frames_available()
	if available > 0:
		var frames = capture_effect.get_buffer(available)
		for i in range(frames.size()):
			var f = frames[i]
			if typeof(f) == TYPE_VECTOR2:
				accumulated.append((f.x + f.y) * 0.5)
			else:
				accumulated.append(float(f))

	send_timer += delta
	if send_timer >= SEND_INTERVAL:
		send_timer = 0.0
		_flush_audio()

func _flush_audio():
	var mix_rate := int(AudioServer.get_mix_rate())
	var min_frames := int(mix_rate * 0.25)

	if accumulated.size() < min_frames:
		return

	# Take everything accumulated so far
	var to_send := accumulated.duplicate()
	accumulated.clear()

	# Basic VAD gate: skip near-silence to reduce STT hallucinations like "Thank you".
	var energy := _measure_energy(to_send)
	if energy["rms"] < MIN_RMS_ENERGY and energy["peak"] < MIN_PEAK_ENERGY:
		return

	var bytes := to_send.to_byte_array()
	network.send_audio(bytes)

func _measure_energy(samples: PackedFloat32Array) -> Dictionary:
	if samples.is_empty():
		return {"rms": 0.0, "peak": 0.0}

	var sum_sq := 0.0
	var peak := 0.0
	for s in samples:
		var v := absf(s)
		sum_sq += v * v
		if v > peak:
			peak = v

	var rms := sqrt(sum_sq / float(samples.size()))
	return {"rms": rms, "peak": peak}
