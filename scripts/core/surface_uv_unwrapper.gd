class_name UVUnwrapper

var surface_arrays = []
var island_boxes = []
var material : StandardMaterial3D
var island_transform = [] #set elsewhere, after the row packer is done
var island_vertex = [] #vertex ids to island id
var island_uvs = [] # island id to array of uv coords

func _init(mesh: ArrayMesh, surface_id: int, _material):
	material = _material
	if _material==null:
		material = StandardMaterial3D.new()
	if material.albedo_texture == null:
		var albedo_size = 2 ** 11 #2k albedo, so normals still look nice
		var new_albedo_image = Image.create(albedo_size,albedo_size,false, Image.FORMAT_RGBA8)
		new_albedo_image.fill(material.albedo_color)
		material.albedo_texture = ImageTexture.create_from_image(new_albedo_image)
	surface_arrays = mesh.surface_get_arrays(surface_id)

func get_albedo_texture_size():
	return material.albedo_texture.get_size()

func get_albedo_texture():
	return material.albedo_texture

func is_normal_enabled():
	if material.normal_enabled and not material.normal_texture == null:
		return true
	return false

func is_ao_enabled():
	if material.ao_enabled and not material.ao_texture == null:
		return true
	return false
	
func get_normal_texture():
	return material.normal_texture

func get_ao_texture():
	return material.ao_texture
	
func get_island_bounding_boxes():
	var margin = Vector2(5,5)
	margin /= get_albedo_texture_size()
	island_boxes = []
	for island in island_uvs:
		var min_x = island[0].x
		var max_x = island[0].x
		var min_y = island[0].y
		var max_y = island[0].y
		#print(min_x)
		for uv_coords in island:
			if uv_coords.x < min_x :
				min_x = uv_coords.x
			if uv_coords.x > max_x:
				max_x = uv_coords.x
			if uv_coords.y < min_y:
				min_y = uv_coords.y
			if uv_coords.y > max_y:
				max_y = uv_coords.y

		min_x = max(0,min_x-margin.x)
		max_x = min(1,max_x+margin.x)
		min_y = max(0,min_y-margin.y)
		max_y = min(1,max_y+margin.y)
		island_boxes.append(Rect2(min_x,min_y,max_x-min_x,max_y-min_y))

	combine_overlapping_islands()
	
func combine_overlapping_islands():
	var new_overlaps = true
	while new_overlaps:
		var base_island_id = 0
		new_overlaps = false
		while base_island_id < island_uvs.size():
			for merge_island_id in range(island_uvs.size()-1,base_island_id,-1): #loop backwards to keep order when deleting
				var box_1 : Rect2 = island_boxes[base_island_id]
				var box_2 : Rect2 = island_boxes[merge_island_id]
				if box_1.intersects(box_2):
					var new_box = box_1.merge(box_2)
					if new_box.get_area() < (box_1.get_area() + box_2.get_area()):
						#print(str(base_island_id) + " and " + str(merge_island_id) + " are overlapping")
						new_overlaps = true
						# update uvs list - there will be no duplicate uvs since we already found those in get_island
						island_uvs[base_island_id].append_array(island_uvs[merge_island_id])
						island_uvs.remove_at(merge_island_id)
						#combine bounding boxes
						island_boxes[base_island_id] = new_box
						island_boxes.remove_at(merge_island_id)
			base_island_id += 1
	island_transform.resize(island_uvs.size())

func get_island_vertex():
	var uv_islands = {} #have to rebuild anyway after merging overlapping boxes
	for island_id in island_uvs.size():
		for uv_coords in island_uvs[island_id]:
			uv_islands[uv_coords] = island_id
	island_vertex = []
	island_vertex.resize(surface_arrays[Mesh.ARRAY_VERTEX].size())
	for vertex_id in surface_arrays[Mesh.ARRAY_VERTEX].size():
		var uv_coords = surface_arrays[Mesh.ARRAY_TEX_UV][vertex_id]
		var island_id = uv_islands[uv_coords]
		island_vertex[vertex_id] = island_id

func get_islands():
	var start_time = Time.get_ticks_msec()
	var uv_islands = {} #uv coords to island id
	island_uvs = []
	var island_counter = 0
	var merge_islands = [] # index = from, value = to
	for face_id in surface_arrays[Mesh.ARRAY_INDEX].size()/3:
		var face_array = surface_arrays[Mesh.ARRAY_INDEX].slice(face_id*3,(face_id+1)*3)
		var in_islands = []
		for i in 3:
			var uv_coords = surface_arrays[Mesh.ARRAY_TEX_UV][face_array[i]]
			if uv_coords in uv_islands and not uv_islands[uv_coords] in in_islands:
				in_islands.append(uv_islands[uv_coords])
		in_islands.sort() # lowest first for island merging
		var island_id : int
		if in_islands.is_empty(): #make a new island
			island_id = island_counter
			island_counter += 1
		elif in_islands.size() == 1:
			island_id = in_islands[0]
		else: #uv is shared by multiple islands
			island_id = in_islands.pop_front() #set id to the lowest
			for i_id in in_islands:
				for uv_coords in island_uvs[i_id]:
					uv_islands[uv_coords] = island_id
				island_uvs[island_id].append_array(island_uvs[i_id])
				island_uvs[i_id] = null
				#print("merging " + str(i_id) + " with " + str(island_id))
		
		if island_uvs.size() <= island_id:
			island_uvs.resize(island_id+1)
			island_uvs[island_id] = []
		
		for i in 3:
			var uv_coords = surface_arrays[Mesh.ARRAY_TEX_UV][face_array[i]]
			if not uv_coords in uv_islands:
				island_uvs[island_id].append(uv_coords)
				uv_islands[uv_coords] = island_id
	
	#consolidate islands
	island_counter = 0
	for i_id in island_uvs.size():
		if island_uvs[i_id] != null:
			for uv_coords in island_uvs[i_id]:
				uv_islands[uv_coords] = island_counter
			island_uvs[island_counter] = island_uvs[i_id]
			island_counter += 1
	island_uvs.resize(island_counter)

	
	get_island_bounding_boxes()
	get_island_vertex()

	#print("unwrapping islands took: ")
	#print(Time.get_ticks_msec()-start_time)
