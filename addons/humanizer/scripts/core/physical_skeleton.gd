class_name HumanizerPhysicalSkeleton

var skeleton: Skeleton3D
var helper_vertex: Array
var layers
var mask

# setup all the constraints for each bone joint
var joints = {
	"Hips": [PhysicalBone3D.JOINT_TYPE_HINGE, {"joint_constraints/angular_limit_enabled": true, "joint_constraints/angular_limit_lower": 20, "joint_constraints/angular_limit_upper": 135}],#[PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 1, "joint_constraints/twist_span": 1}],[PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 5, "joint_constraints/twist_span": 5}],
	"Spine": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 10, "joint_constraints/twist_span": 10}],
	"Chest": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 10, "joint_constraints/twist_span": 10}],
	"UpperChest": [PhysicalBone3D.JOINT_TYPE_HINGE, {"joint_constraints/angular_limit_enabled": true, "joint_constraints/angular_limit_lower": 20, "joint_constraints/angular_limit_upper": 135}],#[PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 1, "joint_constraints/twist_span": 1}],
	"Neck": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 2, "joint_constraints/twist_span": 2}],
	"Head": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 10, "joint_constraints/twist_span": 10}],
	"LeftShoulder": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 90, "joint_constraints/twist_span": 30}],
	"RightShoulder": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 90, "joint_constraints/twist_span": 30}],
	"LeftUpperArm": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 90, "joint_constraints/twist_span": 45}],
	"RightUpperArm": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 90, "joint_constraints/twist_span": 45}],
	"LeftLowerArm": [PhysicalBone3D.JOINT_TYPE_HINGE, {"joint_constraints/angular_limit_enabled": true, "joint_constraints/angular_limit_lower": 20, "joint_constraints/angular_limit_upper": 135}],
	"RightLowerArm": [PhysicalBone3D.JOINT_TYPE_HINGE, {"joint_constraints/angular_limit_enabled": true, "joint_constraints/angular_limit_lower": 20, "joint_constraints/angular_limit_upper": 135}],
	"LeftHand": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 45, "joint_constraints/twist_span": 45}],
	"RightHand": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 45, "joint_constraints/twist_span": 45}],
	"LeftUpperLeg": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 45, "joint_constraints/twist_span": 45}],
	"RightUpperLeg": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 45, "joint_constraints/twist_span": 45}],
	"LeftLowerLeg": [PhysicalBone3D.JOINT_TYPE_HINGE,{"joint_rotation"=Vector3(0,-PI/2,0),"joint_constraints/angular_limit_enabled"=true,"joint_constraints/angular_limit_upper"=90,"joint_constraints/angular_limit_lower"=20}],
	"RightLowerLeg": [PhysicalBone3D.JOINT_TYPE_HINGE,{"joint_rotation"=Vector3(0,-PI/2,0),"joint_constraints/angular_limit_enabled"=true,"joint_constraints/angular_limit_upper"=90,"joint_constraints/angular_limit_lower"=20}],
	"LeftFoot": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 20, "joint_constraints/twist_span": 20}],
	"RightFoot": [PhysicalBone3D.JOINT_TYPE_CONE, {"joint_constraints/swing_span": 20, "joint_constraints/twist_span": 20}],
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
	
	# if i understand well, the joins are automaticly created on the most closer parent that have a PhysicalBone
	var main_bones = [
		#"Hips", "Spine", "Chest", "UpperChest",
		"Hips", "UpperChest",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
		#"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
		#"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"Neck", "Head",
	]
	
	for bone in main_bones :
		create_physical_bone(bone)
		
		
