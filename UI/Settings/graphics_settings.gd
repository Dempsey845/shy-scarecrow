extends ColorRect
## Reusable scene-owned settings UI. Its host owns pause/cursor state.
signal closed

const FPS_VALUES := [0, 30, 60, 90, 120, 144, 240]
const TARGET_VALUES := [30, 60, 90, 120]
var _graphics: Node
@onready var _quality: OptionButton = %Quality
@onready var _resolution: HSlider = %ResolutionScale
@onready var _resolution_label: Label = %ResolutionLabel
@onready var _fps: OptionButton = %FPSLimit
@onready var _target: OptionButton = %DynamicTarget
@onready var _back: Button = %DoneButton
@onready var _note: Label = %SettingsNote
var _checks: Dictionary = {}
var _syncing: bool = false
var _slider_dirty: bool = false
var _timer: float = 0.0


func _ready() -> void:
	hide()
	_graphics = get_node_or_null("/root/GraphicsManager")
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
		_note.text = "Add GraphicsManager as an autoload to use graphics settings."


func open_settings() -> void:
	show()
	if is_instance_valid(_graphics):
		_sync_settings(_graphics.get_settings())
	_quality.grab_focus() if not _quality.disabled else _back.grab_focus()


func close_settings() -> void:
	if not visible:
		return
	_flush_slider()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_settings()
		get_viewport().set_input_as_handled()


func flush_pending() -> void:
	_flush_slider()


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


func _exit_tree() -> void:
	_flush_slider()


func _on_check_toggled(value: bool, key: String) -> void:
	_set_option(key, value)


func _on_fps_selected(index: int) -> void:
	_set_option("fps_limit", _fps.get_item_id(index))


func _on_target_selected(index: int) -> void:
	_set_option("target_fps", _target.get_item_id(index))
