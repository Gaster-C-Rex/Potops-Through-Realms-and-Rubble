# player.gd
extends entity

@onready var potop_anim: AnimatedSprite2D = $PotopAnimated2D

const TILE_INDICATOR_SCENE := preload("res://scenes/UI/tile_indicator.tscn")

enum MoveState {
	IDLE,
	KEYBOARD,
	CLICK_TARGETING,
	CLICK_MOVING,
	ATTACK_TARGETING,
	IN_MENU
}

var player_type = "regular"

var movement_tile_sprites: Array[Sprite2D] = []
var targeted_tiles: Array[Vector2i] = []
var targeted_tiles_sprites: Array[Sprite2D] = []
var current_attack_mode := "ranged"

var party_index := 0
var follow_targets: Array[Vector2i] = []

var stop_after_current_slide := false
var keyboard_input_locked := false
var move_state := MoveState.IDLE

#region Lifecycle

## Initializes the player state, archetype, and combat UI references.
func _ready() -> void:
	target_position = position


	load_ranged_archetype()
	has_heal = true
	has_defend = true
	has_special = true

	await get_tree().process_frame
	update_health_bar()
	_update_combat_ui()

	if Globals.combat_ui:
		Globals.combat_ui.visible = false
		
## Updates movement, input, attack preview, and combat trigger behavior each physics frame.
func _physics_process(delta: float) -> void:
	if Globals.in_combat:
		if self == Globals.active_player:
			match move_state:
				MoveState.IDLE:
					process_keyboard_input()
				MoveState.KEYBOARD:
					process_keyboard_input()
				MoveState.CLICK_TARGETING:
					pass
				MoveState.CLICK_MOVING:
					_process_click_move_queue()
				MoveState.ATTACK_TARGETING:
					update_attack_preview()
				MoveState.IN_MENU:
					pass

		process_sliding(delta, Callable(self, "_on_slide_finished"))
		return

	if self != Globals.active_player:
		process_follow_movement()
		process_sliding(delta, Callable(self, "_on_slide_finished"))
		return

	match move_state:
		MoveState.IDLE:
			process_keyboard_input()
		MoveState.KEYBOARD:
			process_keyboard_input()
		MoveState.CLICK_TARGETING:
			pass
		MoveState.CLICK_MOVING:
			_process_click_move_queue()
		MoveState.ATTACK_TARGETING:
			update_attack_preview()
		MoveState.IN_MENU:
			pass

	process_sliding(delta, Callable(self, "_on_slide_finished"))

	if not Globals.entity_manager.enemy_turn_running:
		Globals.entity_manager.check_for_combat_trigger()


## Finalizes movement state after a slide completes and checks for combat triggers when needed.
func _on_slide_finished() -> void:
	if stop_after_current_slide:
		stop_after_current_slide = false
		move_state = MoveState.IDLE
		keyboard_input_locked = true
		return

	if move_state == MoveState.KEYBOARD:
		move_state = MoveState.IDLE

	if self == Globals.active_player and not Globals.in_combat:
		Globals.entity_manager.check_for_combat_trigger()


#endregion


#region Input and control

## Handles left-click interaction for selecting or activating this player.
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if Globals.active_player != self:
		Globals.entity_manager.set_active_player(self)
		return

	start_click_targeting()

