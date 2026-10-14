class_name PumpkinCart
extends CharacterBody3D

const PumpkinSounds = preload("res://Audio/pumpkin_sounds.gd")

@export var push_speed: float = 2.5
@export var gravity: float = 22.0
@export var steering_speed: float = 5.0
@export_range(-180.0, 180.0) var forward_angle_offset: float = 180.0
@export var steering_degrees_per_second: float = 70.0

@export var bump_push_speed: float = 1.5

@export_category("Steps")
@export var step_height: float = 0.2

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

var deliver_cart_task: PlayerTask = preload("uid://dbrt5i4eh850j")
var help_scarecrow_bridge_task: PlayerTask = preload("uid://ctil4sb5asmu")

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
	PumpkinSounds.play_at(small_slots[current_small_slot], "cart")

	try_start_next_task()

	return true


func add_large_pumpkin() -> bool:
	if has_large_pumpkin:
		return false

	has_large_pumpkin = true
	large_slot.visible = true
	PumpkinSounds.play_at(large_slot, "cart")

	try_start_next_task()

	return true


func try_start_next_task():
	if is_full():
		PlayerTasks.complete_task(&"load_cart")
		PlayerTasks.add_task(deliver_cart_task)
		PlayerTasks.add_task(help_scarecrow_bridge_task)

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

	var cart_lift := get_step_lift(
		self,
		drive_velocity * delta,
		step_height
	)

	if cart_lift > 0.0:
		global_position.y += cart_lift
		velocity.y = 0.0

	move_and_slide()

	var player_motion := (
		push_position.global_position
		- pushing_player.global_position
	)
	player_motion.y = 0.0

	var player_lift := get_step_lift(
		pushing_player,
		player_motion,
		step_height
	)

	if player_lift < 0.0:
		global_transform = previous_transform

		velocity.x = 0.0
		velocity.z = 0.0

		return Vector3.ZERO

	if player_lift > 0.0:
		pushing_player.global_position.y += player_lift
		pushing_player.velocity.y = 0.0
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

static func get_step_lift(
	target: CharacterBody3D,
	motion: Vector3,
	max_height: float
) -> float:
	var horizontal_motion := Vector3(motion.x, 0.0, motion.z)

	if horizontal_motion.length_squared() < 0.000001:
		return 0.0

	var start := target.global_transform

	if not target.test_move(start, horizontal_motion):
		return 0.0

	if (
		not target.is_on_floor()
		or target.velocity.y > 0.0
		or max_height <= 0.0
	):
		return -1.0

	var up_motion := Vector3.UP * max_height

	if target.test_move(start, up_motion):
		return -1.0

	var raised := start
	raised.origin += up_motion

	if target.test_move(raised, horizontal_motion):
		return -1.0

	var above_destination := raised
	above_destination.origin += horizontal_motion

	var landing := KinematicCollision3D.new()
	var down_motion := Vector3.DOWN * (max_height + 0.02)

	if not target.test_move(
		above_destination,
		down_motion,
		landing
	):
		return -1.0

	if (
		landing.get_normal().dot(Vector3.UP)
		< cos(target.floor_max_angle)
	):
		return -1.0

	var lift := max_height + landing.get_travel().y

	if lift <= 0.001 or lift > max_height + 0.001:
		return -1.0

	return lift

func nudge(direction: Vector3, speed: float, delta: float) -> void:
	if not is_full() or is_instance_valid(pushing_player):
		return

	var motion := direction * minf(speed, bump_push_speed) * delta

	var lift := get_step_lift(self, motion, step_height)

	if lift > 0.0:
		global_position.y += lift
		velocity.y = 0.0

	move_and_collide(motion)