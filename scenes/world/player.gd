extends Node2D

# Constants
const combat_speed := 4 # How many tiles the character is allowed to move in combat
const slide_speed := 300 # Speed of travel to the next tile
const type := "default" # What potop variant the player is

# Movement
var target_position = Vector2.ZERO # Where the character heads
var sliding := false # A Check to see if it's already moving

var spaces_moved_this_turn := 0 # How many spaces this unit has moved this turn (relevant in combat)
var valid_tiles = []
var invalid_tiles = []
var border_tiles = []
# Movement queue (FIFO)
#_physics_process executes movement from here while not in keyboard mode.
# keyboard movement checks that this is empty before attempting to move.
var movement_queue := [] 

# State machine
enum MoveState {
	IDLE, # Unit standing still and selectable
	KEYBOARD, # Unit being controlled by keyboard
	CLICK_TARGETING, # Unit selected and waiting for click destination
	CLICK_MOVING # Following movement queue
}

# Current state
var move_state := MoveState.IDLE

func _ready():
	# Starting Position of the target
	target_position = position
	
func _physics_process(delta):
	match move_state:
		MoveState.IDLE:
			process_keyboard_input()
		MoveState.KEYBOARD:
			process_keyboard_input()
		MoveState.CLICK_TARGETING:
			pass # Waiting for mouse click
		MoveState.CLICK_MOVING:
			process_movement_queue()

	process_sliding(delta)

func process_keyboard_input():
	if sliding:
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
	
	# Compute the tile the character would move to
	var current_tile := Globals.get_tile_pos(position)
	var target_tile := current_tile + Vector2i(direction)

	# Only move if the target tile is within bounds and walkable
	if walkable(target_tile, Globals.get_map_layer(Globals.active_map, "obstacles")):
		target_position += direction * Globals.TILE_SIZE
		sliding = true
		move_state = MoveState.KEYBOARD

func process_movement_queue():
	if sliding:
		return

	if movement_queue.is_empty():
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
		return # ignore clicks if moving
	if Globals.in_combat:
		show_movement_range()
	%TileSelector.visible = true
	move_state = MoveState.CLICK_TARGETING

## Shows which spaces this unit is allowed to move to based off of speed. Also
## populates the array of allowed space locations.
func show_movement_range() -> void:
	pass

func show_illegal_tiles() -> void:
	pass

## Hides the tile selector, illegal tiles, and range tiles.
func hide_spaces() -> void:
	%TileSelector.visible = false

## Generates a path to a tile location from this unit's current location
func pathfind_to_space(target_tile_pos: Vector2i, ignore_obstacles: bool = false) -> void:
	var obstacles: TileMapLayer
	if !ignore_obstacles:
		obstacles = Globals.get_map_layer(Globals.active_map, "obstacles")
	else:
		obstacles = null
	
	var start_tile_pos := Globals.get_tile_pos(position)
	var current := start_tile_pos
	var cardinal_directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	var explored = [current] # Don't explore a node if someone else found it faster
	var came_from = {} # Where each node came from, look them up in backwards order
	var queue = [] # First in first out
	
	while current != target_tile_pos:
		# Check 4 directions around position for walkable neighbors
		for direction in cardinal_directions:
			var neighbor = current + direction
			if neighbor not in explored and walkable(neighbor, obstacles):
				# Add every neighbor to the back of the queue
				queue.push_back(neighbor)
				explored.push_back(neighbor)
				# And remember that to find that neighbor we came from current
				came_from[neighbor] = current
		if queue.is_empty():
			print("Destination Unreachable")
			Globals.send_to_game_log("Destination Unreachable")
			return
		current = queue.pop_front() # Maybe a little slow but trivial on small scale
	# Arrived at target. Trace the path back, and add instructions to the queue.
	var path := []
	while current != start_tile_pos:
		# While generating, came_from was the previous location
		var dir = current - came_from[current]
		var dir_string: String
		match dir:
			Vector2i(1, 0):
				dir_string = "right"
			Vector2i(-1, 0):
				dir_string = "left"
			Vector2i(0, 1):
				dir_string = "down"
			Vector2i(0, -1):
				dir_string = "up"
		path.push_back(dir_string)
		current = came_from[current]
	# Reverse the array so that it is in the proper order
	path.reverse()
	movement_queue = path
	
## Check if a tile position is walkable (ie not an obstacle and in bounds)
func walkable(tile_pos: Vector2i, obstacles: TileMapLayer) -> bool:
	if !obstacles:
		return Globals.tile_in_bounds(tile_pos)
	else:
		return Globals.tile_in_bounds(tile_pos) and obstacles.get_cell_source_id(tile_pos) == -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Right click: cancel selection
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if move_state == MoveState.CLICK_TARGETING:
				hide_spaces()
				move_state = MoveState.IDLE
		# Left click: designate space to move to
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if move_state == MoveState.CLICK_TARGETING:
				var target_tile_pos := Globals.get_tile_pos(get_global_mouse_position())
				if Globals.tile_in_bounds(target_tile_pos):
					if !Globals.in_combat:
						# Generate movement queue and switch state
						pathfind_to_space(target_tile_pos)
						hide_spaces()
						move_state = MoveState.CLICK_MOVING
					else:
						print("combat movement not implemented")
