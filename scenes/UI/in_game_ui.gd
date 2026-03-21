extends CanvasLayer

@onready var menues = {
	"pause": %PauseMenu,
	"settings": %SettingsMenu,
	"game_over": %GameOverMenu
}

@onready var log_panel = %LogPanel

func _ready() -> void:
	Globals.active_canvas_layer = self

func switch_menu(menu_name: String) -> void:
	for menu in menues.keys():
		menues[menu].visible = (menu == menu_name)

func hide_menu(menu_name: String) -> void:
		menues[menu_name].visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SLASH:
		log_panel.visible = !log_panel.visible
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		switch_menu("pause")

func _on_resume_button_pressed() -> void:
	menues["pause"].visible = false

func _on_quit_button_pressed() -> void:
	clean_exit()

func _on_settings_back_button_pressed() -> void:
	switch_menu("pause")

func _on_settings_button_pressed() -> void:
	switch_menu("settings")

func _on_restart_button_pressed() -> void:
	clean_exit()

func clean_exit() -> void:
	for map in Globals.levels:
		map.queue_free()
	Globals.levels.clear()
	Globals.exit_to_main_menu()
