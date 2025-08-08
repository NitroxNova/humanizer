@tool
extends Node

# called when enters the editor AND when enters the game
# global was the only way to notify when loaded in game, plugin.gd and static resources will not
func _ready() -> void:
	HumanizerRegistry._get_rigs()
	if Engine.is_editor_hint():
		pass
		#mod loading isnt supported in the editor by default,
		#will manually scan the zip here instead, and add to the registry
	else:
		
		HumanizerRegistry.load_all()
		
		var any_zips_loaded = false
		var existing_files = [] #cant use dirAccess.get_files_at for existing files once a 'resource pack' is loaded
		for folder in ProjectSettings.get_setting("addons/humanizer/asset_import_paths"):
			existing_files.append_array(OSPath.get_files_recursive(folder))
		for file_path in existing_files:
			if file_path.get_extension() == "zip":
				ProjectSettings.load_resource_pack(file_path)
				any_zips_loaded = true
		
		if any_zips_loaded:
			HumanizerRegistry.load_all()

# for updating npcs on a background thread, so it keeps the same reference ID 
# update the node's human config first, and then call this
# assumes the physics body script has a 'human_config' variable - see character_controller script in utils
# or can pass in a new config, but it makes more sense to update the existing one
# not for first time generation, just use the normal humanizer.get_character_body3d for that
# takes about a second to load, if you want instant changes for the player character, keep a live_humanizer in memory
static func update_human_node_async(human_node:PhysicsBody3D,new_config:HumanConfig=null):
	var hz_live = Live_Humanizer.new()
	if new_config == null:
		new_config = human_node.human_config
	else:
		human_node.human_config = new_config
	hz_live.load_config_async(new_config)
	hz_live.node = human_node
	hz_live.update_human_node()

func render_overlay_texture(overlay:HumanizerOverlay,type:String):
	var texture = await $ViewportTextures.render_overlay_texture(overlay,type)
	return texture
	
func render_overlay_viewport(overlays:Array,type:String):
	var texture = await $ViewportTextures.render_overlay_viewport(overlays,type)
	return texture
