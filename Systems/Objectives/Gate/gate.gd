class_name Gate
extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_opening: bool = false
var is_closing: bool = false

var is_open: bool = false

var active_pressure_pads: Dictionary = {}

func open_gate():
	if is_opening:
		return

	if is_closing:
		await animation_player.animation_finished

	animation_player.play("open")

	is_open = true

	is_opening = true

	await animation_player.animation_finished

	is_opening = false

func close_gate():
	if is_closing:
		return

	if is_opening:
		await animation_player.animation_finished

	animation_player.play_backwards("open")

	is_open = false

	is_closing = true

	await animation_player.animation_finished

	is_closing = false

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