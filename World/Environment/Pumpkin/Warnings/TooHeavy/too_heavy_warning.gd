class_name Warning
extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func show_warning():
    if animation_player.is_playing():
        return

    animation_player.play("warn")