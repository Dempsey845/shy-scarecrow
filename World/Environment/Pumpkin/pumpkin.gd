class_name Pumpkin
extends StaticBody3D

@export var is_too_large: bool = false

@onready var pumpkin_visual: PumpkinVisual = $PumpkinVisual
@onready var too_heavy_warning: Warning = $TooHeavyWarning

func show_outline() -> void:
	pumpkin_visual.show_outline()


func hide_outline() -> void:
	pumpkin_visual.hide_outline()

func pickup():
	queue_free()

func show_too_heavy_warning():
	too_heavy_warning.show_warning()