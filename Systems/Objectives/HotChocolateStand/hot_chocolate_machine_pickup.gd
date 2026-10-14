class_name HotChocolateMachinePickup
extends StaticBody3D

@onready var hot_chocolate_machine_visual: HotChocolateMachineVisual = $HotChocolateMachineVisual

@onready var pickup_player: AudioStreamPlayer = $PickupPlayer

var return_hot_choco_machine: PlayerTask = preload("uid://bxf8lq8vtfayh")

var picking_up: bool = false

func show_outline():
	hot_chocolate_machine_visual.show_outline()

func hide_outline():
	hot_chocolate_machine_visual.hide_outline()
	
func pickup():
	if picking_up:
		return
	
	PlayerTasks.complete_task(&"find_hot_choco_machine")
	PlayerTasks.add_task(return_hot_choco_machine)

	picking_up = true

	pickup_player.play()
	await pickup_player.finished
	queue_free()
