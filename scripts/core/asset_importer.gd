@tool
class_name HumanizerAssetImporter 
extends Node

signal file_changed(path:String)

@export_file("*.mhclo") var asset_path = '':
	set(value):
		asset_path = value
		file_changed.emit(value)
		#print("file changed")



		
