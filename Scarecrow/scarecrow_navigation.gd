extends Node

enum State {
	IDLE,
	FOLLOWING,
}

@export_category("Movement")
@export var move_speed: float = 5.0
@export var acceleration: float = 18.0
@export var rotation_speed: float = 8.0
@export var gravity: float = 22.0
@export var follow_distance: float = 6.0

@export_category("Navigation")
@export var navigation_update_interval: float = 0.2
@export var navigation_target_threshold: float = 0.75

@onready var follow_distance_sq: float = follow_distance * follow_distance

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D

@onready var scarecrow: Scarecrow = get_parent()

var current_state: State = State.FOLLOWING

var navigation_update_timer: float = 0.0
var last_navigation_target: Vector3
var has_navigation_target: bool = false

func _ready() -> void:
	scarecrow.screen_entered.connect(stop_following)
	scarecrow.screen_exited.connect(start_following)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.FOLLOWING:
			_process_following(delta)

	scarecrow.move_and_slide()

func _process_idle(delta: float):
	pass

func _process_following(delta):
	if !is_instance_valid(scarecrow.player):
		return
	
	var distance_to_player_sq: float = scarecrow.global_position.distance_squared_to(scarecrow.player.global_position)

	if distance_to_player_sq > follow_distance:
		_move_towards_position(scarecrow.player.global_position, delta)
	else:
		_slow_down(delta)

func _move_towards_position(target_position: Vector3, delta: float) -> void:
	var direction: Vector3

	if is_instance_valid(navigation_agent):
		_update_navigation_target(
			target_position
		)

		if navigation_agent.is_navigation_finished():
			_slow_down(delta)
			return

		var next_position := (
			navigation_agent.get_next_path_position()
		)

		direction = (
			next_position - scarecrow.global_position
		)

		direction.y = 0.0

		if direction.length_squared() <= 0.04:
			_slow_down(delta)
			return
	else:
		direction = (
			target_position - scarecrow.global_position
		)

		direction.y = 0.0

	if direction.length_squared() <= 0.001:
		_slow_down(delta)
		return

	direction = direction.normalized()

	var target_velocity: Vector3 = direction * move_speed

	scarecrow.velocity.x = move_toward(
		scarecrow.velocity.x,
		target_velocity.x,
		acceleration * delta
	)

	scarecrow.velocity.z = move_toward(
		scarecrow.velocity.z,
		target_velocity.z,
		acceleration * delta
	)

	_rotate_towards_position(
		scarecrow.global_position + direction,
		delta
	)

func _update_navigation_target(target_position: Vector3) -> void:
	var target_moved_enough: bool = (
		not has_navigation_target
		or last_navigation_target.distance_squared_to(
			target_position
		) > navigation_target_threshold * navigation_target_threshold
	)

	if (
		not target_moved_enough
		and navigation_update_timer > 0.0
	):
		return

	navigation_agent.target_position = target_position

	last_navigation_target = target_position
	has_navigation_target = true
	navigation_update_timer = navigation_update_interval

func _slow_down(delta: float) -> void:
	scarecrow.velocity.x = move_toward(
		scarecrow.velocity.x,
		0.0,
		acceleration * delta
	)

	scarecrow.velocity.z = move_toward(
		scarecrow.velocity.z,
		0.0,
		acceleration * delta
	)


func _rotate_towards_position(
	target_position: Vector3,
	delta: float
) -> void:
	var direction: Vector3 = target_position - scarecrow.global_position
	direction.y = 0.0

	if direction.length_squared() <= 0.001:
		return

	direction = direction.normalized()

	var target_rotation := atan2(
		-direction.x,
		-direction.z
	)

	scarecrow.rotation.y = lerp_angle(
		scarecrow.rotation.y,
		target_rotation,
		rotation_speed * delta
	)

func stop_following():
	scarecrow.velocity = Vector3.ZERO
	current_state = State.IDLE

func start_following():
	current_state = State.FOLLOWING