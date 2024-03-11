class_name HumanizerPhysicalSkeleton

var skeleton: Skeleton3D
var helper_vertex: Array


func _init(_skeleton: Skeleton3D, _helper_vertex):
	skeleton = _skeleton
	helper_vertex = _helper_vertex

func run() -> void:
	for child in skeleton.get_children():
		skeleton.remove_child(child)
		child.queue_free()
	
	# You may want to abstract this out to a function so you can loop but each bone will
	# require specific tweaking so you decide how to do it
	var bone_name = &'Hips'
	var physical_bone: PhysicalBone3D = PhysicalBone3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	physical_bone.name = &'Physical Bone ' + bone_name
	physical_bone.add_child(collider)
	skeleton.add_child(physical_bone)
	physical_bone.owner = skeleton
	# Do we have to set the owner of the child node since we just set its parent's owner?
	collider.owner = skeleton
	
	physical_bone.bone_name = bone_name
	collider.shape = BoxShape3D.new()
	print_debug('Do stuff here for the physical skeleton')
