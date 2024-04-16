class_name NaiveRectPacker
#https://www.david-colson.com/2020/03/10/exploring-rect-packing.html
#It’s worth noting that although our naive row packer is the fastest in all cases, it fails when you give it varied sets of rectangles. Skyline bottom-left fairs a lot better in these situations. This is presumably why the author of stb_rect_pack chose this algorithm. It’s very fast, and does pretty well in a wide range of situations.
#Unfortunately, the binary tree method seems come up a bit short in a lot of test cases. Maybe I’ve missed something, but then again, it’s one redeeming factor is that it’s simple. But you know what’s even simpler? Naive row packing.

var rects = [] #array of rect2
var bin_size : int # how many pixels tall and wide (will be a square)

func _init(_rects:Array, _bin_size : int):
	bin_size = _bin_size
	rects = _rects
	rects.sort_custom(sort_rect)
	#print(rects)
	var row_x = 0
	var row_y = 0
	var tallest_this_row = 0
	
	#// If this rectangle will go past the width of the image
	#// Then loop around to next row, using the largest height from the previous row
	for rect_id in rects.size():
		var rect = rects[rect_id]
		if row_x + rect.get_width() > bin_size:
			row_y += tallest_this_row
			row_x = 0
			tallest_this_row = 0
			
	#// If we go off the bottom edge of the image, then we've failed
		if ((row_y + rect.get_height()) > bin_size):
			print("bin overflow")
			break
			
	 #// This is the position of the rectangle
		rects[rect_id].set_position(Vector2(row_x,row_y)) 
		#print(rect)

		#// Move along to the next spot in the row
		row_x += rect.get_width()

		#// Just saving the largest height in the new row
		if (rect.get_height() > tallest_this_row):
			tallest_this_row = rect.get_height()
			
		#// Success!
		#rect.wasPacked = true;
			

func sort_rect(a:Packable_Rect,b:Packable_Rect):
	 #// Sort by height
	if a.get_height() > b.get_height():
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
	
	func get_position():
		return coords.position
	
	func get_x_position():
		return coords.position.x
	
	func get_y_position():
		return coords.position.y
	
	func set_position(position:Vector2):
		coords.position = position
