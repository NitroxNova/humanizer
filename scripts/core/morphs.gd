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
@export var mesh_paths : Array[NodePath]
@export var skeleton : Skeleton3D
@export var bone_data : Dictionary
var meshes: Array

const AGE_KEYS = {&'baby': 0., &'child': 0.12, &'young': 0.25, &'old': 1.}
const MUSCLE_KEYS = {&'minmuscle': 0., &'avgmuscle': 0.5, &'maxmuscle': 1.}
const WEIGHT_KEYS = {&'minweight': 0., &'avgweight': 0.5, &'maxweight': 1.}

var age_enabled := false
var size_enabled := false
var custom_shape : StringName = &''



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
			if bone_data.has(sk):
				pos += bone_data[sk][bone] * shapekeys[sk]
			else:
				pos += bone_data['basis'][bone] * shapekeys[sk]
			sum += shapekeys[sk]
		pos /= sum
		skeleton.set_bone_pose_position(bone, pos)
		skeleton.set_bone_rest(bone, skeleton.get_bone_pose(bone))
	# Adjust skeleton motion scale
	var sum := 0.
	var scale := 0.
	for sk in bone_data:
		if shapekeys.has(sk):
			scale += bone_data[sk][-1] * shapekeys[sk]
			sum += shapekeys[sk]
	if sum < 1:  # The rest of the weight is from the basis shape
		scale += bone_data['basis'][-1] * (1 - sum)
	skeleton.motion_scale = scale 

	# Reset skin resources
	for mesh in meshes:
		mesh.skin = skeleton.create_skin_from_rest_transforms()
