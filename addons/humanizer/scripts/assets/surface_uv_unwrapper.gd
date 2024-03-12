class_name UVUnwrapper

var surface_arrays = []
var islands = []
var island_boxes = []
var material
var island_transform = [] #set elsewhere, after the row packer is done
var island_vertex = []

func _init(mesh: ArrayMesh, surface_id: int, _material):
	material = _material
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
	get_island_vertex()
	get_island_bounding_boxes()
