class_name HumanizerSurfaceCombiner

var mesh_instances: Array[MeshInstance3D]
var atlas_resolution: int

func _init(_mesh_instances: Array[MeshInstance3D], _atlas_resolution: int) -> void:
	mesh_instances = _mesh_instances
	atlas_resolution = _atlas_resolution
	
func run() -> MeshInstance3D:
	var rect_array: Array = []
	var bin_size: int = 2 ** 12 
	var surfaces: Array = []

	for mesh: MeshInstance3D in mesh_instances:
		var surface_id = surfaces.size()
		var mat = mesh.get_surface_override_material(0)
		var sf_unwrapper = UVUnwrapper.new(mesh.mesh, 0, mat)
		surfaces.append(sf_unwrapper)
		sf_unwrapper.get_islands()
		for island_id in sf_unwrapper.island_boxes.size():
			var rect = sf_unwrapper.island_boxes[island_id]
			rect.size *= sf_unwrapper.get_albedo_texture_size()
			rect.position = Vector2.ZERO
			var packable_rect = BinaryRectPacker.Packable_Rect.new(rect, surface_id, island_id)
			rect_array.append(packable_rect)
	var rect_packer = BinaryRectPacker.new(rect_array, bin_size)
	
	for packed_rect in rect_packer.rects:
		var surface = surfaces[packed_rect.surface_id]
		var new_island_position = packed_rect.get_position() / bin_size
		var old_island_size = surface.island_boxes[packed_rect.island_id].size
		var new_island_size = packed_rect.get_size() / bin_size
		var island_scale = new_island_size/old_island_size
		var xform = Rect2(new_island_position,island_scale)
		surface.island_transform[packed_rect.island_id] = xform
	
	var new_albedo_image = Image.create(bin_size, bin_size, false, Image.FORMAT_RGBA8)
	var new_normal_image = Image.create(bin_size, bin_size, false, Image.FORMAT_RGBA8)
	new_normal_image.fill(Color(.5,.5,1,1))
	var new_ao_image = Image.create(bin_size, bin_size, false, Image.FORMAT_RGB8)
	new_ao_image.fill(Color(1,1,1))
	var has_normal = false
	var has_ao = false
	
	var surface_rects_index = []
	surface_rects_index.resize(surfaces.size())
	for id in rect_packer.rects.size():
		var rect = rect_packer.rects[id]
		var surface_id = rect.surface_id
		if surface_rects_index[surface_id] == null:
			surface_rects_index[surface_id] = []
		surface_rects_index[surface_id].append(id)
	
	for surface_id in surfaces.size():
		var surface : UVUnwrapper = surfaces[surface_id]
		var old_albedo_image : Image = surface.get_albedo_texture().get_image()
		if old_albedo_image.is_compressed():
			old_albedo_image.decompress()
		old_albedo_image.convert(new_albedo_image.get_format())
		if surface.material.albedo_color != Color(1,1,1,1):
			blend_color(old_albedo_image,surface.material.albedo_color)
		var old_normal_image : Image
		var old_ao_image : Image 
		if surface.is_normal_enabled():
			has_normal = true
			old_normal_image = surface.get_normal_texture().get_image()
			if old_normal_image.is_compressed():
				old_normal_image.decompress()
			old_normal_image.convert(new_normal_image.get_format())
			old_normal_image.resize(surface.get_albedo_texture_size().x,surface.get_albedo_texture_size().y)

		if surface.is_ao_enabled():
			has_ao = true
			old_ao_image = surface.get_ao_texture().get_image()
			if old_ao_image.is_compressed():
				old_ao_image.decompress()
			old_ao_image.convert(new_ao_image.get_format())
			old_ao_image.resize(surface.get_albedo_texture_size().x,surface.get_albedo_texture_size().y)
				
		
		for rect_id in surface_rects_index[surface_id]:
			var packed_rect = rect_packer.rects[rect_id]
			var old_island_position = surface.island_boxes[packed_rect.island_id].position * surface.get_albedo_texture_size()
			var island_size =  packed_rect.get_size()
			var new_island_position = packed_rect.get_position()
			new_albedo_image.blit_rect(old_albedo_image,Rect2(old_island_position,island_size),new_island_position)
			if surface.is_normal_enabled():
				if surface.material.normal_scale == 1:
					new_normal_image.blit_rect(old_normal_image,Rect2(old_island_position,island_size),new_island_position)
				else:
					for x in island_size.x:
						for y in island_size.y:
							var old_color = old_normal_image.get_pixel(x + old_island_position.x, y + old_island_position.y)
							old_color.b = sqrt(1 - old_color.g ** 2 - old_color.r ** 2)
							var new_vec = Vector3(old_color.r, old_color.g, old_color.b)
							new_vec = 2 * new_vec - Vector3.ONE
							new_vec.x *= surface.material.normal_scale
							new_vec.y *= surface.material.normal_scale
							new_vec = 0.5 * (new_vec + Vector3.ONE)
							new_vec.z = sqrt(1 - new_vec.x ** 2 - new_vec.y ** 2)

							var new_color := Color(new_vec.x, new_vec.y, new_vec.z)
							new_normal_image.set_pixel(x + new_island_position.x, y + new_island_position.y, new_color)
			if surface.is_ao_enabled():
				new_ao_image.blit_rect(old_ao_image,Rect2(old_island_position,island_size),new_island_position)

	
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = []
	new_sf_arrays.resize(Mesh.ARRAY_MAX)
	new_sf_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	new_sf_arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array()
	new_sf_arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	new_sf_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	new_sf_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	new_sf_arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
	new_sf_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
	
	#issue is the human mesh has 4 bones per vertex and the clothes have 8
	var mesh_bone_count = 0 #get the max bone count for all surfaces, might be better to just set it to 8
	for surface in surfaces:
		var sf_bone_count = surface.surface_arrays[Mesh.ARRAY_BONES].size()/surface.surface_arrays[Mesh.ARRAY_VERTEX].size()
		if sf_bone_count > mesh_bone_count:
			mesh_bone_count = sf_bone_count	
	
	var vertex_offset = 0
	for surface_id in surfaces.size():
		var surface = surfaces[surface_id]
		
		if mesh_instances[surface_id].transform == Transform3D.IDENTITY:
			new_sf_arrays[Mesh.ARRAY_VERTEX].append_array(surface.surface_arrays[Mesh.ARRAY_VERTEX])
		else:
			for vertex_pos in surface.surface_arrays[Mesh.ARRAY_VERTEX]:
				var mi = mesh_instances[surface_id]
				vertex_pos = mi.transform * vertex_pos
				new_sf_arrays[Mesh.ARRAY_VERTEX].append(vertex_pos)  
		
		new_sf_arrays[Mesh.ARRAY_TANGENT].append_array(surface.surface_arrays[Mesh.ARRAY_TANGENT])
		new_sf_arrays[Mesh.ARRAY_NORMAL].append_array(surface.surface_arrays[Mesh.ARRAY_NORMAL])
		
		var sf_bone_count = surface.surface_arrays[Mesh.ARRAY_BONES].size()/surface.surface_arrays[Mesh.ARRAY_VERTEX].size()
		if sf_bone_count == mesh_bone_count:
			new_sf_arrays[Mesh.ARRAY_BONES].append_array(surface.surface_arrays[Mesh.ARRAY_BONES])
			new_sf_arrays[Mesh.ARRAY_WEIGHTS].append_array(surface.surface_arrays[Mesh.ARRAY_WEIGHTS])
		
		for i in surface.surface_arrays[Mesh.ARRAY_INDEX]:
			i += vertex_offset
			new_sf_arrays[Mesh.ARRAY_INDEX].append(i)
		for vertex_id in surface.surface_arrays[Mesh.ARRAY_VERTEX].size():
			var uv = surface.surface_arrays[Mesh.ARRAY_TEX_UV][vertex_id]
			var island_id = surface.island_vertex[vertex_id]
			var island_xform = surface.island_transform[island_id]
			var new_uv = island_xform.position	
			
			var old_offset = uv - surface.island_boxes[island_id].position
			var new_offset = old_offset * island_xform.size
			new_uv += new_offset
			new_sf_arrays[Mesh.ARRAY_TEX_UV].append(new_uv)
						
			if sf_bone_count < mesh_bone_count:
				var bone_slice = surface.surface_arrays[Mesh.ARRAY_BONES].slice(vertex_id*sf_bone_count,(vertex_id+1)*sf_bone_count)
				var weight_slice = surface.surface_arrays[Mesh.ARRAY_WEIGHTS].slice(vertex_id*sf_bone_count,(vertex_id+1)*sf_bone_count)
				while bone_slice.size() < mesh_bone_count:
					bone_slice.append(0)
					weight_slice.append(0)
				new_sf_arrays[Mesh.ARRAY_BONES].append_array(bone_slice)
				new_sf_arrays[Mesh.ARRAY_WEIGHTS].append_array(weight_slice)
				
		vertex_offset += surface.surface_arrays[Mesh.ARRAY_VERTEX].size()
		
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays)

	var new_material := mesh_instances[0].get_surface_override_material(0).duplicate()
	
	if not new_albedo_image.get_width() == atlas_resolution:
		new_albedo_image.resize(atlas_resolution, atlas_resolution)
	var albedo_texture := ImageTexture.create_from_image(new_albedo_image)
	new_material.albedo_texture = albedo_texture
	new_material.albedo_color = Color.WHITE
	
	if has_normal:
		if not new_normal_image.get_width() == atlas_resolution:
			new_normal_image.resize(atlas_resolution,atlas_resolution)
		new_material.normal_enabled = true
		new_material.normal_scale = 1
		new_material.normal_texture = ImageTexture.create_from_image(new_normal_image)
		
	if has_ao:
		if not new_ao_image.get_width() == atlas_resolution:
			new_ao_image.resize(atlas_resolution,atlas_resolution)
		new_material.ao_enabled = true
		new_material.ao_texture = ImageTexture.create_from_image(new_ao_image)
		
	new_mesh.surface_set_material(0, new_material)
	var mi = MeshInstance3D.new()
	mi.mesh = new_mesh
	return mi

func blend_color(image: Image, color: Color) -> void:
	if image.is_compressed():
		image.decompress()
	for x in image.get_width():
		for y in image.get_height():
			image.set_pixel(x, y, image.get_pixel(x, y) * color)
			
static func compress_material(args:Dictionary): 
	var mesh:ArrayMesh = args.mesh
	for surface_id in mesh.get_surface_count():
		var material: BaseMaterial3D = mesh.surface_get_material(surface_id)
		if material.resource_path == '':
			continue
		
		for texture in ['albedo', 'normal', 'ao']:
			if not material.get(texture + '_texture') == null:
				var image = material.get(texture + '_texture').get_image()
				if not image.has_mipmaps():
					image.generate_mipmaps()
				image.compress(Image.COMPRESS_BPTC)
				var save_path = material.get(texture + '_texture').get_path()
				if save_path != "":
					ResourceSaver.save(ImageTexture.create_from_image(image), save_path)
					material.set(texture + '_texture', load(save_path))
				
		ResourceSaver.save(material, material.resource_path)
