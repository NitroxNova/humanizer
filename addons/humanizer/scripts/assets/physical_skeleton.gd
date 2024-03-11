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
	
	bone_name = &'Spine'
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

