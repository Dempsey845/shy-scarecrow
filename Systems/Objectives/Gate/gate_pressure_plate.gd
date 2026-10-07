extends StaticBody3D

@export var gate: Gate
@export var exit_time: float = 0.2

@onready var pressure_detection_area: Area3D = $PressureDetectionArea

var gate_active: bool = false
var empty_timer: float = 0.0


func _ready() -> void:
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
		gate.close_gate()


func _on_pressure_area_body_entered(body: Node3D) -> void:
	if body is not Player and body is not Scarecrow:
		return

	empty_timer = 0.0

	if not gate_active:
		gate_active = true
		gate.open_gate()