extends Control

@onready var menues = {
	"hub": %HubWorldMenu,
	"stats": %CharacterStatsMenu,
	"guide": %InfoGuideMenu,
	"shop": %ShopMenu,
	"map": %MapSelectMenu,
	"char": %CharacterSelectMenu,
	"item": %ItemPurchaseMenu
}


func _ready() -> void:
	%MapDirectoryLabel.text = "Map Directory: " +  OS.get_user_data_dir()
	SignalBus.map_chosen.connect(_on_map_chosen)
	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_CONSTRUCT_SITE))

func _on_map_chosen(id):
	Globals.active_map_id = id
	switch_menu("char")

func switch_menu(menu_name: String) -> void:
	for menu in menues.keys():
		menues[menu].visible = (menu == menu_name)

func _on_start_game_button_pressed() -> void:
	Globals.start_game()

func _on_character_back_button_pressed() -> void:
	switch_menu("map")

func _on_map_back_button_pressed() -> void:
	switch_menu("hub")
	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_CONSTRUCT_SITE))

func _on_hub_maps_button_pressed() -> void:
	switch_menu("map")

func _on_hub_shop_button_pressed() -> void:
	switch_menu("shop")
	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_WORKSHOP))

func _on_hub_guide_button_pressed() -> void:
	switch_menu("guide")

func _on_hub_stats_button_pressed() -> void:
	pass
	
func _on_control_guide_back_button_pressed() -> void:
	switch_menu("hub")
	
func _on_shop_back_button_pressed() -> void:
	switch_menu("hub")
	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_CONSTRUCT_SITE))
	
func _on_shop_items_button_pressed() -> void:
	switch_menu("item")
