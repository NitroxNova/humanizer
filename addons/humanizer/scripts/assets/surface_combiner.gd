class_name HumanizerSurfaceCombiner

var mesh_instances: Array[MeshInstance3D]
var path: String
var name: String

func _init(_mesh_instances: Array[MeshInstance3D], _path: String, _name: String) -> void:
	mesh_instances = _mesh_instances
	path = _path
	name = _name
	
func run() -> MeshInstance3D:
	var rect_array: Array = []
	var bin_size: int = 2 ** 12
	var surfaces: Array = []
	
	DirAccess.make_dir_recursive_absolute(path)
	
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
	
	var new_uv_image = Image.create(bin_size, bin_size, false, Image.FORMAT_RGBA8)
	
	for packed_rect in rect_packer.rects:
		var surface = surfaces[packed_rect.surface_id]
		var old_texture_image : Image = surface.get_albedo_texture().get_image()
		old_texture_image.decompress()
		old_texture_image.convert(new_uv_image.get_format())
		var old_island_position = surface.island_boxes[packed_rect.island_id].position * surface.get_albedo_texture_size()
		var island_size =  packed_rect.get_size()
		var new_island_position = packed_rect.get_position()
		new_uv_image.blit_rect(old_texture_image,Rect2(old_island_position,island_size),new_island_position)

	var texture := ImageTexture.create_from_image(new_uv_image)
	var albedo_path = path.path_join(name + '_albedo.res')
	texture.take_over_path(albedo_path)
	ResourceSaver.save(texture, albedo_path)
	
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
	for surface in surfaces:		
		new_sf_arrays[Mesh.ARRAY_VERTEX].append_array(surface.surface_arrays[Mesh.ARRAY_VERTEX])
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

	var material_path: String = path.path_join(name + '_material.tres')
	var new_material := StandardMaterial3D.new()
	new_material.albedo_texture = load(albedo_path)
	new_material.take_over_path(material_path)
	ResourceSaver.save(new_material, material_path)
	
	new_mesh.surface_set_material(0, new_material)
	var mesh_path: String = path.path_join(name + '_mesh.tres')
	new_mesh.take_over_path(mesh_path)
	ResourceSaver.save(new_mesh, mesh_path)
	
	var mi = MeshInstance3D.new()
	mi.mesh = new_mesh
	return mi
