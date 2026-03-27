# entity_manager.gd
extends Node

#region Data

var entity_lookup = {
	1: [preload("res://scenes/world/enemy.tscn"), ["fireworm"], "fireworm"],
	2: [preload("res://scenes/world/enemy.tscn"), ["crawler"], "crawler"],
	3: [preload("res://scenes/world/enemy.tscn"), ["glowcrushsheller"], "glowcrushsheller"],
	4: [preload("res://scenes/world/enemy.tscn"), ["ghost"], "ghost"],
	5: [preload("res://scenes/world/enemy.tscn"), ["pepperjelly"], "pepperjelly"],
	9: [preload("res://scenes/world/item.tscn"), ["item"], "item"],
	10: [preload("res://scenes/world/shop.tscn"), ["shop"], "shop"],
}

var entities := []
var enemies := []
var players := []

var _spawn_counter := 0
var enemy_turn_running := false

#endregion


#region Lifecycle

## Registers this node as the global entity manager.
func _ready() -> void:
	Globals.entity_manager = self

## Spawns map entities from the entity layer and then spawns the player party.
func spawn_entities() -> void:
	entities.clear()
	enemies.clear()
	players.clear()
	_spawn_counter = 0

	var layer: TileMapLayer = Globals.get_map_layer(Globals.active_map, "entities")
	if layer == null:
		return

	for cell in layer.get_used_cells():
		var source_id := layer.get_cell_source_id(cell)

		if not entity_lookup.has(source_id):
			continue

		var scene_data = entity_lookup[source_id]
		print("Spawning ", scene_data[2], " at ", cell)

		var instance = scene_data[0].instantiate()
		instance.callv("initialize", scene_data[1])
		instance.position = layer.map_to_local(cell)
		instance.spawn_order = _spawn_counter
		_spawn_counter += 1

		add_child(instance)
		entities.append(instance)

		if instance is entity and instance.get_script().resource_path.ends_with("enemy.gd"):
			enemies.append(instance)

	_spawn_player_party()

#endregion


#region Player party

## Spawns the default player party in formation at the current spawn tile.
func _spawn_player_party() -> void:
	var player_scene := preload("uid://b1queastcser2")
	var spawnpoint := _get_player_spawn_tile()

	for i in range(3):
		var instance = player_scene.instantiate()
		var spawn_tile := spawnpoint + Vector2i(-i, 0)

		instance.party_index = i
		instance.position = Globals.get_tile_center(spawn_tile, "tile")
		instance.target_position = instance.position
		instance.spawn_order = _spawn_counter
		_spawn_counter += 1

		add_child(instance)
		entities.append(instance)
		players.append(instance)

	finalize_player_party_setup()

## Returns the tile where the party should spawn.
func _get_player_spawn_tile() -> Vector2i:
	if Globals.active_player != null and is_instance_valid(Globals.active_player):
		return Globals.get_tile_pos(Globals.active_player.position)

	var background: TileMapLayer = Globals.get_map_layer(Globals.active_map, "background")
	if background:
		var used_rect := background.get_used_rect()
		return used_rect.position + Vector2i(2, 2)

	return Vector2i.ZERO

## Returns all currently valid player instances.
func get_living_players() -> Array:
	var out := []

	for player_node in players:
		if is_instance_valid(player_node):
			out.append(player_node)

	return out

## Sort helper that orders players by party index.
func _sort_players_by_party_index(a, b) -> bool:
	return a.party_index < b.party_index

## Returns living party members ordered by party index.
func get_party_members_in_order() -> Array:
	var ordered := get_living_players()
	ordered.sort_custom(_sort_players_by_party_index)
	return ordered

## Returns true if any party member is currently moving or sliding.
func party_is_busy() -> bool:
	for player_node in get_living_players():
		if player_node.sliding:
			return true

		if not player_node.movement_queue.is_empty():
			return true

	return false

## Sets the given player as active and updates party order and UI state.
func set_active_player(player_node) -> void:
	if not is_instance_valid(player_node):
		return

	if player_node not in players:
		return

	if enemy_turn_running:
		return

	if party_is_busy():
		Globals.send_to_game_log("Cannot switch party members while moving")
		return

	var ordered := get_party_members_in_order()

	if Globals.active_player == player_node:
		attach_camera_to(player_node)
		player_node.update_health_bar()
		player_node._update_combat_ui()
		return

	if not Globals.in_combat:
		var new_order := [player_node]

		for member in ordered:
			if member != player_node:
				new_order.append(member)

		for i in range(new_order.size()):
			var member = new_order[i]
			member.party_index = i
			member.clear_follow_targets()

	Globals.active_player = player_node
	attach_camera_to(player_node)

	if Globals.in_combat:
		set_combat_ui_visible(true)

	player_node.update_health_bar()
	player_node._update_combat_ui()

