extends Control

@onready var menues = {
	"main": %GameStartMenu,
	"settings": %SettingsMenu,
}

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/hub_world.tscn")

func _on_map_button_pressed() -> void:
	OS.shell_open(OS.get_user_data_dir())



func _on_map_chosen(id):
	Globals.active_map_id = id
	switch_menu("char")

func switch_menu(menu_name: String) -> void:
	for menu in menues.keys():
		menues[menu].visible = (menu == menu_name)

func _on_exit_button_pressed() -> void:
	get_tree().quit(0)  # 0 = normal exit

func _on_start_game_button_pressed() -> void:
	Globals.start_game()

func _on_settings_back_button_pressed() -> void:
	switch_menu("main")

func _on_settings_button_pressed() -> void:
	switch_menu("settings")
