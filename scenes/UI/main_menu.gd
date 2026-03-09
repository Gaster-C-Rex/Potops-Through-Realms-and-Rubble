extends Control

func _ready() -> void:
	%MapDirectoryLabel.text = "Map Directory: " +  OS.get_user_data_dir()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/game.tscn")

func _on_map_button_pressed() -> void:
	OS.shell_open(OS.get_user_data_dir())
