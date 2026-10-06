extends Node

@export var scarecrow: Scarecrow
@export var player: Player
@export var pumpkin_cart: PumpkinCart

func _ready() -> void:
    player.pumpkin_too_large.connect(_on_player_pumpkin_too_large)

    scarecrow.pumpkin_pickup.connect(_on_scarecrow_pumpkin_pickup)

func _on_player_pumpkin_too_large(pumpkin: Pumpkin):
    scarecrow.try_assign_pumpkin_target(pumpkin)

func _on_scarecrow_pumpkin_pickup(_pumpkin: Pumpkin):
    scarecrow.target_cart = pumpkin_cart
    scarecrow.change_task(Scarecrow.Task.LoadCart)
        