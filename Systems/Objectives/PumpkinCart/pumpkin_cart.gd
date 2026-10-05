class_name PumpkinCart
extends CharacterBody3D

@onready var visual: PumpkinCartVisual = $PumpkinCartVisual

@onready var large_slot: Marker3D = %LargeSlot
@onready var small_slots: Array[Marker3D] = [%SmallSlot, %SmallSlot2, %SmallSlot3]

var current_small_slot: int = -1

func show_outline() -> void:
	visual.show_outline()


func hide_outline() -> void:
	visual.hide_outline()

func add_small_pumpkin():
	current_small_slot += 1
	
	if current_small_slot > small_slots.size() - 1:
		return
	
	small_slots[current_small_slot].visible = true

func add_large_pumpkin():
	large_slot.visible = true