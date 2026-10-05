class_name PumpkinVisual
extends Node3D

@onready var pumpkin_mesh: MeshInstance3D = $MeshInstance3D

var outline_tween: Tween

func show_outline(duration: float = 0.2) -> void:
	_set_outline_strength(1.0, duration)


func hide_outline(duration: float = 0.2) -> void:
	_set_outline_strength(0.0, duration)


func _set_outline_strength(target: float, duration: float) -> void:
	var material := pumpkin_mesh.material_overlay as ShaderMaterial

	if not material:
		return

	if outline_tween:
		outline_tween.kill()

	outline_tween = create_tween()
	outline_tween.set_trans(Tween.TRANS_SINE)
	outline_tween.set_ease(Tween.EASE_IN_OUT)

	outline_tween.tween_method(
		func(value: float):
			pumpkin_mesh.set_instance_shader_parameter("outline_strength", value),
		float(pumpkin_mesh.get_instance_shader_parameter("outline_strength")),
		target,
		duration
	)