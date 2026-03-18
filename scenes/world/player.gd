extends entity

# Preloads
const TILE_INDICATOR_SCENE := preload("res://scenes/UI/tile_indicator.tscn")

# Constants
const slide_speed := 300 # Speed of travel to the next tile
# To simplify pathfinding
const CARDINAL_DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

# Movement
var target_position = Vector2.ZERO # Where the character heads
var sliding := false # A Check to see if it's already moving
var movement_tile_sprites: Array[Sprite2D] = [] # Holds the red green or blue indicator sprites
var reachable_tiles := {} # tile: distance
var movement_came_from := {} # tile: previous tile
var movement_points_left := 0 # How many spaces we are still allowed to move (based off of speed)
var queued_movement_cost := 0 # How many spaces our currently queued movement costs
#_physics_process executes movement from here while not in keyboard mode.
# keyboard movement checks that this is empty before attempting to move.
var movement_queue := [] 

# Combat
var targeted_tiles: Array[Vector2i] = [] # A list of tile positions. Each position represents one attack.
var targeted_tiles_sprites: Array[Sprite2D] = [] # An array of the colored indicator sprites
var current_attack_mode := "ranged" # Can only ever be "ranged" or "melee"

# State machine
enum MoveState {
	IDLE, # Unit standing still and selectable
	KEYBOARD, # Unit being controlled by keyboard
	CLICK_TARGETING, # Unit selected and waiting for click destination
	CLICK_MOVING, # Following movement queue
	ATTACK_TARGETING, # Awaiting attack input
	IN_MENU # Inside a pause menu, ignore input
}

# Current state
var move_state := MoveState.IDLE

func _ready() -> void:
	target_position = position # Not moving
	movement_points_left = speed  # For combat movement
	Globals.active_player = self # For now, when there are more this will be
	load_data() # Pre defined data. Will load from JSON in the future.
	# determined by spawning order in the characters select menu

# Called every physics frame
func _physics_process(delta):
	match move_state:
		MoveState.IDLE:
			process_keyboard_input()
		MoveState.KEYBOARD:
			process_keyboard_input()
		MoveState.CLICK_TARGETING:
			pass
		MoveState.CLICK_MOVING:
			process_movement_queue()
		MoveState.ATTACK_TARGETING:
			update_attack_preview()
		MoveState.IN_MENU:
			pass
	
	# What's actually shifting the player sprite
	process_sliding(delta)

# Predefined default attack data; will be loaded from JSON in the future
func load_data():
	ranged_range = 6
	ranged_attack_type = AttackType.LINE

## Handles keyboard movement input, moves one tile per key press if possible.
## In combat, consumes 1 movement point per tile. Prevents movement if no points remain
func process_keyboard_input():
	if sliding:
		return

	if Globals.in_combat and movement_points_left <= 0:
		return

	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		direction = Vector2.UP
	elif Input.is_action_pressed("move_down"):
		direction = Vector2.DOWN
	elif Input.is_action_pressed("move_left"):
		direction = Vector2.LEFT
	elif Input.is_action_pressed("move_right"):
		direction = Vector2.RIGHT

	if direction == Vector2.ZERO:
		return

	var current_tile := Globals.get_tile_pos(position) as Vector2i
	var target_tile := current_tile + Vector2i(direction)

	if walkable(target_tile, Globals.get_map_layer(Globals.active_map, "obstacles")):
		target_position += direction * Globals.TILE_SIZE
		sliding = true
		move_state = MoveState.KEYBOARD

		if Globals.in_combat:
			movement_points_left -= 1
			movement_points_left = maxi(movement_points_left, 0)

func process_movement_queue() -> void:
	if sliding:
		return

	if movement_queue.is_empty():
		if Globals.in_combat and queued_movement_cost > 0:
			movement_points_left -= queued_movement_cost
			movement_points_left = maxi(movement_points_left, 0)
			queued_movement_cost = 0

		move_state = MoveState.IDLE
		return

	var move: String = movement_queue.pop_front()
	var direction := Vector2.ZERO
	match move:
		"up":
			direction = Vector2.UP
		"down":
			direction = Vector2.DOWN
		"left":
			direction = Vector2.LEFT
		"right":
			direction = Vector2.RIGHT

	target_position += direction * Globals.TILE_SIZE
	sliding = true

