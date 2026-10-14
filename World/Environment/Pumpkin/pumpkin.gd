class_name Pumpkin
extends StaticBody3D

const PumpkinSounds = preload("res://Audio/pumpkin_sounds.gd")


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
	if is_queued_for_deletion():
		return

	if is_too_large:
		await get_tree().create_timer(0.35).timeout

	PumpkinSounds.play_at(self, "pickup")
	queue_free()

func show_too_heavy_warning():
	too_heavy_warning.show_warning()