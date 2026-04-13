extends PanelContainer

@onready var inv_vbox = %InventoryVBox as VBoxContainer

func refresh_inventory() -> void:
	for child in inv_vbox:
		child.queue_free()
	
	for item in Globals.inventory:
		var item_hbox = HBoxContainer.new()
		inv_vbox.add_child(item_hbox)
		item_hbox.add_theme_constant_override("separation", 10)
		
		var item_texture = TextureRect.new()
		item_texture.texture = Globals.item_textures[item]
		item_texture.custom_minimum_size = Vector2(64.0, 64.0)
		item_hbox.add_child(item_texture)
		
		var item_label = Label.new()
		item_label.text = item.capitalize() + " x" + str(Globals.inventory[item])
		item_hbox.add_child(item_label)
		
