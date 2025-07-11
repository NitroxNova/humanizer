@tool
extends Resource
class_name MHCLO

enum SECTION {header,vertices,delete_vertices}

@export var vertex_data = []
@export var delete_vertices : Array
@export var scale_config = { }
	#typically like this, unless using shear (left_shear : start, end, start_length, end_length) or just shear, for x y and z
	#x={start=0, end=0, length=0},#y={start=0, end=0, length=0},#z={start=0, end=0, length=0}}
	
@export var mh2gd_index := []
@export var tags := PackedStringArray()
@export var z_depth := 0

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
			elif line.begins_with("shear_x"):
				parse_shear_data(line,"x")
			elif line.begins_with("shear_y"):
				parse_shear_data(line,"y")
			elif line.begins_with("shear_z"):
				parse_shear_data(line,"z")
			elif line.begins_with("l_shear_x"):
				parse_shear_data(line,"x","left_")
			elif line.begins_with("l_shear_y"):
				parse_shear_data(line,"y","left_")
			elif line.begins_with("l_shear_z"):
				parse_shear_data(line,"z","left_")
			elif line.begins_with("r_shear_x"):
				parse_shear_data(line,"x","right_")
			elif line.begins_with("r_shear_y"):
				parse_shear_data(line,"y","right_")
			elif line.begins_with("r_shear_z"):
				parse_shear_data(line,"z","right_")
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
							line_dict.vertex.append(line_array[i])
							line_dict.weight.append(line_array[i+3])	
						line_dict.offset.x = line_array[6]		
						line_dict.offset.y = line_array[7]	
						line_dict.offset.z = line_array[8]		
						vertex_data.append(line_dict)
					else:
						printerr(line)
				else:
					printerr(line)
					
func parse_scale_data(line:String, index:String): #index is x, y, or z
	var scale_data = line.split_floats(" ",false)
	scale_config[index] = {}
	scale_config[index].start = scale_data[1]
	scale_config[index].end = scale_data[2]
	scale_config[index].length = scale_data[3]

func parse_shear_data(line:String, index:String, left_right:String = ""): #index is x,y, or z .. left_right should be "left_" or "right_"
	var scale_data = line.split_floats(" ",false)
	index = left_right + "shear_" + index 
	scale_config[index] = {}
	scale_config[index].start = scale_data[1]
	scale_config[index].end = scale_data[2]
	scale_config[index].start_length = scale_data[3] #length from start to origin ("centroid")
	scale_config[index].end_length = scale_data[4] #length from end to origin
		

func calculate_mhclo_scale(helper_vertex_array: Array) -> Vector3:
	var mhclo_scale = Vector3.ZERO
	if "x" not in scale_config:
		#derive scale dimensions from shears, i chose not to implement the full shearing function for performance reasons, but this should be good enough		
		if "shear_x" in scale_config:
			#print("getting shear config " + resource_name)
			for axis in ["x","y","z"]:
				get_shear_dimensions(axis)
		elif "left_shear_x" in scale_config:
			#print("getting left right shear config " + resource_name)
			for axis in ["x","y","z"]:
				get_shear_dimensions_left_right(axis)			
		else:
			printerr("no scale given for " + resource_name + ". defaulting to 0.1")
			return Vector3(.1,.1,.1)
	for axis in ["x","y","z"]:
		var scale_data = scale_config[axis]
		mhclo_scale[axis] = get_scale_from_points(scale_data.start,scale_data.end,scale_data.length,axis,helper_vertex_array)
	
	return mhclo_scale

func get_shear_dimensions(axis:String):
	var axis_config = scale_config["shear_" + axis]
	var start = axis_config.start
	var end = axis_config.end
	var length = absf(axis_config.end_length-axis_config.start_length)	
	scale_config[axis] = {start=start,end=end,length=length}

func get_shear_dimensions_left_right(axis:String): #for left and right shears, get greatest lengths from origin
	var start
	var end
	var start_length
	var end_length
	var length
	
	var left_shear = get_shear_min_max("left_shear_" + axis)
	var right_shear = get_shear_min_max("right_shear_" + axis)
	
	if left_shear.start_length < right_shear.start_length:
		start = left_shear.start
		start_length = left_shear.start_length
	else:
		start = right_shear.start
		start_length = right_shear.start_length
	
	if left_shear.end_length > right_shear.end_length:
		end = left_shear.end
		end_length = left_shear.end_length
	else:
		end = right_shear.end
		end_length = right_shear.end_length
		
	length = absf(end_length-start_length)	
	scale_config[axis] = {start=start,end=end,length=length}

func get_shear_min_max(key:String): #key = left_shear_x
	var axis_config = scale_config[key]
	var start = axis_config.start
	var end = axis_config.end
	var start_length = axis_config.start_length
	var end_length = axis_config.end_length
	if axis_config.start_length > axis_config.end_length:
		start = axis_config.end
		end = axis_config.start
		start_length = axis_config.end_length
		end_length = axis_config.start_length
	return {start=start,end=end,start_length=start_length,end_length=end_length}
	
func get_scale_from_points(start:int,end:int,distance:float,axis:String,helper_vertex:Array):
	var start_coords = helper_vertex[start]
	var end_coords = helper_vertex[end]
	var basemesh_dist = absf(end_coords[axis] - start_coords[axis])
	if distance == 0:
		printerr("scale length is zero " + resource_name + " try reimporting")
		return .1
	return basemesh_dist/distance
	
func get_mhclo_vertex_position( helper_vertex_array: PackedVector3Array, vertex_line:Dictionary, mhclo_scale:Vector3):
	var new_coords = Vector3.ZERO
	if vertex_line.format == "single":
		var vertex_id = vertex_line.vertex[0]
		new_coords = helper_vertex_array[vertex_id]
	else:
		for i in 3:
			var vertex_id = vertex_line.vertex[i]
			var v_weight = vertex_line.weight[i]
			var v_coords = helper_vertex_array[vertex_id]
			v_coords *= v_weight
			new_coords += v_coords
		new_coords += (vertex_line.offset * mhclo_scale)
	return new_coords
