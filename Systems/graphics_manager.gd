extends Node
## Autoload as GraphicsManager (do not add class_name with the same name).
## Godot 4.3+. Only optional decorative nodes are culled; gameplay is untouched.

signal settings_changed(settings: Dictionary)
signal render_scale_changed(scale: float)
signal settings_save_failed(error: int)

enum Mode { ULTRA_LOW, VERY_LOW, LOW, MEDIUM, HIGH, ULTRA }
const MODE_NAMES := ["Ultra Low", "Very Low", "Low", "Medium", "High", "Ultra"]
const SAVE_PATH := "user://graphics_settings.cfg"
const SAVE_VERSION := 1
const EFFECTS := [
	"glow_enabled",
	"ssao_enabled",
	"ssil_enabled",
	"ssr_enabled",
	"sdfgi_enabled",
	"volumetric_fog_enabled",
	"fog_enabled"
]
# Each row: scale, MSAA enum, LOD pixels, shadow size, shadow distance,
# particle fraction, decoration distance, anisotropy enum.
const ROWS := [
	[0.50, 0, 8.0, 512, 18.0, 0.0, 18.0, 0],
	[0.60, 0, 6.0, 512, 24.0, 0.20, 25.0, 0],
	[0.75, 0, 4.0, 1024, 35.0, 0.35, 40.0, 1],
	[0.85, 1, 2.5, 2048, 55.0, 0.60, 65.0, 2],
	[1.00, 2, 1.5, 4096, 80.0, 0.85, 90.0, 3],
	[1.00, 3, 1.0, 4096, 110.0, 1.0, 0.0, 4],
]

var current_mode: int = Mode.HIGH
var _overrides: Dictionary = {}
var _settings: Dictionary = {}
# Weak references prevent this registry from retaining old scenes/resources.
var _tracked: Dictionary = {}
var _property_cache: Dictionary = {}
var _resource_baselines: Dictionary = {}
var _last_frame_usec: int = 0
var _scale: float = 1.0
var _sample_time: float = 0.0
var _sample_frames: int = 0
var _slow_windows: int = 0
var _fast_windows: int = 0
var _warmup: float = 4.0
var _sweep_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	_rebuild_settings()
	apply_settings.call_deferred()
	print(current_mode)


func get_mode_names() -> Array:
	return MODE_NAMES.duplicate()


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_actual_render_scale() -> float:
	return get_tree().root.scaling_3d_scale


func get_renderer() -> String:
	return RenderingServer.get_current_rendering_method()


func set_mode(mode: int, persist: bool = true) -> void:
	current_mode = clampi(mode, Mode.ULTRA_LOW, Mode.ULTRA)
	_overrides.clear()
	_rebuild_settings()
	apply_settings()
	if persist:
		save_settings()


## Valid keys are those returned by get_settings(). Numeric values are clamped.
func set_option(key: String, value: Variant, persist: bool = true) -> bool:
	if not _settings.has(key) or key == "mode":
		return false
	if typeof(value) != typeof(_settings[key]):
		return false
	_overrides[key] = value
	_rebuild_settings()
	apply_settings()
	if persist:
		save_settings()
	return true


func reset_to_defaults() -> void:
	set_mode(Mode.VERY_LOW if OS.has_feature("web") else Mode.LOW)


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("graphics", "version", SAVE_VERSION)
	config.set_value("graphics", "mode", current_mode)
	config.set_value("graphics", "overrides", _overrides)
	var result := config.save(SAVE_PATH)
	if result != OK:
		settings_save_failed.emit(result)
		push_warning("Graphics settings could not be saved: %s" % error_string(result))
	return result


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	if config.get_value("graphics", "version", 0) != SAVE_VERSION:
		return
	var mode_value: Variant = config.get_value("graphics", "mode", current_mode)
	if typeof(mode_value) == TYPE_INT:
		current_mode = clampi(mode_value, Mode.ULTRA_LOW, Mode.ULTRA)
	var custom: Variant = config.get_value("graphics", "overrides", {})
	if custom is Dictionary:
		_overrides = custom.duplicate(true)


