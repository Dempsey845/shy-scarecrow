extends Node

@export var scarecrow: Scarecrow
@export var player: Player

func _ready() -> void:
    player.pumpkin_too_large.connect(_on_player_pumpkin_too_large)

func _on_player_pumpkin_too_large(pumpkin: Pumpkin):
    scarecrow.try_assign_pumpkin_target(pumpkin)