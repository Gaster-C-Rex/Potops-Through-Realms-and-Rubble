extends Node2D

# Constants
const combat_speed := 4 # How many tiles the character is allowed to move in combat
const slide_speed := 300 # Speed of travel to the next tile
const type := "default" # What potop variant the player is

# Movement
var target_position = Vector2.ZERO # Where the character heads
var sliding := false # A Check to see if it's already moving

var spaces_moved_this_turn := 0 # How many spaces this unit has moved this turn (relevant in combat)
# Movement stack (LIFO)
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
	var target_tile := current_tile + direction

	# Only move if the target tile is within bounds
	if Globals.tile_in_bounds(target_tile):
		target_position += direction * Globals.TILE_SIZE
		sliding = true
		move_state = MoveState.KEYBOARD

func process_movement_queue():
	if sliding:
		return

	if movement_queue.is_empty():
		move_state = MoveState.IDLE
		return
	var move: String = movement_queue.pop_back()
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
		show_allowed_spaces()
	%TileSelector.visible = true
	move_state = MoveState.CLICK_TARGETING


## Shows which spaces this unit is allowed to move to based off of speed. Also
## populates the array of allowed space locations.
func show_allowed_spaces() -> void:
	if Globals.in_combat == false:
		# Use combat speed
		pass
	else:
		# Use unlimited speed (unless interrupted)
		pass

## Hides the shown spaces and clears the allowed locations array
func hide_spaces() -> void:
	%TileSelector.visible = false

## Populates the movement stack with instructions to tile_pos. Currently assumes
## that all tiles are walkable except for those outside the map.
func pathfind_to_space(tile_pos: Vector2) -> void:
	var current := Globals.get_tile_pos(position)
	if !Globals.tile_in_bounds(tile_pos):
		# Should never be possible anyways as we ignore this in the input stage
		return
	
	# Figure out how much we need to move in each direction
	var x_dif := int(tile_pos.x - current.x)
	var y_dif := int(tile_pos.y - current.y)
	
	# Figure out which way we are moving
	var horiz := "right" if x_dif > 0 else "left"
	var vert := "down" if y_dif > 0 else "up"
	
	# Now that we know which way we are moving, make the values positive
	x_dif = abs(x_dif)
	y_dif = abs(y_dif)
	
	# Alternate between resolving the x and y dif to create diaganol movement
	var toggle := true
	
	# Calculate moves while there is still distance remaining
	while x_dif > 0 or y_dif > 0:
		if toggle and y_dif > 0:
			movement_queue.append(vert)
			y_dif -= 1
		elif x_dif > 0:
			movement_queue.append(horiz)
			x_dif -= 1
		elif y_dif > 0:
			movement_queue.append(vert)
			y_dif -= 1
		
		toggle = !toggle


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
