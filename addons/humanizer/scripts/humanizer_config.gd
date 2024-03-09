@tool
extends Node

## Paths where humanizer will look to find files for building assets
@export var asset_import_paths: Array[String] = ['res://addons/humanizer/data/assets/']
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
## Path where human resources will be serialized
## Defaults to res://data/humans
@export_dir var human_export_path: String = 'res://data/humans/'


@export_group("Node defaults")
## Default skeleton to use for new humanizer nodes
@export var default_skeleton: String
## Default AnimationTree to use for new humanizer nodes
@export var default_animation_tree: PackedScene
## Default physics layers for character colliders
@export_flags_3d_physics var default_character_collision_layers
## Default ragdoll physics layers
@export_flags_3d_physics var default_ragdoll_collision_layers
