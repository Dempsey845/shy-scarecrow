class_name DitchBridge
extends AnimatableBody3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_up: bool = true

func draw_up():
	animation_player.play("draw_up")
	is_up = true

func draw_down():
	animation_player.play("draw_down")
	is_up = false
