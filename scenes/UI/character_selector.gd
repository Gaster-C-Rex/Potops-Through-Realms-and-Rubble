## Sets the party stats in Globals according to selection

extends PanelContainer

var selected_player = "Default"
var selected_equipment = "None"

func _ready() -> void:
	%PlayerTexture.texture = load(Globals.PLAYER_OPTIONS[selected_player]["texture_path"])

func cycle_player(forwards := true):
	var idx = Globals.PLAYER_OPTIONS.keys().find(selected_player)
	var max_idx = Globals.PLAYER_OPTIONS.keys().size() - 1
	if forwards:
		idx += 1
		if idx > max_idx:
			idx = 0
	else:
		idx -= 1
		if idx < 0:
			idx = max_idx
	selected_player = Globals.PLAYER_OPTIONS.keys()[idx]
	%PlayerTexture.texture = load(Globals.PLAYER_OPTIONS[selected_player]["texture_path"])

func cycle_equipment(idx: int):
	pass

func add_to_party(idx: int):
	Globals.party[idx] = Globals.PLAYER_OPTIONS[selected_player]

func _on_player_left_arrow_pressed() -> void:
	cycle_player(false)


func _on_playe_right_arrow_pressed() -> void:
	cycle_player()


func _on_equipment_left_arrow_pressed() -> void:
	pass # Replace with function body.


func _on_equipment_right_arrow_pressed() -> void:
	pass # Replace with function body.
