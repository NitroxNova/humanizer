@tool
extends Resource
class_name HumanizerEquipmentRigConfig

@export var config := [] #bone names and positions
#bones/weights arrays
@export var bones := []
@export var weights := []
@export var attach_bones = [] # what bones it connects to from the main skeleton

class Bone_Config:
	var name
