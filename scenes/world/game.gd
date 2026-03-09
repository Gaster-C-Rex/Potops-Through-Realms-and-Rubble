## Defines game initialization and main loop. Y Sort is enabled on this node so
## children added more recently will be displayed over children added earlier.

extends Node2D

const TILE_SIZE:int = 64

var active_map:TileMapLayer # Reference to the active map
var active_map_id:int # What index in the maps array it is

func _ready() -> void:
	if Globals.load_maps():
		set_map(0)
	else:
		%Log.text += ("\nThere are no valid maps in " + OS.get_user_data_dir() + "!")
		%NextMapButton.disabled = true

## Calculates the given map's bounding rect in global coordinates
func calculate_map_rect(map:TileMapLayer) -> Rect2:
	var tile_size_rect:Rect2 = map.get_used_rect()
	tile_size_rect.size *= TILE_SIZE
	return tile_size_rect


func _on_next_map_button_pressed() -> void:
	next_map()

func set_map(id:int):
	var map:TileMapLayer = Globals.levels[id]
	if active_map:
		remove_child(active_map) # Don't queue free them! All maps are always loaded!
	add_child(map)
	active_map = map
	active_map_id = id
	if !map.is_node_ready():
		await map.ready
	%Camera2D.apply_limits(calculate_map_rect(map))

func next_map():
	active_map_id += 1
	if active_map_id > Globals.levels.size() - 1:
		active_map_id = 0
	set_map(active_map_id)
	%Log.text += "\nSwitched to map " + str(active_map_id)