## Queues follower steps so the party fills the leader's previous tile chain.
func queue_party_follow_step(leader_previous_tile: Vector2i) -> void:
	var ordered := get_party_members_in_order()

	if ordered.size() <= 1:
		return

	var tile_to_fill := leader_previous_tile
	var previous_positions: Array[Vector2i] = []

	for member in ordered:
		previous_positions.append(Globals.get_tile_pos(member.position))

	for i in range(1, ordered.size()):
		var follower = ordered[i]
		follower.follow_targets.append(tile_to_fill)
		tile_to_fill = previous_positions[i]

## Clears all queued follow targets for living players.
func clear_party_follow_targets() -> void:
	for player_node in get_living_players():
		player_node.clear_follow_targets()

## Rebuilds the party into a straight line behind the active leader.
func reform_party_line() -> void:
	var ordered := get_party_members_in_order()
	if ordered.is_empty():
		return

	var leader = Globals.active_player

	if leader == null or leader not in ordered:
		leader = ordered[0]
		Globals.active_player = leader

	leader.party_index = 0

	var leader_tile := Globals.get_tile_pos(leader.position)

	for member in ordered:
		member.clear_follow_targets()
		member.movement_queue.clear()
		member.sliding = false
		member.move_state = member.MoveState.IDLE

	for i in range(1, ordered.size()):
		var member = ordered[i]
		var target_tile := leader_tile + Vector2i(-i, 0)

		member.party_index = i
		member.position = Globals.get_tile_center(target_tile, "tile")
		member.target_position = member.position
		member.last_tile_pos = target_tile

	leader.last_tile_pos = leader_tile
	leader.target_position = leader.position

## Sort helper that orders enemies by speed and then spawn order.
func _sort_enemies_for_turn(a, b) -> bool:
	if a.speed == b.speed:
		return a.spawn_order < b.spawn_order

	return a.speed > b.speed

## Returns true if a tile is invalid for placing a party member during combat spread.
func _tile_blocked_for_party_placement(tile: Vector2i, reserved_tiles: Array[Vector2i]) -> bool:
	if not Globals.tile_in_bounds(tile):
		return true

	var obstacles: TileMapLayer = Globals.get_map_layer(Globals.active_map, "obstacles")
	if obstacles and obstacles.get_cell_source_id(tile) != -1:
		return true

	if tile in reserved_tiles:
		return true

	for ent in entities:
		if ent in players:
			continue

		if Globals.get_tile_pos(ent.position) == tile:
			return true

	return false

## Spreads party members around the leader when combat begins.
func spread_party_for_combat(trigger_enemy: entity) -> void:
	var ordered := get_party_members_in_order()
	if ordered.size() <= 1:
		return

	var leader = Globals.active_player
	if leader == null:
		return

	var leader_tile := Globals.get_tile_pos(leader.position)
	var enemy_tile := Globals.get_tile_pos(trigger_enemy.position)
	var delta := enemy_tile - leader_tile

	var facing := Vector2i.RIGHT

	if absi(delta.x) >= absi(delta.y):
		if signi(delta.x) != 0:
			facing = Vector2i(signi(delta.x), 0)
	else:
		if signi(delta.y) != 0:
			facing = Vector2i(0, signi(delta.y))

	var side_a := Vector2i(-facing.y, facing.x)
	var side_b := Vector2i(facing.y, -facing.x)

	var candidate_offsets: Array[Vector2i] = [
		-facing + side_a,
		-facing + side_b,
		-facing * 2,
		side_a * 2,
		side_b * 2,
	]

	var reserved_tiles: Array[Vector2i] = [leader_tile]

	for i in range(1, ordered.size()):
		var member = ordered[i]
		var chosen_tile := leader_tile

		for offset in candidate_offsets:
			var candidate := leader_tile + offset

			if _tile_blocked_for_party_placement(candidate, reserved_tiles):
				continue

			chosen_tile = candidate
			break

		member.position = Globals.get_tile_center(chosen_tile, "tile")
		member.target_position = member.position
		member.last_tile_pos = chosen_tile
		member.sliding = false
		member.movement_queue.clear()
		member.clear_follow_targets()
		reserved_tiles.append(chosen_tile)

## Finalizes player setup after spawning or reforming the party.
func finalize_player_party_setup() -> void:
	var ordered := get_party_members_in_order()
	if ordered.is_empty():
		return

	Globals.active_player = ordered[0]

	for i in range(ordered.size()):
		var player_node = ordered[i]
		player_node.party_index = i
		player_node.target_position = player_node.position
		player_node.last_tile_pos = Globals.get_tile_pos(player_node.position)
		player_node.sliding = false
		player_node.move_state = player_node.MoveState.IDLE
		player_node.clear_follow_targets()

	reform_party_line()
	attach_camera_to(Globals.active_player)
	Globals.active_player._update_combat_ui()

