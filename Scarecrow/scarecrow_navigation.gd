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

@export_category("Steps")
@export var max_step_height: float = 0.35
@export var step_probe_distance: float = 0.4
@export var step_clearance: float = 0.02
@export var feet_offset_y: float = 0.0

@onready var follow_distance_sq: float = follow_distance * follow_distance

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D

@onready var scarecrow: Scarecrow = get_parent()

@onready var step_cast: RayCast3D = %StepCast

var current_state: State = State.FOLLOWING

var navigation_update_timer: float = 0.0
var last_navigation_target: Vector3
var has_navigation_target: bool = false

var can_move: bool

var current_target: Node3D
var current_interaction_position: Vector3
var interacted_with_current_target: bool

func _ready() -> void:
	navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)

	scarecrow.screen_entered.connect(_on_scarecrow_screen_entered)
	scarecrow.screen_exited.connect(_on_scarecrow_screen_exited)
	scarecrow.task_changed.connect(_on_scarecrow_task_changed)

	step_cast.add_exception(scarecrow)
	step_cast.add_exception(scarecrow.player)

func _physics_process(delta: float) -> void:
	navigation_update_timer = max(
		navigation_update_timer - delta,
		0.0
	)

	match current_state:
		State.FOLLOWING:
			_process_following(delta)
		State.GO_TO_TARGET:
			_process_go_to_target(delta)
		State.INTERACT_WITH_TARGET:
			_process_interact_with_target(delta)

	if scarecrow.is_on_floor():
		scarecrow.velocity.y = 0.0
	else:
		scarecrow.velocity.y -= gravity * delta

	_try_step_up(delta)
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

	var distance_to_interaction_position_sq := (
		scarecrow.global_position.distance_squared_to(
			current_interaction_position
		)
	)

	if distance_to_interaction_position_sq > scarecrow.interaction_distance_sq:
		_move_towards_position(current_interaction_position, delta)
	else:
		navigation_agent.velocity = Vector3.ZERO
		interacted_with_current_target = false
		_change_state(State.INTERACT_WITH_TARGET)

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

	navigation_agent.velocity.x = move_toward(
		navigation_agent.velocity.x,
		target_velocity.x,
		acceleration * delta
	)

	navigation_agent.velocity.z = move_toward(
		navigation_agent.velocity.z,
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
	navigation_agent.velocity.x = move_toward(
		navigation_agent.velocity.x,
		0.0,
		acceleration * delta
	)

	navigation_agent.velocity.z = move_toward(
		navigation_agent.velocity.z,
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

func _try_step_up(delta: float) -> void:
	if not can_move or not scarecrow.is_on_floor():
		return

	var horizontal_velocity: Vector3 = Vector3(
		scarecrow.velocity.x,
		0.0,
		scarecrow.velocity.z
	)

	if horizontal_velocity.length_squared() < 0.001:
		return

	var forward_motion: Vector3 = horizontal_velocity * delta

	if not scarecrow.test_move(
		scarecrow.global_transform,
		forward_motion
	):
		return

	var direction: Vector3 = horizontal_velocity.normalized()
	var feet_y: float = scarecrow.global_position.y + feet_offset_y

	var probe_origin: Vector3 = scarecrow.global_position
	probe_origin += direction * (
		step_probe_distance + forward_motion.length()
	)
	probe_origin.y = feet_y + max_step_height + step_clearance

	step_cast.global_position = probe_origin

	var probe_end: Vector3 = probe_origin
	probe_end.y = feet_y - step_clearance

	step_cast.target_position = step_cast.to_local(probe_end)
	step_cast.force_raycast_update()

	if not step_cast.is_colliding():
		return

	var surface_normal: Vector3 = step_cast.get_collision_normal()
	if surface_normal.dot(Vector3.UP) < cos(scarecrow.floor_max_angle):
		return

	var step_height: float = step_cast.get_collision_point().y - feet_y

	if step_height <= step_clearance or step_height > max_step_height:
		return

	var upward_motion: Vector3 = Vector3.UP * (
		step_height + step_clearance
	)

	if scarecrow.test_move(
		scarecrow.global_transform,
		upward_motion
	):
		return

	var raised_transform: Transform3D = scarecrow.global_transform
	raised_transform.origin += upward_motion

	if scarecrow.test_move(raised_transform, forward_motion):
		return

	scarecrow.global_position += upward_motion
	scarecrow.velocity.y = 0.0

func _change_state(state: State):
	if current_state == state:
		return

	current_state = state

func _calculate_interaction_position() -> void:
	if !is_instance_valid(current_target):
		return

	var navigation_map := navigation_agent.get_navigation_map()

	current_interaction_position = NavigationServer3D.map_get_closest_point(
		navigation_map,
		current_target.global_position
	)

func _on_scarecrow_screen_entered():
	navigation_agent.velocity = Vector3.ZERO
	can_move = false

func _on_scarecrow_screen_exited():
	can_move = true

func _on_scarecrow_task_changed(new_task: Scarecrow.Task):
	match new_task:
		Scarecrow.Task.Follow:
			current_target = null
			_change_state(State.FOLLOWING)

		Scarecrow.Task.PickupPumpkin:
			if !is_instance_valid(scarecrow.target_pumpkin):
				push_error("Scarecrow does not have an assigned pumpkin.")
				scarecrow.change_task(Scarecrow.Task.Follow)
			else:
				_set_interaction_target(scarecrow.target_pumpkin)

		Scarecrow.Task.LoadCart:
			if !is_instance_valid(scarecrow.target_cart):
				push_error("Scarecrow does not have an assigned cart.")
				scarecrow.change_task(Scarecrow.Task.Follow)
			else:
				_set_interaction_target(scarecrow.target_cart)

		Scarecrow.Task.EquipMask:
			if !is_instance_valid(scarecrow.target_mask):
				push_error("Scarecrow does not have an assigned pumpkin mask.")
				scarecrow.change_task(Scarecrow.Task.Follow)
			else:
				_set_interaction_target(scarecrow.target_mask)

		Scarecrow.Task.DrawWheel:
			if !is_instance_valid(scarecrow.target_wheel):
				push_error("Scarecrow does not have an assigned draw wheel.")
				scarecrow.change_task(Scarecrow.Task.Follow)
			else:
				_set_interaction_target(scarecrow.target_wheel)

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
	elif current_target is PumpkinCart:
		scarecrow.drop_current_held_pumpkin()
		var cart: PumpkinCart = current_target as PumpkinCart
		cart.add_large_pumpkin()
		interacted_with_current_target = true
	elif current_target is PumpkinVisual:
		scarecrow.equip_pumpkin_mask(current_target)
		interacted_with_current_target = true
	elif current_target is DrawWheel:
		if !scarecrow.drawn_wheel_task_completed and current_target.ditch_bridge.is_up and current_target.try_spin_wheel(scarecrow):
			scarecrow.drawn_wheel_task_completed = true
			current_target.can_player_interact = false
			return

		if scarecrow.bridge_locked:
			interacted_with_current_target = true


func _set_interaction_target(target: Node3D) -> void:
	interacted_with_current_target = false
	current_target = target

	_calculate_interaction_position()

	_change_state(State.GO_TO_TARGET)

func _on_navigation_velocity_computed(safe_velocity: Vector3) -> void:
	scarecrow.velocity.x = safe_velocity.x
	scarecrow.velocity.z = safe_velocity.z