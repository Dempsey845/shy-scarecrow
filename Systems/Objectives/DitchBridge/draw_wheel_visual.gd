class_name DrawWheelVisual
extends Node3D

@onready var wheel_mesh: MeshInstance3D = $Circle
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var outline_tween: Tween

func try_spin_wheel() -> bool:
	if animation_player.is_playing():
		return false

	animation_player.play("spin_wheel")
	return true

func show_outline(duration: float = 0.2) -> void:
	_set_outline_strength(1.0, duration)


func hide_outline(duration: float = 0.2) -> void:
	_set_outline_strength(0.0, duration)


func _set_outline_strength(target: float, duration: float) -> void:
	var material := wheel_mesh.material_overlay as ShaderMaterial

	if not material:
		return

	if outline_tween:
		outline_tween.kill()

	outline_tween = create_tween()
	outline_tween.set_trans(Tween.TRANS_SINE)
	outline_tween.set_ease(Tween.EASE_IN_OUT)

	outline_tween.tween_method(
		func(value: float):
			wheel_mesh.set_instance_shader_parameter("outline_strength", value),
		float(wheel_mesh.get_instance_shader_parameter("outline_strength")),
		target,
		duration
	)