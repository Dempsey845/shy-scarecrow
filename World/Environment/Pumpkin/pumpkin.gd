class_name Pumpkin
extends StaticBody3D

@export var is_too_large: bool = false

@onready var pumpkin_visual: PumpkinVisual = $PumpkinVisual

func show_outline() -> void:
	pumpkin_visual.show_outline()


func hide_outline() -> void:
	pumpkin_visual.hide_outline()

func pickup():
	queue_free()
