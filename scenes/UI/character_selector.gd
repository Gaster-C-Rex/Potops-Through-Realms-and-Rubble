## Sets the party stats in Globals according to selection
extends PanelContainer

@export var party_index := -1 # Which player this instance controls

var selected_player := "Default"
var selected_equipment := "None"

var equipment := {} # {"name": qty}

func _ready() -> void:
	if party_index == -1:
		push_error("You need to set party_index in the editor!!")
	%PlayerTexture.texture = load(Globals.PLAYER_OPTIONS[selected_player]["texture_path"])
	calculate_available_equipment()

	Globals.equipped[party_index] = selected_equipment
	_update_equipment_display()
	add_to_party(party_index)

func cycle_player(forwards := true) -> void:
	var player_keys := Globals.PLAYER_OPTIONS.keys()
	var idx := player_keys.find(selected_player)
	var max_idx := player_keys.size() - 1

	if forwards:
		idx += 1
		if idx > max_idx:
			idx = 0
	else:
		idx -= 1
		if idx < 0:
			idx = max_idx

	selected_player = player_keys[idx]
	%PlayerTexture.texture = load(Globals.PLAYER_OPTIONS[selected_player]["texture_path"])
	add_to_party(party_index)

## Updates selected_equipment with a valid value and wraps.
func cycle_equipment(forwards := true) -> void:
	calculate_available_equipment()
	print(equipment)

	var options := _get_cycleable_equipment_list()
	if options.is_empty():
		options = ["None"]

	var idx := options.find(selected_equipment)
	if idx == -1:
		idx = 0

	if forwards:
		idx += 1
		if idx >= options.size():
			idx = 0
	else:
		idx -= 1
		if idx < 0:
			idx = options.size() - 1

	selected_equipment = options[idx]
	Globals.equipped[party_index] = selected_equipment

	_update_equipment_display()
	add_to_party(party_index)

## Writes the selected player to Globals.party with equipment bonuses applied
func add_to_party(idx: int) -> void:
	var party_member: Dictionary = Globals.PLAYER_OPTIONS[selected_player].duplicate(true)

	if "properties" not in party_member:
		party_member["properties"] = {}

	if selected_equipment != "None" and selected_equipment in Globals.EQUIPMENT_OPTIONS:
		var bonuses: Dictionary = Globals.EQUIPMENT_OPTIONS[selected_equipment]

		for stat in bonuses:
			var bonus_value = bonuses[stat]

			if stat not in party_member["properties"]:
				party_member["properties"][stat] = bonus_value
			else:
				var current_value = party_member["properties"][stat]

				match typeof(current_value):
					TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2I, TYPE_VECTOR2:
						party_member["properties"][stat] += bonus_value
					_:
						party_member["properties"][stat] = bonus_value

	party_member["equipment"] = selected_equipment
	Globals.party[idx] = party_member

func calculate_available_equipment() -> void:
	equipment.clear()
	
	for item in Globals.inventory:
		if item in Globals.EQUIPMENT_OPTIONS:
			equipment[item] = Globals.inventory[item]

func _get_cycleable_equipment_list() -> Array[String]:
	var options: Array[String] = ["None"]

	for item in equipment.keys():
		var available_count: int = equipment[item]
		var used_by_others := 0

		for i in range(Globals.equipped.size()):
			if i != party_index and Globals.equipped[i] == item:
				used_by_others += 1

		if available_count - used_by_others > 0:
			options.append(item)

	return options

func _update_equipment_display() -> void:
	if selected_equipment == "None":
		%EquipmentTexture.texture = preload("uid://bkao6milc6500") # Red x
	else:
		%EquipmentTexture.texture = Globals.item_textures[selected_equipment]

func _on_player_left_arrow_pressed() -> void:
	cycle_player(false)

func _on_playe_right_arrow_pressed() -> void:
	cycle_player(true)

func _on_equipment_left_arrow_pressed() -> void:
	cycle_equipment(false)

func _on_equipment_right_arrow_pressed() -> void:
	cycle_equipment(true)
