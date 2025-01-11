@tool
class_name HumanizerConfig
extends Resource

@export_group('Paths')
## Paths where humanizer will look to find files for building assets
@export var asset_import_paths: Array[String] = ['res://addons/humanizer/data/assets/',"res://addons/humanizer_assets/","user://humanizer/"] #where you'll put the mods
## Path where human resources will be serialized
@export_dir var human_export_path: String = 'res://data/humans/'
## Path to default root node script for baked humans
@export_file var default_characterbody_script: String = "res://addons/humanizer/scripts/utils/human_controller.gd"
## Path to default root node script for baked humans
@export_file var default_rigidbody_script: String
## Path to default root node script for baked humans
@export_file var default_staticbody_script: String
## Path to default root node script for baked humans
@export_file var default_area_script: String

@export_group('Slot Definitions')
@export var equipment_slots: Array[HumanizerSlotCategory] = [
	
	HumanizerSlotCategory.new("Body Parts","", 
		PackedStringArray( ['Body', 'RightEye', 'LeftEye', 'RightEyebrow', 'LeftEyebrow', 'RightEyelash', 'LeftEyelash', 'Hair', 'Tongue', 'Teeth',]), 
		Array([HumanizerFolderOverride.new("hair", ["Hair"]), 
			HumanizerFolderOverride.new("eyes",["LeftEye","RightEye"], true), 
			HumanizerFolderOverride.new("eyebrows",["LeftEyebrow","RightEyebrow"], true), 
			HumanizerFolderOverride.new("eyelashes",["LeftEyelash","RightEyelash"], true)], 
		TYPE_OBJECT, "Resource", HumanizerFolderOverride)),
	
	HumanizerSlotCategory.new("Clothing","Clothes",
		PackedStringArray(['Head','Eyes','Mouth','Hands','Arms','Torso','Legs','Feet',]), 
		Array([HumanizerFolderOverride.new("hats",["Head"]),
			HumanizerFolderOverride.new("shoes",["Feet"])], 
		TYPE_OBJECT, "Resource", HumanizerFolderOverride)),
	
]

@export_group("Animation")
## Default skeleton to use for new humanizer nodes
@export var default_skeleton: String = 'game_engine-RETARGETED'
## Default AnimationTree to use for new humanizer nodes
@export var default_animation_tree: PackedScene = preload("res://addons/humanizer/data/animations/animation_tree.tscn")

@export_group('Physics')
## Default root node class for baked humans
@export_enum("CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D") var default_baked_root_node: String = "CharacterBody3D"
## Default character collider layer
@export_flags_3d_physics var default_character_physics_layers = 1 << 1
## Default character collider mask
@export_flags_3d_physics var default_character_physics_mask = 1 | 1 << 1
## Default static layer for StaticBody3D humans
@export_flags_3d_physics var default_staticbody_physics_layers = 1
## Default ragdoll physics layer
@export_flags_3d_physics var default_physical_bone_layers = 1 << 2
## Default ragdoll physics mask
@export_flags_3d_physics var default_physical_bone_mask = 1 | 1 << 2

@export_group('Rendering')
## Default character render layers
@export_flags_3d_render var default_character_render_layers = 1
## Texture atlas resolution
@export_enum("1k:1024", "2k:2048", "4k:4096") var atlas_resolution: int = 2048

func get_folder_override_slots(mhclo_path:String):
	#print(mhclo_path)
	var folder_path = mhclo_path
	for import_path in asset_import_paths:
		import_path = import_path.path_join("equipment")
		if folder_path.begins_with(import_path):
			folder_path = folder_path.replace(import_path,"")
			continue
	folder_path = folder_path.get_base_dir().path_join("") #add a slash on the end, so it can be searched for multi level folder names
	folder_path = folder_path.to_lower()
	mhclo_path = mhclo_path.to_lower()
	#print(mhclo_path)
	var slots = []
	for slot_cat in equipment_slots:
		for folder_ovr in slot_cat.folder_overrides:
			var fn = "/".path_join(folder_ovr.folder_name.to_lower()).path_join("") #slashes on both sides to eliminate false positives (in case one name is partially in another)
			if fn in mhclo_path:
				if folder_ovr.left_right:
					#print(mhclo_path.get_file())
					var has_side
					for side in ["left","right"]:
						if mhclo_path.get_file().begins_with(side):
							for slot in folder_ovr.slots:
								slot += slot_cat.suffix
								if slot.to_lower().begins_with(side) and slot not in slots:
									slots.append(slot)
							has_side = true
					if not has_side: # assign to both sides, so they can add single equipment with both eyelashes	
						for slot in folder_ovr.slots:
							slot += slot_cat.suffix
							if slot not in slots:
								slots.append(slot)
				else:
					for slot in folder_ovr.slots:
						slot += slot_cat.suffix
						if slot not in slots:
							slots.append(slot)
	return slots	
