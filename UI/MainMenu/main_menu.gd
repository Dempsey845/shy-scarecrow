extends Node3D

@export_file("*.tscn") var game_scene_path: String = "res://World/world.tscn"

const FPS_VALUES := [0, 30, 60, 90, 120, 144, 240]
const TARGET_VALUES := [30, 60, 90, 120]

var _graphics: Node

@onready var _main: Control = %MainPanel
@onready var _overlay: ColorRect = %SettingsOverlay
@onready var _dialog: ConfirmationDialog = %QuitDialog
@onready var _quality: OptionButton = %Quality
@onready var _resolution: HSlider = %ResolutionScale
@onready var _resolution_label: Label = %ResolutionLabel
@onready var _fps: OptionButton = %FPSLimit
@onready var _target: OptionButton = %DynamicTarget

var _checks: Dictionary = {}

@onready var _status: Label = %StatusLabel
@onready var _play: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _back: Button = %DoneButton

var _syncing: bool = false
var _slider_dirty: bool = false
var _timer: float = 0.0
var _quitting: bool = false
var _starting: bool = false


func _ready() -> void:
	_graphics = get_node_or_null("/root/GraphicsManager")
	_overlay.hide()
	_main.show()
	_checks = {
		"directional_shadows": %DirectionalShadows,
		"local_shadows": %LocalShadows,
		"fog": %Fog,
		"glow": %Glow,
		"ssao": %Ssao,
		"dynamic_resolution": %DynamicResolution,
		"vsync": %Vsync
	}
	if _graphics != null and _graphics.has_method("get_settings"):
		_graphics.settings_changed.connect(_sync_settings)
		_graphics.settings_save_failed.connect(_on_save_failed)
		_sync_settings(_graphics.get_settings())
	else:
		_graphics = null
		_set_settings_enabled(false)
	_play.grab_focus()


func _open_settings() -> void:
	_main.hide()
	_overlay.show()
	if _graphics != null:
		_sync_settings(_graphics.get_settings())
	_quality.grab_focus() if not _quality.disabled else _back.grab_focus()


func _close_settings() -> void:
	_flush_slider()
	_overlay.hide()
	_main.show()
	_settings_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay.visible:
			_close_settings()
		else:
			_request_quit()
		get_viewport().set_input_as_handled()


func _select_quality(index: int) -> void:
	if _syncing or _graphics == null:
		return
	_flush_slider()
	var previous: Dictionary = _graphics.get_settings()
	_graphics.set_mode(index, false)
	# The user's frame pacing choice is independent of graphics quality.
	for key in ["fps_limit", "vsync", "dynamic_resolution", "target_fps"]:
		_graphics.set_option(key, previous[key], false)
	_graphics.save_settings()
	_sync_settings(_graphics.get_settings())


func _set_option(key: String, value: Variant) -> void:
	if not _syncing and _graphics != null:
		_graphics.set_option(key, value)


func _set_resolution(value: float) -> void:
	if _syncing or _graphics == null:
		return
	_graphics.set_option("render_scale", value / 100.0, false)
	_slider_dirty = true
	_timer = 0.0


func _on_resolution_drag_ended(_changed: bool) -> void:
	_flush_slider()


func _flush_slider() -> void:
	if _slider_dirty and is_instance_valid(_graphics):
		_slider_dirty = false
		_graphics.save_settings()


func _process(delta: float) -> void:
	if _slider_dirty:
		_timer += delta
		if _timer >= 0.5:
			_flush_slider()


func _sync_settings(settings: Dictionary) -> void:
	if not is_instance_valid(_quality):
		return
	_syncing = true
	_quality.select(settings.mode)
	_resolution.set_value_no_signal(settings.render_scale * 100.0)
	_resolution_label.text = "3D resolution · %d%%" % int(round(settings.render_scale * 100.0))
	_select_value(_fps, FPS_VALUES, settings.fps_limit)
	_select_value(_target, TARGET_VALUES, settings.target_fps)
	for key in _checks:
		_checks[key].set_pressed_no_signal(settings[key])
	var forward: bool = _graphics.get_renderer() == "forward_plus"
	_checks.ssao.disabled = not forward
	_checks.ssao.tooltip_text = (
		"Available with Forward+ rendering."
		if not forward
		else "Adds soft contact shading where objects meet."
	)
	_checks.vsync.disabled = OS.has_feature("web")
	_checks.vsync.tooltip_text = (
		"Your browser controls display synchronization."
		if OS.has_feature("web")
		else "Synchronizes frames with your display."
	)
	_target.disabled = not settings.dynamic_resolution
	_syncing = false


func _select_value(option: OptionButton, values: Array, value: int) -> void:
	var index := values.find(value)
	# Preserve custom values saved by another options screen or script.
	if index < 0:
		var label_text := "%d FPS (custom)" % value
		index = values.size()
		if option.item_count == index:
			option.add_item(label_text, value)
		else:
			option.set_item_text(index, label_text)
			option.set_item_id(index, value)
	option.select(index)


func _set_settings_enabled(enabled: bool) -> void:
	_quality.disabled = not enabled
	_resolution.editable = enabled
	_fps.disabled = not enabled
	_target.disabled = not enabled
	for check in _checks.values():
		check.disabled = not enabled


func _reset_graphics() -> void:
	if _graphics == null:
		return
	_flush_slider()
	var before: Dictionary = _graphics.get_settings()
	_graphics.set_mode(1 if OS.has_feature("web") else 2, false)
	for key in ["fps_limit", "vsync"]:
		_graphics.set_option(key, before[key], false)
	_graphics.save_settings()


func _on_save_failed(_error: int) -> void:
	pass


func _start_game() -> void:
	if _starting:
		return
	_flush_slider()
	var path := game_scene_path
	if not ResourceLoader.exists(path) and path == "res://World/world.tscn":
		for candidate in ["res://world.tscn", "res://World/World.tscn"]:
			if ResourceLoader.exists(candidate):
				path = candidate
				break
	if not ResourceLoader.exists(path):
		_status.text = "Set Game Scene Path on MainMenu to your world scene."
		return
	_starting = true
	_play.disabled = true
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		_starting = false
		_play.disabled = false
		_status.text = "Could not open the game scene. Please check its path."


func _request_quit() -> void:
	if OS.has_feature("web"):
		_status.text = "Thanks for playing — close this browser tab to leave."
		return
	_dialog.popup_centered(Vector2i(360, 160))


func _confirm_quit() -> void:
	if _quitting:
		return
	_quitting = true
	_flush_slider()
	get_tree().quit()


func _exit_tree() -> void:
	_flush_slider()


func _on_check_toggled(value: bool, key: String) -> void:
	_set_option(key, value)


func _on_fps_selected(index: int) -> void:
	_set_option("fps_limit", _fps.get_item_id(index))


func _on_target_selected(index: int) -> void:
	_set_option("target_fps", _target.get_item_id(index))
