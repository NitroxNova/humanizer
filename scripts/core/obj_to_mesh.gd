class_name ObjToMesh

var obj_path = "res://mpfb2_plugin/assets/hair/ponytail01/ponytail01.obj"
var obj_arrays = {}
var sf_arrays = []
var mh2gd_index = []
var gd2mh_index = []
var unique_uv_vertex = {}

func _init(_obj_path: String):
	obj_path = _obj_path

func run() -> Dictionary:
	process_obj()
	expand_vertices()
	#The flags argument is the bitwise or of, as required: 
	#One value of ArrayCustomFormat left shifted by ARRAY_FORMAT_CUSTOMn_SHIFT for each custom channel in use,
	# Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS, or Mesh.ARRAY_FLAG_USES_EMPTY_VERTEX_ARRAY.
	var flags = 0
	flags = Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	#flags = 1 << 2
	#print(flags)
	
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,sf_arrays,[],{},flags)
	
	var data = {}
	data.sf_arrays = sf_arrays
	data.mesh = new_mesh
	data.mh2gd_index = mh2gd_index
	return data


#need separate vertex for each vertex / uv pair
func expand_vertices():	
	sf_arrays.resize(Mesh.ARRAY_MAX)
	sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	sf_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	sf_arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array()
	

	for face in obj_arrays.face:
		for face_data in face:
			if not face_data in unique_uv_vertex:
				unique_uv_vertex[face_data] = unique_uv_vertex.size()
	#print(obj_arrays.vertex.size())
	#print(unique_uv_vertex.size())
		
	for key in unique_uv_vertex:
		#print(value[0])
		var mh_id = key[0]
		gd2mh_index.append(mh_id)
		var vert_vector = obj_arrays.vertex[mh_id]
		var uv_vector = obj_arrays.uv[key[1]]
		sf_arrays[Mesh.ARRAY_VERTEX].append(vert_vector)
		sf_arrays[Mesh.ARRAY_TEX_UV].append(uv_vector)
		sf_arrays[Mesh.ARRAY_CUSTOM0].append(mh_id)
		#print(uv_vector)
	
	mh2gd_index.resize(obj_arrays.vertex.size())
	# using fill([]) or fill(Array()) puts all the ids in each element, because they all point to the same array
	for gd_id in gd2mh_index.size():
		var mh_id = gd2mh_index[gd_id]
		#print(gd_id)
		if mh2gd_index[mh_id] == null:
			mh2gd_index[mh_id] = []
		mh2gd_index[mh_id].append(gd_id)
	#print(mh2gd_index)
	
	for face in obj_arrays.face:
		#print(face)
		#vertex faces in quads, convert to triangles
		var face_array = convert_face_array(face)
		sf_arrays[Mesh.ARRAY_INDEX].append_array([face_array[2],face_array[1],face_array[0]])
		if face_array.size() < 4:
			continue
		sf_arrays[Mesh.ARRAY_INDEX].append_array([face_array[0],face_array[3],face_array[2]])
	
func convert_face_array(face_array):
	var out_array = []
	for point in face_array:
		#print(point)
		var gd_id = unique_uv_vertex[point]
		#print(gd_id)
		out_array.append(gd_id)
	return out_array
		
	
func process_obj():
	var obj_file = FileAccess.open(obj_path,FileAccess.READ)	
	obj_arrays.vertex = []
	obj_arrays.uv = []
	obj_arrays.face = []
	while obj_file.get_position() < obj_file.get_length():
		var line = obj_file.get_line()
		if not line.begins_with("#") and not line == "":
			if line.begins_with("v "):
				#v -0.4384 15.7479 1.3509
				#    v     Geometric vertices:                 v x y z
				var vert_floats = line.split_floats(" ",false)
				#index 0 is "0" because value was "v"
				#print(vert_floats)
				vert_floats.remove_at(0)
				var vert_vector = Vector3(vert_floats[0],vert_floats[1],vert_floats[2])
				obj_arrays.vertex.append(vert_vector)
			elif line.begins_with("f "):
				# f 671/151 681/156 680/155 670/148
				#   f     Face with texture coords:       f v1/t1 v2/t2 .... vn/tn
				var face_string_array = line.split(" ",false)
				#index 0 is "0" because value was "f"
				face_string_array.remove_at(0)
				var face_index = []
				for i in face_string_array.size():
					var split_index = face_string_array[i].split_floats("/",false)
					split_index[0] -= 1
					split_index[1] -= 1
					face_index.append(split_index)
				#print(face_index)	
				obj_arrays.face.append(face_index)
			elif line.begins_with("vt "):
				#vertex texture, which is the UV 
				#vt 0.7060 0.7065
				#    vt   Texture vertices:                     vt u v
				var texture_floats = line.split_floats(" ",false)
				texture_floats.remove_at(0)
				var texture_vector = Vector2(texture_floats[0],1-texture_floats[1])
				obj_arrays.uv.append(texture_vector)		
			elif line.begins_with("g "):
				#face group, can only have one per face, so refer to the basemesh_vertex_groups.json	
				#print(line)
				#The group name command specifies a sub-object grouping. All 'f' face commands that follow are considered to be in the same group. 
				pass				
			elif line.begins_with("vn "):
				#vertex normal, ignore these because they will be regenerated
				#vn -0.0719 -0.1557 0.9852
				#    vn   Vertex normals:                      vn dx dy dz
				pass	
			elif line.begins_with("s "):
				# s off
				#idk what this means
				pass
			else:
				print(line)
