## This script contains global variables and external data loading functions

extends Node

const TILE_SIZE = 64
const MAP_DIR = "user://maps"

var in_combat:bool = false

# Array of TileMapLayer nodes containing level data
var levels = []

var items = []
var potops = []
var enemies = []

func _ready() -> void:
	ensure_user_folders()

## Makes sure that the following folders exist in the user directory each time
## the program is run
func ensure_user_folders():
	var folders = [
		"user://maps",
		"user://maps/tiles"
	]

	for f in folders:
		if !DirAccess.dir_exists_absolute(f):
			DirAccess.make_dir_recursive_absolute(f)

## Attempts to load maps from the user directory. Returns false if no maps were loaded.
func load_maps() -> bool:
	var dir := DirAccess.open(MAP_DIR)
	
	if dir == null:
		print("Failed to open directory: ", MAP_DIR)
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# Create an instance of the YATI importer script
	var tilemap_creator = preload("res://addons/YATI/TilemapCreator.gd").new()
	
	while file_name != "":
		print(file_name)
		if !dir.current_is_dir() and file_name.ends_with(".tmx"):
			var full_path = MAP_DIR + "/" + file_name
			print("Found map file: ", full_path)
			var map = tilemap_creator.create(full_path)
			
			# Sometimes the tilemap_creator adds a base node like node2D
			if map.get_parent():
				var parent = map.get_parent()
				parent.remove_child(map)
				parent.queue_free()
			levels.append(map)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if levels.is_empty():
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false
		
	return true