func create_physical_bone(bone_name: String) -> void:
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		print(bone_name, "bone_idx == -1")
		return
	
	var children = skeleton.get_bone_children(bone_idx)
	if children.is_empty():
		print(bone_name, "empty child")
		return
	
	var child_idx = children[0]
	var bone_pose = skeleton.get_bone_global_pose(bone_idx)
	var child_pose = skeleton.get_bone_global_pose(child_idx)

	# compute position size based on child position
	var p1 = bone_pose.origin
	var p2 = child_pose.origin
	var direction = p2 - p1
	var height = direction.length()

	# PhysicalBone3D creation
	var phys_bone := PhysicalBone3D.new()
	phys_bone.name = "PhysicalBone_" + bone_name
	phys_bone.bone_name = bone_name
	phys_bone.collision_layer = layers
	phys_bone.collision_mask = mask

	# compute orientation based on bone direction
	var basis = Basis()
	basis = basis.looking_at(direction.normalized(), Vector3.UP)
	var transform = Transform3D(basis, p1)
	phys_bone.global_transform = transform

	# make the collider
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = height * 0.9
	shape.radius = height * 0.1
	shape_node.shape = shape
	shape_node.transform.origin.y = height * 0.5

	# specific corrections
	# don't know why but the arms colliders are not aligned correctly, like if there was in Tpose, but the position is good
	# maybe related to that : https://github.com/godotengine/godot/issues/98979
	# this is not specific to arms, it appear on legs bones too, but it's really visible on UpperArms, LowerArms and Hands
	if bone_name.begins_with("LeftUpperArm") or bone_name.begins_with("RightUpperArm"):
		var rotate_offset = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(45)), Vector3.ZERO)
		shape_node.transform = rotate_offset * shape_node.transform
	if bone_name.begins_with("LeftLowerArm") or bone_name.begins_with("RightLowerArm"):
		var rotate_offset =  Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(45)), Vector3.ZERO)
		var rotate_offset2 = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-15)), Vector3.ZERO) # maybe inverse if right
		shape_node.transform = rotate_offset * rotate_offset2 * shape_node.transform
	
	# specific corrections to better cover the body
	if bone_name.begins_with("Head") :
		var _shape = SphereShape3D.new()
		_shape.radius = 0.05
		shape_node.shape = _shape
		
	if bone_name.begins_with("Hips") :
		var _shape = SphereShape3D.new()
		_shape.radius = 0.2
		shape_node.shape = _shape
		shape_node.transform.origin.z -= height * 0.1
		
	if bone_name.begins_with("UpperChest") :
		var _shape = BoxShape3D.new()
		_shape.size = Vector3(height, height, height * 0.5);
		shape_node.shape = _shape
		shape_node.transform.origin.z += height * 0.1
		
	# if the the bone is Spine, Chest or an other not needed bone, we don't add the shape
	# resulting with a physical bone without shapen collision or join, it seems to help the other bones
	# it's optionnal, enable it if you use any of this bones in main_bones
	# var excluded_bones = ["RightShoulder", "LeftShoulder", "Spine", "Chest", "Neck"]
	# if bone_name not in excluded_bones :
	# 	phys_bone.add_child(shape_node)
	phys_bone.add_child(shape_node)

	skeleton.add_child(phys_bone)
	phys_bone.owner = skeleton
	shape_node.owner = skeleton
	
	# it's optionnal, enable it if you use any of this bones in main_bones
	# if bone_name in excluded_bones :
	# 	return

	# setup constraints, the empiric way
	# default values
	phys_bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	phys_bone["joint_constraints/swing_span"] = 0.5
	phys_bone["joint_constraints/twist_span"] = 0.5
	phys_bone["joint_constraints/softness"] = 1.
	phys_bone["joint_constraints/relaxation"] = 1.
	phys_bone["joint_constraints/bias"] = 0.2
	if bone_name in ["Hips", "UpperChest", "RightShoulder", "LeftShoulder"] :
		phys_bone["joint_constraints/relaxation"] = 5.0
		
		
	## if bone is in the joints list, apply this settings
	if joints.has(bone_name):
		var joint_info = joints[bone_name]
		phys_bone.joint_type = joint_info[0]
		var constraint_data = joint_info[1]
		for key in constraint_data.keys():
			phys_bone[key] = constraint_data[key]

	#print("Bone : ", bone_name, " setup at : ", phys_bone.global_transform)
