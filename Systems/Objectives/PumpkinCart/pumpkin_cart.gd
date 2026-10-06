class_name PumpkinCart
extends CharacterBody3D

@export var push_speed: float = 2.5
@export var gravity: float = 22.0
@export var steering_speed: float = 5.0
@export_range(-180.0, 180.0) var forward_angle_offset: float = 180.0
@export var steering_degrees_per_second: float = 70.0

@onready var push_position: Marker3D = $PushPosition

@onready var visual: PumpkinCartVisual = $PumpkinCartVisual

@onready var large_slot: Marker3D = %LargeSlot
@onready var small_slots: Array[Marker3D] = [
	%SmallSlot,
	%SmallSlot2,
	%SmallSlot3
]

@onready var push_zone: Area3D = $PushZone

var current_small_slot: int = -1
var has_large_pumpkin: bool = false

var pushing_player: CharacterBody3D


func _physics_process(delta: float) -> void:
	if is_instance_valid(pushing_player):
		return

	pushing_player = null
	velocity.x = 0.0
	velocity.z = 0.0

	_apply_gravity(delta)
	move_and_slide()


func show_outline() -> void:
	visual.show_outline()


func hide_outline() -> void:
	visual.hide_outline()


func add_small_pumpkin() -> bool:
	if current_small_slot >= small_slots.size() - 1:
		return false

	current_small_slot += 1
	small_slots[current_small_slot].visible = true
	return true


func add_large_pumpkin() -> bool:
	if has_large_pumpkin:
		return false

	has_large_pumpkin = true
	large_slot.visible = true
	return true


func is_full() -> bool:
	return (
		has_large_pumpkin
		and current_small_slot == small_slots.size() - 1
	)

func can_start_pushing(player: CharacterBody3D) -> bool:
	return (
		is_full()
		and not is_instance_valid(pushing_player)
		and push_zone.overlaps_body(player)
	)

func start_pushing(player: CharacterBody3D) -> bool:
	if not can_start_pushing(player):
		return false

	pushing_player = player

	add_collision_exception_with(player)
	player.add_collision_exception_with(self)

	var alignment_motion := (
		push_position.global_position - player.global_position
	)
	alignment_motion.y = 0.0

	if player.test_move(player.global_transform, alignment_motion):
		stop_pushing()
		return false

	player.global_position += alignment_motion

	player.global_rotation.y = (
		global_rotation.y - deg_to_rad(forward_angle_offset)
	)

	hide_outline()
	return true


func stop_pushing() -> void:
	if is_instance_valid(pushing_player):
		remove_collision_exception_with(pushing_player)
		pushing_player.remove_collision_exception_with(self)

	pushing_player = null
	velocity.x = 0.0
	velocity.z = 0.0


func push(delta: float) -> Vector3:
	if not is_instance_valid(pushing_player) or delta <= 0.0:
		return Vector3.ZERO

	var drive_input := Input.get_axis(
		"move_backward",
		"move_forward"
	)

	var steer_input := Input.get_axis(
		"move_left",
		"move_right"
	)

	var previous_transform := global_transform

	var turn_amount := (
		-steer_input
		* deg_to_rad(steering_degrees_per_second)
		* delta
	)

	# Steering only turns the cart while driving.
	turn_amount *= drive_input

	global_rotation.y += turn_amount

	var facing_angle := (
		global_rotation.y - deg_to_rad(forward_angle_offset)
	)

	var forward_direction := Vector3(
		-sin(facing_angle),
		0.0,
		-cos(facing_angle)
	)

	var drive_velocity := (
		forward_direction * drive_input * push_speed
	)

	var predicted_player_motion := (
		push_position.global_position
		+ drive_velocity * delta
		- pushing_player.global_position
	)
	predicted_player_motion.y = 0.0

	if pushing_player.test_move(
		pushing_player.global_transform,
		predicted_player_motion
	):
		global_transform = previous_transform
		drive_velocity = Vector3.ZERO

	velocity.x = drive_velocity.x
	velocity.z = drive_velocity.z

	_apply_gravity(delta)
	move_and_slide()

	var player_motion := (
		push_position.global_position
		- pushing_player.global_position
	)
	player_motion.y = 0.0

	if pushing_player.test_move(
		pushing_player.global_transform,
		player_motion
	):
		var updated_height := global_position.y

		global_transform = previous_transform
		global_position.y = updated_height

		velocity.x = 0.0
		velocity.z = 0.0

		return Vector3.ZERO

	pushing_player.global_rotation.y = (
		global_rotation.y - deg_to_rad(forward_angle_offset)
	)

	return player_motion / delta


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

func _steer(move_velocity: Vector3, delta: float) -> void:
	var direction := Vector3(
		move_velocity.x,
		0.0,
		move_velocity.z
	)

	if direction.length_squared() < 0.01:
		return

	var target_angle := atan2(-direction.x, -direction.z)
	target_angle += deg_to_rad(forward_angle_offset)

	var weight := 1.0 - exp(-steering_speed * delta)

	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_angle,
		weight
	)