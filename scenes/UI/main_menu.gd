extends Control

@onready var menues = {
	"main": %GameStartMenu,
	"char": %CharacterSelectMenu,
	"map": %MapSelectMenu,
	"settings": %SettingsMenu,
}

func _ready() -> void:
	%MapDirectoryLabel.text = "Map Directory: " +  OS.get_user_data_dir()
	SignalBus.map_chosen.connect(_on_map_chosen)

func _on_start_button_pressed() -> void:
	switch_menu("map")

func _on_map_button_pressed() -> void:
	OS.shell_open(OS.get_user_data_dir())

func _on_map_chosen(id):
	Globals.active_map_id = id
	switch_menu("char")
	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_CHAR_SELECT))

func switch_menu(menu_name: String) -> void:
	for menu in menues.keys():
		menues[menu].visible = (menu == menu_name)

func _on_exit_button_pressed() -> void:
	get_tree().quit(0)  # 0 = normal exit

func _on_start_game_button_pressed() -> void:
	Globals.start_game()

func _on_character_back_button_pressed() -> void:
	switch_menu("map")
	AudioController.stop_bg_music()

func _on_map_back_button_pressed() -> void:
	switch_menu("main")

func _on_settings_back_button_pressed() -> void:
	switch_menu("main")

func _on_settings_button_pressed() -> void:
	switch_menu("settings")
