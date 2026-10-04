extends Node

@onready var pickup_cast: RayCast3D = %PickupCast
@onready var pumpkin_slot: Node3D = %PumpkinSlot

var current_hovered_pumpkin: Pumpkin

var current_held_pumpkin: Node3D

var pumpkin_item_scene: PackedScene = preload("uid://45qjv1yl14gf")

func _process(_delta: float) -> void:
    if pickup_cast.is_colliding():
        if !current_hovered_pumpkin and !current_held_pumpkin:
            var collider: Object = pickup_cast.get_collider()

            if collider is Pumpkin:
                current_hovered_pumpkin = collider
                current_hovered_pumpkin.show_outline()
        elif Input.is_action_just_pressed("interact") and !current_held_pumpkin:
            current_hovered_pumpkin.pickup()
            current_hovered_pumpkin = null

            current_held_pumpkin = pumpkin_item_scene.instantiate()

            pumpkin_slot.add_child(current_held_pumpkin)
    else:
        if current_hovered_pumpkin:
            current_hovered_pumpkin.hide_outline()
            current_hovered_pumpkin = null