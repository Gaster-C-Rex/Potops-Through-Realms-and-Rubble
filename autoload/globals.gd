## This script contains global variables and external data loading functions

extends Node

const TILE_SIZE = 64
const MAP_DIR = "user://maps"

var active_map: Node2D
var active_map_id: int
var game_log: RichTextLabel

var in_combat:bool = false

# Array of TileMapLayer nodes containing level data
var levels := []

var items := []
var potops := []
var enemies := []

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
	print("Scanning for map files...")
	if !levels.is_empty():
		levels.clear()
	
	var dir := DirAccess.open(MAP_DIR)
	
	if dir == null:
		print("Failed to open directory: ", MAP_DIR)
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	# Create an instance of the YATI importer script
	var tilemap_creator = preload("res://addons/YATI/TilemapCreator.gd").new()
	
	# Discover and load map files to levels array
	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".tmx"):
			var full_path = MAP_DIR + "/" + file_name
			print("Found map file: ", full_path)
			var map: Node2D = tilemap_creator.create(full_path)
			
			# The entity layer is never shown, it only exists to be useful to
			# the people making the maps in tiled. We extract the data and
			# instantiate each entity at the corresponding place later.
			if map.has_node("entities"):
				map.get_node("entities").visible = false
			levels.append(map)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if levels.is_empty():
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false
		
	return true

## Returns a position in global coordinates of the nearest tile's center
func get_tile_center(coords: Vector2, system = "global") -> Vector2:
	if system == "global":
		return Vector2(
			floor(coords.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
			floor(coords.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2
		)
	elif system == "tile":
		return Vector2(
			coords.x * TILE_SIZE + TILE_SIZE / 2,
			coords.y * TILE_SIZE + TILE_SIZE / 2
		)

	return coords

## Returns a tile position from a position in global coordinates
func get_tile_pos(coords: Vector2) -> Vector2i:
	return Vector2i(
		floor(coords.x / TILE_SIZE),
		floor(coords.y / TILE_SIZE)
	)

func tile_in_bounds(tile_pos: Vector2) -> bool:
	if active_map:
		var tilemaplayer: TileMapLayer = get_map_layer(active_map, "background")
		var map_rect := tilemaplayer.get_used_rect() # This is in tile coords
		return map_rect.has_point(tile_pos)
	else:
		# If no map is loaded, allow all movement
		return true

## Returns a refernce to the specified tilemap layer. Can either be background,
## obstacles, or entities
func get_map_layer(map: Node2D, layer: String):
	if map.has_node(layer):
		return map.get_node(layer)
	else:
		push_warning("Tilemap does not have a layer named \"", layer, "\"")
		return null

## Calculates the given map's bounding rect in global coordinates
func calculate_map_pixel_rect(map: Node2D) -> Rect2:
	var tilemaplayer: TileMapLayer = get_map_layer(map, "background")
	var tile_rect := tilemaplayer.get_used_rect() # rect is in tile coords
	return Rect2(tile_rect.position * TILE_SIZE, tile_rect.size * TILE_SIZE)

func send_to_game_log(message):
	if game_log:
		game_log.append_text("\n" + message)
	else:
		push_warning("Race condition: Log not yet defined")

func clear_game_log():
	if log:
		game_log.clear()
	else:
		push_warning("Race condition: Log not yet defined")

func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/world/game.tscn")

func exit_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")
