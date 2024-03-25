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
	
	
	bone_name = &'LeftUpperArm'
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
	collider.shape = CapsuleShape3D.new()
	

