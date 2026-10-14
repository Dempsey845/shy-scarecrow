extends StaticBody3D

@export var gate: Gate
@export var exit_time: float = 0.2
@export var plate: Node3D

@export var press_depth: float = 0.1
@export var press_duration: float = 0.25
@export var release_duration: float = 0.35

@export_category("Pressure Pad Audio")
@export var press_sound: AudioStream = preload("res://Audio/10 Clicks and Switches/click.2.ogg")
@export var release_sound: AudioStream = preload("res://Audio/10 Clicks and Switches/click.3.ogg")
@export_range(-40.0, 6.0, 0.5) var sound_volume_db: float = -14.0
var _pad_audio: AudioStreamPlayer3D

@onready var pressure_detection_area: Area3D = $PressureDetectionArea

var gate_active: bool = false
var empty_timer: float = 0.0

var plate_rest_y: float
var plate_tween: Tween


func _ready() -> void:
	_pad_audio = AudioStreamPlayer3D.new()
	_pad_audio.name = "PressurePadSFX"
	_pad_audio.bus = &"SFX"
	_pad_audio.unit_size = 4.0
	_pad_audio.max_distance = 22.0
	plate.add_child(_pad_audio)
	plate_rest_y = plate.position.y

	pressure_detection_area.body_entered.connect(
		_on_pressure_area_body_entered
	)


func _physics_process(delta: float) -> void:
	if not gate_active:
		return

	for body in pressure_detection_area.get_overlapping_bodies():
		if body is Player or body is Scarecrow:
			empty_timer = 0.0
			return

	empty_timer += delta

	if empty_timer >= exit_time:
		gate_active = false
		empty_timer = 0.0
		gate.set_pressure_pad_active(self, false)
		_animate_plate(false)


func _on_pressure_area_body_entered(body: Node3D) -> void:
	if body is not Player and body is not Scarecrow:
		return

	empty_timer = 0.0

	if not gate_active:
		gate_active = true
		gate.set_pressure_pad_active(self, true)
		_animate_plate(true)


func _exit_tree() -> void:
	if is_instance_valid(gate):
		gate.set_pressure_pad_active(self, false)


func _animate_plate(pressed: bool) -> void:
	# Called only when occupancy changes, not for every body entering the pad.
	_pad_audio.stream = press_sound if pressed else release_sound
	_pad_audio.volume_db = sound_volume_db
	if _pad_audio.stream != null:
		_pad_audio.play()
	if plate_tween != null and plate_tween.is_valid():
		plate_tween.kill()

	var target_y := plate_rest_y
	var duration := release_duration

	if pressed:
		target_y -= press_depth
		duration = press_duration

	plate_tween = create_tween()
	plate_tween.set_trans(Tween.TRANS_BACK)
	plate_tween.set_ease(Tween.EASE_OUT)
	plate_tween.tween_property(
		plate,
		"position:y",
		target_y,
		duration
	)