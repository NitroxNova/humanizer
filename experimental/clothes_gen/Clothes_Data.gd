extends Resource
class_name Clothes_Data

@export var mh2gd_index : Array
@export var vertex : Array
@export var delete_vertex : Array
@export var scale_config : Dictionary

func _init(_mh2gd=[],_vertex=[],_delete_vertex=[],_scale_config={}):
	mh2gd_index = _mh2gd
	vertex = _vertex
	delete_vertex = _delete_vertex
	scale_config = _scale_config
	
