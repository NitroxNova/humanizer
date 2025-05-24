@tool
extends Resource
class_name HumanizerRig

@export var skeleton : PackedScene #saving the skeleton3d node doesnt work, it gets reset when you open it
@export var config : Array #bone position info, from json
@export var weights : Array #weights and bones arrays, indexed to helper vertex
@export var retargeted : bool = false

func load_skeleton() -> Skeleton3D:
	return skeleton.instantiate()

func init_skeleton_data():
	var skel3D = load_skeleton()
	return HumanizerRigService.init_skeleton_data(skel3D)

#func load_bone_weights() -> Dictionary:
	#var weights: Dictionary = HumanizerResourceService.load_resource(mh_weights_path).weights
	#for in_name:String in weights.keys():
		#if ':' not in in_name:
			#continue
		#var out_name = in_name.replace(":", "_")
		#weights[out_name] = weights[in_name]
		#weights.erase(in_name)
	#return weights
