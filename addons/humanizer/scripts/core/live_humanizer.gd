extends Humanizer
# attaches to a physics body to update the meshes and skeletons on that node.
# so you DONT have to change node resources when updating the character
# can be loaded for npcs like normal humanizer, or kept alive for the Player Character for instant gear changing. 
# Not recomended to keep too many of these around, as it duplicates all the vertex data
# Will add them to a list to keep them alive until done rendering materials, at least
# cant just extend characterbody3d because then i'll have duplicate code for each type
class_name Live_Humanizer

var physics_body : PhysicsBody3D # can be any Character3D, StaticBody or Rigid
enum HIDE_VERTEX_FLAGS {disabled, enabled, body_only} #still need to implement 'body only'
var hide_vertex = HIDE_VERTEX_FLAGS.disabled

func get_CharacterBody3D(baked=false):
	if hide_vertex == HIDE_VERTEX_FLAGS.enabled:
		hide_clothes_vertices()
	physics_body = super.get_CharacterBody3D(baked)
	skeleton_changed.connect(update_skeleton_node)
	return physics_body
	
func set_vertex_hiding_enabled():
	hide_vertex = HIDE_VERTEX_FLAGS.enabled

func add_equipment(equip:HumanizerEquipment):
	super.add_equipment(equip)
	update_all_equipment_nodes()

func remove_equipment(equip:HumanizerEquipment):
	super.remove_equipment(equip)
	update_all_equipment_nodes()

func set_targets(target_data:Dictionary):
	super.set_targets(target_data)
	#update_skeleton_node()
	update_all_equipment_nodes()

func find_skeleton_node():
	return physics_body.get_node("GeneralSkeleton")

func find_animation_tree_node()->AnimationTree:
	return physics_body.get_node("AnimationTree")

func find_main_collider_node()-> CollisionShape3D:
	return physics_body.get_node("MainCollider")

func toggle_animation_tree():
	#fixes skeleton a-pose
	var anim_tree = find_animation_tree_node()
	anim_tree.active=false
	anim_tree.active=true

func update_human_node():
	update_skeleton_node()
	update_main_collider_node()
	update_all_equipment_nodes()
	
func update_skeleton_node():
	var skeleton = find_skeleton_node()
	HumanizerEditorUtils.replace_node(skeleton,super.get_skeleton())
	toggle_animation_tree()

func update_main_collider_node():
	var collider = find_main_collider_node()
	HumanizerEditorUtils.replace_node(collider,super.get_main_collider())
	
func update_all_equipment_nodes():
	# because of vertex hiding, cant just update one piece of clothing. 
	var body_mesh = physics_body.get_node("Avatar")
	if hide_vertex == HIDE_VERTEX_FLAGS.enabled:
		super.hide_clothes_vertices()
	body_mesh.mesh = get_combined_meshes()
	var skeleton = find_skeleton_node()
	body_mesh.skeleton = NodePath('../' + skeleton.name)
	body_mesh.skin = skeleton.create_skin_from_rest_transforms()
