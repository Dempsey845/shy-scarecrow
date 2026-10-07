class_name Gate
extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_opening: bool = false
var is_closing: bool = false

var is_open: bool = false

func open_gate():
    if is_opening:
        return

    if is_closing:
        await animation_player.animation_finished

    animation_player.play("open")

    is_open = true

    is_opening = true

    await animation_player.animation_finished

    is_opening = false

func close_gate():
    if is_closing:
        return

    if is_opening:
        await animation_player.animation_finished

    animation_player.play_backwards("open")

    is_open = false

    is_closing = true

    await animation_player.animation_finished

    is_closing = false