## Handles global mouse input for movement targeting, attack targeting, and cancellation.
func _unhandled_input(event: InputEvent) -> void:
	if self != Globals.active_player:
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	if Globals.entity_manager.enemy_turn_running:
		return

	var mouse_tile_pos := Globals.get_tile_pos(get_global_mouse_position())
	var my_tile_pos := Globals.get_tile_pos(position)

	if event.button_index == MOUSE_BUTTON_RIGHT:
		match move_state:
			MoveState.CLICK_TARGETING:
				hide_spaces()
				move_state = MoveState.IDLE

				if Globals.in_combat:
					Globals.entity_manager.set_combat_ui_visible(true)

			MoveState.ATTACK_TARGETING:
				cancel_attack_targeting()

			MoveState.IDLE:
				if Globals.in_combat and mouse_tile_pos != my_tile_pos:
					start_attack_targeting("ranged")

	elif event.button_index == MOUSE_BUTTON_LEFT:
		match move_state:
			MoveState.CLICK_TARGETING:
				if not Globals.tile_in_bounds(mouse_tile_pos):
					hide_spaces()
					move_state = MoveState.IDLE

					if Globals.in_combat:
						Globals.entity_manager.set_combat_ui_visible(true)

					return

				if Globals.in_combat:
					var combat_path := pathfind_to_reachable_space(mouse_tile_pos)

					if combat_path.is_empty():
						hide_spaces()
						move_state = MoveState.IDLE
						Globals.send_to_game_log("Destination Unreachable")
						Globals.entity_manager.set_combat_ui_visible(true)
						return

					if not spend_movement(combat_path.size()):
						hide_spaces()
						move_state = MoveState.IDLE
						Globals.send_to_game_log("Destination Unreachable")
						Globals.entity_manager.set_combat_ui_visible(true)
						return

					hide_spaces()
					follow_path(combat_path)
					move_state = MoveState.CLICK_MOVING
					Globals.entity_manager.set_combat_ui_visible(false)
					_update_combat_ui()
					return

				hide_spaces()
				var path := pathfind_to_space(mouse_tile_pos)

				if path.is_empty():
					move_state = MoveState.IDLE
				else:
					follow_path(path)
					move_state = MoveState.CLICK_MOVING

			MoveState.ATTACK_TARGETING:
				perform_attack()

