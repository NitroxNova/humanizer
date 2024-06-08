@tool
class_name HumanizerMorphs
extends Node

## If you are only using custom shapes and not the macro age/size sliders
## you would just call set_shapekeys directly with your own blendshape
## names and values in a dictionary.  In that case the sliders below will
## do nothing.

## If you are using macro morphs you may set 1 custom shape also
@export_range(0., 1.) var custom_shape_value := 0.:
	set(v):
		custom_shape_value = v
		if age_enabled or size_enabled:
			update_shape()
@export_range(0., 1.) var age := 0.25:
	set(v):
		age = v
		if age_enabled:
			update_shape()
@export_range(0., 1.) var muscle := 0.5:
	set(v):
		muscle = v
		if size_enabled:
			update_shape()
@export_range(0., 1.) var weight := 0.5:
	set(v):
		weight = v
		if size_enabled:
			update_shape()
@export var mesh_paths: Array[NodePath]
@export var skeleton: Skeleton3D
@export var animator: AnimationTree
@export var bone_positions: Dictionary
@export var skeleton_motion_scale: Dictionary
@export var collider_shapes: Dictionary

@onready var collider: CollisionShape3D = $'../MainCollider'
var meshes: Array

const AGE_KEYS = {&'baby': 0., &'child': 0.12, &'young': 0.25, &'old': 1.}
const MUSCLE_KEYS = {&'minmuscle': 0., &'avgmuscle': 0.5, &'maxmuscle': 1.}
const WEIGHT_KEYS = {&'minweight': 0., &'avgweight': 0.5, &'maxweight': 1.}

var age_enabled := false
var size_enabled := false
var custom_shape : StringName = &''

func _validate_property(property: Dictionary) -> void:
	if property.name == 'weight' and not size_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == 'muscle' and not size_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == 'age' and not age_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == 'custom_shape_value' and custom_shape == '':
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name in ['mesh_paths', 'skeleton', 'bone_positions', 'skeleton_motion_scale', 'collider_shapes']:
		property.usage |= PROPERTY_USAGE_NO_EDITOR
		property.usage &= ~PROPERTY_USAGE_EDITOR

func _enter_tree() -> void:
	initialize()

func initialize() -> void:
	if not mesh_paths.is_empty():
		meshes = []
		for path in mesh_paths:
			meshes.append(get_node(path))
	age_enabled = false
	size_enabled = false
	custom_shape = ''
	for bs in meshes[0].get_blend_shape_count():
		var bs_name = (meshes[0].mesh as ArrayMesh).get_blend_shape_name(bs)
		if 'baby' in bs_name:
			age_enabled = true
		if 'avgmuscle' in bs_name:
			size_enabled = true
		var shape_name = bs_name.split('-')[0]
		if shape_name.to_lower() != 'base':
			custom_shape = shape_name

