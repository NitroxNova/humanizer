@tool
extends Resource
class_name MHCLO

enum SECTION {header,vertices,delete_vertices}

@export var vertex_data = []
@export var delete_vertices : Array
@export var scale_config = {
	x={start=0, end=0, length=0},
	y={start=0, end=0, length=0},
	z={start=0, end=0, length=0}
}
@export var mh2gd_index := []
@export var tags := PackedStringArray()
@export var z_depth := 0
@export var rigged_config := []
@export var rigged_bones := []
@export var rigged_weights := []
var obj_file_name: String


func parse_file(filename:String):
	var unique_lines = {}
	var file = FileAccess.open(filename,FileAccess.READ)
	var current_section = SECTION.header
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if current_section == SECTION.header:
			if line == "verts 0":
				current_section = SECTION.vertices
			elif line.begins_with("obj_file "):
				obj_file_name = line.get_slice(" ",1)
			elif line.begins_with("name"):
				resource_name = line.get_slice(' ', 1).strip_edges()
			elif line.begins_with("tag "):
				tags.append(line.substr(4).strip_edges()) 
			elif line.begins_with("x_scale "):
				parse_scale_data(line,"x")
			elif line.begins_with("y_scale "):
				parse_scale_data(line,"y")
			elif line.begins_with("z_scale "):
				parse_scale_data(line,"z")
			elif line.begins_with("z_depth "):
				z_depth = int(line.get_slice(' ',1))
		elif current_section == SECTION.delete_vertices:
			var dv_split = line.split(" ",false)
			var new_element = true
			for dv_value in dv_split:
				if dv_value == "-":
					new_element = false
				elif new_element:
					delete_vertices.append([int(dv_value)])
				else:
					delete_vertices[delete_vertices.size()-1].append(int(dv_value))
					new_element = true	
			
		elif current_section == SECTION.vertices:
			if line == "delete_verts":
				current_section = SECTION.delete_vertices
			elif not line == "":
				if line.strip_edges().get_slice(" ",0).is_valid_int():
					unique_lines[line] = true
					var line_array = line.split_floats(" ",false)
					if line_array.size() == 1:
						var line_dict = {}
						line_dict.format = "single"
						line_dict.vertex = [line_array[0]]
						vertex_data.append(line_dict)
					elif line_array.size() == 9:
						var line_dict = {}
						line_dict.format = "triangle"
						line_dict.vertex = []
						line_dict.weight = []
						line_dict.offset = Vector3.ZERO	
						for i in 3:
							line_dict.vertex.append(line_array[i])
							line_dict.weight.append(line_array[i+3])	
						line_dict.offset.x = line_array[6]		
						line_dict.offset.y = line_array[7]	
						line_dict.offset.z = line_array[8]		
						vertex_data.append(line_dict)
					else:
						printerr(line)
				else:
					if not line.begins_with('material'):
						printerr(line)
					
func parse_scale_data(line:String, index:String): #index is x, y, or z
	var scale_data = line.split_floats(" ",false)
	scale_config[index].start = scale_data[1]
	scale_config[index].end = scale_data[2]
	scale_config[index].length = scale_data[3]
	
func calculate_vertex_bone_weights(mh_id:int,bone_weights:Dictionary, rigged_bone_ids = []):
	var bone_count=8
	var bones = []
	var weights = []
	if rigged_bone_ids.is_empty():
		var vtx_bone_weights = _calculate_base_vertex_bone_weights(mh_id,bone_weights)
		bones = vtx_bone_weights.bones
		weights = vtx_bone_weights.weights
	else:
		var remainder = 0
		for array_id in rigged_bones[mh_id].size():
			var rig_bone_id = rigged_bones[mh_id][array_id]
			var bone_id = rigged_bone_ids[rig_bone_id]
			if bone_id == -1:
				remainder += rigged_weights[mh_id][array_id]
			else:
				bones.append(bone_id)
				weights.append(rigged_weights[mh_id][array_id])
		if remainder > 0:
			var base_vtx_bx = _calculate_base_vertex_bone_weights(mh_id,bone_weights)		
			for array_id in base_vtx_bx.bones.size():
				bones.append(base_vtx_bx.bones[array_id])
				#assuming rigged weights are already normalized
				weights.append(base_vtx_bx.weights[array_id] * remainder)
	
	while bones.size() < bone_count:
		bones.append(0)
		weights.append(0)
		
	return {bones=bones,weights=weights}

func _calculate_base_vertex_bone_weights(mh_id:int,bone_weights:Dictionary):
	var bones = []
	var weights = []
	var v_data = vertex_data[mh_id]
	if v_data.format == 'single':
		var id = v_data.vertex[0]
		bones = bone_weights.bones[id]
		weights = bone_weights.weights[id]
	else:
		for i in 3:
			var v_id = v_data.vertex[i]
			var v_weight = v_data.weight[i]
			var vb_id = bone_weights.bones[v_id]
			var vb_weights = bone_weights.weights[v_id]
			for j in vb_weights.size():
				var l_weight = vb_weights[j]
				if not l_weight == 0:
					var l_bone = vb_id[j]
					l_weight *= v_weight
					if l_bone in bones:
						var l_id = bones.find(l_bone)
						weights[l_id] += l_weight
					else:
						bones.append(l_bone)
						weights.append(l_weight)
						
	for weight_id in range(weights.size()-1,-1,-1):
		if v_data.format == "triangle":
			weights[weight_id] /= (v_data.weight[0] + v_data.weight[1] + v_data.weight[2])
		if weights[weight_id] > 1:
			weights[weight_id] = 1
		elif weights[weight_id] < 0.001: #small weights and NEGATIVE
			weights.remove_at(weight_id)
			bones.remove_at(weight_id)
	
	## seems counterintuitive to the bone_count of 8, but is how makehuman does it, too many weights just deforms the mesh
	while bones.size() > 4:
		var min_id = 0
		for this_id in bones.size():
			if weights[this_id] < weights[min_id]:
				min_id = this_id
		bones.remove_at(min_id)
		weights.remove_at(min_id)
	
	#normalize		
	var total_weight = 0
	for weight in weights:
		total_weight += weight
	var ratio = 1/total_weight
	for weight_id in weights.size():
		weights[weight_id] *= ratio
	
	return {bones=bones,weights=weights}
