extends Node

@onready var pickup_cast: RayCast3D = %PickupCast
@onready var pumpkin_slot: Node3D = %PumpkinSlot
@onready var player: Player = get_parent()

var current_hovered_pumpkin: Pumpkin

var current_held_pumpkin: Node3D


func _process(_delta: float) -> void:
	var target_pumpkin: Pumpkin = null

	if pickup_cast.is_colliding():
		var collider := pickup_cast.get_collider()

		if collider is Pumpkin:
			if not is_instance_valid(current_held_pumpkin) or collider.is_too_large:
				target_pumpkin = collider

	if current_hovered_pumpkin != target_pumpkin:
		if is_instance_valid(current_hovered_pumpkin):
			current_hovered_pumpkin.hide_outline()

		current_hovered_pumpkin = target_pumpkin

		if is_instance_valid(current_hovered_pumpkin):
			current_hovered_pumpkin.show_outline()

	if not is_instance_valid(current_hovered_pumpkin):
		return

	if not Input.is_action_just_pressed("interact"):
		return

	if current_hovered_pumpkin.is_too_large:
		current_hovered_pumpkin.show_too_heavy_warning()
		player.emit_pumpkin_too_large(current_hovered_pumpkin)
		return

	current_hovered_pumpkin.hide_outline()
	current_hovered_pumpkin.pickup()
	current_hovered_pumpkin = null

	current_held_pumpkin = PSSR.pumpkin_item_scene.instantiate()
	pumpkin_slot.add_child(current_held_pumpkin)