## for macro age/size sliders only
func update_shape() -> void:
	var agek1 : StringName
	var agek2 : StringName
	var musclek1 : StringName
	var musclek2 : StringName
	var weightk1 : StringName
	var weightk2 : StringName

	if age_enabled:
		if age == 0:
			agek1 = &'baby'
			agek2 = &'young'
		else:
			for a in AGE_KEYS:
				if age > AGE_KEYS[a]:
					agek1 = a
				if age <= AGE_KEYS[a]:
					agek2 = a
					break
	if size_enabled:
		if muscle == 0:
			musclek1 = &'minmuscle'
			musclek2 = &'avgmuscle'
		else:
			for m in MUSCLE_KEYS:
				if muscle > MUSCLE_KEYS[m]:
					musclek1 = m
				if muscle <= MUSCLE_KEYS[m]:
					musclek2 = m
					break
	if size_enabled:
		if weight == 0:
			weightk1 = &'minweight'
			weightk2 = &'avgweight'
		else:
			for w in WEIGHT_KEYS:
				if weight > WEIGHT_KEYS[w]:
					weightk1 = w
				if weight <= WEIGHT_KEYS[w]:
					weightk2 = w
					break

	var shapekeys := {}
	for k in [custom_shape, 'base']:
		if k == '':
			continue
		var xc = 1 - custom_shape_value if k == 'base' else custom_shape_value
		var xa := 1.
		var xm := 1.
		var xw := 1.
		if age_enabled:
			xa = (age - AGE_KEYS[agek1]) / (AGE_KEYS[agek2] - AGE_KEYS[agek1]) if agek1	!= agek2 else 0
		if size_enabled:
			xm = (muscle - MUSCLE_KEYS[musclek1]) / (MUSCLE_KEYS[musclek2] - MUSCLE_KEYS[musclek1]) if musclek1 != musclek2 else 0
			xw = (weight - WEIGHT_KEYS[weightk1]) / (WEIGHT_KEYS[weightk2] - WEIGHT_KEYS[weightk1]) if weightk1 != weightk2 else 0

		var name: StringName
		if age_enabled and size_enabled:
			name = k + '-' + musclek1 + '-' + weightk1 + '-' + agek1
			shapekeys[name] = (1 - xm) * (1 - xw) * (1 - xa) * xc
			name = k + '-' + musclek1 + '-' + weightk1 + '-' + agek2
			shapekeys[name] = (1 - xm) * (1 - xw) * xa * xc
			name = k + '-' + musclek1 + '-' + weightk2 + '-' + agek1
			shapekeys[name] = (1 - xm) * xw * (1 - xa) * xc
			name = k + '-' + musclek1 + '-' + weightk2 + '-' + agek2
			shapekeys[name] = (1 - xm) * xw * xa * xc
			name = k + '-' + musclek2 + '-' + weightk1 + '-' + agek1
			shapekeys[name] = xm * (1 - xw) * (1 - xa) * xc
			name = k + '-' + musclek2 + '-' + weightk1 + '-' + agek2
			shapekeys[name] = xm * (1 - xw) * xa * xc
			name = k + '-' + musclek2 + '-' + weightk2 + '-' + agek1
			shapekeys[name] = xm * xw * (1 - xa) * xc
			name = k + '-' + musclek2 + '-' + weightk2 + '-' + agek2
			shapekeys[name] = xm * xw * xa * xc
		elif age_enabled:
			name = k + '-' + agek1
			shapekeys[name] = (1 - xa) * xc
			name = k + '-' + agek2
			shapekeys[name] = xa * xc
		elif size_enabled:
			name = k + '-' + musclek1 + '-' + weightk1
			shapekeys[name] = (1 - xm) * (1 - xw) * xc
			name = k + '-' + musclek1 + '-' + weightk2
			shapekeys[name] = (1 - xm) * xw * xc
			name = k + '-' + musclek2 + '-' + weightk1
			shapekeys[name] = xm * (1 - xw) * xc
			name = k + '-' + musclek2 + '-' + weightk2
			shapekeys[name] = xm * xw * xc

	set_shapekeys(shapekeys)

func set_shapekeys(shapekeys: Dictionary) -> void:
	# Reset all
	for mesh in meshes:
		for bs in mesh.get_blend_shape_count():
			mesh.set_blend_shape_value(bs, 0.)
	# Set new values
	for name in shapekeys:
		for mesh in meshes:
			var bs = (mesh as MeshInstance3D).find_blend_shape_by_name(name)
			if bs != -1:
				mesh.set_blend_shape_value(bs, shapekeys[name])
	# Adjust skeleton
	skeleton.reset_bone_poses()
	for bone in skeleton.get_bone_count():
		var sum := 0.
		var pos := Vector3.ZERO
		for sk in shapekeys:
			if bone_positions.has(sk):
				pos += bone_positions[sk][bone] * shapekeys[sk]
			else:
				pos += bone_positions['basis'][bone] * shapekeys[sk]
			sum += shapekeys[sk]
		pos /= sum
		skeleton.set_bone_pose_position(bone, pos)
		skeleton.set_bone_rest(bone, skeleton.get_bone_pose(bone))
	# Adjust skeleton motion scale
	var sum := 0.
	var scale := 0.
	if bone_positions.size() > 0:
		for sk in shapekeys:
			if skeleton_motion_scale.has(sk):
				scale += skeleton_motion_scale[sk] * shapekeys[sk]
				sum += shapekeys[sk]
		if sum < 1:  # The rest of the weight is from the basis shape
			scale += skeleton_motion_scale['basis'] * (1 - sum)
		skeleton.motion_scale = scale 
	# Adjust collider size
	if collider_shapes.size() > 0:
		sum = 0.
		var height := 0.
		var radius := 0.
		var center := 0.
		for sk in shapekeys:
			if collider_shapes.has(sk):
				height += collider_shapes[sk].height * shapekeys[sk]
				radius += collider_shapes[sk].radius * shapekeys[sk]
				center += collider_shapes[sk].center * shapekeys[sk]
				sum += shapekeys[sk]
		if sum < 1:
			height += collider_shapes['basis'].height * (1 - sum)
			radius += collider_shapes['basis'].radius * (1 - sum)
			center += collider_shapes['basis'].center * (1 - sum)
		collider.shape.radius = radius
		collider.shape.height = height
		collider.position.y = center
	# Reset skin resources
	for mesh in meshes:
		mesh.skin = skeleton.create_skin_from_rest_transforms()
