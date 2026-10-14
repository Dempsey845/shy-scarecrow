extends ColorRect
## Reusable scene-owned settings UI. Its host owns pause/cursor state.
signal closed

const AUDIO_SAVE_PATH := "user://audio_settings.cfg"
const AUDIO_BUSES := [&"Master", &"SFX", &"Music"]
var _audio_sliders: Dictionary = {}
var _audio_labels: Dictionary = {}
var _audio_dirty: bool = false
var _audio_timer: float = 0.0

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
	_setup_audio_settings()
	UISounds.bind_controls(self)
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
	if visible:
		return
	UISounds.play("open")
	_sync_audio_controls()
	show()
	if is_instance_valid(_graphics):
		_sync_settings(_graphics.get_settings())
	_quality.grab_focus() if not _quality.disabled else _back.grab_focus()


func close_settings() -> void:
	if not visible:
		return
	_flush_slider()
	UISounds.play("back")
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
	_save_audio_settings()
	if _slider_dirty and is_instance_valid(_graphics):
		_slider_dirty = false
		_graphics.save_settings()


func _process(delta: float) -> void:
	if _audio_dirty:
		_audio_timer += delta
		if _audio_timer >= 0.35:
			_save_audio_settings()
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
	UISounds.play("error")


func _exit_tree() -> void:
	_flush_slider()


func _on_check_toggled(value: bool, key: String) -> void:
	_set_option(key, value)


func _on_fps_selected(index: int) -> void:
	_set_option("fps_limit", _fps.get_item_id(index))


func _on_target_selected(index: int) -> void:
	_set_option("target_fps", _target.get_item_id(index))


func _setup_audio_settings() -> void:
	_audio_sliders = {&"Master": %MasterVolume, &"SFX": %SFXVolume, &"Music": %MusicVolume}
	_audio_labels = {&"Master": %MasterVolumeLabel, &"SFX": %SFXVolumeLabel, &"Music": %MusicVolumeLabel}
	var config := ConfigFile.new()
	_apply_audio_volume(&"Music", 15.0)
	if config.load(AUDIO_SAVE_PATH) == OK:
		for bus in AUDIO_BUSES:
			var saved: Variant = config.get_value("volume", String(bus), null)
			if saved is float or saved is int:
				var level: float = float(saved)
				if is_finite(level):
					_apply_audio_volume(bus, clampf(level, 0.0, 100.0))
	_sync_audio_controls()


func _apply_audio_volume(bus: StringName, percent: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent / 100.0, 0.0001)))
	AudioServer.set_bus_mute(index, percent <= 0.0)


func _audio_percent(bus: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0, 0.0, 100.0)


func _sync_audio_controls() -> void:
	for bus in AUDIO_BUSES:
		var available: bool = AudioServer.get_bus_index(bus) >= 0
		var percent: float = _audio_percent(bus)
		_audio_sliders[bus].editable = available
		_audio_sliders[bus].set_value_no_signal(percent)
		_audio_labels[bus].text = "%s · %d%%" % [String(bus), roundi(percent)] if available else "%s · unavailable" % String(bus)
		_audio_sliders[bus].tooltip_text = "Adjust %s volume" % String(bus) if available else "Add a %s audio bus to enable this control." % String(bus)


func _on_audio_volume_changed(value: float, bus: StringName) -> void:
	_apply_audio_volume(bus, value)
	_audio_labels[bus].text = "%s · %d%%" % [String(bus), roundi(value)]
	_audio_dirty = true
	_audio_timer = 0.0


func _on_audio_drag_ended(_changed: bool) -> void:
	_save_audio_settings()


func _save_audio_settings() -> void:
	if not _audio_dirty:
		return
	var config := ConfigFile.new()
	# Preserve any unavailable bus's saved level.
	config.load(AUDIO_SAVE_PATH)
	for bus in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			config.set_value("volume", String(bus), _audio_percent(bus))
	var error: Error = config.save(AUDIO_SAVE_PATH)
	_audio_dirty = false
	if error != OK and is_instance_valid(_note):
		_note.text = "Audio changes applied, but could not be saved."


func _reset_audio() -> void:
	for bus in AUDIO_BUSES:
		_apply_audio_volume(bus, 100.0)
	_apply_audio_volume(&"Music", 15.0)
	_sync_audio_controls()
	_audio_dirty = true
	_save_audio_settings()
