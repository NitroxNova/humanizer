@tool
extends Resource
class_name Human_Builder

var helper_vertex = []
const shapekey_data = preload("res://experimental/process_shapekeys/shapekey_data.res")
const skeleton_config = preload("res://experimental/build_skeleton/skeleton_config.res")
var human_char : Human_Character
var basis_mesh = preload("res://experimental/generate_mesh/human.res")

func _init(_human_char:Human_Character):
	human_char = _human_char
	calculate_helper_vertex()
	rebuild_human()

func rebuild_human():
	build_skeleton()
	build_human_mesh()
	set_clothes(human_char.clothes_folder)
	generate_normals_tangents()
	reset_mesh_skins_from_skeleton()

func generate_normals_tangents():
	human_char.body_mesh_inst.mesh = Utils.generate_normals_tangents(human_char.body_mesh_inst.mesh)
	human_char.get_node("Clothes").mesh = Utils.generate_normals_tangents(human_char.get_node("Clothes").mesh)

func calculate_helper_vertex():
	var mesh_inst = human_char.body_mesh_inst
	helper_vertex = shapekey_data.basis.duplicate(true)
	for shapekey_name in human_char.shapekeys.values():
		var shapekey_value = human_char.shapekeys[shapekey_name]
		for mh_id in shapekey_data.shapekeys[shapekey_name]:
			helper_vertex[int(mh_id)] += shapekey_data.shapekeys[shapekey_name][mh_id] * shapekey_value
	for combo_name in human_char.macros.combo_shapekeys:
		for shapekey_name in human_char.macros.combo_shapekeys[combo_name]:
			var ratio = human_char.macros.combo_shapekeys[combo_name][shapekey_name]
			for mh_id in shapekey_data.shapekeys[shapekey_name]:
				helper_vertex[int(mh_id)] += shapekey_data.shapekeys[shapekey_name][mh_id] * ratio
	
func build_human_mesh():
	var new_mesh = ArrayMesh.new()
	var new_sf_arrays = basis_mesh.surface_get_arrays(0)
	for gd_id in new_sf_arrays[Mesh.ARRAY_VERTEX].size():
		var mh_id = new_sf_arrays[Mesh.ARRAY_CUSTOM0][gd_id]
		new_sf_arrays[Mesh.ARRAY_VERTEX][gd_id] = helper_vertex[mh_id]
		
	var flags = basis_mesh.surface_get_format(0)
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,new_sf_arrays,[],{},flags)
	human_char.body_mesh_inst.mesh = new_mesh
	
func set_macro_value(macro_name:String,macro_value:float):
	human_char.macros.set_macro_value(macro_name,macro_value)
	calculate_helper_vertex()
	update_skin_textures()
	
func set_race(race:String):
	if race == "african":
		human_char.macros.set_race(1,0,0)
	elif race == "asian":
		human_char.macros.set_race(0,1,0)
	elif race == "caucasian":
		human_char.macros.set_race(0,0,1)
	calculate_helper_vertex()
	
func update_skin_textures():
	var shader_material : ShaderMaterial = human_char.body_mesh_inst.get_surface_override_material(0)
	if human_char.get_age() < 15:
		if human_char.macros.data.gender.value > .5:
			shader_material.set_shader_parameter("texture_light",load("res://addons/humanizer/data/assets/skins/young_asian_male/young_asian_male_diffuse3.png"))
			shader_material.set_shader_parameter("texture_dark",load("res://addons/humanizer/data/assets/skins/young_african_male/young_african_male_diffuse.png"))
		else:
			shader_material.set_shader_parameter("texture_light",load("res://addons/humanizer/data/assets/skins/young_asian_female/young_asian_female_diffuse3.png"))
			shader_material.set_shader_parameter("texture_dark",load("res://addons/humanizer/data/assets/skins/young_african_female/young_african_female_diffuse.png"))
	elif human_char.get_age() < 65:
		if human_char.macros.data.gender.value > .5:
			shader_material.set_shader_parameter("texture_light",load("res://addons/humanizer/data/assets/skins/middleage_asian_male/middleage_asian_male_diffuse2.png"))
			shader_material.set_shader_parameter("texture_dark",load("res://addons/humanizer/data/assets/skins/middleage_african_male/middleage_african_male_diffuse.png"))
		else:
			shader_material.set_shader_parameter("texture_light",load("res://addons/humanizer/data/assets/skins/middleage_asian_female/middleage_asian_female_diffuse2.png"))
			shader_material.set_shader_parameter("texture_dark",load("res://addons/humanizer/data/assets/skins/middleage_african_female/middleage_african_female_diffuse.png"))
	else:
		if human_char.macros.data.gender.value > .5:
			shader_material.set_shader_parameter("texture_light",load("res://addons/humanizer/data/assets/skins/old_caucasian_male/old_caucasian_male_diffuse.png"))
			shader_material.set_shader_parameter("texture_dark",load("res://addons/humanizer/data/assets/skins/old_african_male/old_african_male_diffuse.png"))
		else:
			shader_material.set_shader_parameter("texture_light",load("res://addons/humanizer/data/assets/skins/old_caucasian_female/old_caucasian_female_diffuse.png"))
			shader_material.set_shader_parameter("texture_dark",load("res://addons/humanizer/data/assets/skins/old_african_female/old_african_female_diffuse.png"))


func reset_mesh_skins_from_skeleton():
	human_char.body_mesh_inst.skin = human_char.skeleton.create_skin_from_rest_transforms()
	human_char.get_node("Clothes").skin = human_char.skeleton.create_skin_from_rest_transforms()
	
func set_blend_shape_value(sk_name,ratio,is_macro=false):
	var sk_id = human_char.body_mesh_inst.find_blend_shape_by_name(sk_name)
	human_char.body_mesh_inst.set_blend_shape_value(sk_id,ratio)
	#human_char.get_node("Clothes").set_blend_shape_value(sk_id,value)
	
	var category = "other"
	if is_macro:
		category = "macro"
	
	var had_shapekey = false
	if sk_name in human_char.shapekeys:
		had_shapekey = true
	
	for mh_id in shapekey_data.shapekeys[sk_name]:
		var shapekey_max = shapekey_data.shapekeys[sk_name][mh_id]
		var prev_value = Vector3.ZERO
		if had_shapekey:
			prev_value = human_char.shapekeys[sk_name] * shapekey_max
		var new_value = ratio * shapekey_max
		var change_amount = new_value - prev_value
		helper_vertex[mh_id] += change_amount
		
	if ratio == 0:
		human_char.shapekeys.erase(sk_name)
	else:
		human_char.shapekeys[sk_name] = ratio

func build_skeleton():
	var skeleton = human_char.skeleton
	skeleton.reset_bone_poses()
	for bone_id in skeleton.get_bone_count():
		var bone_pos = calculate_bone_position(bone_id)
#		var bone_id = skeleton.find_bone(bone_name)
		var parent_id = skeleton.get_bone_parent(bone_id)
		if not parent_id == -1:
			var parent_xform = skeleton.get_bone_global_pose(parent_id)
			bone_pos = bone_pos * parent_xform
		skeleton.set_bone_pose_position(bone_id,bone_pos)
		skeleton.set_bone_rest(bone_id,skeleton.get_bone_pose(bone_id))
	skeleton.reset_bone_poses()
		
func calculate_bone_position(bone_id:int):
	var bone_data = skeleton_config.data[bone_id]
	var bone_pos = average_bone_vertex(bone_data.head.vertex_indices)
	return bone_pos
			
func average_bone_vertex(index_array:Array):
	var bone_pos = Vector3.ZERO
	for b_index in index_array:
		bone_pos += helper_vertex[b_index] 
	bone_pos /= index_array.size()
	#bone_pos = bone_pos - skeleton_data.basis[bone_id]
	return bone_pos
	
func set_clothes(clothes_path:String):
	human_char.clothes_folder = clothes_path
	var clothes_builder = Clothes_Builder.new(clothes_path)
	var new_mesh = clothes_builder.build_fitted_mesh(helper_vertex)
	human_char.get_node("Clothes").mesh = new_mesh
	
	human_char.get_node("Mask_Viewport/ClothesMask").texture = load("res://experimental/generated_assets/".path_join(clothes_path).path_join("clothes_mask.png"))
	var mask_texture = human_char.get_node("Mask_Viewport").get_texture()
	var shader_material : ShaderMaterial = human_char.body_mesh_inst.get_surface_override_material(0)
	shader_material.set_shader_parameter("texture_mask",mask_texture)

func set_skin_color(color:Color):
	#print("setting skin color")
	var shader_material : ShaderMaterial = human_char.body_mesh_inst.get_surface_override_material(0)
	shader_material.set_shader_parameter("albedo",color)

func set_skin_color_ratio(ratio:float):
	#print("setting skin tone " + str(ratio))
	var shader_material : ShaderMaterial = human_char.body_mesh_inst.get_surface_override_material(0)
	shader_material.set_shader_parameter("percent_light",1-(ratio/100.0))
	
	
#the image copy_from function does not combine transparent images, it just replaces
#need to use a viewport instead?
func combine_clothing_mask(clothes_list:Array):
	var clothes_mask = Image.create(256,256,false,Image.FORMAT_RGBA8)
	clothes_mask.fill(Color.WHITE)
	for path:String in clothes_list:
		var image = Image.load_from_file(path.path_join("clothes_mask.png"))
		clothes_mask.copy_from(image)
	#An Image cannot be assigned to a texture property of an object directly (such as Sprite2D.texture), and has to be converted manually to an ImageTexture first.
	return ImageTexture.create_from_image(clothes_mask)