## Processes keyboard movement input for the active player and spends movement in combat.
func process_keyboard_input() -> void:
	if self != Globals.active_player:
		return

	if keyboard_input_locked:
		if is_any_move_key_held():
			return
		keyboard_input_locked = false

	if sliding:
		return

	if Globals.entity_manager.enemy_turn_running:
		return

	if Globals.in_combat and get_total_movement_remaining() <= 0:
		return

	var direction := Vector2i.ZERO

	if Input.is_action_pressed("move_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("move_down"):
		direction = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"):
		direction = Vector2i.RIGHT

	if direction == Vector2i.ZERO:
		return

	var current_tile := Globals.get_tile_pos(position)
	var target_tile := current_tile + direction
	var obstacles: TileMapLayer = Globals.get_map_layer(Globals.active_map, "obstacles")

	if not walkable(target_tile, obstacles):
		return

	if Globals.in_combat:
		if not spend_movement(1):
			return

	start_slide_to_tile(target_tile)
	move_state = MoveState.KEYBOARD
	_update_combat_ui()

## Queues follower movement when the active player begins a step outside combat.
func on_step_started(previous_tile: Vector2i, _next_tile: Vector2i) -> void:
	if Globals.in_combat:
		return

	if self != Globals.active_player:
		return

	Globals.entity_manager.queue_party_follow_step(previous_tile)


## Advances queued follower movement for inactive party members outside combat.
func process_follow_movement() -> void:
	if Globals.in_combat:
		return

	if self == Globals.active_player:
		return

	if sliding:
		return

	if follow_targets.is_empty():
		return

	var target_tile: Vector2i = follow_targets[0]
	var my_tile := Globals.get_tile_pos(position)

	if target_tile == my_tile:
		follow_targets.pop_front()
		return

	var path := pathfind_to_space(target_tile)

	if path.is_empty():
		follow_targets.pop_front()
		return

	follow_targets.pop_front()
	follow_path(path)
	process_movement_queue()
	
## Clears all pending follower target tiles for this player.
func clear_follow_targets() -> void:
	follow_targets.clear()

## Resets movement and targeting state when combat begins.
func reset_movement_state_for_combat() -> void:
	movement_queue.clear()
	clear_follow_targets()
	stop_after_current_slide = false
	move_state = MoveState.IDLE

	if not sliding:
		target_position = position

## Processes queued click movement until the path is exhausted.
func _process_click_move_queue() -> void:
	if sliding:
		return

	if movement_queue.is_empty():
		move_state = MoveState.IDLE

		if Globals.in_combat:
			Globals.entity_manager.set_combat_ui_visible(true)

		_update_combat_ui()
		return

	process_movement_queue()

## Enters click targeting mode and shows movement range when appropriate.
func start_click_targeting() -> void:
	if self != Globals.active_player:
		return

	if move_state != MoveState.IDLE:
		return

	if Globals.in_combat and get_total_movement_remaining() <= 0:
		Globals.send_to_game_log("No movement left")
		return

	if Globals.in_combat:
		show_movement_range()

	if Globals.tile_selector:
		Globals.tile_selector.visible = true

	move_state = MoveState.CLICK_TARGETING

## Hides all movement targeting visuals.
func hide_spaces() -> void:
	if Globals.tile_selector:
		Globals.tile_selector.visible = false

	hide_movement_range()

## Interrupts current movement state so combat can begin cleanly.
func interrupt_movement_for_combat() -> void:
	movement_queue.clear()
	clear_follow_targets()
	hide_spaces()

	keyboard_input_locked = true

	if sliding:
		stop_after_current_slide = true
	else:
		move_state = MoveState.IDLE
		target_position = position

## Returns true if any movement key is currently held.
func is_any_move_key_held() -> bool:
	return (
		Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
		or Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
	)

#endregion


#region Combat UI

## Formats a colored outlined count string for combat UI labels.
func _format_count(count: int, color: String) -> String:
	return "[outline_size=6][outline_color=black][color=%s]%s[/color][/outline_color][/outline_size]" % [
		color,
		count
	]

## Refreshes the active player's combat UI counts and health display.
func _update_combat_ui() -> void:
	if self != Globals.active_player:
		return

	if not Globals.combat_ui:
		return

	var attacks_remaining := get_attacks_remaining()

	var move_count := 0
	var move_color := "red"

	var free_remaining := get_free_movement_remaining()
	var paid_remaining := get_paid_movement_remaining()

	if free_remaining > 0:
		move_count = free_remaining
		move_color = "green"
	elif paid_remaining > 0:
		move_count = paid_remaining
		move_color = "blue"

	var defend_count := 0
	var defend_color := "red"

	if has_defend:
		if get_bonus_actions_remaining() > 0:
			defend_count = get_bonus_actions_remaining()
			defend_color = "green"
		elif get_attacks_remaining() > 0:
			defend_count = get_attacks_remaining()
			defend_color = "yellow"

	var heal_count := 0
	var heal_color := "red"

	if has_heal:
		if get_bonus_actions_remaining() > 0:
			heal_count = get_bonus_actions_remaining()
			heal_color = "green"
		elif get_attacks_remaining() > 0:
			heal_count = get_attacks_remaining()
			heal_color = "yellow"

	var melee_color := "red"
	if attacks_remaining > 0 and has_melee:
		melee_color = "green"

	var ranged_color := "red"
	if attacks_remaining > 0 and has_ranged:
		ranged_color = "green"

	Globals.melee_attack_count.text = _format_count(attacks_remaining, melee_color)
	Globals.ranged_attack_count.text = _format_count(attacks_remaining, ranged_color)
	Globals.move_count.text = _format_count(move_count, move_color)
	Globals.defend_count.text = _format_count(defend_count, defend_color)
	Globals.heal_count.text = _format_count(heal_count, heal_color)

	if Globals.special_count:
		var special_color := "red"
		if can_use_special():
			special_color = "green"

		Globals.special_count.text = _format_count(get_special_remaining(), special_color)

	update_health_bar()

#endregion


#region Combat buttons

## Starts melee attack targeting for the active player.
func melee_action() -> void:
	start_attack_targeting("melee")

## Starts ranged attack targeting for the active player.
func ranged_action() -> void:
	start_attack_targeting("ranged")

## Starts movement targeting from the combat UI.
func move_action() -> void:
	if self != Globals.active_player:
		return

	if move_state != MoveState.IDLE:
		return

	if Globals.in_combat and get_total_movement_remaining() <= 0:
		Globals.send_to_game_log("No movement left")
		return

	start_click_targeting()

	if Globals.in_combat and move_state == MoveState.CLICK_TARGETING:
		Globals.entity_manager.set_combat_ui_visible(false)

## Uses the defend action and refreshes the combat UI on success.
func defend_action() -> void:
	if defend():
		_update_combat_ui()

## Uses the heal action and refreshes the combat UI on success.
func heal_action() -> void:
	if heal_self():
		_update_combat_ui()

## Executes the player's special behavior or begins special targeting.
func special_action() -> void:
	match player_type:
		"regular":
			start_attack_targeting("special")
		"_":
			add_temp_bonus_action(2)

#endregion


#region Attack targeting / previews

## Spawns red tile indicators for the currently targeted attack tiles.
func _show_targeted_tiles() -> void:
	for tile in targeted_tiles:
		var tile_indicator = TILE_INDICATOR_SCENE.instantiate()
		tile_indicator.set_type("red")
		tile_indicator.position = Globals.get_tile_center(tile, "tile")
		Globals.active_map.add_child(tile_indicator)
		targeted_tiles_sprites.append(tile_indicator)

## Removes all attack preview indicators and clears targeted tile data.
func hide_attack_range() -> void:
	for tile_indicator in targeted_tiles_sprites:
		tile_indicator.queue_free()

	targeted_tiles.clear()
	targeted_tiles_sprites.clear()

## Enters attack targeting mode for the specified attack if it is usable.
func start_attack_targeting(attack_name: String = "ranged") -> void:
	if self != Globals.active_player:
		return

	if move_state != MoveState.IDLE:
		return

	if sliding:
		return

	if Globals.entity_manager.enemy_turn_running:
		return

	if not can_use_attack(attack_name):
		Globals.send_to_game_log("No attacks left")
		return

	var my_tile := Globals.get_tile_pos(position)
	var mouse_tile := Globals.get_tile_pos(get_global_mouse_position())

	if mouse_tile == my_tile:
		return

	current_attack_mode = attack_name
	hide_spaces()
	hide_attack_range()
	Globals.entity_manager.set_combat_ui_visible(false)
	move_state = MoveState.ATTACK_TARGETING
	update_attack_preview()

## Cancels attack targeting mode and restores combat UI visibility.
func cancel_attack_targeting() -> void:
	hide_attack_range()
	move_state = MoveState.IDLE

	if Globals.in_combat:
		Globals.entity_manager.set_combat_ui_visible(true)

## Recomputes the targeted tiles based on the mouse cursor and current attack mode.
func update_attack_preview() -> void:
	hide_attack_range()

	var tile_pos := Globals.get_tile_pos(position)
	var mouse_tile_pos := Globals.get_tile_pos(get_global_mouse_position())

	targeted_tiles = get_attack_affected_tiles(tile_pos, mouse_tile_pos, current_attack_mode)
	_show_targeted_tiles()

## Resolves the current attack against targeted tiles and updates combat state.
func perform_attack() -> void:
	if not can_use_attack(current_attack_mode):
		Globals.send_to_game_log("No attacks left")
		cancel_attack_targeting()
		return

	if current_attack_mode == "special":
		if not spend_special():
			Globals.send_to_game_log("No specials left")
			cancel_attack_targeting()
			return

		var special_targets := apply_attack_to_targets(targeted_tiles, "special")

		if special_targets.is_empty():
			Globals.send_to_game_log("Special hit nothing")
		else:
			for ent in special_targets:
				if ent in Globals.entity_manager.enemies:
					Globals.entity_manager.enter_combat(ent)

		hide_attack_range()
		move_state = MoveState.IDLE

		if Globals.in_combat:
			Globals.entity_manager.set_combat_ui_visible(true)

		Globals.entity_manager.recalculate_active_enemies()
		_update_combat_ui()
		Globals.entity_manager.check_for_combat_end()
		return

	var attacked_entities := apply_attack_to_targets(targeted_tiles, current_attack_mode)

	if attacked_entities.is_empty():
		Globals.send_to_game_log("Attack hit nothing")
	else:
		spend_attack()

		for ent in attacked_entities:
			if ent in Globals.entity_manager.enemies:
				Globals.entity_manager.enter_combat(ent)

	hide_attack_range()
	move_state = MoveState.IDLE

	if Globals.in_combat:
		Globals.entity_manager.set_combat_ui_visible(true)

	Globals.entity_manager.recalculate_active_enemies()
	_update_combat_ui()
	Globals.entity_manager.check_for_combat_end()

#endregion


#region Movement preview

## Shows movement indicators for reachable, paid, and unreachable tiles in combat.
func show_movement_range() -> void:
	hide_movement_range()

	var start_tile := Globals.get_tile_pos(position)
	var move_data := get_combat_movement_data()

	reachable_tiles = move_data.distances
	movement_came_from = move_data.came_from

	var free_remaining := get_free_movement_remaining()
	var total_remaining := get_total_movement_remaining()
	var candidate_tiles := get_tiles_in_movement_radius(start_tile, total_remaining)

	for tile in candidate_tiles:
		if tile == start_tile:
			continue

		if reachable_tiles.has(tile):
			var dist: int = reachable_tiles[tile]

			if dist <= free_remaining:
				_add_movement_indicator(tile, "green")
			else:
				_add_movement_indicator(tile, "blue")
		else:
			_add_movement_indicator(tile, "red")

## Creates and displays a movement indicator tile with the given color type.
func _add_movement_indicator(tile: Vector2i, indicator_type: String) -> void:
	var tile_indicator = TILE_INDICATOR_SCENE.instantiate()
	tile_indicator.set_type(indicator_type)
	tile_indicator.position = Globals.get_tile_center(tile, "tile")
	Globals.active_map.add_child(tile_indicator)
	movement_tile_sprites.append(tile_indicator)

## Removes all movement preview indicators and cached pathfinding data.
func hide_movement_range() -> void:
	for tile_indicator in movement_tile_sprites:
		tile_indicator.queue_free()

	movement_tile_sprites.clear()
	reachable_tiles.clear()
	movement_came_from.clear()

#endregion


#region Debug

## Cycles the ranged attack type enum for debugging.
func _on_cycle_attack_button_pressed() -> void:
	if ranged_attack_type < AttackType.size() - 1:
		ranged_attack_type += 1
	else:
		ranged_attack_type = 0

	Globals.send_to_game_log("Ranged attack type is now %s" % AttackType.keys()[ranged_attack_type])

## Toggles the current debug attack mode between ranged and melee.
func _on_change_attack_button_pressed() -> void:
	if current_attack_mode == "ranged":
		current_attack_mode = "melee"
	else:
		current_attack_mode = "ranged"

	Globals.send_to_game_log("Switched attack mode to " + current_attack_mode)

## Updates melee and ranged pierce values from the debug spin box.
func _on_pierce_spin_box_value_changed(value: float) -> void:
	melee_attack_pierce = int(value)
	ranged_attack_pierce = int(value)
	Globals.send_to_game_log("Set pierce to %s" % int(value))

## Updates melee and ranged range values from the debug spin box.
func _on_width_spin_box_value_changed(value: float) -> void:
	ranged_range = int(value)
	melee_range = int(value)
	Globals.send_to_game_log("Set attack range to %s" % int(value))

## Applies debug respawn stats and hides the game over menu.
func _on_respawn_button_pressed() -> void:
	health = 999
	max_health = 999
	ranged_damage = Vector2i(999, 999)
	melee_damage = Vector2i(999, 999)
	update_health_bar()
	Globals.active_canvas_layer.hide_menu("game_over")

#endregion