#endregion


#region Combat flow

## Starts combat if any enemy can currently see the player.
func check_for_combat_trigger() -> void:
	if Globals.in_combat:
		return

	for enemy in enemies:
		if enemy.can_see_player():
			enter_combat(enemy)
			return

## Enters combat, interrupts movement, and activates valid enemies.
func enter_combat(trigger_enemy: entity = null) -> void:
	if Globals.in_combat:
		if trigger_enemy != null:
			trigger_enemy.forced_engaged = true

		recalculate_active_enemies()

		if Globals.active_player:
			Globals.active_player._update_combat_ui()

		return

	for player_node in get_living_players():
		player_node.interrupt_movement_for_combat()

	Globals.in_combat = true
	enemy_turn_running = false

	for player_node in get_living_players():
		player_node.reset_turn_resources()

	if trigger_enemy != null:
		trigger_enemy.forced_engaged = true
		spread_party_for_combat(trigger_enemy)

	for player_node in get_living_players():
		player_node.reset_movement_state_for_combat()
		player_node.last_tile_pos = Globals.get_tile_pos(player_node.position)

	recalculate_active_enemies()
	set_combat_ui_visible(true)
	attach_camera_to(Globals.active_player)

	if Globals.active_player:
		Globals.active_player._update_combat_ui()

	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_BATTLE)) #when entering battle, play battle music

	Globals.send_to_game_log("Combat started")

## Exits combat, resets player resources, and reforms the party line.
func exit_combat() -> void:
	Globals.in_combat = false
	enemy_turn_running = false

	for enemy in enemies:
		enemy.active_in_combat = false
		enemy.forced_engaged = false

	for player_node in get_living_players():
		player_node.reset_turn_resources()
		player_node.reset_combat_resources()
		player_node.hide_attack_range()
		player_node.hide_spaces()
		player_node.clear_follow_targets()
		player_node.move_state = player_node.MoveState.IDLE

	set_combat_ui_visible(false)
	finalize_player_party_setup()

	if Globals.active_player:
		Globals.active_player._update_combat_ui()

	AudioController.play_bg_music(Globals.get_audio(Globals.SONG_EXPLORE)) #goes back to exploring after combat

	Globals.send_to_game_log("Combat ended")

## Recalculates which enemies should be active in the current combat.
func recalculate_active_enemies() -> void:
	var active_players := get_living_players()
	var directly_engaged: Array = []

	for enemy in enemies:
		enemy.active_in_combat = false

	for enemy in enemies:
		if enemy.forced_engaged:
			enemy.active_in_combat = true
			directly_engaged.append(enemy)
			continue

		for player_node in active_players:
			if enemy.has_line_of_sight_to_entity(player_node, enemy.sight_range):
				enemy.active_in_combat = true
				directly_engaged.append(enemy)
				break

	for enemy in enemies:
		if enemy.active_in_combat:
			continue

		for player_node in active_players:
			if enemy.get_distance_to_entity(player_node) > 20:
				continue

			for engaged_enemy in directly_engaged:
				if enemy.has_line_of_sight_to_entity(engaged_enemy, enemy.sight_range):
					enemy.active_in_combat = true
					break

			if enemy.active_in_combat:
				break

## Returns all enemies currently active in combat.
func get_active_enemies() -> Array:
	var out := []

	for enemy in enemies:
		if enemy.active_in_combat:
			out.append(enemy)

	return out

## Ends combat if no active enemies remain.
func check_for_combat_end() -> void:
	if not Globals.in_combat:
		return

	recalculate_active_enemies()

	if get_active_enemies().is_empty():
		exit_combat()

## Ends the player turn, runs enemy turns, and restores player control.
func end_turn() -> void:
	Globals.send_to_game_log("Ending turn")

	if not Globals.in_combat:
		return

	if enemy_turn_running:
		return

	enemy_turn_running = true

	for player_node in get_living_players():
		player_node.move_state = player_node.MoveState.IN_MENU
		player_node.hide_attack_range()
		player_node.hide_spaces()

	set_combat_ui_visible(false)

	var ordered_enemies := get_active_enemies()
	ordered_enemies.sort_custom(_sort_enemies_for_turn)

	for enemy in ordered_enemies:
		if not is_instance_valid(enemy):
			continue

		attach_camera_to(enemy)
		await enemy.take_turn()
		recalculate_active_enemies()

		if get_active_enemies().is_empty():
			break

	attach_camera_to(Globals.active_player)

	for player_node in get_living_players():
		player_node.reset_turn_resources()
		player_node.move_state = player_node.MoveState.IDLE

	enemy_turn_running = false

	if get_active_enemies().is_empty():
		exit_combat()
	else:
		set_combat_ui_visible(true)
		if Globals.active_player:
			Globals.active_player._update_combat_ui()

