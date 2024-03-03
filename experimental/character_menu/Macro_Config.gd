extends Resource
class_name Macro_Config

const shapekey_data = preload("res://experimental/process_shapekeys/shapekey_data.res")

var data :Dictionary = {
	race={african=0.33,asian=0.33,caucasian=0.34},
	age = Macro_Data.new([["baby",0],["child",12.0],["young",25.0],["old",100]]),
	gender = Macro_Data.new([["female",0.0],["male",1.0]]),
	height = Macro_Data.new([["minheight",0],["",.5],["maxheight",1]]),
	muscle = Macro_Data.new([["minmuscle",0],["averagemuscle",0.5],["maxmuscle",1]]),
	proportions = Macro_Data.new([["uncommonproportions",0],["",0.5],["idealproportions",1]]),
	weight = Macro_Data.new([["minweight",0],["averageweight",0.5],["maxweight",1]]),
	cupsize = Macro_Data.new([["mincup",0],["averagecup",0.5],["maxcup",1]]),
	firmness = Macro_Data.new([["minfirmness",0],["averagefirmness",0.5],["maxfirmness",1]])
}

var combinations : Dictionary = {
	"racegenderage": ["race", "gender", "age"],
	"genderagemuscleweight": ["universal", "gender", "age", "muscle", "weight"],
	"genderagemuscleweightproportions": ["gender", "age", "muscle", "weight", "proportions"],
	"genderagemuscleweightheight": ["gender", "age", "muscle", "weight", "height"],
	"genderagemuscleweightcupsizefirmness": ["gender", "age", "muscle", "weight", "cupsize", "firmness"]
}

var combo_shapekeys : Dictionary = {} #shapekey_name and value pairs

func _init(values:Dictionary={}):
	for macro_name in values:
		var macro_value = values[macro_name]
		if macro_name == "race":
			set_race(macro_value[0],macro_value[1],macro_value[2])
		else:
			data[macro_name].set_value(macro_value)
	update_shapekey_combinations()

func set_race(african:float,asian:float,caucasian:float):
	data.race.caucasian = caucasian
	data.race.asian = asian
	data.race.african = african
	update_shapekey_combinations("race")

func set_macro_value(macro_name:String,value:float): #everything other than race
	if macro_name in data:
		data[macro_name].set_value(value)
		update_shapekey_combinations(macro_name)
	else:
		print("invalid macro name " + macro_name)

func set_gender_female():
	set_macro_value("gender",0.0)

func set_gender_male():
	set_macro_value("gender",1.0)
	
func update_shapekey_combinations(macro_name=null):
	for combo_name in combinations:
		if macro_name == null or macro_name in combinations[combo_name]:
			get_combination_shapekeys(combo_name)

func get_combination_shapekeys(combo_name:String):
	#print(combo_name)
	#print(combinations[combo_name])
	var curr_shapes = {""=1}
	var next_shapes = {}
	for macro_name in combinations[combo_name]:
		#print(macro_name)
		if macro_name == "universal":
			next_shapes = {"universal"=1}
		elif macro_name == "race":
			next_shapes = data.race.duplicate()
		else:
			var curr_macro = data[macro_name]
			for shape_name in curr_shapes:
				for offset_counter in curr_macro.offset.size():
					var offset_id = curr_macro.offset[offset_counter]
					var new_shape_name = shape_name 
					if not shape_name == "":
						new_shape_name += "-"
					new_shape_name += curr_macro.category[offset_id][0]
					#print(new_shape_name)
					var new_shape_value = curr_shapes[shape_name] * curr_macro.ratio[offset_counter]
					next_shapes[new_shape_name] = new_shape_value
		#print(next_shapes)
		curr_shapes = next_shapes
		next_shapes = {}
	#print(curr_shapes)
	for shape_name in curr_shapes.keys():
		if not shape_name in shapekey_data.shapekeys:
			#print(shape_name + " not found")
			curr_shapes.erase(shape_name)
	
	combo_shapekeys[combo_name] = curr_shapes
	#print(curr_shapes)
	#print()

class Macro_Data:
	var value : float = 0.0
	var offset : Array = [] # low and high offset
	var ratio : Array = [] #ratio between low (0) and high (1)
	var category : Array = [] #array of string names and offsets
	
	func _init(_category:Array):
		category = _category
		set_value(.5)
	
	func set_value(_value:float):
		value = _value
		update_category_offset()
	
	func update_category_offset():
		var counter = 0
		for i in category.size():
			if value == category[i][1]:
				offset = [i]
				ratio = [1]
				break
			elif value < category[i][1]:
				offset = [i-1,i]
				ratio = []
				var high_ratio = (value-category[i-1][1])/(category[i][1]-category[i-1][1])
				ratio.append(1-high_ratio)
				ratio.append(high_ratio)
				break
		for i in range(offset.size()-1,-1,-1):
			if category[offset[i]][0] == "":
				offset.remove_at(i)
				ratio.remove_at(i)
		
	
	
