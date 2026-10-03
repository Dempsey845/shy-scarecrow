extends Node

@export_category("Movement")
@export var move_speed: float = 7.0
@export var ground_acceleration: float = 35.0
@export var ground_deceleration: float = 30.0
@export var air_acceleration: float = 10.0

@export_category("Jump")
@export var jump_velocity: float = 7.0
@export var gravity: float = 22.0
@export var fall_gravity_multiplier: float = 1.4
@export var jump_cut_multiplier: float = 2.5

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var controller_look_sensitivity: float = 2.5
@export var minimum_pitch: float = -85.0
@export var maximum_pitch: float = 85.0

@onready var camera: Camera3D = %Camera3D
@onready var head: Node3D = %Head
@onready var body: CharacterBody3D = get_parent()

var camera_pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_rotate_camera(
			event.relative.x * mouse_sensitivity,
			event.relative.y * mouse_sensitivity
			)
	if event.is_action_pressed("pause"):
		_toggle_mouse_capture()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	_apply_controller_look(delta)
	_handle_jump()
	_handle_movement(delta)

	body.move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var local_direction: Vector3 = Vector3(
		input_direction.x,
		0.0,
		input_direction.y
	)

	var move_direction: Vector3 = (
		body.global_basis * local_direction
	).normalized()

	var target_velocity: Vector3 = move_direction * move_speed

	var acceleration: float

	if not body.is_on_floor():
		acceleration = air_acceleration
	elif move_direction.length_squared() > 0.0:
		acceleration = ground_acceleration
	else:
		acceleration = ground_deceleration

	body.velocity.x = move_toward(
		body.velocity.x,
		target_velocity.x,
		acceleration * delta
	)

	body.velocity.z = move_toward(
		body.velocity.z,
		target_velocity.z,
		acceleration * delta
	)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and body.is_on_floor():
		body.velocity.y = jump_velocity

	if (
		Input.is_action_just_released("jump")
		and body.velocity.y > 0.0
	):
		body.velocity.y /= jump_cut_multiplier


func _apply_gravity(delta: float) -> void:
	if body.is_on_floor():
		if body.velocity.y < 0.0:
			body.velocity.y = -0.5

		return

	var current_gravity: float = gravity

	if body.velocity.y < 0.0:
		current_gravity *= fall_gravity_multiplier

	body.velocity.y -= current_gravity * delta


func _apply_controller_look(delta: float) -> void:
	var look_input: Vector2 = Input.get_vector(
		"look_left",
		"look_right",
		"look_up",
		"look_down"
	)

	if look_input.length_squared() <= 0.0:
		return

	_rotate_camera(
		look_input.x * controller_look_sensitivity * delta,
		look_input.y * controller_look_sensitivity * delta
	)


func _rotate_camera(
	yaw_amount: float,
	pitch_amount: float
) -> void:
	body.rotate_y(-yaw_amount)

	camera_pitch -= pitch_amount
	camera_pitch = clamp(
		camera_pitch,
		deg_to_rad(minimum_pitch),
		deg_to_rad(maximum_pitch)
	)

	head.rotation.x = camera_pitch

func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED