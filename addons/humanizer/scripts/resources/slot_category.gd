@tool
extends Resource
class_name HumanizerSlotCategory

@export var category : String
@export var suffix : String
@export var slots : PackedStringArray
@export var folder_overrides : Array[HumanizerFolderOverride]

func _init(_category=null,_suffix=null,_slots=null,_fo=null) -> void:
	if not _category == null:
		category = _category
		suffix = _suffix
		slots = _slots
		folder_overrides = _fo
	
func get_slot_name(slot_id):
	return slots[slot_id]+suffix

func get_slots():
	var names = []
	for s_id in slots.size():
		names.append(get_slot_name(s_id))
	return names
		
