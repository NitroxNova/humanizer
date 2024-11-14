@tool
class_name HumanizerAssetImporter 
extends Node

signal file_changed(path:String)

@export_file("*.mhclo") var _asset_path = '':
	set(value):
		_asset_path = value
		file_changed.emit(value)
		#print("file changed")



		
