class_name Scarecrow
extends CharacterBody3D

enum Task {
	Follow,
	PickupPumpkin
}

signal screen_entered
signal screen_exited

signal task_changed(new_task: Task)

@export_category("References")
@export var player: Player

@onready var notifier: VisibleOnScreenNotifier3D = %VisibleOnScreenNotifier

var current_task: Task = Task.Follow

func _ready() -> void:
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)

func _on_screen_entered():
	screen_entered.emit()

func _on_screen_exited():
	screen_exited.emit()

func change_task(task: Task):
	current_task = task

	task_changed.emit(task)