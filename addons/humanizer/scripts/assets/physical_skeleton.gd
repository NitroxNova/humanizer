class_name HumanizerPhysicalSkeleton

var skeleton: Skeleton3D
var helper_vertex: Array
var layers
var mask

var next_limb_bone = {
	&'Hips': &'UpperChest',
	&'UpperChest': &'Neck',
	&'Shoulder': &'UpperArm',
	&'UpperArm': &'LowerArm',
	&'LowerArm': &'Hand',
	&'UpperLeg': &'LowerLeg',
	&'LowerLeg': &'Foot',
	&'Neck': &'Head',
	&'Hand': &'MiddleProximal',
	&'Foot': &'Toes',
}

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

func _init(_skeleton: Skeleton3D, _helper_vertex, _layers, _mask):
	skeleton = _skeleton
	helper_vertex = _helper_vertex
	layers = _layers
	mask = _mask

func run() -> void:
	for child in skeleton.get_children():
		skeleton.remove_child(child)
		child.queue_free()
	
	'''
	# You may want to abstract this out to a function so you can loop but each bone will
	# require specific tweaking so you decide how to do it
	var bone_name: StringName
	var physical_bone: PhysicalBone3D 
	var collider: CollisionShape3D 
	
	bone_name = &'Hips'
	physical_bone = PhysicalBone3D.new()
	collider = CollisionShape3D.new()
	physical_bone.name = &'Physical Bone ' + bone_name
	physical_bone.add_child(collider)
	skeleton.add_child(physical_bone)
	physical_bone.scale = Vector3.ONE
	physical_bone.owner = skeleton
	collider.owner = skeleton
	
	physical_bone.collision_layer = layers
	physical_bone.collision_mask = mask
	physical_bone.bone_name = bone_name
	collider.shape = BoxShape3D.new()
	#outer left hip to outer right hip
	collider.shape.size.x = helper_vertex[10920].distance_to(helper_vertex[4290])
	#crotch to bellybutton
	collider.shape.size.y = helper_vertex[4372].distance_to(helper_vertex[4110])
	#stomach to booty
	collider.shape.size.z = helper_vertex[4367].distance_to(helper_vertex[10847])
	
	bone_name = &'UpperChest'
	physical_bone = PhysicalBone3D.new()
	collider = CollisionShape3D.new()
	physical_bone.name = &'Physical Bone ' + bone_name
	physical_bone.add_child(collider)
	skeleton.add_child(physical_bone)
	physical_bone.owner = skeleton
	collider.owner = skeleton

	physical_bone.collision_layer = layers
	physical_bone.collision_mask = mask
	physical_bone.bone_name = bone_name
	collider.shape = BoxShape3D.new()
	#outer left hip to outer right hip
	
	### MOVE THIS STUFF TO A DICTIONARY TO KEEP THINGS CLEAN
	collider.shape.size.x = helper_vertex[10920].distance_to(helper_vertex[4290])
	#shoulder to bellybutton
	collider.shape.size.y = helper_vertex[1396].distance_to(helper_vertex[4110])
	#middle chest to middle back
	collider.shape.size.z = helper_vertex[1891].distance_to(helper_vertex[1598])
	var spine_offset_z = helper_vertex[13659].distance_to(helper_vertex[3932])
	collider.position.z += collider.shape.size.z / 2 - spine_offset_z
	#spine to shoulder
	var spine_offset_y = helper_vertex[13651].distance_to(helper_vertex[15879])
	collider.position.y += spine_offset_y - (collider.shape.size.y / 2)
	'''
	
	_add_collider(&'Head', null, 'sphere')
	
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
			if bone == "LeftUpperArm":
				collider.shape.radius = distance_between_vertex("LeftUpperArmFront","LeftUpperArmBack")/2
			elif bone == "RightUpperArm":
				collider.shape.radius = distance_between_vertex("RightUpperArmFront","RightUpperArmBack")/2
			elif bone == "LeftLowerArm":
				collider.shape.radius = distance_between_vertex("LeftLowerArmFront","LeftLowerArmBack")/2
			elif bone == "RightLowerArm":
				collider.shape.radius = distance_between_vertex("RightLowerArmFront","RightLowerArmBack")/2
			elif bone == "LeftLowerLeg":
				collider.shape.radius = distance_between_vertex("LeftLowerLegFront","LeftLowerLegBack")/2
			elif bone == "RightLowerLeg":
				collider.shape.radius = distance_between_vertex("RightLowerLegFront","RightLowerLegBack")/2
			elif bone == "LeftUpperLeg":
				collider.shape.radius = distance_between_vertex("LeftUpperLegFront","LeftUpperLegBack")/2
			elif bone == "RightUpperLeg":
				collider.shape.radius = distance_between_vertex("RightUpperLegFront","RightUpperLegBack")/2
			else:
				collider.shape.radius = 0.07
		elif shape == 'box':
			collider.shape.size.z

func distance_between_vertex(vertex_1:String,vertex_2:String): #vertex_1 and vertex_2 are string names from the vertex_names dictionary
	return helper_vertex[vertex_names[vertex_1]].distance_to(helper_vertex[vertex_names[vertex_2]])
