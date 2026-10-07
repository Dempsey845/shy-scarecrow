class_name Pumpkin
extends StaticBody3D


@onready var pumpkin_visual: PumpkinVisual = $PumpkinVisual
@onready var too_heavy_warning: Warning = $TooHeavyWarning

var patch: PumpkinGroundPatch

var is_too_large: bool = false

func _ready() -> void:
	if is_instance_valid(patch):
		is_too_large = patch.is_too_large
	else:
		push_error("Cannot determine if pumpkin is too large due to unassigned patch!")

func show_outline() -> void:
	pumpkin_visual.show_outline()


func hide_outline() -> void:
	pumpkin_visual.hide_outline()

func pickup():
	queue_free()

func show_too_heavy_warning():
	too_heavy_warning.show_warning()