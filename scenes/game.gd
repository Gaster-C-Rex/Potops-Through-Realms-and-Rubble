## Defines game initialization and main loop. Y Sort is enabled on this node so
## children added more recently will be displayed over children added earlier.

extends Node2D

@export var test_map = load("res://assets/levels/test_map.tmx")

const TILE_SIZE:int = 32

func _ready() -> void:
	assert(Globals.load_maps("user://maps") == true, "Failed to load maps, program exiting")
	var map:TileMapLayer = test_map.instantiate()
	add_child(map)
	Globals.active_map = map
	if !map.is_node_ready():
		await map.ready
	%Camera2D.apply_limits(calculate_map_rect(map))

## Calculates the given map's bounding rect in global coordinates
func calculate_map_rect(map:TileMapLayer) -> Rect2:
	var tile_size_rect:Rect2 = map.get_used_rect()
	tile_size_rect.size *= TILE_SIZE
	return tile_size_rect
