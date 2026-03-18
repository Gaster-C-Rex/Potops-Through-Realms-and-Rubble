## Loads the world, entities, and items for selected level.

extends Node2D

const TILE_SIZE:int = 64

var active_map_id:int # What index in the Globals.levels array it is

func _ready() -> void:
	Globals.game_log = %Log
	set_map(Globals.active_map_id)

func _on_next_map_button_pressed() -> void:
	next_map()

func set_map(id:int):
	var map: Variant = Globals.levels[id]
	if Globals.active_map:
		remove_child(Globals.active_map) # Don't queue free them! Maps are always loaded.
	add_child(map)
	Globals.active_map = map
	active_map_id = id
	if !map.is_node_ready():
		await map.ready
	%Camera2D.apply_limits(Globals.calculate_map_pixel_rect(map))
	%EntityManager.spawn_entities()

func next_map():
	active_map_id += 1
	if active_map_id > Globals.levels.size() - 1:
		active_map_id = 0
	set_map(active_map_id)
	%Log.text += "\nSwitched to map " + str(active_map_id)

func _on_end_turn_button_pressed() -> void:
	Globals.active_player.reset_movement_for_turn()

func _on_enter_combat_button_pressed() -> void:
	Globals.in_combat = !Globals.in_combat
