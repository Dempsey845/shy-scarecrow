class_name PumpkinCarving
extends Node3D

signal progress_changed(coverage: Vector3, stray_ratio: float, ready: bool)

const SIZE := 256
const FACE_SIZE := Vector2(0.72, 0.56)
const MAX_UNDO := 20

@export_range(0.005, 0.08) var brush_radius: float = 0.022
@export_range(0.1, 1.0) var required_coverage: float = 0.72
@export_range(0.0, 1.0) var maximum_stray_ratio: float = 0.22
@onready var shell: MeshInstance3D = $PumpkinVisual/MeshInstance3D

var mask: Image
var mask_texture: ImageTexture
var guide_texture: ImageTexture
var material: ShaderMaterial
var ready_to_finish := false
var coverage := Vector3.ZERO
var stray_ratio := 0.0
var _target := PackedByteArray()
var _totals := Vector3.ZERO
var _undo: Array[Image] = []
var _vertices := PackedVector3Array()
var _shaped := PackedVector3Array()
var _indices := PackedInt32Array()
var _last_uv := Vector2(-1, -1)
var _stroke_active := false
var _dirty := false


func _ready() -> void:
	var source := shell.get_active_material(0) as ShaderMaterial
	material = source.duplicate() as ShaderMaterial
	material.shader = preload("uid://so1kmm3rbjf3")
	shell.material_override = material
	
	mask = Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	mask.fill(Color.BLACK)
	mask_texture = ImageTexture.create_from_image(mask)
	_build_target()
	material.set_shader_parameter("carve_mask", mask_texture)
	material.set_shader_parameter("face_guide", guide_texture)
	material.set_shader_parameter("face_size", FACE_SIZE)
	_cache_mesh()
	_update_progress()


func _process(_delta: float) -> void:
	if _dirty:
		mask_texture.update(mask)
		_dirty = false


func set_guide(enabled: bool) -> void:
	material.set_shader_parameter("show_guide", enabled)


func begin_stroke() -> void:
	if _stroke_active:
		return
	_undo.append(mask.duplicate())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_stroke_active = true
	_last_uv = Vector2(-1, -1)


func end_stroke() -> void:
	if not _stroke_active:
		return
	_stroke_active = false
	_last_uv = Vector2(-1, -1)
	_update_progress()


func carve_at(camera: Camera3D, screen_position: Vector2, erase: bool) -> void:
	var uv := _pick_uv(camera, screen_position)
	if uv.x < 0.0:
		_last_uv = Vector2(-1, -1)
		return
	if _last_uv.x >= 0.0 and _last_uv.distance_to(uv) < 0.15:
		var steps := maxi(1, int(ceil(_last_uv.distance_to(uv) / (brush_radius * 0.4))))
		for i in range(1, steps + 1):
			_stamp(_last_uv.lerp(uv, float(i) / steps), erase)
	else:
		_stamp(uv, erase)
	_last_uv = uv
	_dirty = true


func undo() -> void:
	end_stroke()
	if _undo.is_empty():
		return
	mask = _undo.pop_back()
	mask_texture.update(mask)
	_update_progress()


func reset() -> void:
	end_stroke()
	_undo.append(mask.duplicate())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	mask.fill(Color.BLACK)
	mask_texture.update(mask)
	_update_progress()


func export_mask() -> Image:
	return mask.duplicate()


func apply_to_visual(visual: Node3D) -> void:
	var target_mesh := visual.get_node("MeshInstance3D") as MeshInstance3D
	var target_material := material.duplicate() as ShaderMaterial
	target_material.set_shader_parameter(
		"carve_mask", ImageTexture.create_from_image(export_mask())
	)
	target_material.set_shader_parameter("show_guide", false)
	target_mesh.material_override = target_material
	target_mesh.material_overlay = null


func _stamp(uv: Vector2, erase: bool) -> void:
	var centre := uv * SIZE
	var radius := brush_radius * SIZE
	for y in range(maxi(0, int(centre.y - radius)), mini(SIZE, int(ceil(centre.y + radius)) + 1)):
		for x in range(
			maxi(0, int(centre.x - radius)), mini(SIZE, int(ceil(centre.x + radius)) + 1)
		):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(centre) <= radius * radius:
				mask.set_pixel(x, y, Color.BLACK if erase else Color.WHITE)


