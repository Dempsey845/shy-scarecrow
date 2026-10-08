class_name DayNightCycle
extends Node3D

signal time_changed(hour: float)

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D
@export_range(0.0, 24.0, 0.01) var start_hour: float = 9.0
@export_range(10.0, 7200.0, 1.0) var cycle_duration_seconds: float = 600.0
@export var running: bool = true
@export_range(0.0, 360.0, 1.0) var sun_path_rotation: float = 25.0
@export_range(0.0, 4.0, 0.01) var sun_energy: float = 1.1
@export_range(0.0, 1.0, 0.01) var moon_energy: float = 0.15
@export_range(0.0, 2.0, 0.01) var day_ambient_energy: float = 0.45
@export_range(0.0, 1.0, 0.01) var night_ambient_energy: float = 0.18
@export var cloud_speed: float = 0.012

const SKY_SHADER = preload("uid://10lice7qhj2k")

var current_hour: float = 9.0
var _environment: Environment
var _material: ShaderMaterial
var _cloud_offset: float = 0.0

func _ready() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(sun_light):
		push_error("DayNightCycle: assign WorldEnvironment and Sun Light in the Inspector.")
		set_process(false)
		return
	if sun_light == moon_light:
		push_error("DayNightCycle: Sun Light and Moon Light must be different nodes.")
		set_process(false)
		return

	if world_environment.environment:
		_environment = world_environment.environment.duplicate() as Environment
	else:
		_environment = Environment.new()
	world_environment.environment = _environment
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_sky_contribution = 0.0

	var sky_resource := Sky.new()
	sky_resource.process_mode = Sky.PROCESS_MODE_REALTIME
	sky_resource.radiance_size = Sky.RADIANCE_SIZE_256
	_material = ShaderMaterial.new()
	_material.shader = SKY_SHADER
	sky_resource.sky_material = _material
	_environment.sky = sky_resource
	_environment.sky_rotation = Vector3.ZERO
	set_hour(start_hour)

func _process(delta: float) -> void:
	if not running:
		return
	current_hour = fposmod(current_hour + delta * 24.0 / maxf(cycle_duration_seconds, 0.01), 24.0)
	_cloud_offset = fposmod(_cloud_offset + delta * cloud_speed, 1000.0)
	_update_cycle()
	time_changed.emit(current_hour)

func set_hour(hour: float) -> void:
	current_hour = fposmod(hour, 24.0)
	if _material:
		_update_cycle()
		time_changed.emit(current_hour)

func _update_cycle() -> void:
	# Sunrise: 06:00. Noon: 12:00. Sunset: 18:00.
	var angle := (current_hour / 24.0) * TAU - PI * 0.5
	var sun_direction := Vector3(cos(angle), sin(angle), 0.0)
	sun_direction = sun_direction.rotated(Vector3.UP, deg_to_rad(sun_path_rotation))
	var altitude := sun_direction.y
	var daylight := smoothstep(-0.16, 0.20, altitude)
	var sunset := (1.0 - smoothstep(0.0, 0.35, absf(altitude))) * smoothstep(-0.20, 0.0, altitude)

	_material.set_shader_parameter("sun_direction", sun_direction)
	_material.set_shader_parameter("daylight", daylight)
	_material.set_shader_parameter("sunset", sunset)
	_material.set_shader_parameter("cloud_offset", _cloud_offset)

	_orient_light(sun_light, sun_direction)
	sun_light.light_energy = sun_energy * smoothstep(-0.02, 0.18, altitude)
	sun_light.light_color = Color("ffe8c3").lerp(Color("ffac70"), sunset)
	sun_light.visible = sun_light.light_energy > 0.001

	if is_instance_valid(moon_light):
		_orient_light(moon_light, -sun_direction)
		moon_light.light_energy = moon_energy * smoothstep(0.0, 0.20, -altitude)
		moon_light.light_color = Color("b6c9ff")
		moon_light.visible = moon_light.light_energy > 0.001

	_environment.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight)
	var ambient_color := Color("777baf").lerp(Color("fff0d5"), daylight)
	_environment.ambient_light_color = ambient_color.lerp(Color("ffc393"), sunset * 0.45)

func _orient_light(light: DirectionalLight3D, direction_to_body: Vector3) -> void:
	# Directional lights shine along local -Z; +Z points towards the sky disc.
	var up := Vector3.UP
	if absf(direction_to_body.dot(up)) > 0.99:
		up = Vector3.FORWARD
	light.global_basis = Basis.looking_at(-direction_to_body, up)
