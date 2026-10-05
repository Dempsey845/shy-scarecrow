extends Node

@onready var pumpkin_slot: Node3D = %PumpkinSlot

@onready var scarecrow: Scarecrow = get_parent()

var current_held_pumpkin: Node3D

func _ready() -> void:
	scarecrow.pumpkin_pickup.connect(_on_pumpkin_pickup)

func _on_pumpkin_pickup(pumpkin: Pumpkin):
	if is_instance_valid(current_held_pumpkin):
		drop_current_pumpkin()

	pumpkin.pickup()

	current_held_pumpkin = PSSR.pumpkin_item_scene.instantiate()

	pumpkin_slot.add_child(current_held_pumpkin)

	scarecrow.is_holding_pumpkin = true

func drop_current_pumpkin():
	current_held_pumpkin.queue_free()
	scarecrow.is_holding_pumpkin = false