func _rebuild_settings() -> void:
	var row: Array = ROWS[current_mode]
	_settings = {
		"mode": current_mode,
		"render_scale": float(row[0]),
		"msaa": int(row[1]),
		"lod_threshold": float(row[2]),
		"shadow_size": int(row[3]),
		"shadow_distance": float(row[4]),
		"particles": float(row[5]),
		"decoration_distance": float(row[6]),
		"anisotropy": int(row[7]),
		"directional_shadows": current_mode >= Mode.LOW,
		"local_shadows": current_mode >= Mode.MEDIUM,
		"glow": current_mode >= Mode.MEDIUM,
		"ssao": current_mode >= Mode.MEDIUM,
		"ssil": current_mode >= Mode.HIGH,
		"ssr": current_mode >= Mode.HIGH,
		"sdfgi": current_mode >= Mode.ULTRA,
		"volumetric_fog": current_mode >= Mode.HIGH,
		"fog": current_mode >= Mode.LOW,
		"debanding": current_mode >= Mode.MEDIUM,
		"decorative_lights": current_mode >= Mode.LOW,
		"decals": current_mode >= Mode.MEDIUM,
		"reflection_probes": current_mode >= Mode.MEDIUM,
		"dof": current_mode >= Mode.HIGH,
		"fps_limit": 240,
		"vsync": true,
		"dynamic_resolution": false,
		"target_fps": 30 if current_mode <= Mode.LOW else 60,
		"minimum_scale": 0.40,
		"max_3d_pixels": [518400, 921600, 1280000, 2073600, 0, 0][current_mode],
	}
	for key in _overrides:
		if key != "mode" and _settings.has(key):
			if typeof(_overrides[key]) == typeof(_settings[key]):
				_settings[key] = _overrides[key]
	_settings.render_scale = clampf(_settings.render_scale, 0.4, 1.0)
	_settings.minimum_scale = clampf(_settings.minimum_scale, 0.4, _settings.render_scale)
	_settings.max_3d_pixels = clampi(_settings.max_3d_pixels, 0, 8294400)
	_settings.msaa = clampi(_settings.msaa, 0, 3)
	_settings.anisotropy = clampi(_settings.anisotropy, 0, 4)
	_settings.lod_threshold = clampf(_settings.lod_threshold, 1.0, 16.0)
	_settings.shadow_distance = clampf(_settings.shadow_distance, 5.0, 200.0)
	_settings.shadow_size = _nearest_shadow_size(_settings.shadow_size)
	_settings.particles = clampf(_settings.particles, 0.0, 1.0)
	_settings.decoration_distance = clampf(_settings.decoration_distance, 0.0, 300.0)
	_settings.fps_limit = clampi(_settings.fps_limit, 0, 240)
	_settings.target_fps = clampi(_settings.target_fps, 20, 120)
	if _settings.fps_limit > 0:
		_settings.target_fps = mini(_settings.target_fps, _settings.fps_limit)
	# Forward+ only features must not be enabled on Mobile/Compatibility.
	if get_renderer() != "forward_plus":
		for key in ["ssao", "ssil", "ssr", "sdfgi", "volumetric_fog", "dof"]:
			_settings[key] = false
	if get_renderer() == "gl_compatibility":
		_settings.debanding = false
		_settings.decals = false


func _nearest_shadow_size(value: int) -> int:
	for size in [512, 1024, 2048, 4096]:
		if value <= size:
			return size
	return 4096


func apply_settings() -> void:
	if not is_inside_tree():
		return
	Engine.max_fps = _settings.fps_limit
	# Browsers own presentation timing; VSync cannot be controlled there.
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if _settings.vsync else DisplayServer.VSYNC_DISABLED
		)
	RenderingServer.directional_shadow_atlas_set_size(_settings.shadow_size, true)
	if get_renderer() == "forward_plus":
		var quality: int = 0 if current_mode <= Mode.LOW else 1
		if current_mode >= Mode.HIGH:
			quality = 2
		RenderingServer.directional_soft_shadow_filter_set_quality(quality)
		RenderingServer.positional_soft_shadow_filter_set_quality(quality)
	_scale = _settings.render_scale
	_reset_sampling()
	# Only traverse on settings changes, not every frame.
	_scan(get_tree().root)
	settings_changed.emit(get_settings())


