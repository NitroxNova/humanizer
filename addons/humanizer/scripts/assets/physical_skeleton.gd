class_name HumanizerPhysicalSkeleton

var skeleton: Skeleton3D
var helper_vertex: Array
var layers
var mask

enum ColliderShape {
	BOX,
	CAPSULE,
	SPHERE
}


func _init(_skeleton: Skeleton3D, _helper_vertex, _layers, _mask):
	skeleton = _skeleton
	helper_vertex = _helper_vertex
	layers = _layers
	mask = _mask

func run() -> void:
	for child in skeleton.get_children():
		skeleton.remove_child(child)
		child.queue_free()
	
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
	_add_collider(&'Head', null, ColliderShape.SPHERE)
	for bone in next_limb_bone:
		var shape := ColliderShape.CAPSULE
		if 'Hand' in bone or 'Foot' in bone or 'Hips' in bone or 'Chest' in bone:
			shape = ColliderShape.BOX
		if skeleton.find_bone(bone) > -1:
			_add_collider(bone, next_limb_bone[bone], shape)
		else:
			for side in [&'Left', &'Right']:
				_add_collider(side + bone, side + next_limb_bone[bone], shape)

func _add_collider(bone, next=null, shape:=ColliderShape.CAPSULE) -> void:
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
	
	if shape == ColliderShape.CAPSULE:
		collider.shape = CapsuleShape3D.new()
	elif shape == ColliderShape.BOX:
		collider.shape = BoxShape3D.new()
	elif shape == ColliderShape.SPHERE:
		collider.shape = SphereShape3D.new()

	if next == null:
		collider.global_basis = physical_bone.global_basis
		collider.global_position = physical_bone.global_position
		#### May need to adjust positions here
	else:
		var next_id: int = skeleton.find_bone(next)
		var next_position: Vector3 = skeleton.get_bone_global_pose(next_id).origin * skeleton.global_transform.inverse()
		var this_position: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin * skeleton.global_transform.inverse()
		var up = Basis.looking_at(this_position - next_position).z
		var forward = up.cross(skeleton.basis.x)
		if shape == ColliderShape.CAPSULE:
			collider.global_basis = Basis.looking_at(forward, up) 
		else:
			collider.global_basis = Basis.looking_at(up, forward) 
		collider.global_position = 0.5 * (this_position + next_position)
		
		### Do resizing here
		if shape == ColliderShape.CAPSULE:
			collider.shape.height = (next_position - this_position).length()
			var vertex_bounds = get_capsule_vertex_bounds(bone)
			collider.shape.radius = vertex_bounds.distance * 0.5
			var bone_y_cross_ratio = (vertex_bounds.center.y - this_position.y)/(next_position.y-this_position.y)
			var bone_y_cross = this_position.lerp(next_position,bone_y_cross_ratio)
			## need to fix offset
			#collider.global_position.z += vertex_bounds.center.z - bone_y_cross.z
			#collider.global_position.x += vertex_bounds.center.x - bone_y_cross.x
			
		elif shape == ColliderShape.BOX:
			var bounds = get_box_vertex_bounds(bone)
			var size: Vector3 = bounds.size
			var center: Vector3 = bounds.center
			if 'Hips' in bone or 'Chest' in bone:
				size = Vector3(size.y, size.z, size.x)
				collider.global_position = center
			collider.shape.size = size

func get_box_vertex_bounds(bone: String) -> Dictionary:
	var vertex_names = {
		"HipsTop" = 4154,
		"HipsBottom" = 4370,
		"HipsFront" = 4110,
		"HipsBack" = 11006,
		"HipsLeft" = 10899,
		"HipsRight" = 4269,
		"UpperChestTop" = 1524,
		"UpperChestBottom" = 4154,
		"UpperChestFront" = 4070,
		"UpperChestBack" = 8259,
		"UpperChestLeft" = 10602,
		"UpperChestRight" = 3938,
		"LeftFootFront" = 13146,
		"LeftFootBack" = 12442,
		"LeftFootRight" = 13300,
		"LeftFootLeft" = 12808,
		"LeftFootTop" = 12818,
		"LeftFootBottom" = 12877,
		"RightFootFront" = 6550,
		"RightFootBack" = 5845,
		"RightFootRight" = 6211,
		"RightFootLeft" = 6704,
		"RightFootTop" = 6221,
		"RightFootBottom" = 6280,
		"LeftHandTop" = 10492,
		"LeftHandBottom" = 8929,
		"LeftHandFront" = 8600,
		"LeftHandBack" = 10535,
		"LeftHandLeft" = 9390,
		"LeftHandRight" = 8983,
		"RightHandTop" = 3826,
		"RightHandBottom" = 2261,
		"RightHandFront" = 1932,
		"RightHandBack" = 3870,
		"RightHandLeft" = 2315,
		"RightHandRight" = 2722,
		}
		
	var top : int = vertex_names[bone + 'Top']
	var bottom : int = vertex_names[bone + 'Bottom']
	var left : int = vertex_names[bone + 'Left']
	var right : int = vertex_names[bone + 'Right']
	var front : int = vertex_names[bone + 'Front']
	var back : int = vertex_names[bone + 'Back']
	
		
	var size := Vector3.ZERO
	size.x = abs(helper_vertex[left].x - helper_vertex[right].x)
	size.y = abs(helper_vertex[top].y - helper_vertex[bottom].y)
	size.z = abs(helper_vertex[front].z - helper_vertex[back].z)
	
	var center := Vector3.ZERO
	center.x = (helper_vertex[left].x + helper_vertex[right].x) * .5
	center.y = (helper_vertex[top].y + helper_vertex[bottom].y) * .5
	center.z = (helper_vertex[front].z + helper_vertex[back].z) * .5
	
	return {size=size, center=center}

func get_capsule_vertex_bounds(bone: String) -> Dictionary:
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
		"NeckFront" = 791,
		"NeckBack" = 856,
		"LeftShoulderFront" = 8057,
		"LeftShoulderBack" = 8281,
		"RightShoulderFront" = 1365,
		"RightShoulderBack" = 1609,
		
	}
	var vertex_1 : int = vertex_names[bone + &'Front']
	var vertex_2 : int = vertex_names[bone + &'Back']
	return {
		'distance': helper_vertex[vertex_1].distance_to(helper_vertex[vertex_2]),
		'center': 0.5 * (helper_vertex[vertex_1] + helper_vertex[vertex_2])
	}
