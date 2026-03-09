## Godot's default grid container leaves a lot to be desired, so I made my own.
extends VBoxContainer

const map_button = preload("res://scenes/UI/map_button.tscn")
const columns = 6 # The godot grid container leaves a lot to be desired

func _ready() -> void:
	var count = 0
	var active_hbox: HBoxContainer
	if !Globals.load_maps():
		Globals.send_to_game_log("\nThere are no valid maps in " + OS.get_user_data_dir() + "!")
	for map:Node2D in Globals.levels:
		if count % columns == 0:
			active_hbox = HBoxContainer.new()
			active_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			add_child(active_hbox)
		var new_map_button = map_button.instantiate()
		new_map_button.initialize(map.name, count)
		active_hbox.add_child(new_map_button)
		count += 1