func process_sliding(delta):
	if not sliding:
		return

	position = position.move_toward(target_position, slide_speed * delta)
	if position.distance_to(target_position) < slide_speed * delta:
		position = target_position
		sliding = false
		if move_state == MoveState.KEYBOARD:
			move_state = MoveState.IDLE

## When the player is clicked...
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			start_click_targeting()

func start_click_targeting():
	if move_state != MoveState.IDLE:
		return

	if Globals.in_combat and movement_points_left <= 0:
		Globals.send_to_game_log("No movement left")
		return

	if Globals.in_combat:
		show_movement_range()

	%TileSelector.visible = true
	move_state = MoveState.CLICK_TARGETING

## Hides the tile selector, illegal tiles, and range tiles.
func hide_spaces() -> void:
	%TileSelector.visible = false
	hide_movement_range()

## Generates a path to a target tile using BFS and populates movement_queue with movement steps.
## target_tile_pos: Destination tile. ignore_obstacles: If true, ignores tilemap obstacles
## If no path is found, prints "Destination Unreachable" to the game log.
func pathfind_to_space(target_tile_pos: Vector2i, ignore_obstacles: bool = false) -> void:
	var obstacles: TileMapLayer = null
	if not ignore_obstacles:
		obstacles = Globals.get_map_layer(Globals.active_map, "obstacles")

	var start_tile_pos := Globals.get_tile_pos(position)
	var current := start_tile_pos

	var explored = [current]
	var came_from := {}
	var queue: Array[Vector2i] = []

	while current != target_tile_pos:
		for direction in CARDINAL_DIRECTIONS:
			var neighbor := current + direction as Vector2i
			if neighbor not in explored and walkable(neighbor, obstacles):
				queue.push_back(neighbor)
				explored.push_back(neighbor)
				came_from[neighbor] = current

		if queue.is_empty():
			Globals.send_to_game_log("Destination Unreachable")
			return

		current = queue.pop_front()
	movement_queue = _build_path_from_came_from(start_tile_pos, target_tile_pos, came_from)
	
## Check if a tile position is walkable (ie not an obstacle or enemy and in bounds)
func walkable(tile_pos: Vector2i, obstacles: TileMapLayer) -> bool:
	if not Globals.tile_in_bounds(tile_pos):
		return false
	if obstacles and obstacles.get_cell_source_id(tile_pos) != -1:
		return false
	if _tile_has_blocking_entity(tile_pos):
		return false

	return true

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var mouse_tile_pos := Globals.get_tile_pos(get_global_mouse_position()) as Vector2i
	var my_tile_pos := Globals.get_tile_pos(position) as Vector2i

	if event.button_index == MOUSE_BUTTON_RIGHT:
		match move_state:
			MoveState.CLICK_TARGETING:
				hide_spaces()
				move_state = MoveState.IDLE
			MoveState.ATTACK_TARGETING:
				cancel_attack_targeting()
			MoveState.IDLE:
				if mouse_tile_pos != my_tile_pos:
					start_attack_targeting("ranged")

	elif event.button_index == MOUSE_BUTTON_LEFT:
		match move_state:
			MoveState.CLICK_TARGETING:
				if not Globals.tile_in_bounds(mouse_tile_pos):
					hide_spaces()
					move_state = MoveState.IDLE
					return

				if not Globals.in_combat:
					pathfind_to_space(mouse_tile_pos)
					hide_spaces()
					if not movement_queue.is_empty():
						move_state = MoveState.CLICK_MOVING
					else:
						move_state = MoveState.IDLE
				else:
					var success := pathfind_to_reachable_space(mouse_tile_pos)
					hide_spaces()
					if success and not movement_queue.is_empty():
						move_state = MoveState.CLICK_MOVING
					else:
						move_state = MoveState.IDLE

			MoveState.ATTACK_TARGETING:
				perform_attack()

func show_melee_attack_range() -> void:
	var tile_pos = Globals.get_tile_pos(position)
	var mouse_tile_pos = Globals.get_tile_pos(get_global_mouse_position())
	targeted_tiles = get_attack_affected_tiles(tile_pos, mouse_tile_pos, "melee")
	_show_targeted_tiles()

func show_ranged_attack_range() -> void:
	var tile_pos = Globals.get_tile_pos(position)
	var mouse_tile_pos = Globals.get_tile_pos(get_global_mouse_position())
	targeted_tiles = get_attack_affected_tiles(tile_pos, mouse_tile_pos, "ranged")
	_show_targeted_tiles()

