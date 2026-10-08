class_name DrawWheel
extends StaticBody3D

@export var ditch_bridge: DitchBridge

@onready var visual: DrawWheelVisual = $DrawWheelVisual
@onready var release_timer: Timer = $ReleaseTimer

func _ready() -> void:
	release_timer.timeout.connect(_on_release_timer_timeout)

func try_spin_wheel(source: Node3D) -> bool:
	if visual.try_spin_wheel():
		if ditch_bridge.is_up:
			ditch_bridge.draw_down()

			if source is Player:
				release_timer.start()
		else:
			ditch_bridge.draw_up()
		return true
	
	return false

func show_outline() -> void:
	visual.show_outline()


func hide_outline() -> void:
	visual.hide_outline()

func _on_release_timer_timeout():
	if !ditch_bridge.is_up:
		ditch_bridge.draw_up()
