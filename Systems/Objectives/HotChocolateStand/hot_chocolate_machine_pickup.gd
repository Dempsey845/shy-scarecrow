class_name HotChocolateMachinePickup
extends StaticBody3D

@onready var hot_chocolate_machine_visual: HotChocolateMachineVisual = $HotChocolateMachineVisual

func show_outline():
	hot_chocolate_machine_visual.show_outline()

func hide_outline():
	hot_chocolate_machine_visual.hide_outline()
	
func pickup():
	queue_free()
