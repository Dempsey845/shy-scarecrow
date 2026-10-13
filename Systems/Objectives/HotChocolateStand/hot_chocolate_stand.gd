class_name HotChocolateStand
extends StaticBody3D

@onready var hot_chocolate_machine_visual: Node3D = $hot_chocolate_machine
@onready var hot_chocolate_stand_visual: HotChocolateStandVisual = $HotChocolateStandVisual

func show_outline():
    hot_chocolate_stand_visual.show_outline()

func hide_outline():
    hot_chocolate_stand_visual.hide_outline()

func try_add_hot_chocolate_machine() -> bool:
    if hot_chocolate_machine_visual.visible:
        return false
    
    hot_chocolate_machine_visual.visible = true

    PlayerTasks.complete_task(&"return_hot_choco_machine")

    return true

