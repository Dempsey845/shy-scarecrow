class_name Scarecrow
extends CharacterBody3D

enum Task {
	Follow,
	PickupPumpkin,
	LoadCart,
	EquipMask
}

signal screen_entered
signal screen_exited

signal task_changed(new_task: Task)

signal pumpkin_pickup(pumpkin: Pumpkin)

signal attempt_drop

@export_category("References")
@export var player: Player
@export var pumpkin_workbench: PumpkinWorkbench

@export_category("Pumpkin Interaction")
@export var interaction_distance: float = 1.5

@onready var interaction_distance_sq: float = interaction_distance * interaction_distance

@onready var notifier: VisibleOnScreenNotifier3D = %VisibleOnScreenNotifier

@onready var pumpkin_mask: Node3D = %PumpkinMask
@onready var scarecrow_visual: ScarecrowVisual = %ScarecrowVisual

var current_task: Task = Task.Follow

var target_pumpkin: Pumpkin

var target_cart: PumpkinCart

var target_mask: PumpkinVisual

var is_holding_pumpkin: bool = false

var current_held_pumpkin: Pumpkin

func _ready() -> void:
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)
	pumpkin_workbench.task_completed.connect(_on_pumpkin_workbench_task_completed)

func change_task(task: Task):
	if current_task == task:
		return

	current_task = task

	task_changed.emit(task)

func try_assign_pumpkin_target(pumpkin: Pumpkin) -> bool:
	if is_instance_valid(target_pumpkin) or is_holding_pumpkin:
		return false

	target_pumpkin = pumpkin

	change_task(Task.PickupPumpkin)

	return true

func attempt_pickup_pumpkin(pumpkin: Pumpkin):
	if is_holding_pumpkin:
		return
	
	pumpkin_pickup.emit(pumpkin)

	is_holding_pumpkin = true

func drop_current_held_pumpkin():
	attempt_drop.emit()
	is_holding_pumpkin = false

func equip_pumpkin_mask(pumpkin_visual: PumpkinVisual):
	pumpkin_visual.reparent(pumpkin_mask)
	pumpkin_visual.position = Vector3.ZERO
	pumpkin_visual.rotation = Vector3.ZERO
	scarecrow_visual.hide_head()

func _on_screen_entered():
	screen_entered.emit()

func _on_screen_exited():
	screen_exited.emit()

func _on_pumpkin_workbench_task_completed(pumpkin_visual: PumpkinVisual):
	target_mask = pumpkin_visual
	change_task(Task.EquipMask)