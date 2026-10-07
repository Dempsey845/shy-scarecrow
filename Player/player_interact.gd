extends Node

@onready var interact_cast: RayCast3D = %InteractCast
@onready var pumpkin_slot: Node3D = %PumpkinSlot
@onready var player: Player = get_parent()

var current_hovered_target: Node3D
var current_held_pumpkin: Node3D


func _process(_delta: float) -> void:
	if is_instance_valid(player.pushing_cart):
		_set_hovered_target(null)

		if Input.is_action_just_pressed("interact"):
			player.stop_pushing_cart()

		return

	var target: Node3D = null

	if interact_cast.is_colliding():
		var collider := interact_cast.get_collider()

		if collider is Pumpkin:
			if (
				not is_instance_valid(current_held_pumpkin)
				or collider.is_too_large
			):
				target = collider

		elif collider is PumpkinCart:
			if _can_interact_with_cart(collider):
				target = collider

		elif collider is PumpkinGroundPatch:
			if !collider.is_too_large and !collider.has_pumpkin:
				target = collider

	_set_hovered_target(target)

	if not is_instance_valid(current_hovered_target):
		return

	if Input.is_action_just_pressed("interact"):
		if current_hovered_target is Pumpkin:
			_interact_with_pumpkin(current_hovered_target)

		elif current_hovered_target is PumpkinCart:
			_interact_with_cart(current_hovered_target)

		elif current_hovered_target is PumpkinGroundPatch:
			_interact_with_patch(current_hovered_target)


func _can_interact_with_cart(cart: PumpkinCart) -> bool:
	if is_instance_valid(current_held_pumpkin):
		return cart.current_small_slot < cart.small_slots.size() - 1

	return cart.can_start_pushing(player)


func _set_hovered_target(target: Node3D) -> void:
	if current_hovered_target == target:
		return

	if is_instance_valid(current_hovered_target):
		current_hovered_target.hide_outline()

	current_hovered_target = target

	if is_instance_valid(current_hovered_target):
		current_hovered_target.show_outline()


func _interact_with_pumpkin(pumpkin: Pumpkin) -> void:
	if pumpkin.is_too_large:
		pumpkin.show_too_heavy_warning()
		player.emit_pumpkin_too_large(pumpkin)
		return

	if is_instance_valid(current_held_pumpkin):
		return

	_set_hovered_target(null)

	var pumpkin_scale: Vector3 = pumpkin.patch.scale
	pumpkin.pickup()

	current_held_pumpkin = PSSR.pumpkin_item_scene.instantiate()
	pumpkin_slot.add_child(current_held_pumpkin)
	current_held_pumpkin.scale = pumpkin_scale


func _interact_with_cart(cart: PumpkinCart) -> void:
	if is_instance_valid(current_held_pumpkin):
		if cart.add_small_pumpkin():
			current_held_pumpkin.queue_free()
			current_held_pumpkin = null

			_set_hovered_target(null)

		return

	player.start_pushing_cart(cart)
	_set_hovered_target(null)

func _interact_with_patch(patch: PumpkinGroundPatch):
	if is_instance_valid(current_held_pumpkin):
		patch.add_pumpkin()
		current_held_pumpkin.queue_free()
		current_held_pumpkin = null
		_set_hovered_target(null)