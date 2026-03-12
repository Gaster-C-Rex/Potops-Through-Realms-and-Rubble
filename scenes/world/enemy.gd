extends Node2D

var health := 10
var armor := 1 # Damage reduction per hit
var speed := 4 # Number of tiles this unit can move per turn
var has_melee := true
var melee_hits_flying := false
var melee_damage := Vector2i(1, 5) # 1-5 damage per hit
var melee_range := Globals.Melee_Range_Type.ONE_SQUARE
var has_ranged := false
var ranged_hits_flying := false
var attack_range := 4
var ranged_damage: Vector2i
var flying := false

# For connecting the popup selected signal to the right function based on id
var popup_dict := {}

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			print("I am clicked")
			open_interaction_menu(event.position)

## Attempts to open an interaction menu between the player and this instance.
## Returns false if no options are available.
func open_interaction_menu(pos) -> bool:
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
			"args": [caller]
		}
	if caller.has_ranged and caller.ranged_attack_in_range(enemy_tile_pos, flying):
		var option_id = Globals.Popup_Option.RANGED_ATTACK
		popup.add_item("Ranged Attack", option_id)
		popup_dict[option_id] = {
			"node": self,
			"function": "take_ranged_damage",
			"args": [caller]
		}
	if popup.item_count == 0:
		return false
	else:
		popup.popup(Rect2(pos.x, pos.y, 100, 100))
		return true

## Returns the distance between vectors a and b assuming you can't move diaganol
func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## Returns the distance between vectors a and b rounded to tiles
func tile_distance(a: Vector2i, b: Vector2i) -> int:
	return int(round(Vector2(a).distance_to(Vector2(b))))

func attack_in_range(a, b) -> bool:
	return true

func remap_popup_id(id) -> void:
	var node : Node = popup_dict[id]["node"]
	var function : String = popup_dict[id]["function"]
	var vargs : Array = popup_dict[id]["args"]
	node.callv(function, vargs)

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
	queue_free()
