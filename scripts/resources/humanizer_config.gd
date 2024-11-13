@tool
class_name HumanizerConfig
extends Resource

@export_group('Paths')
## Paths where humanizer will look to find files for building assets
@export var asset_import_paths: Array[String] = ['res://addons/humanizer/data/assets/']
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
@export var equipment: Array[HumanizerSlotCategory] = [
	HumanizerSlotCategory.new("Body Parts","", PackedStringArray( ['Body', 'RightEye', 'LeftEye', 'RightEyebrow', 'LeftEyebrow', 'RightEyelash', 'LeftEyelash', 'Hair', 'Tongue', 'Teeth',])),
	HumanizerSlotCategory.new("Clothing","Clothes",PackedStringArray(['Head','Eyes','Mouth','Hands','Arms','Torso','Legs','Feet',])),
]
## Body Part Slot Definitions
@export var body_part_slots: Array[String] = [
	'Body',
	'RightEye',
	'LeftEye',
	'RightEyebrow',
	'LeftEyebrow',
	'RightEyelash',
	'LeftEyelash',
	'Hair',
	'Tongue',
	'Teeth',
]
## Clothing Slot Definitions
@export var clothing_slots: Array[String] =  [
	'Head',
	'Eyes',
	'Mouth',
	'Hands',
	'Arms',
	'Torso',
	'Legs',
	'Feet',
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
