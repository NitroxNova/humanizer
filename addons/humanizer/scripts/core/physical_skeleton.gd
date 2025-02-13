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
		if child is PhysicalBone3D:
			skeleton.remove_child(child)
			child.queue_free()
	
	var next_limb_bone = {
		&'Hips': &'UpperChest',
		&'UpperChest': &'Neck',
		#&'Shoulder': &'UpperArm', ## unity default ragdoll does not include
		&'UpperArm': &'LowerArm',
		&'LowerArm': &'Hand',
		&'UpperLeg': &'LowerLeg',
		&'LowerLeg': &'Foot',
		&'Neck': &'Head',  ## Don't think we need this collider
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
		if shape == ColliderShape.SPHERE:
			var bounds = get_sphere_vertex_bounds(bone)
			collider.shape.radius = bounds.radius
			collider.global_position = bounds.center
			collider.global_transform = skeleton.global_transform * collider.global_transform
	else:
		var next_id: int = skeleton.find_bone(next)
		var next_position: Vector3 = skeleton.get_bone_global_pose(next_id).origin 
		var this_position: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
		var up = Basis.looking_at(this_position - next_position).z
		var forward = Vector3.FORWARD
		var right = up.cross(forward)
		forward = right.cross(up)
		if 'Foot' not in bone:
			collider.global_basis = Basis.looking_at(forward, up) 
		else:
			collider.global_basis = Basis.looking_at(up, forward)
		collider.global_position = 0.5 * (this_position + next_position)

		### Do resizing here
		if shape == ColliderShape.CAPSULE:
			collider.shape.height = (next_position - this_position).length()
			var vertex_bounds = get_capsule_vertex_bounds(bone)
			collider.shape.radius = vertex_bounds.distance * 0.5
			var bone_y_cross_ratio = (vertex_bounds.center.y - this_position.y)/(next_position.y - this_position.y)
			var bone_y_cross = this_position.lerp(next_position, bone_y_cross_ratio)
			var offset := Vector3.ZERO
			collider.global_position.z += vertex_bounds.center.z - bone_y_cross.z
			collider.global_position.x += vertex_bounds.center.x - bone_y_cross.x
			
		elif shape == ColliderShape.BOX:
			var bounds = get_box_vertex_bounds(bone)
			var size: Vector3 = bounds.size
			var center: Vector3 = bounds.center
			collider.global_position = center
			collider.shape.size = size
			#if 'RightHand' in bone:
			#	collider.rotate_y(30)
			#elif 'LeftHand' in bone:
			#	collider.rotate_y(-30)

		collider.global_transform = skeleton.global_transform * collider.global_transform
	add_joint(physical_bone,bone)

func add_joint(phys_bone:PhysicalBone3D,bone_name:String):
	var joints = {
		"LeftLowerLeg" = [PhysicalBone3D.JOINT_TYPE_HINGE,{"joint_rotation"=Vector3(0,-PI/2,0),"joint_constraints/angular_limit_enabled"=true,"joint_constraints/angular_limit_upper"=90,"joint_constraints/angular_limit_lower"=20}],
		"RightLowerLeg" = [PhysicalBone3D.JOINT_TYPE_HINGE,{"joint_rotation"=Vector3(0,-PI/2,0),"joint_constraints/angular_limit_enabled"=true,"joint_constraints/angular_limit_upper"=90,"joint_constraints/angular_limit_lower"=20}],
		"LeftLowerArm" = [PhysicalBone3D.JOINT_TYPE_HINGE,{"joint_rotation"=Vector3(deg_to_rad(-15),deg_to_rad(-50),0),"joint_constraints/angular_limit_enabled"=true,"joint_constraints/angular_limit_lower"=0,"joint_constraints/angular_limit_upper"=90}],
		"RightLowerArm" = [PhysicalBone3D.JOINT_TYPE_HINGE,{"joint_rotation"=Vector3(deg_to_rad(15),deg_to_rad(50),0),"joint_constraints/angular_limit_enabled"=true,"joint_constraints/angular_limit_lower"=0,"joint_constraints/angular_limit_upper"=90}],
		"Head" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"LeftShoulder" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"RightShoulder" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"LeftUpperArm" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=60,"joint_constraints/twist_span"=30}],
		"RightUpperArm" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=60,"joint_constraints/twist_span"=30}],
		#"Hips" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"UpperChest" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=50,"joint_constraints/twist_span"=20}],
		"LeftUpperLeg" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"RightUpperLeg" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"LeftFoot" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"RightFoot" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"LeftHand" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"RightHand" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=30,"joint_constraints/twist_span"=30}],
		"Neck" = [PhysicalBone3D.JOINT_TYPE_CONE,{"joint_constraints/swing_span"=20,"joint_constraints/twist_span"=20}],
		
	}
	
	if bone_name in joints:
		var this_joint = joints[bone_name]
		phys_bone.joint_type = this_joint[0]
		for property in this_joint[1]:
			phys_bone[property] = this_joint[1][property]
	else:
		phys_bone.joint_type = PhysicalBone3D.JOINT_TYPE_PIN