## Displays attack indicators on targeted tiles.
func _show_targeted_tiles() -> void:
	for tile in targeted_tiles:
		var tile_indicator = preload("res://scenes/UI/tile_indicator.tscn").instantiate()
		tile_indicator.set_type("red")
		tile_indicator.position = Globals.get_tile_center(tile, "tile")
		Globals.active_map.add_child(tile_indicator)
		targeted_tiles_sprites.append(tile_indicator)

## Clears all attack indicators.
func hide_attack_range():
	for tile_indicator in targeted_tiles_sprites:
		tile_indicator.queue_free()
	targeted_tiles.clear()
	targeted_tiles_sprites.clear()

## Starts attack targeting mode. Cancels movement UI and initializes attack preview.
## Does nothing if: Not in IDLE state, currently sliding, or clicking own tile
func start_attack_targeting(attack_name: String = "ranged") -> void:
	if move_state != MoveState.IDLE:
		return
	if sliding:
		return

	var my_tile := Globals.get_tile_pos(position) as Vector2i
	var mouse_tile := Globals.get_tile_pos(get_global_mouse_position()) as Vector2i
	if mouse_tile == my_tile:
		return

	current_attack_mode = attack_name
	hide_spaces()
	hide_attack_range()
	move_state = MoveState.ATTACK_TARGETING
	update_attack_preview()

## Cancels attack targeting and clears preview.
func cancel_attack_targeting() -> void:
	hide_attack_range()
	move_state = MoveState.IDLE

## Updates attack preview based on current mouse position.
## Recomputes affected tiles and redraws indicators.
func update_attack_preview() -> void:
	hide_attack_range()

	var tile_pos := Globals.get_tile_pos(position) as Vector2i
	var mouse_tile_pos := Globals.get_tile_pos(get_global_mouse_position()) as Vector2i
	targeted_tiles = get_attack_affected_tiles(tile_pos, mouse_tile_pos, current_attack_mode)
	_show_targeted_tiles()

## Beats the crap out of someone (anyone in attacked tiles)
func perform_attack() -> void:
	var attacked_entities := []

	for tile in targeted_tiles:
		for ent in Globals.entity_manager.entities:
			if ent == self:
				continue

			var ent_tile := Globals.get_tile_pos(ent.position)
			if ent_tile == tile:
				attacked_entities.append(ent)

	# Apply damage (duplicates in targeted_tiles = multiple hits)
	for ent in attacked_entities:
		match current_attack_mode:
			"melee":
				if ent.has_method("take_melee_damage"):
					ent.take_melee_damage(self)
			"ranged":
				if ent.has_method("take_ranged_damage"):
					ent.take_ranged_damage(self)

	print("attack with %s on %s" % [current_attack_mode, attacked_entities])

	hide_attack_range()
	move_state = MoveState.IDLE

## In case I ever add the player or entities that you can walk through later, I
## abstract through this function.
func _tile_has_blocking_entity(tile_pos: Vector2i) -> bool:
	for ent in Globals.entity_manager.entities:
		if ent == self:
			continue
		if Globals.get_tile_pos(ent.position) == tile_pos:
			return true
	return false

## Computes reachable tiles using BFS (combat movement).
## Returns a dictionary:
## {distances: {tile: distance from start},
## came_from: {tile: previous tile for path reconstruction}}
## Movement is limited by movement_points_left.
func _get_combat_movement_data() -> Dictionary:
	var obstacles: TileMapLayer = Globals.get_map_layer(Globals.active_map, "obstacles")
	var start_tile := Globals.get_tile_pos(position) as Vector2i
	var cardinal_directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	var distances := {}
	var came_from := {}
	var queue: Array[Vector2i] = []

	distances[start_tile] = 0
	queue.push_back(start_tile)

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_dist: int = distances[current]

		if current_dist >= movement_points_left:
			continue

		for direction in cardinal_directions:
			var neighbor := current + direction as Vector2i

			if neighbor in distances:
				continue

			if not walkable(neighbor, obstacles):
				continue

			distances[neighbor] = current_dist + 1
			came_from[neighbor] = current
			queue.push_back(neighbor)

	return {
		"distances": distances,
		"came_from": came_from,
	}