#endregion


#region Camera and UI

## Reparents and centers the active camera on the given target.
func attach_camera_to(target: Node2D) -> void:
	if target == null:
		return

	if Globals.active_camera == null:
		return

	var old_global := Globals.active_camera.global_position

	if Globals.active_camera.get_parent() != target:
		Globals.active_camera.reparent(target)

	Globals.active_camera.global_position = old_global
	Globals.active_camera.position = Vector2.ZERO
	Globals.active_camera.enabled = true

## Shows or hides the combat UI based on combat state.
func set_combat_ui_visible(v: bool) -> void:
	if Globals.combat_ui:
		Globals.combat_ui.visible = Globals.in_combat and v

	if %ToggleUIButton:
		%ToggleUIButton.visible = Globals.in_combat

#endregion


#region Death and cleanup

## Removes and frees the given entity, then checks if combat should end.
func kill(ent: Node) -> void:
	entities.erase(ent)
	enemies.erase(ent)
	players.erase(ent)
	ent.queue_free()

	check_for_combat_end()

## Removes a player or shows game over if the last player is downed.
func kill_player(player_node) -> void:
	var was_active := (Globals.active_player == player_node) as bool

	if players.size() <= 1:
		if is_instance_valid(player_node):
			player_node.health = 0
			player_node.update_health_bar()

		Globals.active_canvas_layer.switch_menu("game_over")
		return

	entities.erase(player_node)
	players.erase(player_node)
	player_node.queue_free()

	if was_active:
		var ordered := get_party_members_in_order()
		if not ordered.is_empty():
			Globals.active_player = ordered[0]
			Globals.active_player.party_index = 0
			attach_camera_to(Globals.active_player)
			Globals.active_player.update_health_bar()
			Globals.active_player._update_combat_ui()

	check_for_combat_end()

## Restores living players to debug respawn state and refreshes UI.
func _on_respawn_button_pressed() -> void:
	var living_or_downed := get_living_players()

	if living_or_downed.is_empty():
		return

	for player_node in living_or_downed:
		player_node.max_health = 999
		player_node.health = player_node.max_health
		player_node.melee_damage = Vector2i(999, 999)
		player_node.ranged_damage = Vector2i(999, 999)

		player_node.reset_turn_resources()
		player_node.reset_combat_resources()
		player_node.movement_queue.clear()
		player_node.clear_follow_targets()
		player_node.sliding = false
		player_node.move_state = player_node.MoveState.IDLE
		player_node.target_position = player_node.position
		player_node.update_health_bar()

	if Globals.active_player == null or not is_instance_valid(Globals.active_player):
		var ordered := get_party_members_in_order()
		if not ordered.is_empty():
			Globals.active_player = ordered[0]

	reform_party_line()
	attach_camera_to(Globals.active_player)

	%GameOverMenu.visible = false

	if Globals.in_combat:
		set_combat_ui_visible(true)
	else:
		set_combat_ui_visible(false)

	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.update_health_bar()
		Globals.active_player._update_combat_ui()

#endregion


#region Combat UI routing

## Routes the melee button press to the active player.
func _on_melee_button_pressed() -> void:
	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.melee_action()

## Routes the ranged button press to the active player.
func _on_ranged_button_pressed() -> void:
	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.ranged_action()

## Routes the move button press to the active player.
func _on_move_button_pressed() -> void:
	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.move_action()

## Routes the defend button press to the active player.
func _on_defend_button_pressed() -> void:
	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.defend_action()

## Routes the heal button press to the active player.
func _on_heal_button_pressed() -> void:
	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.heal_action()

## Routes the special button press to the active player.
func _on_special_button_pressed() -> void:
	if Globals.active_player and is_instance_valid(Globals.active_player):
		Globals.active_player.special_action()

## Ends the current combat turn.
func _on_end_turn_button_pressed() -> void:
	end_turn()

## Cycles the active player to the next party member.
func _on_next_player_button_pressed() -> void:
	var ordered := get_party_members_in_order()
	if ordered.is_empty():
		return

	if Globals.active_player == null or Globals.active_player not in ordered:
		set_active_player(ordered[0])
		return

	var current_index := ordered.find(Globals.active_player)
	if current_index == -1:
		set_active_player(ordered[0])
		return

	var next_index := current_index + 1
	if next_index >= ordered.size():
		next_index = 0

	set_active_player(ordered[next_index])

## Toggles combat UI visibility.
func _on_toggle_ui_pressed() -> void:
	if %CombatUI == null:
		return

	set_combat_ui_visible(not %CombatUI.visible)

#endregion
