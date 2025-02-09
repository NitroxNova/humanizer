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
