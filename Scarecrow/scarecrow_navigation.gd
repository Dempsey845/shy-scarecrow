extends Node

enum State {
	FOLLOWING,
	GO_TO_TARGET,
	INTERACT_WITH_TARGET
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

var can_move: bool

var current_target: Node3D
var interacted_with_current_target: bool

func _ready() -> void:
	scarecrow.screen_entered.connect(_on_scarecrow_screen_entered)
	scarecrow.screen_exited.connect(_on_scarecrow_screen_exited)
	scarecrow.task_changed.connect(_on_scarecrow_task_changed)

func _physics_process(delta: float) -> void:
	match current_state:
		State.FOLLOWING:
			_process_following(delta)
		State.GO_TO_TARGET:
			_process_go_to_target(delta)
		State.INTERACT_WITH_TARGET:
			_process_interact_with_target(delta)

	scarecrow.move_and_slide()

func _process_following(delta: float):
	if !is_instance_valid(scarecrow.player):
		return
	
	var distance_to_player_sq: float = scarecrow.global_position.distance_squared_to(scarecrow.player.global_position)

	if distance_to_player_sq > follow_distance:
		_move_towards_position(scarecrow.player.global_position, delta)
	else:
		_slow_down(delta)

func _process_go_to_target(delta: float):
	if !is_instance_valid(current_target):
		return
	
	var distance_to_target_sq: float = scarecrow.global_position.distance_squared_to(current_target.global_position)

	if distance_to_target_sq > scarecrow.interaction_distance_sq:
		_move_towards_position(current_target.global_position, delta)
	else:
		scarecrow.velocity = Vector3.ZERO
		_change_state(State.INTERACT_WITH_TARGET)

func _process_interact_with_target(_delta: float):
	if interacted_with_current_target:
		current_target = null
		interacted_with_current_target = false
		scarecrow.change_task(Scarecrow.Task.Follow)
		return

	if !is_instance_valid(current_target):
		push_warning("Trying to interact with a non-valid target.")
		return
	
	if current_target is Pumpkin:
		var pumpkin: Pumpkin = current_target as Pumpkin
		scarecrow.attempt_pickup_pumpkin(pumpkin)
		interacted_with_current_target = true

func _move_towards_position(target_position: Vector3, delta: float) -> void:
	if !can_move:
		return

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
	if !can_move:
		return

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

func _change_state(state: State):
	if current_state == state:
		return

	current_state = state

func _on_scarecrow_screen_entered():
	scarecrow.velocity = Vector3.ZERO
	can_move = false

func _on_scarecrow_screen_exited():
	can_move = true

func _on_scarecrow_task_changed(new_task: Scarecrow.Task):
	match new_task:
		Scarecrow.Task.Follow:
			_change_state(State.FOLLOWING)
		Scarecrow.Task.PickupPumpkin:
			if !is_instance_valid(scarecrow.target_pumpkin):
				push_error("Scarecrow does not have an assigned pumpkin.")
				scarecrow.change_task(Scarecrow.Task.Follow)
			else:
				interacted_with_current_target = false
				current_target = scarecrow.target_pumpkin
				_change_state(State.GO_TO_TARGET)