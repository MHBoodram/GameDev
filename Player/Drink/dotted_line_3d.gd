@tool
class_name DottedLine3D
extends Node3D

const DEFAULT_TOLERANCE_HALF_WIDTH: float = 0.025
const DEFAULT_TOLERANCE_COLOR: Color = Color(0.20, 0.90, 0.35, 0.28)
const DEFAULT_TOLERANCE_BORDER_COLOR: Color = Color(0.28, 1.0, 0.42, 0.72)
const DEFAULT_TOLERANCE_BORDER_WIDTH: float = 0.004

@export var start_point: Vector3 = Vector3(-0.2, 0.0, 0.0):
	set(value):
		start_point = value
		_dirty = true

@export var end_point: Vector3 = Vector3(0.2, 0.0, 0.0):
	set(value):
		end_point = value
		_dirty = true

@export var plane_normal: Vector3 = Vector3.BACK:
	set(value):
		plane_normal = value
		_dirty = true

@export var dotted: bool = true:
	set(value):
		dotted = value
		_dirty = true

@export var dash_length: float = 0.03:
	set(value):
		dash_length = maxf(0.001, value)
		_dirty = true

@export var gap_length: float = 0.02:
	set(value):
		gap_length = maxf(0.0, value)
		_dirty = true

@export var line_thickness: float = 0.012:
	set(value):
		line_thickness = maxf(0.0005, value)
		_dirty = true

@export var outline_thickness: float = 0.004:
	set(value):
		outline_thickness = maxf(0.0, value)
		_dirty = true

@export var line_color: Color = Color(1.0, 0.98, 0.88, 0.92):
	set(value):
		line_color = value
		_dirty = true

@export var outline_color: Color = Color(0.06, 0.05, 0.08, 0.85):
	set(value):
		outline_color = value
		_dirty = true

@export var centered_pattern: bool = true:
	set(value):
		centered_pattern = value
		_dirty = true

@export var scroll_speed: float = 0.0

@export var render_priority: int = 5:
	set(value):
		render_priority = value
		if _material:
			_material.render_priority = render_priority

@export var no_depth_test: bool = false:
	set(value):
		no_depth_test = value
		if _material:
			_material.no_depth_test = no_depth_test

@export_group("Tolerance Zone")
@export var show_tolerance_zone: bool = false:
	set(value):
		show_tolerance_zone = value
		_dirty = true

@export var tolerance_half_width: float = DEFAULT_TOLERANCE_HALF_WIDTH:
	set(value):
		tolerance_half_width = maxf(0.0, value)
		_dirty = true

@export var tolerance_color: Color = DEFAULT_TOLERANCE_COLOR:
	set(value):
		tolerance_color = value
		_dirty = true

@export var tolerance_border_color: Color = DEFAULT_TOLERANCE_BORDER_COLOR:
	set(value):
		tolerance_border_color = value
		_dirty = true

@export var tolerance_border_width: float = DEFAULT_TOLERANCE_BORDER_WIDTH:
	set(value):
		tolerance_border_width = maxf(0.0, value)
		_dirty = true

@export var tolerance_zone_length: float = -1.0:
	set(value):
		tolerance_zone_length = value
		_dirty = true

var _mesh_instance: MeshInstance3D = null
var _mesh: ArrayMesh = null
var _material: StandardMaterial3D = null
var _dirty: bool = true
var _phase: float = 0.0

func _ready() -> void:
	_ensure_mesh_nodes()
	_rebuild_mesh()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not Engine.is_editor_hint() and dotted and gap_length > 0.0001 and not is_zero_approx(scroll_speed):
		_phase += scroll_speed * delta
		_dirty = true
	if _dirty:
		_rebuild_mesh()

func set_points(p_start: Vector3, p_end: Vector3) -> void:
	if start_point.is_equal_approx(p_start) and end_point.is_equal_approx(p_end):
		return
	start_point = p_start
	end_point = p_end
	_dirty = true
	if is_inside_tree():
		_rebuild_mesh()

func set_horizontal(y_pos: float, min_x: float, max_x: float, z_pos: float = 0.0) -> void:
	set_points(Vector3(min_x, y_pos, z_pos), Vector3(max_x, y_pos, z_pos))

func set_vertical(x_pos: float, min_y: float, max_y: float, z_pos: float = 0.0) -> void:
	set_points(Vector3(x_pos, min_y, z_pos), Vector3(x_pos, max_y, z_pos))