func _region(uv: Vector2) -> int:
	if ((uv - Vector2(0.29, 0.33)) / Vector2(0.085, 0.105)).length_squared() <= 1.0:
		return 1
	if ((uv - Vector2(0.71, 0.33)) / Vector2(0.085, 0.105)).length_squared() <= 1.0:
		return 2
	var x := (uv.x - 0.5) / 0.29
	var smile_y := 0.72 - 0.14 * x * x
	if absf(x) < 1.0 and absf(uv.y - smile_y) < 0.037:
		return 3
	return 0


func _build_target() -> void:
	_target.resize(SIZE * SIZE)
	var guide := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	guide.fill(Color.BLACK)
	for y in SIZE:
		for x in SIZE:
			var region := _region(Vector2(x + 0.5, y + 0.5) / SIZE)
			_target[y * SIZE + x] = region
			if region > 0:
				_totals[region - 1] += 1.0
	for y in range(2, SIZE - 2):
		for x in range(2, SIZE - 2):
			var r := _target[y * SIZE + x]
			if (
				r > 0
				and (
					_target[y * SIZE + x - 2] != r
					or _target[y * SIZE + x + 2] != r
					or _target[(y - 2) * SIZE + x] != r
					or _target[(y + 2) * SIZE + x] != r
				)
			):
				guide.set_pixel(x, y, Color.WHITE)
	guide_texture = ImageTexture.create_from_image(guide)


func _update_progress() -> void:
	var hits := Vector3.ZERO
	var carved := 0
	var stray := 0
	for y in SIZE:
		for x in SIZE:
			if mask.get_pixel(x, y).r > 0.5:
				carved += 1
				var region := _target[y * SIZE + x]
				if region > 0:
					hits[region - 1] += 1.0
				else:
					stray += 1
	coverage = hits / _totals
	stray_ratio = float(stray) / maxi(1, carved)
	ready_to_finish = (
		coverage.x >= required_coverage
		and coverage.y >= required_coverage
		and coverage.z >= required_coverage
	)
	progress_changed.emit(coverage, stray_ratio, ready_to_finish)


func _cache_mesh() -> void:
	var arrays := shell.mesh.surface_get_arrays(0)
	_vertices = arrays[Mesh.ARRAY_VERTEX]
	_indices = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indentation := float(material.get_shader_parameter("indentation"))
	var rotation_offset := float(material.get_shader_parameter("ridge_rotation"))
	var segments := int(material.get_shader_parameter("segment_count"))
	for i in _vertices.size():
		var v := _vertices[i]
		if Vector2(v.x, v.z).length() > 0.0001:
			var phase := (atan2(v.z, v.x) + rotation_offset) * segments
			var wave := 0.5 + 0.5 * cos(phase)
			var fade := clampf((absf(normals[i].y) - 0.65) / (0.98 - 0.65), 0.0, 1.0)
			var side := 1.0 - fade * fade * (3.0 - 2.0 * fade)
			var factor := 1.0 - indentation * wave * wave * wave * side
			v.x *= factor
			v.z *= factor
		_shaped.append(v)


func _pick_uv(camera: Camera3D, screen: Vector2) -> Vector2:
	var origin := shell.to_local(camera.project_ray_origin(screen))
	var direction := (shell.global_basis.inverse() * camera.project_ray_normal(screen)).normalized()
	var best_distance := INF
	var original := Vector3.ZERO
	var found := false
	for i in range(0, _indices.size(), 3):
		var ia := _indices[i]
		var ib := _indices[i + 1]
		var ic := _indices[i + 2]
		var a := _shaped[ia]
		var b := _shaped[ib]
		var c := _shaped[ic]
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
		if hit == null:
			continue
		var distance := origin.distance_squared_to(hit)
		if distance >= best_distance:
			continue
		var ab := b - a
		var ac := c - a
		var ap: Vector3 = hit - a
		var denominator := ab.dot(ab) * ac.dot(ac) - ab.dot(ac) * ab.dot(ac)
		if absf(denominator) < 0.0000001:
			continue
		var v := (ac.dot(ac) * ap.dot(ab) - ab.dot(ac) * ap.dot(ac)) / denominator
		var w := (ab.dot(ab) * ap.dot(ac) - ab.dot(ac) * ap.dot(ab)) / denominator
		original = _vertices[ia] * (1.0 - v - w) + _vertices[ib] * v + _vertices[ic] * w
		best_distance = distance
		found = true
	if not found or original.z <= 0.12:
		return Vector2(-1, -1)
	var uv := Vector2(original.x / FACE_SIZE.x + 0.5, 0.5 - original.y / FACE_SIZE.y)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv
