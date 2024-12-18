@tool
extends Resource
class_name HumanizerMaterial

signal material_updated

const TEXTURE_LAYERS = ['albedo', 'normal', 'ao']
static var material_property_names = get_standard_material_properties()

@export var overlays: Array[HumanizerOverlay] = []
@export_file var base_material_path: String

static func get_standard_material_properties() -> PackedStringArray:
	var prop_names = PackedStringArray()
	#only get properties unique to material, so we can copy those onto existing material instead of gernating a new material and using signals
	
	var base_props = []
	for prop in Material.new().get_property_list():
		base_props.append(prop.name)
	
	for prop in StandardMaterial3D.new().get_property_list():
		var flags = PROPERTY_USAGE_SCRIPT_VARIABLE
		#if prop.name not in base_props and (prop.usage & flags > 0):
		if prop.name not in base_props and prop.usage < 64:
			prop_names.append(prop.name) 
			#print(str(prop.usage) + " " + prop.name)
	if not ProjectSettings.get("rendering/lights_and_shadows/use_physical_light_units"):
		prop_names.remove_at( prop_names.find("emission_intensity"))
	#remove these so it doesnt flash the base texture when it changes (only set texture when its done updating)
	for tex_name in TEXTURE_LAYERS:
		prop_names.remove_at( prop_names.find(tex_name + "_texture"))
	return prop_names

func duplicate(subresources=false):
	if not subresources:
		return super(subresources)
	else:
		var dupe = HumanizerMaterial.new()
		dupe.base_material_path = base_material_path
		for overlay in overlays:
			dupe.overlays.append(overlay.duplicate(true))
		return dupe

func generate_material_3D(material:StandardMaterial3D)->void:
	var base_material := StandardMaterial3D.new()
	if FileAccess.file_exists(base_material_path):
		base_material = HumanizerResourceService.load_resource(base_material_path)
		for prop_name in material_property_names:
			material.set(prop_name,base_material.get(prop_name))
		material.resource_local_to_scene = true
	if overlays.size() == 0:
		for tex_name in TEXTURE_LAYERS:
			tex_name += "_texture"
			material.set(tex_name , base_material.get(tex_name ))
	elif overlays.size() == 1:
		material.albedo_color = overlays[0].color
		if not overlays[0].albedo_texture_path in ["",null]:
			material.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, HumanizerResourceService.load_resource(overlays[0].albedo_texture_path))
		else:
			material.set_texture(BaseMaterial3D.TEXTURE_ALBEDO,null)
		if overlays[0].normal_texture_path in ["",null]:
			material.normal_enabled = false
			material.set_texture(BaseMaterial3D.TEXTURE_NORMAL,null)
		else:
			material.normal_enabled = true
			material.normal_scale = overlays[0].normal_strength
			material.set_texture(BaseMaterial3D.TEXTURE_NORMAL, HumanizerResourceService.load_resource(overlays[0].normal_texture_path))
		if not overlays[0].ao_texture_path in ["",null]:
			material.set_texture(BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, HumanizerResourceService.load_resource(overlays[0].ao_texture_path))
	else:
		# awaiting outside the main thread will switch to the main thread if the signal awaited is emitted by the main thread
		HumanizerJobQueue.add_job_main_thread(func():
			var textures = await _update_material()
			material.normal_enabled = textures.normal != null
			material.ao_enabled = textures.ao != null
			material.albedo_texture = textures.albedo
			material.normal_texture = textures.normal
			material.ao_texture = textures.ao
		)
	
	
func _update_material() -> Dictionary:
	var textures : Dictionary = {}
	if overlays.size() <= 1:
		return textures
	for texture in TEXTURE_LAYERS: #albedo, normal, ambient occulsion ect..
		var texture_size = Vector2(2**11,2**11)
		if overlays[0].albedo_texture_path != "":
			texture_size = HumanizerResourceService.load_resource(overlays[0].albedo_texture_path).get_size()
		var image_vp = SubViewport.new()
		
		image_vp.size = texture_size
		image_vp.transparent_bg = true
	

		for overlay in overlays:
			if overlay == null:
				continue
			var path = overlay.get(texture + '_texture_path')
			if path == null || path == '':
				if texture == 'albedo':
					var im_col_rect = ColorRect.new()
					im_col_rect.color = overlay.color
					image_vp.add_child(im_col_rect)
				continue
			var im_texture = HumanizerResourceService.load_resource(path)
			var im_tex_rect = TextureRect.new()
			im_tex_rect.position = overlay.offset
			im_tex_rect.texture = im_texture
			#image_vp.call_deferred("add_child",im_tex_rect)
			image_vp.add_child(im_tex_rect)
			if texture == 'albedo':
				#blend color with overlay texture and then copy to base image
				im_tex_rect.modulate = overlay.color
		
		if image_vp.get_child_count() == 0:
			textures[texture] = null
		else:
			Engine.get_main_loop().get_root().add_child.call_deferred(image_vp)
			image_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			if not image_vp.is_inside_tree():
				await Signal(image_vp,"tree_entered")
			await Signal(RenderingServer, "frame_post_draw")
			await RenderingServer.frame_post_draw
			var image = image_vp.get_texture().get_image()
			image.generate_mipmaps()
			textures[texture] = ImageTexture.create_from_image(image)
		image_vp.queue_free()
	return textures


func set_base_textures(overlay: HumanizerOverlay) -> void:
	if overlays.size() == 0:
		# Don't append, we want to call the setter 
		overlays = [overlay]
	overlays[0] = overlay

func add_overlay(overlay: HumanizerOverlay) -> void:
	if _get_index(overlay.resource_name) != -1:
		printerr('Overlay already present?')
		return
	overlays.append(overlay)
	material_updated.emit()

func set_overlay(idx: int, overlay: HumanizerOverlay) -> void:
	if overlays.size() - 1 >= idx:
		overlays[idx] = overlay
		material_updated.emit()
	else:
		push_error('Invalid overlay index')

func remove_overlay(ov: HumanizerOverlay) -> void:
	for o in overlays:
		if o == ov:
			overlays.erase(o)
			material_updated.emit()
			return
	push_warning('Cannot remove overlay ' + ov.resource_name + '. Not found.')
	
func remove_overlay_at(idx: int) -> void:
	if overlays.size() - 1 < idx or idx < 0:
		push_error('Invalid index')
		return
	overlays.remove_at(idx)
	material_updated.emit()

func remove_overlay_by_name(name: String) -> void:
	var idx := _get_index(name)
	if idx == -1:
		printerr('Overlay not present? ' + name)
		return
	overlays.remove_at(idx)
	material_updated.emit()
	
func _get_index(name: String) -> int:
	for i in overlays.size():
		if overlays[i].resource_name == name:
			return i
	return -1