func get_sphere_vertex_bounds(bone: String) -> Dictionary:
	var vertex_names = {
		"Head" = {front=169,back=5389}
	}
	
	var front : Vector3 = helper_vertex[vertex_names[bone]['front']]
	var back = helper_vertex[vertex_names[bone]['back']]
	var center = (front + back)/2
	var radius = front.distance_to(back) / 2
	
	return {center=center,radius=radius}

func get_box_vertex_bounds(bone: String) -> Dictionary:
	var vertex_names = {
		"Hips" = {upper=4154, lower=4370, front=4110, back=11006, left=10899, right=4269},
		"UpperChest" = {upper=1526, lower=4154, front=1890, back=1598, left=10602, right=3938},
		"LeftFoot" = {upper=12818, lower=12877, front=13146, back=12442, left=12808, right=13300},
		"RightFoot" = {upper=6221, lower=6280, front=6550, back=5845, left=6704, right=6211},
		"LeftHand" = {upper=10489, lower=8929, front=9456,back=10535,left=9833,right=10306},
		"RightHand" = {upper=3823 ,lower=2261 ,front=2788 ,back=3870 ,left=3638 ,right=3165 },
		}
		
	var upper : Vector3 = helper_vertex[vertex_names[bone]['upper']]
	var lower : Vector3 = helper_vertex[vertex_names[bone]['lower']]
	var left : Vector3 = helper_vertex[vertex_names[bone]['left']]
	var right : Vector3 = helper_vertex[vertex_names[bone]['right']]
	var front : Vector3 = helper_vertex[vertex_names[bone]['front']]
	var back : Vector3 = helper_vertex[vertex_names[bone]['back']]
	
		
	var size := Vector3.ZERO
	size.x = abs(left.x - right.x)
	size.y = abs(upper.y - lower.y)
	size.z = abs(front.z - back.z)
	
	var center := Vector3.ZERO
	center.x = (left.x + right.x) * .5
	center.y = (upper.y + lower.y) * .5
	center.z = (front.z + back.z) * .5
	
	return {size=size, center=center}

func get_capsule_vertex_bounds(bone: String) -> Dictionary:
	#refer to mpfb2_plugin.data/mesh_metadata/hm08.mirror for opposites
	var vertex_names = {
		"LeftUpperArm" = {front=8114, back=8330},
		"RightUpperArm" = {front=1426, back=1658},
		"LeftLowerArm" = {front=10541, back=10110}, 
		"RightLowerArm" = {front=3876, back=3442}, 
		"LeftLowerLeg" = {front=11325, back=11339},
		"RightLowerLeg" = {front=4707, back=4721},
		"LeftUpperLeg" = {front=11116, back=13340},
		"RightUpperLeg" = {front=4498, back=6744},
		"Neck" = {front=791, back=856},
		"LeftShoulder" = {front=8057, back=8281},
		"RightShoulder" = {front=1365, back=1609},
	}
	var front : Vector3 = helper_vertex[vertex_names[bone]['front']]
	var back : Vector3 = helper_vertex[vertex_names[bone]['back']]
	return {
		'distance': front.distance_to(back),
		'center': 0.5 * (front + back)
	}
