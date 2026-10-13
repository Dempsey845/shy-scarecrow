class_name HotChocolateMachinePickup
extends StaticBody3D

@onready var hot_chocolate_machine_visual: HotChocolateMachineVisual = $HotChocolateMachineVisual

var return_hot_choco_machine: PlayerTask = preload("uid://bxf8lq8vtfayh")

func show_outline():
	hot_chocolate_machine_visual.show_outline()

func hide_outline():
	hot_chocolate_machine_visual.hide_outline()
	
func pickup():
	PlayerTasks.complete_task(&"find_hot_choco_machine")
	PlayerTasks.add_task(return_hot_choco_machine)
	queue_free()
