## Loads the world, entities, and items for selected level.

extends Node2D

const TILE_SIZE:int = 64

var active_map_id:int # What index in the Globals.levels array it is

func _ready() -> void:
	Globals.log = %Log
	if Globals.load_maps():
		set_map(0)
	else:
		Globals.game_log("\nThere are no valid maps in " + OS.get_user_data_dir() + "!")
		%NextMapButton.disabled = true

func _on_next_map_button_pressed() -> void:
	next_map()

func set_map(id:int):
	var map: Variant = Globals.levels[id]
	if Globals.active_map:
		remove_child(Globals.active_map) # Don't queue free them! All maps are always loaded!
	add_child(map)
	Globals.active_map = map
	active_map_id = id
	if !map.is_node_ready():
		await map.ready
	%Camera2D.apply_limits(Globals.calculate_map_pixel_rect(map))

func next_map():
	active_map_id += 1
	if active_map_id > Globals.levels.size() - 1:
		active_map_id = 0
	set_map(active_map_id)
	%Log.text += "\nSwitched to map " + str(active_map_id)

func _unhandled_key_input(event: InputEvent) -> void:
	# why do i do this to myself just use the action manager in project settings
	if event is InputEventKey and event.pressed and event.keycode == 47: # / key
		%PanelContainer.visible = !%PanelContainer.visible
