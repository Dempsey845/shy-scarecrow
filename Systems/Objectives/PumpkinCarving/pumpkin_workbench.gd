class_name PumpkinWorkbench
extends StaticBody3D

signal task_completed(mask_image: Image)
signal carving_started
signal carving_ended

@export var transition_duration: float = 0.65
@export var carving_fov: float = 38.0
@export var completed := false
@onready var carving: PumpkinCarving = $PumpkinCarving
@onready var camera: Camera3D = $CarvingCamera
@onready var camera_pose: Marker3D = $CameraPose
@onready var tabletop: MeshInstance3D = $Tabletop

var active := false
var transitioning := false
var _player: CharacterBody3D
var _previous_camera: Camera3D
var _previous_mouse_mode: Input.MouseMode
var _locked_nodes: Array[Node] = []
var _previous_modes: Array[int] = []
var _camera_tween: Tween
@onready var _ui: CanvasLayer = $CarvingUI
@onready var _status: Label = $CarvingUI/Panel/Column/Status
@onready var _finish: Button = $CarvingUI/Panel/Column/Buttons/Finish
@onready var _guide: CheckButton = $CarvingUI/Panel/Column/Guide
var _painting := false
var _erase := false
var _finished_pending := false


func _ready() -> void:
	camera_pose.look_at($PumpkinCarving.global_position + Vector3(0, 0.38, 0), Vector3.UP)
	_ui.hide()
	carving.progress_changed.connect(_on_progress)
	tree_exiting.connect(_restore_immediately)


func can_interact(player: CharacterBody3D) -> bool:
	return not active and not transitioning and not completed and is_instance_valid(player)


func show_outline() -> void:
	tabletop.set_instance_shader_parameter("outline_strength", 1.0)


func hide_outline() -> void:
	tabletop.set_instance_shader_parameter("outline_strength", 0.0)


func interact(player: CharacterBody3D) -> void:
	if not can_interact(player):
		return
	_previous_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(_previous_camera):
		return
	_player = player
	_previous_mouse_mode = Input.mouse_mode
	_locked_nodes.clear()
	_previous_modes.clear()
	for node_name in ["PlayerMovement", "PlayerInteract"]:
		var node := player.get_node_or_null(NodePath(node_name))
		if node != null:
			_locked_nodes.append(node)
			_previous_modes.append(node.process_mode)
			node.process_mode = Node.PROCESS_MODE_DISABLED
	player.velocity = Vector3.ZERO
	hide_outline()
	active = true
	transitioning = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.global_transform = _previous_camera.global_transform.orthonormalized()
	camera.fov = _previous_camera.fov
	camera.make_current()
	carving_started.emit()
	_move_camera(camera_pose.global_transform.orthonormalized(), carving_fov, _on_entered)


func _on_entered() -> void:
	transitioning = false
	_ui.show()
	carving.set_guide(_guide.button_pressed)
	_on_progress(carving.coverage, carving.stray_ratio, carving.ready_to_finish)


func _move_camera(target: Transform3D, target_fov: float, callback: Callable) -> void:
	var start := camera.global_transform
	var start_fov := camera.fov
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(
		func(weight: float) -> void:
			camera.global_transform = start.interpolate_with(target, weight)
			camera.fov = lerpf(start_fov, target_fov, weight),
		0.0,
		1.0,
		transition_duration
	)
	_camera_tween.tween_callback(callback)


func leave() -> void:
	if not active or transitioning:
		return
	_end_stroke()
	transitioning = true
	_ui.hide()
	carving.set_guide(false)
	if is_instance_valid(_previous_camera):
		_move_camera(
			_previous_camera.global_transform.orthonormalized(), _previous_camera.fov, _on_left
		)
	else:
		_on_left()


func _on_left() -> void:
	_restore_controls()
	active = false
	transitioning = false
	carving_ended.emit()
	if _finished_pending:
		_finished_pending = false
		task_completed.emit(carving.export_mask())


func _restore_controls() -> void:
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	for i in _locked_nodes.size():
		if is_instance_valid(_locked_nodes[i]):
			_locked_nodes[i].process_mode = _previous_modes[i]
	_locked_nodes.clear()
	_previous_modes.clear()
	Input.mouse_mode = _previous_mouse_mode


func _restore_immediately() -> void:
	if not active:
		return
	if _camera_tween != null:
		_camera_tween.kill()
	_restore_controls()
	active = false
	transitioning = false


func _unhandled_input(event: InputEvent) -> void:
	if not active or transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			leave()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_end_stroke()
			carving.undo()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_painting = true
			_erase = event.button_index == MOUSE_BUTTON_RIGHT
			carving.begin_stroke()
			carving.carve_at(camera, event.position, _erase)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_player):
		_restore_immediately()
		_ui.hide()
		return
	if transitioning or not _painting:
		return
	var button := MOUSE_BUTTON_RIGHT if _erase else MOUSE_BUTTON_LEFT
	if not Input.is_mouse_button_pressed(button):
		_end_stroke()
		return
	if get_viewport().gui_get_hovered_control() == null:
		carving.carve_at(camera, get_viewport().get_mouse_position(), _erase)
	else:
		_end_stroke()


func _end_stroke() -> void:
	_painting = false
	carving.end_stroke()


func _complete() -> void:
	_end_stroke()

	if not carving.ready_to_finish or transitioning:
		return

	carving.material.set_shader_parameter("face_glowing", true)

	completed = true
	_finished_pending = true
	leave()


func _on_progress(value: Vector3, stray: float, ready: bool) -> void:
	_status.text = (
		"Left eye %d%%   Right eye %d%%   Smile %d%%\n%s"
		% [
			int(value.x * 100),
			int(value.y * 100),
			int(value.z * 100),
			(
				"Your friendly mask is ready!"
				if ready
				else (
					"Erase a few stray cuts outside the guide."
					if stray > carving.maximum_stray_ratio
					else "Carve inside the pale outlines to make a friendly face."
				)
			)
		]
	)
	_finish.disabled = not ready


func _on_guide_toggled(enabled: bool) -> void:
	carving.set_guide(enabled)


func _on_undo_pressed() -> void:
	_end_stroke()
	carving.undo()


func _on_reset_pressed() -> void:
	_end_stroke()
	carving.reset()
