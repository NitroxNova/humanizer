class_name Random


static func choice(iterable):
	var rng := RandomNumberGenerator.new()
	var i: int = rng.randi_range(0, iterable.size() - 1) 
	if iterable is Array:
		return iterable[i]
	elif iterable is Dictionary:
		var key = iterable.keys()[i]
		return iterable[key]
