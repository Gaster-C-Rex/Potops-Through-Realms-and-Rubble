# enemy.gd
extends entity

var drops := {} #{"item": count,}

#region Setup

## Initializes this enemy's visuals and archetype data based on its name.
func initialize(enemy_name: String, human_readable_name: String) -> void:
	readable_name = human_readable_name

	match enemy_name:
		"pyroslug":
			$Sprite2D.texture = preload("uid://dxhe8u0y4j7hm")
			load_melee_archetype()
			max_health = 8
			health = 8
			armor = 0
			speed = 4
			sight_range = 6
			drops = {Globals.rare_gems.pick_random(): 1}

		"round_hoglet":
			$Sprite2D.texture = preload("uid://bx5tx0ea00eif")
			load_melee_archetype()
			max_health = 10
			health = 10
			armor = 1
			speed = 4
			sight_range = 6
			drops = {"stick": randi_range(1, 4)}

		"glowcrush_sheller":
			$Sprite2D.texture = preload("uid://326o7hqogisv")
			load_defender_archetype()
			max_health = 14
			health = 14
			armor = 2
			speed = 3
			sight_range = 6
			drops = {"clay": randi_range(1, 2), Globals.common_gems.pick_random(): 1}

		"drafty_wizor":
			$Sprite2D.texture = preload("uid://dvhldadmvlu6")
			load_ranged_archetype()
			max_health = 8
			health = 8
			armor = 0
			speed = 4
			sight_range = 6
			drops = {"clay": randi_range(1, 2), "stick": randi_range(1, 2)}

		"pepperjelly":
			$Sprite2D.texture = preload("uid://bd7mhgqyerhy5")
			load_healer_archetype()
			max_health = 9
			health = 9
			armor = 1
			speed = 4
			sight_range = 6
			drops = {"stick": randi_range(1, 2), Globals.common_gems.pick_random(): 1}
		
		"skuttershot":
			$Sprite2D.texture = preload("uid://cxs3p31w4gbd1")
			load_ranged_archetype()
			max_health = 9
			health = 9
			armor = 0
			speed = 5
			sight_range = 6
			drops = {"clay": randi_range(1, 4)}

## Advances queued movement and sliding for the enemy each physics frame.
func _physics_process(delta: float) -> void:
	process_movement_queue()
	process_sliding(delta)

#endregion


#region Input

## Opens the interaction menu on right click.
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		open_interaction_menu(event.position)

## Handles enemy interaction menu requests.
func open_interaction_menu(_pos) -> bool:
	return false

#endregion


#region Targeting

## Returns true if this enemy currently has line of sight to the active player.
func can_see_player() -> bool:
	if Globals.active_player == null:
		return false

	return has_line_of_sight_to_entity(Globals.active_player, sight_range)

## Returns the closest living player to this enemy.
func get_closest_player() -> entity:
	var living_players := Globals.entity_manager.get_living_players() as Array
	var best_player: entity = null
	var best_dist := 999999

	for player_node in living_players:
		var dist := get_distance_to_entity(player_node)

		if dist < best_dist:
			best_dist = dist
			best_player = player_node

	return best_player

## Finds the best walkable adjacent tile near the given player.
func get_best_adjacent_tile_to_player(player_node: entity) -> Vector2i:
	var player_tile := Globals.get_tile_pos(player_node.position)
	var obstacles: TileMapLayer = Globals.get_map_layer(Globals.active_map, "obstacles")

	var best_tile := Vector2i(-9999, -9999)
	var best_path_len := 999999

	for direction in CARDINAL_DIRECTIONS:
		var candidate := player_tile + direction

		if not walkable(candidate, obstacles):
			continue

		var path := pathfind_to_space(candidate)

		if path.is_empty() and Globals.get_tile_pos(position) != candidate:
			continue

		if path.size() < best_path_len:
			best_path_len = path.size()
			best_tile = candidate

	return best_tile

## Returns true if the given player is within this enemy's melee attack area.
func is_in_melee_range_of_player(player_node: entity) -> bool:
	var my_tile := Globals.get_tile_pos(position)
	var player_tile := Globals.get_tile_pos(player_node.position)
	var tiles := get_attack_affected_tiles(my_tile, player_tile, "melee")
	return player_tile in tiles

## Returns true if the given player is within this enemy's ranged attack area.
func is_in_ranged_range_of_player(player_node: entity) -> bool:
	var my_tile := Globals.get_tile_pos(position)
	var player_tile := Globals.get_tile_pos(player_node.position)
	var tiles := get_attack_affected_tiles(my_tile, player_tile, "ranged")
	return player_tile in tiles

#endregion


#region Combat actions

## Attempts to attack the given player using ranged or melee attacks.
func perform_attack_on_player(player_node: entity) -> bool:
	var my_tile := Globals.get_tile_pos(position)
	var player_tile := Globals.get_tile_pos(player_node.position)

	if has_ranged and not is_in_melee_range_of_player(player_node) and can_use_attack("ranged"):
		var ranged_tiles := get_attack_affected_tiles(my_tile, player_tile, "ranged")

		if player_tile in ranged_tiles:
			spend_attack()
			player_node.take_damage(self, "ranged")
			Globals.send_to_game_log("%s used ranged attack" % readable_name)
			return true

	if has_melee and can_use_attack("melee"):
		var melee_tiles := get_attack_affected_tiles(my_tile, player_tile, "melee")

		if player_tile in melee_tiles:
			spend_attack()
			player_node.take_damage(self, "melee")
			Globals.send_to_game_log("%s used melee attack" % readable_name)
			return true

	return false

## Attempts to use a defend or heal bonus action.
func try_bonus_action() -> bool:
	if has_defend and defend():
		return true

	if has_heal and heal_self():
		return true

	return false

## Moves this enemy toward the given player while respecting combat movement limits.
func move_toward_player(player_node: entity) -> void:
	if get_total_movement_remaining() <= 0:
		return

	if ai_type == "ranged" and is_in_ranged_range_of_player(player_node):
		return

	var target_tile := get_best_adjacent_tile_to_player(player_node)
	if target_tile.x == -9999:
		return

	reachable_tiles.clear()
	movement_came_from.clear()

	var move_data := get_combat_movement_data()
	reachable_tiles = move_data.distances
	movement_came_from = move_data.came_from

	var path := pathfind_to_reachable_space(target_tile)

	if path.is_empty():
		path = pathfind_to_space(target_tile)

		if path.size() > get_total_movement_remaining():
			path = path.slice(0, get_total_movement_remaining())

	if path.is_empty():
		return

	if not spend_movement(path.size()):
		return

	follow_path(path)

	while not movement_queue.is_empty() or sliding:
		process_movement_queue()
		await get_tree().physics_frame

## Resets the turn, moves toward a player, attacks if possible, and tries a bonus action.
func take_turn() -> void:
	reset_turn_resources()

	var player_node := get_closest_player()
	if player_node == null:
		return

	await move_toward_player(player_node)

	player_node = get_closest_player()
	if player_node == null:
		return

	if perform_attack_on_player(player_node):
		return

	try_bonus_action()

#endregion
