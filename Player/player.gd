class_name Player
extends CharacterBody3D

signal pumpkin_too_large(pumpkin: Pumpkin)

var pushing_cart: PumpkinCart


func emit_pumpkin_too_large(pumpkin: Pumpkin) -> void:
	pumpkin_too_large.emit(pumpkin)


func start_pushing_cart(cart: PumpkinCart) -> void:
	if is_instance_valid(pushing_cart):
		return

	if cart.start_pushing(self):
		pushing_cart = cart

		velocity.x = 0.0
		velocity.z = 0.0


func stop_pushing_cart() -> void:
	if is_instance_valid(pushing_cart):
		pushing_cart.stop_pushing()

	pushing_cart = null

	velocity.x = 0.0
	velocity.z = 0.0