extends Node
class_name Binary_Rect_Packer
# https://blackpawn.com/texts/lightmaps/default.html
# https://github.com/TeamHypersomnia/rectpack2D/tree/legacy?tab=readme-ov-file
# https://www.david-colson.com/2020/03/10/exploring-rect-packing.html

var rects = [] #array of Packable_Rect
var bin_size : int # how many pixels tall and wide (will be a square)
var nodes = []

func _init(_rects:Array, _bin_size : int):
	bin_size = _bin_size
	rects = _rects
	rects.sort_custom(sort_rect)
	nodes.append(Rect2(0,0,bin_size,bin_size))
	
	for rect in rects:
		place_rect(rect)
		#print(rect.get_position())

func insert_node(new_node:Rect2):
	var new_dimension = min(new_node.size.x,new_node.size.y)
	#keep nodes in order from smallest to largest, so we can fill the smallest ones first
	for i in nodes.size():
		var compare_node = nodes[i]
		var compare_dimension = min(compare_node.size.x,compare_node.size.y)
		if new_dimension < compare_dimension:
			nodes.insert(i,new_node)
			return
	nodes.append(new_node)

func place_rect(rect:Packable_Rect):		
	for node in nodes:
		if rect.get_width() <= node.size.x and rect.get_height() <= node.size.y:
			rect.coords.position = node.position #put rect in top left corner
			var big_node : Rect2
			var small_node : Rect2
			var remainder = node.size - rect.get_size()
			var min_right = min(remainder.x,node.size.y)
			var min_bottom = min(remainder.y,node.size.x)
			
			if min_right > min_bottom:
				#print("Right side is bigger")
				big_node = Rect2(node.position.x+rect.get_width(),node.position.y,remainder.x,node.size.y)
				small_node = Rect2(node.position.x,node.position.y+rect.get_height(),rect.get_width(),remainder.y)
			else:
				#print("Bottom side is bigger")
				big_node = Rect2(node.position.x,node.position.y+rect.get_height(),node.size.x,remainder.y)
				small_node = Rect2(node.position.x+rect.get_width(),node.position.y,remainder.x,rect.get_height())
			insert_node(big_node)
			insert_node(small_node)
			nodes.erase(node)
			return
	print("no place for rectangle found")

func sort_rect(a:Packable_Rect,b:Packable_Rect):
	 # sort by height or width, whichever is bigger
	var a_max_dim = max(a.get_width(),a.get_height())
	var b_max_dim = max(b.get_width(),b.get_height())
	if a_max_dim > b_max_dim:
		return true
	return false


class Packable_Rect:
	var coords : Rect2 #size and position
	var surface_id : int
	var island_id : int
	
	func _init(_coords:Rect2,_surface_id:int,_island_id:int):
		coords = _coords
		surface_id = _surface_id
		island_id = _island_id		
	
	func get_width():
		return coords.size.x
	
	func get_height():
		return coords.size.y
	
	func get_size():
		return coords.size
	
	func get_area():
		return coords.get_area()
	
	func get_position():
		return coords.position
	
	func get_x_position():
		return coords.position.x
	
	func get_y_position():
		return coords.position.y
	
	func set_position(position:Vector2):
		coords.position = position
