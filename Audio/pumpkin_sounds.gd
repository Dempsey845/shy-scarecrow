extends RefCounted
## Positional one-shots live in the scene so picking up/deleting a pumpkin
## does not cut off its sound. Kenney Impact Sounds, CC0.
const PICKUP := [
	preload("res://Audio/kenney_impact-sounds/Audio/impactSoft_medium_000.ogg"),
	preload("res://Audio/kenney_impact-sounds/Audio/impactSoft_medium_001.ogg"),
	preload("res://Audio/kenney_impact-sounds/Audio/impactSoft_medium_002.ogg"),
]
const PLACE := [
	preload("res://Audio/kenney_impact-sounds/Audio/impactSoft_heavy_000.ogg"),
	preload("res://Audio/kenney_impact-sounds/Audio/impactSoft_heavy_001.ogg"),
	preload("res://Audio/kenney_impact-sounds/Audio/impactSoft_heavy_002.ogg"),
]
const CART := [
	preload("res://Audio/kenney_impact-sounds/Audio/impactWood_light_000.ogg"),
	preload("res://Audio/kenney_impact-sounds/Audio/impactWood_light_001.ogg"),
	preload("res://Audio/kenney_impact-sounds/Audio/impactWood_light_002.ogg"),
]


static func play_at(source: Node3D, action: String) -> void:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return
	var scene: Node = source.get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var choices: Array
	match action:
		"pickup": choices = PICKUP
		"place": choices = PLACE
		"cart": choices = CART
		_: return
	var sound := AudioStreamPlayer3D.new()
	sound.name = "PumpkinSFX"
	sound.bus = &"SFX"
	sound.stream = choices.pick_random()
	sound.volume_db = -13.0 if action == "pickup" else -10.0
	sound.pitch_scale = randf_range(0.95, 1.05)
	sound.unit_size = 4.0
	sound.max_distance = 24.0
	scene.add_child(sound)
	sound.global_position = source.global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
