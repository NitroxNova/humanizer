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

@export var bones := {}
@export var weights := {}
@export var uv_array := PackedVector2Array()
@export var index_array := PackedInt32Array()
@export var custom0_array := PackedFloat32Array()

var obj_file_name: String
var display_name : String
var default_material : String
var mhclo_path : String

func parse_file(filename:String):
	mhclo_path = filename
	resource_name = filename.get_basename().get_file()
	var file = FileAccess.open(filename,FileAccess.READ)
	var current_section = SECTION.header
	while file.get_position() < file.get_length():
		var line = file.get_line()
		if line.begins_with("material "):  #can be above or below the "verts 0"
			default_material = line.split(" ",false,1)[1]
		elif current_section == SECTION.header:
			if line == "verts 0":
				current_section = SECTION.vertices
			elif line.begins_with("name "):
				#use substring instead of split so there can be additional spaces in name
				display_name = line.substr(5).strip_edges()
				#print(display_name)
			elif line.begins_with("obj_file "):
				obj_file_name = line.get_slice(" ",1)
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
			elif not line == "" and not line.begins_with("#"):
				if line.strip_edges().get_slice(" ",0).is_valid_int():
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
							line_dict.vertex.append(int(line_array[i]))
							line_dict.weight.append(float(line_array[i+3]))
						line_dict.offset.x = float(line_array[6])
						line_dict.offset.y = float(line_array[7])
						line_dict.offset.z = float(line_array[8])
						#print("line dict: ", line_array)
						vertex_data.append(line_dict)
					else:
						printerr(line)
				else:
					printerr(line)
					
func parse_scale_data(line:String, index:String): #index is x, y, or z
	var scale_data = line.split_floats(" ",false)
	scale_config[index].start = scale_data[1]
	scale_config[index].end = scale_data[2]
	scale_config[index].length = scale_data[3]
	

func calculate_mhclo_scale(helper_vertex_array: Array) -> Vector3:
	var mhclo_scale = Vector3.ZERO
	for axis in ["x","y","z"]:
		var scale_data = scale_config[axis]
		if is_zero_approx(scale_data.length):
			#print("no scale was found, scale set to 1 for axis", axis)
			mhclo_scale[axis] = 0.1 # im not sure why this magic number is correct for Fem_suit but it is...
			continue # we're assuming a default
		var start_coords = helper_vertex_array[scale_data.start]
		var end_coords = helper_vertex_array[scale_data.end]
		var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
		mhclo_scale[axis] = basemesh_dist / scale_data.length
		#print("mcloscale axis ", axis, mhclo_scale[axis])
	#if is_nan(mhclo_scale.x) or is_nan(mhclo_scale.y) or is_nan(mhclo_scale.z):
		##assert(false, "we detected nan in the scale and prevented it being imported!")
		#mhclo_scale =
	assert(not is_nan(mhclo_scale.x))
	assert(not is_nan(mhclo_scale.y))
	assert(not is_nan(mhclo_scale.z))
	# ban zero scale its not a real thing
	var scale_fixed: Vector3 = Vector3(max(0.01, mhclo_scale.x), max(0.01, mhclo_scale.y), max(0.01, mhclo_scale.z))
	return scale_fixed

func get_mhclo_vertex_position( helper_vertex_array: PackedVector3Array, vertex_line:Dictionary, mhclo_scale:Vector3):
	var new_coords = Vector3.ZERO
	if vertex_line.format == "single":
		var vertex_id: int = vertex_line.vertex[0]
		new_coords = helper_vertex_array[vertex_id]
	else:
		for i in 3:
			var vertex_id: int = vertex_line.vertex[i]
			var v_weight: float = vertex_line.weight[i]
			var v_coords: Vector3 = helper_vertex_array[vertex_id]
			v_coords *= v_weight
			new_coords += v_coords
		new_coords += (vertex_line.offset * mhclo_scale)
	assert(not is_nan(new_coords.x))
	assert(not is_nan(new_coords.y))
	assert(not is_nan(new_coords.z))
	return new_coords
