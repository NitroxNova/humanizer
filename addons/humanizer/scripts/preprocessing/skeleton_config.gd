class_name HumanizerSkeletonConfig
extends RefCounted

func run():
	print('Creating Skeleton Config')
	# Prepare data structures
	var vertex_groups = HumanizerUtils.read_json("res://addons/humanizer/data/resources/basemesh_vertex_groups.json")
	
	for path in HumanizerGlobal.config.asset_import_paths:
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
			var data := {}
			data.bones = []
			data.weights = []
			var surface_arrays = load(rig.rigged_mesh_path).surface_get_arrays(0)
			var bone_count = surface_arrays[Mesh.ARRAY_BONES].size() / surface_arrays[Mesh.ARRAY_VERTEX].size()
			var b2g_index = Utils.create_unique_index(surface_arrays[Mesh.ARRAY_VERTEX])
			for i in b2g_index.size():
				var g_index = b2g_index[i][0]
				var local_bones = surface_arrays[Mesh.ARRAY_BONES].slice(g_index*bone_count,(g_index+1)*bone_count)
				var local_weights = surface_arrays[Mesh.ARRAY_WEIGHTS].slice(g_index*bone_count,(g_index+1)*bone_count)
				data.bones.append(local_bones)
				data.weights.append(local_weights)
			rig.bone_weights_json_path = dir.path_join('bone_weights.json')
			HumanizerUtils.save_json(rig.bone_weights_json_path, data)
			print('Finished creating skeleton config')
	
