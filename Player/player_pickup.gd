extends Node

@onready var pickup_cast: RayCast3D = %PickupCast

var current_hovered_pumpkin: Pumpkin

func _process(_delta: float) -> void:
    if pickup_cast.is_colliding():
        if !current_hovered_pumpkin:
            var collider: Object = pickup_cast.get_collider()

            if collider is Pumpkin:
                current_hovered_pumpkin = collider
                current_hovered_pumpkin.show_outline()
    else:
        if current_hovered_pumpkin:
            current_hovered_pumpkin.hide_outline()
            current_hovered_pumpkin = null