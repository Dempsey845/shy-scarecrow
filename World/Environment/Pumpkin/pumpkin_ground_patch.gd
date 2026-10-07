class_name PumpkinGroundPatch
extends StaticBody3D

@export var patch_mesh: MeshInstance3D

@onready var pumpkin_slot: Marker3D = $PumpkinSlot

var current_pumpkin: Pumpkin

var outline_tween: Tween

var has_pumpkin: bool

var is_too_large: bool

func _ready() -> void:
	is_too_large = scale > Vector3.ONE
	
	add_pumpkin()

func add_pumpkin():
	current_pumpkin = PSSR.pumpkin_scene.instantiate()
	current_pumpkin.patch = self
	pumpkin_slot.add_child(current_pumpkin)

	has_pumpkin = true

	current_pumpkin.tree_exited.connect(_on_current_pumpkin_tree_exited)


func show_outline(duration: float = 0.2) -> void:
	_set_outline_strength(1.0, duration)


func hide_outline(duration: float = 0.2) -> void:
	_set_outline_strength(0.0, duration)


func _set_outline_strength(target: float, duration: float) -> void:
	var material := patch_mesh.material_overlay as ShaderMaterial

	if not material:
		return

	if outline_tween:
		outline_tween.kill()

	outline_tween = create_tween()
	outline_tween.set_trans(Tween.TRANS_SINE)
	outline_tween.set_ease(Tween.EASE_IN_OUT)

	outline_tween.tween_method(
		func(value: float):
			patch_mesh.set_instance_shader_parameter("outline_strength", value),
		float(patch_mesh.get_instance_shader_parameter("outline_strength")),
		target,
		duration
	)

func _on_current_pumpkin_tree_exited():
	current_pumpkin = null
	has_pumpkin = false
