extends Node
class_name Binary_Rect_Packer
# https://blackpawn.com/texts/lightmaps/default.html
# https://github.com/TeamHypersomnia/rectpack2D/tree/legacy?tab=readme-ov-file
# https://www.david-colson.com/2020/03/10/exploring-rect-packing.html

var rects = [] #array of rect2
var was_packed = []
var leaves = [] #array of rect2
var bin_size = 1000

func _init(_rects:Array):
	rects = _rects
	rects.sort_custom(sort_rect)
	#print(rects)
	leaves.push_back(Rect2(0,0,bin_size,bin_size))

func sort_rect(a,b):
	 #// Sort by area, seemed to work best for this algorithm
	if a.get_area() < b.get_area():
		return true
	return false
		
