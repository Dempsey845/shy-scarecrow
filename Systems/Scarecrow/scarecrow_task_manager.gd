extends Node

@export var scarecrow: Scarecrow
@export var player: Player
@export var pumpkin_cart: PumpkinCart

@export var draw_wheel: DrawWheel
@export var lock_draw_wheel: DrawWheel

@export var next_area: Area3D

var player_reached_next_area: bool

func _ready() -> void:
	player.pumpkin_too_large.connect(_on_player_pumpkin_too_large)

	scarecrow.pumpkin_pickup.connect(_on_scarecrow_pumpkin_pickup)

	draw_wheel.interacted_with.connect(_on_draw_wheel_interacted_with)

	lock_draw_wheel.interacted_with.connect(_on_lock_draw_wheel_interacted_with)

	scarecrow.screen_entered.connect(_on_scarecrow_screen_entered)
	scarecrow.screen_exited.connect(_on_scarecrow_screen_exited)

	next_area.body_entered.connect(_on_next_area_body_entered)

func _on_player_pumpkin_too_large(pumpkin: Pumpkin):
	scarecrow.try_assign_pumpkin_target(pumpkin)

func _on_scarecrow_pumpkin_pickup(_pumpkin: Pumpkin):
	scarecrow.target_cart = pumpkin_cart
	scarecrow.change_task(Scarecrow.Task.LoadCart)

func _on_draw_wheel_interacted_with(source: Node3D):
	if source is Player:
		scarecrow.target_wheel = draw_wheel
		scarecrow.change_task(Scarecrow.Task.DrawWheel)

func _on_lock_draw_wheel_interacted_with(source: Node3D):
	if source is Player:
		scarecrow.bridge_locked = true

func _on_scarecrow_screen_entered():
	if scarecrow.current_task == Scarecrow.Task.DrawWheel:
		if player_reached_next_area:
			return

		if !draw_wheel.ditch_bridge.is_up:
			draw_wheel.try_spin_wheel(scarecrow)

func _on_scarecrow_screen_exited():
	if scarecrow.current_task == Scarecrow.Task.DrawWheel:
		if player_reached_next_area:
			return

		if draw_wheel.ditch_bridge.is_up:
			draw_wheel.try_spin_wheel(scarecrow)

func _on_next_area_body_entered(body: Node3D):
	if body is Player and !player_reached_next_area:
		player_reached_next_area = true

		if !draw_wheel.ditch_bridge.is_up:
			draw_wheel.ditch_bridge.draw_up()
