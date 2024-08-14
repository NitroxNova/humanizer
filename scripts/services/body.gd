@tool
extends Resource
class_name HumanizerBodyService
#everything to do with the humanizer body mesh

## Vertex ids
const shoulder_id: int = 16951 
const waist_id: int = 17346
const hips_id: int = 18127
const feet_ids: Array[int] = [15500, 16804]
const head_top_id : int = 14570

static func load_basis_arrays()->Array:
	return load_basis_mesh().surface_get_arrays(0)

static func load_basis_mesh()->ArrayMesh:
	return load("res://addons/humanizer/data/resources/base_human.res")

static func fit_mesh_arrays(sf_arrays:Array,helper_vertex:PackedVector3Array)-> Array:
	for gd_id in sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		sf_arrays[Mesh.ARRAY_VERTEX][gd_id] = helper_vertex[mh_id]
	return sf_arrays
	
#only delete face if all 3 vertices are hidden
static func hide_vertices(mesh_arrays:Array,equipment:Dictionary):
	if equipment.is_empty():
		return
	var delete_verts_mh :Dictionary = {}
	for equip: HumanizerEquipment in equipment.values():
		var mhclo : MHCLO = load(equip.get_type().mhclo_path)
		for entry in mhclo.delete_vertices:
				if entry.size() == 1:
					delete_verts_mh[entry[0]] = true
				else:
					for mh_id in range(entry[0], entry[1] + 1):
						delete_verts_mh[mh_id] = true
	
	var new_face_array : PackedInt32Array = []
	for face_id in mesh_arrays[Mesh.ARRAY_INDEX].size()/3:
		var face =  mesh_arrays[Mesh.ARRAY_INDEX].slice(face_id*3, (face_id+1) * 3)
		var keep_face = false
		for gd_id in face:
			var mh_id:int = mesh_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
			if delete_verts_mh.get(mh_id) == null:
				keep_face = true
				break
		if keep_face:
			new_face_array.append_array(face)
	mesh_arrays[Mesh.ARRAY_INDEX] = new_face_array
	
static func get_hips_height(helper_vertex:PackedVector3Array):
	return helper_vertex[hips_id].y

static func get_foot_offset(helper_vertex:PackedVector3Array):
	var offset = max(helper_vertex[feet_ids[0]].y, helper_vertex[feet_ids[1]].y)
	var foot_offset = Vector3.UP * offset
	return foot_offset.y

static func get_head_height(helper_vertex:PackedVector3Array):
	return helper_vertex[head_top_id].y

static func get_max_width(helper_vertex:PackedVector3Array):
	var width_ids = [shoulder_id,waist_id,hips_id]
	var max_width = 0
	for mh_id in width_ids:
		var vertex_position = helper_vertex[mh_id]
		var distance = Vector2(vertex_position.x,vertex_position.z).distance_to(Vector2.ZERO)
		if distance > max_width:
			max_width = distance
	return max_width * 1.5
