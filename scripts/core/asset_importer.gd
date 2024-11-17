@tool
class_name HumanizerAssetImporter 
extends Node

signal file_changed()

@export_file("*.mhclo") var asset_path = '':
	set(value):
		asset_path = value
		file_changed.emit()
		#print("file changed")



		
