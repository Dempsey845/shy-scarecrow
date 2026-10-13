class_name HotChocolateCup
extends Node3D

signal filled

@onready var chocolate: MeshInstance3D = $CupFill
@onready var steam: GPUParticles3D = $HotChocolateSteam/Steam
@onready var cup: MeshInstance3D = $Cup

var outline_tween: Tween

func _ready() -> void:
	chocolate.material_override = chocolate.material_override.duplicate()

func fill_cup() -> void:
	var material := chocolate.material_override as ShaderMaterial

	create_tween().set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	).tween_property(
		material,
		"shader_parameter/fill_amount",
		1.0,
		2.0
	).finished.connect(func(): 
		steam.emitting = true
		filled.emit()
	)
	

func show_outline(duration: float = 0.2) -> void:
	_set_outline_strength(1.0, duration)


func hide_outline(duration: float = 0.2) -> void:
	_set_outline_strength(0.0, duration)


func _set_outline_strength(target: float, duration: float) -> void:
	var material := cup.material_overlay as ShaderMaterial

	if not material:
		return

	if outline_tween:
		outline_tween.kill()

	outline_tween = create_tween()
	outline_tween.set_trans(Tween.TRANS_SINE)
	outline_tween.set_ease(Tween.EASE_IN_OUT)

	outline_tween.tween_method(
		func(value: float):
			cup.set_instance_shader_parameter("outline_strength", value),
		float(cup.get_instance_shader_parameter("outline_strength")),
		target,
		duration
	)