class_name EndingBench
extends StaticBody3D

signal sequence_started
signal scarecrow_revealed
signal sequence_finished

@export_file("*.tscn") var main_menu_scene_path := "res://UI/MainMenu/main_menu.tscn"

@export var scarecrow: Node3D

@export_range(0.1, 5.0) var sit_duration := 4.0
@export_range(0.05, 2.0) var blink_duration := 0.22
@export_range(0.1, 10.0) var reveal_duration := 2.5
@export_range(0.1, 5.0) var fade_duration := 1.8

@onready var _camera: Camera3D = $EndingCamera
@onready var _seat: Marker3D = $SeatAnchor
@onready var _view: Marker3D = $SeatedView
@onready var _reveal: Marker3D = $ScarecrowReveal
@onready var _ui: Control = $EndingUI/ScreenEffects
@onready var _top: ColorRect = $EndingUI/ScreenEffects/TopEyelid
@onready var _bottom: ColorRect = $EndingUI/ScreenEffects/BottomEyelid
@onready var _fade: ColorRect = $EndingUI/ScreenEffects/Fade
@onready var _prompt: Label3D = $SitPrompt
@onready var _highlight: MeshInstance3D = $HoverHighlight
@onready var sit_down_player: AudioStreamPlayer = $SitDownPlayer
@onready var success_player: AudioStreamPlayer = $SuccessPlayer

var _busy := false
var _player: Node3D
var _old_camera: Camera3D
var _old_player_transform: Transform3D
var _old_player_visible := true
var _old_mouse: int
var _old_paused := false
var _saved_nodes: Array[Dictionary] = []
var _scarecrow_transform: Transform3D
var _scarecrow_visible := true
var _spawned := false
var _transitioning := false
var _tween: Tween

var completed_all_tasks: bool = false

var sit_on_bench: PlayerTask = preload("uid://coj1c00j8q463")

func _ready() -> void:
	PlayerTasks.task_completed.connect(_on_task_completed)

func show_outline() -> void:
	if not _busy:
		_highlight.show()
		_prompt.show()


func hide_outline() -> void:
	_highlight.hide()
	_prompt.hide()


func can_interact(_actor: Node3D) -> bool:
	return completed_all_tasks and not _busy and not get_tree().paused


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return

	if not is_instance_valid(scarecrow):
		return

	PlayerTasks.complete_task(&"sit_on_bench")

	sit_down_player.play()

	_busy = true
	_player = actor

	_old_camera = get_viewport().get_camera_3d()
	_old_player_transform = actor.global_transform
	_old_player_visible = actor.visible
	_old_mouse = Input.mouse_mode
	_old_paused = get_tree().paused

	_scarecrow_transform = scarecrow.global_transform
	_scarecrow_visible = scarecrow.visible

	_save_and_disable(actor)
	_save_and_disable(scarecrow)

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hide_outline()

	_ui.show()
	_fade.modulate.a = 0.0
	_set_blink(0.0)
	scarecrow.hide()

	if is_instance_valid(_old_camera):
		_camera.global_transform = _old_camera.global_transform
		_camera.fov = _old_camera.fov
	else:
		_camera.global_transform = _view.global_transform

	_camera.make_current()
	actor.global_transform = _seat.global_transform
	actor.hide()

	if actor is CharacterBody3D:
		actor.velocity = Vector3.ZERO

	sequence_started.emit()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	(
		_tween
		. tween_property(_camera, "global_transform", _view.global_transform, sit_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	_tween.tween_method(_set_blink, 0.0, 1.0, blink_duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)

	_tween.tween_callback(_reveal_scarecrow)
	_tween.tween_interval(0.18)
	(
		_tween
		. tween_method(_set_blink, 1.0, 0.0, blink_duration * 1.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	_tween.tween_interval(reveal_duration)
	(
		_tween
		. tween_property(_fade, "modulate:a", 1.0, fade_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	_tween.tween_interval(0.35)
	_tween.tween_callback(_finish_sequence)


func _reveal_scarecrow() -> void:
	if not is_instance_valid(scarecrow):
		_restore()
		return
	scarecrow.global_transform = _reveal.global_transform
	scarecrow.show()
	success_player.play()
	scarecrow_revealed.emit()


func _finish_sequence() -> void:
	sequence_finished.emit()
	_transitioning = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene_to_file(main_menu_scene_path)
	if error != OK:
		_transitioning = false
		_restore()
		push_warning("EndingBench: menu transition failed: %s" % error_string(error))


func _set_blink(amount: float) -> void:
	_top.anchor_bottom = amount * 0.5
	_bottom.anchor_top = 1.0 - amount * 0.5


func _save_and_disable(node: Node) -> void:
	_saved_nodes.append({"node": weakref(node), "mode": node.process_mode})
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_save_and_disable(child)


func _restore() -> void:
	if not _busy:
		return
	if is_instance_valid(_tween):
		_tween.kill()
	for entry in _saved_nodes:
		var node: Node = entry.node.get_ref()
		if is_instance_valid(node):
			node.process_mode = entry.mode
	_saved_nodes.clear()
	if is_instance_valid(_player):
		_player.global_transform = _old_player_transform
		_player.visible = _old_player_visible
	if is_instance_valid(scarecrow):
		if _spawned:
			scarecrow.queue_free()
			scarecrow = null
		else:
			scarecrow.global_transform = _scarecrow_transform
			scarecrow.visible = _scarecrow_visible
	_camera.current = false
	if is_instance_valid(_old_camera) and _old_camera.is_inside_tree():
		_old_camera.make_current()
	get_tree().paused = _old_paused
	Input.mouse_mode = _old_mouse as Input.MouseMode
	_ui.hide()
	_busy = false
	_spawned = false


func _exit_tree() -> void:
	if _busy and not _transitioning:
		_restore()

func _on_task_completed(task_id: StringName):
	if task_id != &"make_hot_choco":
		return

	if !completed_all_tasks and PlayerTasks.is_all_tasks_completed():
		completed_all_tasks = true
		PlayerTasks.add_task(sit_on_bench)
	