func set_from_center(center: Vector3, angle_rad: float, length: float) -> void:
	var normal := plane_normal.normalized() if plane_normal.length_squared() > 0.0001 else Vector3.BACK
	var ref_right := Vector3.RIGHT
	if absf(ref_right.dot(normal)) > 0.99:
		ref_right = Vector3.FORWARD
	var basis_x := ref_right.slide(normal).normalized()
	var basis_y := normal.cross(basis_x).normalized()
	var dir := basis_x * cos(angle_rad) + basis_y * sin(angle_rad)
	var half_vec := dir * (maxf(0.001, length) * 0.5)
	set_points(center - half_vec, center + half_vec)

func set_colors(p_line_color: Color, p_outline_color: Color = outline_color) -> void:
	if line_color == p_line_color and outline_color == p_outline_color:
		return
	line_color = p_line_color
	outline_color = p_outline_color
	_dirty = true
	if is_inside_tree():
		_rebuild_mesh()

func set_dash_metrics(p_dash_length: float, p_gap_length: float, p_line_thickness: float, p_outline_thickness: float = -1.0) -> void:
	var next_dash := maxf(0.001, p_dash_length)
	var next_gap := maxf(0.0, p_gap_length)
	var next_thick := maxf(0.0005, p_line_thickness)
	var next_outline := outline_thickness if p_outline_thickness < 0.0 else maxf(0.0, p_outline_thickness)
	if (
		is_equal_approx(dash_length, next_dash)
		and is_equal_approx(gap_length, next_gap)
		and is_equal_approx(line_thickness, next_thick)
		and is_equal_approx(outline_thickness, next_outline)
	):
		return
	dash_length = next_dash
	gap_length = next_gap
	line_thickness = next_thick
	outline_thickness = next_outline
	_dirty = true
	if is_inside_tree():
		_rebuild_mesh()

func set_tolerance_zone(
	enabled: bool,
	half_width: float = DEFAULT_TOLERANCE_HALF_WIDTH,
	fill_color: Color = DEFAULT_TOLERANCE_COLOR,
	border_color: Color = DEFAULT_TOLERANCE_BORDER_COLOR,
	border_width: float = DEFAULT_TOLERANCE_BORDER_WIDTH,
	length_override: float = -1.0
) -> void:
	show_tolerance_zone = enabled
	tolerance_half_width = maxf(0.0, half_width)
	tolerance_color = fill_color
	tolerance_border_color = border_color
	tolerance_border_width = maxf(0.0, border_width)
	tolerance_zone_length = length_override
	_dirty = true
	if is_inside_tree():
		_rebuild_mesh()

func _ensure_mesh_nodes() -> void:
	if is_instance_valid(_mesh_instance):
		return
	_mesh = ArrayMesh.new()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.render_priority = render_priority
	_material.no_depth_test = no_depth_test

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "LineMesh"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = _material
	add_child(_mesh_instance)

