extends StaticBody3D

@onready var delivery_detection_area: Area3D = $DeliveryDetectionArea

var carve_pumpkin: PlayerTask = preload("uid://cfjbssnmxorvx")

var delivered: bool = false

func _ready() -> void:
    delivery_detection_area.body_entered.connect(_on_delivery_detection_area_body_entered)

func _on_delivery_detection_area_body_entered(body: Node3D):
    if body is not PumpkinCart or delivered:
        return
    
    PlayerTasks.complete_task(&"deliver_cart")

    PlayerTasks.add_task(carve_pumpkin)

    delivered = true