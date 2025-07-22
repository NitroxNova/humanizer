extends Resource
class_name Humanizer_Weight_Cache

#will always be the same on the same skeleton, so we dont have to recalculate the weights everytime
#rigged weights require some additional calculation but it is minimal since asset bone positions arent garaunteed (if theres more than 1 and added in a different order)
@export var weights : PackedFloat32Array
@export var bones: PackedInt32Array