func _scan(node: Node) -> void:
	_register(node)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	# Scene resources and groups are ready before the deferred callback.
	_register.call_deferred(node)


func _on_node_removed(node: Node) -> void:
	_tracked.erase(node.get_instance_id())


## Call after assigning groups at runtime or swapping an Environment resource.
func refresh_node(node: Node) -> void:
	if is_instance_valid(node):
		_register(node)


## Explicitly re-capture authored values after changing a managed property.
## Set desired values first, then call this. Do not call on every day/night tick.
func recapture_node(node: Node) -> void:
	if is_instance_valid(node):
		_tracked.erase(node.get_instance_id())
		_register(node)


func _register(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or _settings.is_empty():
		return
	if node.is_in_group("graphics_ignore"):
		return
	var relevant: bool = node is Viewport or node is WorldEnvironment or node is Light3D
	relevant = relevant or node is Camera3D
	relevant = relevant or node.is_in_group("graphics_decoration")
	relevant = relevant or node.is_in_group("graphics_no_shadow_low")
	relevant = relevant or node.is_in_group("graphics_optional_particles")
	relevant = relevant or node is Decal or node is ReflectionProbe
	relevant = relevant or node.is_in_group("graphics_optional")
	if not relevant:
		return
	var id := node.get_instance_id()
	if not _tracked.has(id):
		_tracked[id] = {"ref": weakref(node), "values": {}}
		if node is Viewport:
			node.size_changed.connect(_on_viewport_resized.bind(weakref(node)))
	var entry: Dictionary = _tracked[id]
	if node is Viewport:
		_apply_viewport(node)
	if node is WorldEnvironment:
		_apply_environment(node, entry)
	if node is Camera3D:
		_apply_camera(node, entry)
	if node is Light3D:
		_limit(
			node,
			entry.values,
			"shadow_enabled",
			_settings.directional_shadows if node is DirectionalLight3D else _settings.local_shadows
		)
		if node is DirectionalLight3D:
			var authored: float = _original(node, entry.values, "directional_shadow_max_distance")
			# An authored zero means unlimited; low modes impose a finite range.
			node.directional_shadow_max_distance = (
				minf(authored, _settings.shadow_distance)
				if authored > 0.0
				else _settings.shadow_distance
			)
			_original(node, entry.values, "directional_shadow_mode")
			node.directional_shadow_mode = (
				0 if current_mode <= Mode.LOW else entry.values.directional_shadow_mode
			)
		if node.is_in_group("graphics_decorative_light"):
			_limit(node, entry.values, "visible", _settings.decorative_lights)
	if node is Decal:
		_limit(node, entry.values, "visible", _settings.decals)
	if node is ReflectionProbe:
		_limit(node, entry.values, "visible", _settings.reflection_probes)
	if node is GeometryInstance3D:
		if node.is_in_group("graphics_no_shadow_low"):
			var authored_shadow: int = _original(node, entry.values, "cast_shadow")
			node.cast_shadow = 0 if current_mode <= Mode.LOW else authored_shadow
		if node.is_in_group("graphics_decoration"):
			_apply_decoration(node, entry.values)
	if node.is_in_group("graphics_optional"):
		var minimum: int = clampi(int(node.get_meta("graphics_min_mode", Mode.MEDIUM)), 0, 5)
		_limit(node, entry.values, "visible", current_mode >= minimum)
	if node.is_in_group("graphics_optional_particles"):
		_apply_particles(node, entry.values)


func _apply_viewport(viewport: Viewport) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = _viewport_scale(viewport)
	viewport.msaa_3d = _settings.msaa
	viewport.use_taa = false
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.mesh_lod_threshold = _settings.lod_threshold
	viewport.anisotropic_filtering_level = _settings.anisotropy
	viewport.use_debanding = _settings.debanding
	viewport.positional_shadow_atlas_size = _settings.shadow_size if _settings.local_shadows else 0
	if get_renderer() != "gl_compatibility":
		_safe_set(viewport, "texture_mipmap_bias", 0.75 if current_mode <= Mode.LOW else 0.0)


func _viewport_scale(viewport: Viewport) -> float:
	var size := viewport.get_visible_rect().size
	var pixels: float = maxf(1.0, size.x * size.y)
	var cap: int = _settings.max_3d_pixels
	if cap > 0:
		return clampf(minf(_scale, sqrt(float(cap) / pixels)), 0.1, 1.0)
	return _scale


func _on_viewport_resized(reference: WeakRef) -> void:
	var viewport: Viewport = reference.get_ref()
	if is_instance_valid(viewport):
		viewport.scaling_3d_scale = _viewport_scale(viewport)


func _apply_environment(node: WorldEnvironment, entry: Dictionary) -> void:
	var env := node.environment
	if env == null:
		return
	var previous: Object = entry.get("environment_ref", null)
	if previous == null or previous.get_ref() != env:
		entry.environment_ref = weakref(env)
		entry.environment_values = _resource_values(env)
	var baseline: Dictionary = entry.environment_values
	var keys := ["glow", "ssao", "ssil", "ssr", "sdfgi", "volumetric_fog", "fog"]
	for index in range(EFFECTS.size()):
		_limit(env, baseline, EFFECTS[index], _settings[keys[index]])
	# Keep sky, ambient light, exposure and autumn grading untouched.


func _apply_camera(camera: Camera3D, entry: Dictionary) -> void:
	var attributes := camera.attributes
	if attributes == null or not attributes is CameraAttributesPractical:
		return
	var previous: Object = entry.get("attributes_ref", null)
	if previous == null or previous.get_ref() != attributes:
		entry.attributes_ref = weakref(attributes)
		entry.attributes_values = _resource_values(attributes)
	for property in ["dof_blur_far_enabled", "dof_blur_near_enabled"]:
		_limit(attributes, entry.attributes_values, property, _settings.dof)


func _apply_decoration(node: GeometryInstance3D, baseline: Dictionary) -> void:
	var authored: float = _original(node, baseline, "visibility_range_end")
	var distance: float = _settings.decoration_distance
	if distance > 0.0 and authored > 0.0:
		distance = minf(distance, authored)
	elif distance <= 0.0:
		distance = authored
	# A range ending before its start would hide the object at every distance.
	if distance > 0.0 and distance <= node.visibility_range_begin:
		distance = node.visibility_range_begin + 1.0
	node.visibility_range_end = distance
	_original(node, baseline, "visibility_range_end_margin")
	node.visibility_range_end_margin = (
		minf(2.0, distance * 0.1) if distance > 0.0 else baseline.visibility_range_end_margin
	)


func _apply_particles(node: Node, baseline: Dictionary) -> void:
	if not (node is GPUParticles3D or node is CPUParticles3D):
		return
	var fraction: float = _settings.particles
	# Freeze only tagged cosmetic emitters. No change to emitting/one-shot state.
	var authored_process: int = _original(node, baseline, "process_mode")
	node.process_mode = Node.PROCESS_MODE_DISABLED if fraction <= 0.0 else authored_process
	_limit(node, baseline, "visible", fraction > 0.0)
	if node is GPUParticles3D:
		var ratio: float = _original(node, baseline, "amount_ratio")
		node.amount_ratio = ratio * fraction
	else:
		var amount: int = _original(node, baseline, "amount")
		var desired: int = maxi(1, int(round(amount * fraction)))
		if node.amount != desired:
			node.amount = desired


func _resource_values(resource: Resource) -> Dictionary:
	var id := resource.get_instance_id()
	if not _resource_baselines.has(id):
		_resource_baselines[id] = {"ref": weakref(resource), "values": {}}
	return _resource_baselines[id].values


func _original(object: Object, baseline: Dictionary, property: String) -> Variant:
	if not baseline.has(property):
		baseline[property] = object.get(property)
	return baseline[property]


func _limit(object: Object, baseline: Dictionary, property: String, allowed: bool) -> void:
	if _has_property(object, property):
		object.set(property, bool(_original(object, baseline, property)) and allowed)


func _has_property(object: Object, property: String) -> bool:
	var type_name := object.get_class()
	if not _property_cache.has(type_name):
		var properties: Dictionary = {}
		for item in object.get_property_list():
			properties[item.name] = true
		_property_cache[type_name] = properties
	return _property_cache[type_name].has(property)


func _safe_set(object: Object, property: String, value: Variant) -> void:
	if _has_property(object, property):
		object.set(property, value)


func _reset_sampling() -> void:
	_sample_time = 0.0
	_sample_frames = 0
	_slow_windows = 0
	_fast_windows = 0
	_warmup = 4.0


func _process(_delta: float) -> void:
	# Real frame time is independent of Engine.time_scale and pause state.
	var now := Time.get_ticks_usec()
	var frame_time: float = (
		float(now - _last_frame_usec) / 1000000.0 if _last_frame_usec > 0 else 0.0
	)
	_last_frame_usec = now
	_sweep_elapsed += frame_time
	if _sweep_elapsed >= 2.0:
		_sweep_elapsed = 0.0
		for resource_id in _resource_baselines.keys():
			if _resource_baselines[resource_id].ref.get_ref() == null:
				_resource_baselines.erase(resource_id)
		# Detect resource swaps and enforce effect caps if another script re-enables them.
		for id in _tracked.keys():
			var entry: Dictionary = _tracked[id]
			var node: Node = entry.ref.get_ref()
			if not is_instance_valid(node):
				_tracked.erase(id)
			elif node is WorldEnvironment:
				_apply_environment(node, entry)
			elif node is Camera3D:
				_apply_camera(node, entry)
	if not _settings.get("dynamic_resolution", false) or get_tree().paused:
		return
	# Do not react to background tabs, loading stalls, or unfocused desktop windows.
	if (
		frame_time > 0.25
		or (DisplayServer.get_name() != "headless" and not get_window().has_focus())
	):
		_reset_sampling()
		return
	if _warmup > 0.0:
		_warmup -= frame_time
		return
	_sample_time += frame_time
	_sample_frames += 1
	if _sample_time < 2.0:
		return
	var fps: float = float(_sample_frames) / _sample_time
	_sample_time = 0.0
	_sample_frames = 0
	var target: float = _settings.target_fps
	_slow_windows = _slow_windows + 1 if fps < target * 0.88 else 0
	_fast_windows = _fast_windows + 1 if fps >= target * 0.97 else 0
	var desired := _scale
	if _slow_windows >= 2:
		desired = maxf(_settings.minimum_scale, _scale - 0.05)
		_slow_windows = 0
	elif _fast_windows >= 5:
		desired = minf(_settings.render_scale, _scale + 0.025)
		_fast_windows = 0
	if not is_equal_approx(desired, _scale):
		_scale = desired
		for entry in _tracked.values():
			var node: Node = entry.ref.get_ref()
			if is_instance_valid(node) and node is Viewport:
				node.scaling_3d_scale = _viewport_scale(node)
		render_scale_changed.emit(get_actual_render_scale())


## UI/debug information. These counters describe the root viewport only.
func get_diagnostics() -> Dictionary:
	var viewport := get_tree().root
	return {
		"mode": MODE_NAMES[current_mode],
		"renderer": get_renderer(),
		"web": OS.has_feature("web"),
		"fps": Engine.get_frames_per_second(),
		"render_scale": get_actual_render_scale(),
		"tracked_nodes": _tracked.size(),
		"draw_calls":
		viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
		),
		"primitives":
		viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME
		)
	}
