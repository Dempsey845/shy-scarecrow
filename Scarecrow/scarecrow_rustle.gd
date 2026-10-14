extends AudioStreamPlayer3D

## CC0 recordings by qubodup.
const RUSTLES := [
	preload("res://Audio/qubodup-rustles-wav/rustle09.wav"),
	preload("res://Audio/qubodup-rustles-wav/rustle10.wav"),
	preload("res://Audio/qubodup-rustles-wav/rustle12.wav"),
	preload("res://Audio/qubodup-rustles-wav/rustle17.wav"),
	preload("res://Audio/qubodup-rustles-wav/rustle18.wav"),
	preload("res://Audio/qubodup-rustles-wav/rustle20.wav"),
]
var _last_clip: int = -1
var _cooldown: float = 0.0


func _ready() -> void:
	name = "MovementRustle"
	bus = &"SFX"
	volume_db = -12.0
	unit_size = 6.0
	max_distance = 28.0
	max_polyphony = 1
	position = Vector3(0.0, 1.0, 0.0)


func update_movement(moving_unseen: bool, delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not moving_unseen:
		stop()
		return
	if playing or _cooldown > 0.0:
		return

	var index: int = randi_range(0, RUSTLES.size() - 2)
	if index >= _last_clip:
		index += 1
	_last_clip = index
	stream = RUSTLES[index]
	pitch_scale = randf_range(0.94, 1.06)
	play()
	_cooldown = float(stream.get_length()) / pitch_scale + randf_range(0.15, 0.35)
