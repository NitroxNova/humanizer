extends Resource
class_name Shapekey_Data

@export var basis: Array
@export var shapekeys: Dictionary

func _init(_basis = [], _shapekeys = {}):
	basis = _basis
	shapekeys = _shapekeys