## Returns all tiles within a Manhattan radius.
## Used for previewing movement range regardless of obstacles.
func _get_tiles_in_movement_radius(center: Vector2i, move_range: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	for x in range(-move_range, move_range + 1):
		for y in range(-move_range, move_range + 1):
			var offset := Vector2i(x, y)
			if abs(offset.x) + abs(offset.y) <= move_range:
				var tile := center + offset
				if Globals.tile_in_bounds(tile):
					tiles.append(tile)

	return tiles

## Displays tile indicators for movement range.
## Green means good. Blue means on the border. Red means invalid.
func show_movement_range() -> void:
	hide_movement_range()

	var start_tile := Globals.get_tile_pos(position) as Vector2i
	var move_data := _get_combat_movement_data()
	reachable_tiles = move_data.distances
	movement_came_from = move_data.came_from


	var candidate_tiles := _get_tiles_in_movement_radius(start_tile, movement_points_left)

	for tile in candidate_tiles:
		if tile == start_tile:
			continue

		if tile in reachable_tiles:
			var dist: int = reachable_tiles[tile]
			if dist == movement_points_left:
				_add_movement_indicator(tile, "blue")
			else:
				_add_movement_indicator(tile, "green")
		else:
			_add_movement_indicator(tile, "red")

## Removes all movement indicators and clears cached data.
func _add_movement_indicator(tile: Vector2i, indicator_type: String) -> void:
	var tile_indicator = TILE_INDICATOR_SCENE.instantiate()
	tile_indicator.set_type(indicator_type)
	tile_indicator.position = Globals.get_tile_center(tile, "tile")
	Globals.active_map.add_child(tile_indicator)
	movement_tile_sprites.append(tile_indicator)

## Removes all movement indicators and clears cached data.
func hide_movement_range() -> void:
	for tile_indicator in movement_tile_sprites:
		tile_indicator.queue_free()
	movement_tile_sprites.clear()

	reachable_tiles.clear()
	movement_came_from.clear()

## Attempts to build a movement path to a tile for generating movement hints.
## Returns true if a valid path was generated. Checks that movement would not
## expend too many movement points or target an unreachable tile.
func pathfind_to_reachable_space(target_tile_pos: Vector2i) -> bool:
	movement_queue.clear()
	queued_movement_cost = 0
	if not reachable_tiles.has(target_tile_pos):
		Globals.send_to_game_log("Destination Unreachable")
		return false
	var start_tile_pos := Globals.get_tile_pos(position)
	var path := _build_path_from_came_from(start_tile_pos, target_tile_pos, movement_came_from)
	if path.is_empty() and target_tile_pos != start_tile_pos:
		return false
	if path.size() > movement_points_left:
		Globals.send_to_game_log("Not enough movement")
		return false
	movement_queue = path
	queued_movement_cost = path.size()
	return true

## Will be further implemented when turns are a thing
func reset_movement_for_turn() -> void:
	movement_points_left = speed

## Temporary debug attack cycler
func _on_cycle_attack_button_pressed() -> void:
	if ranged_attack_type < AttackType.size() - 1:
		ranged_attack_type += 1 as AttackType 
	else:
		ranged_attack_type = 0 as AttackType

## Converts a movement vector into a human readable direction string for the
## movement queue parser. "This could've been an enum!" - my coworkers, probably
func _direction_to_string(dir: Vector2i) -> String:
	match dir:
		Vector2i(1, 0):
			return "right"
		Vector2i(-1, 0):
			return "left"
		Vector2i(0, 1):
			return "down"
		Vector2i(0, -1):
			return "up"
		_:
			return ""

## Reconstructs a movement path from a BFS came_from map.
## Returns an array of direction strings ("up", "down", etc.).
## If the path is broken (missing came_from entries), returns an empty array.
func _build_path_from_came_from(
		start_tile_pos: Vector2i,
		target_tile_pos: Vector2i,
		came_from: Dictionary
	) -> Array[String]:
	var current := target_tile_pos
	var path: Array[String] = []

	while current != start_tile_pos:
		if not came_from.has(current):
			return []
		var previous: Vector2i = came_from[current]
		var dir := current - previous
		var dir_string := _direction_to_string(dir)
		if dir_string == "":
			return []
		path.push_back(dir_string)
		current = previous
	path.reverse()
	return path
