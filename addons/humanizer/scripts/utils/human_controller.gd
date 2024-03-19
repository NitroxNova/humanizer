extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	var msg: String = 'This script was automatically added to your generated human. '
	msg += 'You can set a different default script in your HumanizerConfig resource '
	msg += 'on the humanizer_global.tscn scene root node.'
	print(msg)

