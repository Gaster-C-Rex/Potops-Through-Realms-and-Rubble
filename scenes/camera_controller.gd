## The camera controller automatically calculates the bounds of the current map
## to set scrolling limits. It currently follows around the player node. It will
## need to be able to toggle a fixed and scrolling mode for combat sequences.

extends Camera2D

@onready var map:TileMapLayer = %World

const TILE_SIZE:int = 32

func _ready() -> void:
	apply_limits(calculate_map_rect(map))

## Calculates the given map's bounding rect in global coordinates
func calculate_map_rect(map:TileMapLayer) -> Rect2:
	var tile_size_rect:Rect2 = map.get_used_rect()
	tile_size_rect.size *= TILE_SIZE
	return tile_size_rect

## Sets the camera's limit variables to the given rectangle
func apply_limits(limiting_rect: Rect2) -> void:
	limit_left = limiting_rect.position.x
	limit_right = limiting_rect.size.x
	limit_top = limiting_rect.position.y
	limit_bottom = limiting_rect.size.y
