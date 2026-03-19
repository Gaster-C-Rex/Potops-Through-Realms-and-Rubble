extends entity

# For connecting the popup selected signal to the right function based on id
var popup_dict := {}

func initialize(enemy_name: String) -> void:
	match enemy_name:
		"fireworm":
			$Sprite2D.texture = preload("uid://dxhe8u0y4j7hm")
		"crawler":
			$Sprite2D.texture = preload("uid://bx5tx0ea00eif")
		"glowcrushsheller":
			$Sprite2D.texture = preload("uid://326o7hqogisv")
		"ghost":
			$Sprite2D.texture = preload("uid://dvhldadmvlu6")
		"pepperjelly":
			$Sprite2D.texture = preload("uid://bd7mhgqyerhy5")


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			open_interaction_menu(event.position)

## Attempts to open an interaction menu between the player and this instance.
## Returns false if no options are available.
func open_interaction_menu(pos) -> bool:
	return false # Combat was reworked and this menu is currently unused
	var popup := PopupMenu.new()
	popup.position = pos
	popup.id_pressed.connect(remap_popup_id)
	Globals.active_canvas_layer.add_child(popup)
	var caller = Globals.active_player
	var enemy_tile_pos := Globals.get_tile_pos(position)
	if caller.has_melee and caller.melee_attack_in_range(enemy_tile_pos, flying):
		var option_id = Globals.Popup_Option.MELEE_ATTACK
		popup.add_item("Melee Attack", option_id)
		popup_dict[option_id] = {
			"node": self,
			"function": "take_melee_damage",
			"args": [caller],
			"player": caller
		}
	if caller.has_ranged and caller.ranged_attack_in_range(enemy_tile_pos, flying):
		var option_id = Globals.Popup_Option.RANGED_ATTACK
		popup.add_item("Ranged Attack", option_id)
		popup_dict[option_id] = {
			"node": self,
			"function": "take_ranged_damage",
			"args": [caller],
			"player": caller
		}
	if popup.item_count == 0:
		return false
	else:
		caller.move_state = caller.MoveState.IN_MENU
		popup.popup(Rect2(pos.x, pos.y, 100, 100))
		return true

func remap_popup_id(id) -> void:
	var node : Node = popup_dict[id]["node"]
	var function : String = popup_dict[id]["function"]
	var vargs : Array = popup_dict[id]["args"]
	node.callv(function, vargs)
	var player = popup_dict[id]["player"]
	player.move_state = player.MoveState.IDLE

func take_melee_damage(attacker):
	var damage_range : Vector2i = attacker.melee_damage
	var damage_taken = randi_range(damage_range.x, damage_range.y)
	health -= damage_taken
	if health <= 0:
		die()
	Globals.send_to_game_log("I took " + str(damage_taken) + " melee damage! I now have " + str(health) + " health!")

func take_ranged_damage(attacker):
	var damage_range : Vector2i = attacker.ranged_damage
	var damage_taken = randi_range(damage_range.x, damage_range.y)
	health -= damage_taken
	if health <= 0:
		die()
	Globals.send_to_game_log("I took " + str(damage_taken) + " ranged damage! I now have " + str(health) + " health!")

func die():
	Globals.send_to_game_log("I am dead")
	Globals.entity_manager.entities.erase(self)
	queue_free()
