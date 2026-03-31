extends Control

@onready var shop_vbox = %TradesVBox as VBoxContainer
@onready var button_vbox = %ButtonsVBox as VBoxContainer

var buttons = []

func _ready() -> void:
	for trade in Globals.trades:
		add_shop_item(trade)
	for button in buttons:
		button.pressed.connect(_on_button_pressed.bind(button))

func add_shop_item(trade: Dictionary):
	var ware_hbox = HBoxContainer.new()
	shop_vbox.add_child(ware_hbox)
	for item in trade["price"]:
		var needed = trade["price"][item]
		if needed > 0:
			var cost_vbox = VBoxContainer.new()
			ware_hbox.add_child(cost_vbox)
			
			var cost_texture = TextureRect.new()
			cost_texture.texture = Globals.item_textures[item]
			cost_texture.custom_minimum_size = Vector2(128.0, 128.0)
			cost_vbox.add_child(cost_texture)
			
			var cost_label = Label.new()
			cost_label.text = item + " x" + str(needed)
			cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost_label.add_theme_font_size_override("font_size", 20)
			cost_vbox.add_child(cost_label)
	
	var result_vbox = VBoxContainer.new() # This must get added last
	result_vbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END # Nasty bit field
	ware_hbox.add_child(result_vbox)
	
	var result_texture = TextureRect.new()
	result_texture.texture = Globals.item_textures.get(trade["result"], preload("uid://ys4yciugkf8l"))
	result_texture.custom_minimum_size = Vector2(128.0, 128.0)
	result_vbox.add_child(result_texture)
	
	var result_label = Label.new()
	result_label.text = trade["result"] + " x1"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 20)
	result_vbox.add_child(result_label)
	
	var trade_button = Button.new()
	trade_button.text = "DEAL"
	trade_button.add_theme_font_size_override("font_size", 30)
	trade_button.disabled = true
	trade_button.custom_minimum_size = Vector2(200.0, 159.0)
	
	button_vbox.add_child(trade_button)
	buttons.append(trade_button)

func update_trade_buttons() -> void:
	var idx = 0
	for trade in Globals.trades:
		if can_afford_trade(trade):
			buttons[idx].disabled = false
		else:
			buttons[idx].disabled = true
		idx += 1

func can_afford_trade(trade: Dictionary) -> bool:
	for item in trade["price"]:
		var required := trade["price"][item] as int
		var available := Globals.inventory.get(item, 0) as int
		
		if available < required:
			return false
	return true

func apply_trade(trade: Dictionary) -> void:
	if not can_afford_trade(trade):
		push_warning("Tried to apply trade without enough resources, cancelling")
		return
	
	for item in trade["price"]:
		var required := trade["price"][item] as int
		Globals.inventory[item] -= required
		
		# Clean up zero entries
		if Globals.inventory[item] <= 0:
			Globals.inventory.erase(item)
	print("Remaining inventory: \n", Globals.inventory)

func _on_button_pressed(button: Button) -> void:
	var trade = Globals.trades[buttons.find(button)]
	if can_afford_trade(trade):
		apply_trade(trade)
	else:
		push_warning("Couldn't afford trade, but button was enabled. Doing nothing.")
	update_trade_buttons()
