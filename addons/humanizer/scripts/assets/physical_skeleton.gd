class_name HumanizerPhysicalSkeleton

var skeleton: Skeleton3D
var helper_vertex: Array
var layers
var mask


func _init(_skeleton: Skeleton3D, _helper_vertex, _layers, _mask):
	skeleton = _skeleton
	helper_vertex = _helper_vertex
	layers = _layers
	mask = _mask

func run() -> void:
	for child in skeleton.get_children():
		skeleton.remove_child(child)
		child.queue_free()
	
	_add_collider(&'Head', null, 'sphere')
	
	var next_limb_bone = {
		&'Hips': &'UpperChest',
		&'UpperChest': &'Neck',
		&'Shoulder': &'UpperArm',
		&'UpperArm': &'LowerArm',
		&'LowerArm': &'Hand',
		&'UpperLeg': &'LowerLeg',
		&'LowerLeg': &'Foot',
		&'Neck': &'Head',
		&'Hand': &'MiddleDistal',
		&'Foot': &'Toes',
	}

	for bone in next_limb_bone:
		var shape := 'capsule'
		if 'Hand' in bone or 'Foot' in bone or 'Hips' in bone or 'Chest' in bone:
			shape = 'box'
		if skeleton.find_bone(bone) > -1:
			_add_collider(bone, next_limb_bone[bone], shape)
		else:
			for side in [&'Left', &'Right']:
				_add_collider(side + bone, side + next_limb_bone[bone], shape)

func _add_collider(bone, next=null, shape='capsule') -> void:
	var physical_bone = PhysicalBone3D.new()
	var collider = CollisionShape3D.new()
	physical_bone.name = &'Physical Bone ' + bone
	physical_bone.add_child(collider)
	skeleton.add_child(physical_bone)
	physical_bone.owner = skeleton
	collider.owner = skeleton
	physical_bone.scale = Vector3.ONE
	physical_bone.collision_layer = layers
	physical_bone.collision_mask = mask
	physical_bone.bone_name = bone
	
	if shape == 'capsule':
		collider.shape = CapsuleShape3D.new()
	elif shape == 'box':
		collider.shape = BoxShape3D.new()
	elif shape == 'sphere':
		collider.shape = SphereShape3D.new()

	if shape == 'box': 
		collider.shape.size = Vector3.ONE * 0.1
	elif shape == 'sphere':
		collider.shape.radius = 0.1
		
	if next == null:
		collider.global_basis = physical_bone.global_basis
		collider.global_position = physical_bone.global_position
		#### May need to adjust positions here
	else:
		var next_id: int = skeleton.find_bone(next)
		var next_position: Vector3 = skeleton.get_bone_global_pose(next_id).origin
		var this_position: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
		var up = Basis.looking_at(this_position - next_position).z
		var forward = up.cross(skeleton.basis.z)  # Choose a random vector normal to up
		if shape == 'capsule':
			collider.global_basis = Basis.looking_at(forward, up) 
		else:
			collider.global_basis = Basis.looking_at(up) 
		collider.global_position = 0.5 * (this_position + next_position)
		
		### Do resizing here
		if shape == 'capsule':
			collider.shape.height = (next_position - this_position).length()
			var vertex_bounds = get_vertex_bounds(bone)
			collider.shape.radius = vertex_bounds.distance * 0.5
			
		elif shape == 'box':
			collider.shape.size.z

func get_vertex_bounds(bone: String) -> Dictionary:
	#refer to mpfb2_plugin.data/mesh_metadata/hm08.mirror for opposites
	var vertex_names = {
		"LeftUpperArmFront" = 8114,
		"LeftUpperArmBack" = 8330,
		"RightUpperArmFront" = 1426,
		"RightUpperArmBack" = 1658,
		"LeftLowerArmFront" = 10541,
		"LeftLowerArmBack" = 10110,
		"RightLowerArmFront" = 3876,
		"RightLowerArmBack" = 3442,
		"LeftLowerLegFront" = 11325,
		"LeftLowerLegBack" = 11339,
		"RightLowerLegFront" = 4707,
		"RightLowerLegBack" = 4721,
		"LeftUpperLegFront" = 11116,
		"LeftUpperLegBack" = 13340,
		"RightUpperLegFront" = 4498,
		"RightUpperLegBack" = 6744,
	}
	var vertex_1 : int = vertex_names[bone + &'Front']
	var vertex_2 : int = vertex_names[bone + &'Back']
	return {
		'distance': helper_vertex[vertex_1].distance_to(helper_vertex[vertex_2]),
		'center': 0.5 * (helper_vertex[vertex_1] + helper_vertex[vertex_2])
	}
