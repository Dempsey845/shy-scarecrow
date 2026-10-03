class_name Scarecrow
extends CharacterBody3D

signal screen_entered
signal screen_exited

@export_category("References")
@export var player: Player

@onready var notifier: VisibleOnScreenNotifier3D = %VisibleOnScreenNotifier

func _ready() -> void:
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)

func _on_screen_entered():
	screen_entered.emit()

func _on_screen_exited():
	screen_exited.emit()
