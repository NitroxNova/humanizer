class_name UVUnwrapper

var surface_arrays = []
var islands = []
var island_boxes = []
var material
var island_transform = [] #set elsewhere, after the row packer is done
var island_vertex = []

func _init(mesh: ArrayMesh, surface_id: int, _material):
	material = _material
	if _material==null:
		material = StandardMaterial3D.new()
	if material.albedo_texture == null:
		var albedo_size = 2 ** 9 #512 seems reasonable, may need to change this later
		var new_albedo_image = Image.create(albedo_size,albedo_size,false, Image.FORMAT_RGBA8)
		new_albedo_image.fill(material.albedo_color)
		material.albedo_texture = ImageTexture.create_from_image(new_albedo_image)
	surface_arrays = mesh.surface_get_arrays(surface_id)

func get_albedo_texture_size():
	return material.albedo_texture.get_size()

func get_albedo_texture():
	return material.albedo_texture
	
func get_island_bounding_boxes():
	island_boxes = []
	for island:Dictionary in islands:
		var first_uv = island.keys()[0]
		var min_x = first_uv.x
		var max_x = first_uv.x
		var min_y = first_uv.y
		var max_y = first_uv.y
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
		island_boxes.append(Rect2(min_x,min_y,max_x-min_x,max_y-min_y))
	#print(island_boxes)	
	combine_overlapping_islands()
	
func combine_overlapping_islands():
	var new_overlaps = true
	while new_overlaps:
		var base_island_id = 0
		new_overlaps = false
		while base_island_id < islands.size():
			for merge_island_id in range(islands.size()-1,base_island_id,-1): #loop backwards to keep order when deleting
				var box_1 : Rect2 = island_boxes[base_island_id]
				var box_2 : Rect2 = island_boxes[merge_island_id]
				if box_1.intersects(box_2):
					var new_box = box_1.merge(box_2)
					if new_box.get_area() < (box_1.get_area() + box_2.get_area()):
						#print(str(base_island_id) + " and " + str(merge_island_id) + " are overlapping")
						new_overlaps = true
						# update uvs list - there will be no duplicate uvs since we already found those in get_island
						for uv_coords in islands[merge_island_id]:
							islands[base_island_id][uv_coords] = islands[merge_island_id][uv_coords]
						islands.remove_at(merge_island_id)
						#combine bounding boxes
						island_boxes[base_island_id] = new_box
						island_boxes.remove_at(merge_island_id)
			base_island_id += 1
	
	island_transform.resize(islands.size())

func get_island_vertex():
	island_vertex = []
	island_vertex.resize(surface_arrays[Mesh.ARRAY_VERTEX].size())
	for island_id in islands.size():
		var island = islands[island_id]
		for uv_coords in island:
			var vertex_ids = island[uv_coords]
			#print(vertex_ids)
			for id in vertex_ids:
				#if not island_vertex[id] == null:
					#print("id already set! " + str(id))
				island_vertex[id] = island_id

func get_islands():
	islands = []
	for i in surface_arrays[Mesh.ARRAY_INDEX].size()/3:
		var face_array = surface_arrays[Mesh.ARRAY_INDEX].slice(i*3,(i+1)*3)
		var face_was_added = -1
		var remove_islands = [] # remove after loop so it doesnt skip any
		
		for island_id in islands.size():
			var add_face_to_island = false
			for vertex_id in face_array:
				var uv_coords = surface_arrays[Mesh.ARRAY_TEX_UV][vertex_id]
				if uv_coords in islands[island_id]:
					add_face_to_island = true
			if add_face_to_island:
				if face_was_added == -1:
					for vertex_id in face_array:
						var uv_coords = surface_arrays[Mesh.ARRAY_TEX_UV][vertex_id]
						if not uv_coords in islands[island_id]:
							islands[island_id][uv_coords] = []
						if not vertex_id in islands[island_id][uv_coords]:
							islands[island_id][uv_coords].append(vertex_id)
					face_was_added = island_id
				else:
					# merge islands
					for uv_coords in islands[island_id]:
						if not uv_coords in islands[face_was_added]:
							islands[face_was_added][uv_coords] = []
						for vertex_id in islands[island_id][uv_coords]:
							if not vertex_id in islands[face_was_added][uv_coords]:
								islands[face_was_added][uv_coords].append(vertex_id)
					remove_islands.append(island_id)

		remove_islands.reverse() # to preserve order
		for island_id in remove_islands:
			islands.remove_at(island_id)

		if face_was_added == -1:
			var new_island = {}
			for vertex_id in face_array:
				var uv_coords = surface_arrays[Mesh.ARRAY_TEX_UV][vertex_id]
				new_island[uv_coords] = [vertex_id]
			islands.append(new_island)

	island_transform.resize(islands.size())
	get_island_bounding_boxes()
	get_island_vertex()
