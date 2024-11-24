@tool
extends Resource
class_name HumanizerFolderOverride

#goes in slot category

@export var folder_name : String
@export var slots : PackedStringArray
@export var left_right = false

func _init(_fn=null,_sl=null,_lr=false)->void:
	if not _fn == null:
		folder_name = _fn
		slots = _sl
		left_right = _lr	
