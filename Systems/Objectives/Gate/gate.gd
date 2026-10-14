class_name Gate
extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_opening: bool = false
var is_closing: bool = false

var is_open: bool = false

var active_pressure_pads: Dictionary = {}

@export_category("Gate Audio")
@export var movement_sound: AudioStream = preload("res://Audio/iron_door.ogg")
@export_range(-40.0, 6.0, 0.5) var sound_volume_db: float = -10.0
var _gate_audio: AudioStreamPlayer3D
var _desired_open: bool = false
var _transition_running: bool = false
var _exiting: bool = false


func _ready() -> void:
	_gate_audio = AudioStreamPlayer3D.new()
	_gate_audio.name = "GateSFX"
	_gate_audio.bus = &"SFX"
	_gate_audio.unit_size = 6.0
	_gate_audio.max_distance = 30.0
	add_child(_gate_audio)
	_gate_audio.position = Vector3(0.0, 1.0, 0.0)


func open_gate() -> void:
	_desired_open = true
	_update_gate()


func close_gate() -> void:
	_desired_open = false
	_update_gate()


func _update_gate() -> void:
	if _transition_running or _exiting or not is_inside_tree():
		return
	_transition_running = true
	# One animation/sound per transition, even when occupants change quickly.
	while is_open != _desired_open:
		var opening: bool = _desired_open
		is_opening = opening
		is_closing = not opening
		if opening:
			animation_player.play("open")
		else:
			animation_player.play_backwards("open")
		is_open = opening
		if is_instance_valid(_gate_audio) and movement_sound != null:
			_gate_audio.stream = movement_sound
			_gate_audio.volume_db = sound_volume_db
			_gate_audio.pitch_scale = 1.0 if opening else 0.94
			_gate_audio.play()
		await animation_player.animation_finished
		is_opening = false
		is_closing = false
	_transition_running = false


func _exit_tree() -> void:
	_exiting = true


func set_pressure_pad_active(pad: Node, active: bool) -> void:
	var was_open := not active_pressure_pads.is_empty()

	if active:
		active_pressure_pads[pad] = true
	else:
		active_pressure_pads.erase(pad)

	var should_open := not active_pressure_pads.is_empty()

	if should_open == was_open:
		return

	if should_open:
		open_gate()
	else:
		close_gate()
