@tool
extends Node

@export_group('Paths')
## Paths where humanizer will look to find files for building assets
@export var asset_import_paths: Array[String] = ['res://addons/humanizer/data/assets/']
## Path where human resources will be serialized
## Defaults to res://data/humans
@export_dir var human_export_path: String = 'res://data/humans/'

@export_group('Slot Definitions')
## Body Part Slot Definitions
@export var body_part_slots: Array[String] = [
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
@export var default_skeleton: String
## Default AnimationTree to use for new humanizer nodes
@export var default_animation_tree: PackedScene

@export_group('Physics')
## Default root node class for baked humans
@export_enum("CharacterBody3D", "RigidBody3D", "StaticBody3D") var default_baked_root_node: String = "CharacterBody3D"
## Default character collider layer
@export_flags_3d_physics var default_character_physics_layers
## Default character collider mask
@export_flags_3d_physics var default_character_physics_mask
## Default ragdoll physics layer
@export_flags_3d_physics var default_physical_bone_layers
## Default ragdoll physics mask
@export_flags_3d_physics var default_physical_bone_mask

@export_group('Rendering')
## Default character render layers
@export_flags_3d_render var default_character_render_layers
