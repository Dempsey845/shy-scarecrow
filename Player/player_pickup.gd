extends Node

@onready var pickup_cast: RayCast3D = %PickupCast
@onready var pumpkin_slot: Node3D = %PumpkinSlot
@onready var player: Player = get_parent()

var current_hovered_pumpkin: Pumpkin

var current_held_pumpkin: Node3D


func _process(_delta: float) -> void:
    if pickup_cast.is_colliding():
        if !current_hovered_pumpkin and !current_held_pumpkin:
            var collider: Object = pickup_cast.get_collider()

            if collider is Pumpkin:
                current_hovered_pumpkin = collider
                current_hovered_pumpkin.show_outline()
        elif Input.is_action_just_pressed("interact") and !current_held_pumpkin:
            if current_hovered_pumpkin.is_too_large:
                player.emit_pumpkin_too_large(current_hovered_pumpkin)
            else:
                current_hovered_pumpkin.pickup()
                current_hovered_pumpkin = null

                current_held_pumpkin = PSSR.pumpkin_item_scene.instantiate()

                pumpkin_slot.add_child(current_held_pumpkin)
    else:
        if current_hovered_pumpkin:
            current_hovered_pumpkin.hide_outline()
            current_hovered_pumpkin = null