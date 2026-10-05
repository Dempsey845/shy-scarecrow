class_name PumpkinCart
extends CharacterBody3D

@onready var visual: PumpkinCartVisual = $PumpkinCartVisual

func show_outline() -> void:
	visual.show_outline()


func hide_outline() -> void:
	visual.hide_outline()