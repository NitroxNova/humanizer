class_name HumanizerSkeletonConfig
extends RefCounted

func run():
	print('Creating Skeleton Config')
	# Prepare data structures
	var vertex_groups = HumanizerUtils.read_json("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")
	
	for path in HumanizerGlobalConfig.config.asset_import_paths:
		for name in HumanizerRegistry.rigs:
			print('Importing rig ' + name)
			var rig: HumanizerRig = HumanizerRegistry.rigs[name]
			if rig.skeleton_path in [null, '']:
				printerr('Missing scene for skeleton')
				return
			if rig.rigged_mesh_path in [null, '']:
				printerr('You must extract the rigged mesh instance to a .res file')
				return
			var in_data: Dictionary
			var skeleton: Skeleton3D = null
			var dir: String = rig.mh_json_path.get_base_dir()
			in_data = HumanizerUtils.read_json(rig.mh_json_path)
			if in_data.has('bones'):  # Game Engine rig doesn't have bones key
				in_data = in_data['bones']
			skeleton = load(rig.skeleton_path).instantiate()
			
			if in_data.size() == 0:
				printerr('Failed to load skeleton json from makehuman')
				return
			
			# Create skeleton config			
			var rig_config = []
			rig_config.resize(skeleton.get_bone_count())
			for in_name in in_data:
				var out_name = in_name.replace(":","_")
				var bone_id = skeleton.find_bone(out_name)
				if bone_id > -1:
					var parent_name = in_data[in_name].parent.replace(":","_")
					var parent_id = skeleton.find_bone(parent_name)
					rig_config[bone_id] = in_data[in_name]
					rig_config[bone_id].parent = parent_id
					if rig_config[bone_id].head.strategy == "CUBE":
						var cube_range = vertex_groups[rig_config[bone_id].head.cube_name][0]
						var cube_index = []
						for i in range(cube_range[0], cube_range[1] + 1):
							cube_index.append(i)
						rig_config[bone_id].head.vertex_indices = cube_index
			
			rig.config_json_path = dir.path_join('skeleton_config.json')
			HumanizerUtils.save_json(rig.config_json_path, rig_config)
			
			# Get bone weights for clothes
			var out_data := []
			out_data.resize(HumanizerTargetService.data.basis.size())
			for i in out_data.size():
				out_data[i] = []
			var bone_names := []
			
			var skeleton_weights:Dictionary = HumanizerUtils.read_json(dir.path_join("weights."+name+".json")).weights
			for in_name:String in skeleton_weights.keys():
				var out_name = in_name.replace(":","_")
				if not in_name == out_name:
					skeleton_weights[out_name] = skeleton_weights[in_name]
					skeleton_weights.erase(in_name)
			for bone_name in skeleton_weights:
				bone_names.append(bone_name)
				var bone_id = bone_names.size()-1
				for id_weight_pair in skeleton_weights[bone_name]:
					out_data[id_weight_pair[0]].append([bone_id,id_weight_pair[1]])
			
			#normalize
			for bw_array in out_data:
				var weight_sum = 0
				for bw_pair in bw_array:
					weight_sum += bw_pair[1]
				for bw_pair in bw_array:
					bw_pair[1] /= weight_sum
			
			rig.bone_weights_json_path = dir.path_join('bone_weights.json')
			HumanizerUtils.save_json(rig.bone_weights_json_path, {names=bone_names,weights=out_data})
			print('Finished creating skeleton config')
	
