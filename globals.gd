extends Node

var in_combat:bool = false
var active_map:TileMapLayer = null

var levels = []
var items = []
var potops = []
var enemies = []

## Attempts to load maps from the user directory. Returns false if no maps were loaded.
func load_maps(map_folder_path: String) -> bool:
	var dir := DirAccess.open(map_folder_path)
	
	if dir == null:
		print("Failed to open directory: ", map_folder_path)
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".tmx"):
			var full_path = map_folder_path + "/" + file_name
			var map = load(full_path)
			if map:
				levels.append(map)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if levels.is_empty():
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false
		
	return true
