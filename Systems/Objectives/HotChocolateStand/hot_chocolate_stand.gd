class_name HotChocolateStand
extends StaticBody3D

@export var player: Player

@onready var hot_chocolate_machine_visual: HotChocolateMachineVisual = $HotChocolateMachineVisual
@onready var hot_chocolate_stand_visual: HotChocolateStandVisual = $HotChocolateStandVisual
@onready var hot_chocolate_cup: HotChocolateCup = $HotChocolateCup
@onready var machine_buzz_player: AudioStreamPlayer = $MachineBuzzPlayer
@onready var success_chime_player: AudioStreamPlayer = $SuccessChimePlayer
@onready var claim_hot_chocolate_player: AudioStreamPlayer = $ClaimHotChocolatePlayer

var has_chocolate_machine: bool = false

var can_make_hot_chocolate: bool = true

var claimed_hot_chocolate: bool = false

var is_hot_chocolate_made: bool = false

var make_hot_choco: PlayerTask = preload("uid://b72mn218bt582")

func _ready() -> void:
	hot_chocolate_cup.filled.connect(func():
		is_hot_chocolate_made = true
		success_chime_player.play()
	)

func show_outline():
	if !can_make_hot_chocolate:
		return

	if has_chocolate_machine:
		hot_chocolate_machine_visual.show_outline()
	else:
		hot_chocolate_stand_visual.show_outline()

func hide_outline():
	hot_chocolate_machine_visual.hide_outline()
	hot_chocolate_stand_visual.hide_outline()

func try_add_hot_chocolate_machine() -> bool:
	if hot_chocolate_machine_visual.visible or has_chocolate_machine:
		return false
	
	hot_chocolate_machine_visual.visible = true

	hot_chocolate_machine_visual.show_outline()

	hot_chocolate_stand_visual.hide_outline()

	PlayerTasks.complete_task(&"return_hot_choco_machine")

	PlayerTasks.add_task(make_hot_choco)

	has_chocolate_machine = true

	claim_hot_chocolate_player.play()

	return true

func try_make_hot_chocolate():
	if !has_chocolate_machine:
		return

	if !can_make_hot_chocolate:
		if is_hot_chocolate_made and !claimed_hot_chocolate:
			hot_chocolate_cup.hide_outline()
			hot_chocolate_cup.reparent(player.hot_chocolate_slot)
			hot_chocolate_cup.position = Vector3.ZERO
			hot_chocolate_cup.rotation_degrees = Vector3.ZERO
			claimed_hot_chocolate = true
			claim_hot_chocolate_player.play()

			PlayerTasks.complete_task(&"make_hot_choco")
		return

	hot_chocolate_cup.visible = true

	hot_chocolate_cup.fill_cup()

	machine_buzz_player.play()

	hot_chocolate_machine_visual.hide_outline()

	hot_chocolate_cup.show_outline()

	can_make_hot_chocolate = false