func _rebuild_mesh() -> void:
	_ensure_mesh_nodes()
	_dirty = false
	_mesh.clear_surfaces()

	var delta_vec := end_point - start_point
	var total_len := delta_vec.length()
	if total_len <= 0.0001:
		_mesh_instance.visible = false
		return

	var dir := delta_vec / total_len
	var normal := plane_normal.normalized() if plane_normal.length_squared() > 0.0001 else Vector3.BACK
	if absf(dir.dot(normal)) > 0.99:
		normal = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var perp := dir.cross(normal).normalized()

	var dash_ranges: Array[Vector2] = _compute_dash_ranges(total_len)
	if dash_ranges.is_empty():
		_mesh_instance.visible = false
		return

	var zone_verts := PackedVector3Array()
	var zone_cols := PackedColorArray()
	var zone_indices := PackedInt32Array()

	if show_tolerance_zone and tolerance_half_width > 0.0001:
		var mid := (start_point + end_point) * 0.5
		var band_len := total_len if tolerance_zone_length < 0.0 else maxf(0.001, tolerance_zone_length)
		var half_len := band_len * 0.5
		var back_off := -normal * 0.0005
		var b0 := mid - dir * half_len + back_off
		var b1 := mid + dir * half_len + back_off
		_append_quad(zone_verts, zone_cols, zone_indices, b0, b1, perp, tolerance_half_width, tolerance_color)
		if tolerance_border_width > 0.0001 and tolerance_border_color.a > 0.001:
			var edge_off := perp * tolerance_half_width
			var half_bw := tolerance_border_width * 0.5
			_append_quad(zone_verts, zone_cols, zone_indices, b0 - edge_off, b1 - edge_off, perp, half_bw, tolerance_border_color)
			_append_quad(zone_verts, zone_cols, zone_indices, b0 + edge_off, b1 + edge_off, perp, half_bw, tolerance_border_color)

	var outline_verts := PackedVector3Array()
	var outline_cols := PackedColorArray()
	var outline_indices := PackedInt32Array()

	var fill_verts := PackedVector3Array()
	var fill_cols := PackedColorArray()
	var fill_indices := PackedInt32Array()

	var half_fill_w := line_thickness * 0.5
	var half_out_w := half_fill_w + outline_thickness
	var draw_outline := outline_thickness > 0.0001 and outline_color.a > 0.001

	for seg in dash_ranges:
		var d0 := seg.x
		var d1 := seg.y
		if draw_outline:
			var od0 := maxf(0.0, d0 - outline_thickness)
			var od1 := minf(total_len, d1 + outline_thickness)
			_append_quad(outline_verts, outline_cols, outline_indices, start_point + dir * od0, start_point + dir * od1, perp, half_out_w, outline_color)
		_append_quad(fill_verts, fill_cols, fill_indices, start_point + dir * d0, start_point + dir * d1, perp, half_fill_w, line_color)

	var combined_verts := PackedVector3Array()
	var combined_cols := PackedColorArray()
	var combined_indices := PackedInt32Array()

	if not zone_verts.is_empty():
		combined_verts.append_array(zone_verts)
		combined_cols.append_array(zone_cols)
		combined_indices.append_array(zone_indices)

	if draw_outline:
		var out_base_idx := combined_verts.size()
		combined_verts.append_array(outline_verts)
		combined_cols.append_array(outline_cols)
		for idx in outline_indices:
			combined_indices.append(out_base_idx + idx)

	var fill_base_idx := combined_verts.size()
	combined_verts.append_array(fill_verts)
	combined_cols.append_array(fill_cols)
	for idx in fill_indices:
		combined_indices.append(fill_base_idx + idx)

	if combined_verts.is_empty():
		_mesh_instance.visible = false
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = combined_verts
	arrays[Mesh.ARRAY_COLOR] = combined_cols
	arrays[Mesh.ARRAY_INDEX] = combined_indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.visible = true

func _compute_dash_ranges(total_len: float) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	if not dotted or gap_length <= 0.0001:
		ranges.append(Vector2(0.0, total_len))
		return ranges

	var pattern := maxf(dash_length + gap_length, 0.001)

	if centered_pattern and is_zero_approx(scroll_speed):
		var num_dashes := maxi(1, int(floor((total_len + gap_length + 0.0001) / pattern)))
		if num_dashes == 1 and dash_length >= total_len:
			ranges.append(Vector2(0.0, total_len))
			return ranges
		var used_len := float(num_dashes) * dash_length + float(num_dashes - 1) * gap_length
		var cursor := maxf(0.0, (total_len - used_len) * 0.5)
		for _i in num_dashes:
			var d0 := cursor
			var d1 := minf(total_len, d0 + dash_length)
			if d1 - d0 > 0.0005:
				ranges.append(Vector2(d0, d1))
			cursor += pattern
		return ranges

	var offset := fposmod(_phase, pattern) - pattern
	var pos := offset
	while pos < total_len:
		var d0 := maxf(0.0, pos)
		var d1 := minf(total_len, pos + dash_length)
		if d1 - d0 > 0.0005:
			ranges.append(Vector2(d0, d1))
		pos += pattern
	return ranges

static func _append_quad(
	verts: PackedVector3Array,
	cols: PackedColorArray,
	indices: PackedInt32Array,
	p0: Vector3,
	p1: Vector3,
	perp: Vector3,
	half_w: float,
	col: Color
) -> void:
	var base := verts.size()
	var off := perp * half_w
	verts.append(p0 - off)
	verts.append(p1 - off)
	verts.append(p1 + off)
	verts.append(p0 + off)
	cols.append(col)
	cols.append(col)
	cols.append(col)
	cols.append(col)
	indices.append(base + 0)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base + 0)
	indices.append(base + 2)
	indices.append(base + 3)