extends Node2D

@export var combat_speed = 4 # How many tiles the character is allowed to move in combat
@export var slide_speed = 100 # Speed of travel to the next tile
@export var grid_size = 32 # the size of the tiles of the plane
@export var type = "default" # What potop variant the player is

var target_position = Vector2.ZERO # Where the character heads
var moving = false # A Check to see if it's already moving

func _ready():
	# Starting Position of the target
	target_position = position
	
func _physics_process(delta):
	if not moving:
		var direction = Vector2.ZERO
		# Cardinal Directions
		if Input.is_action_pressed("move_up"):
			direction = Vector2.UP
		elif Input.is_action_pressed("move_down"):
			direction = Vector2.DOWN
		elif Input.is_action_pressed("move_left"):
			direction = Vector2.LEFT
		elif Input.is_action_pressed("move_right"):
			direction = Vector2.RIGHT
			
		if direction != Vector2.ZERO:
			# Updating target position based on direction + grid size
			target_position += direction * grid_size
			moving = true
			
	if moving:
		# Move the character to target position
		position = position.move_toward(target_position, slide_speed * delta)
		# Check to see if its close enough to stop and snap position
		if position.distance_to(target_position) < slide_speed * delta:
			position = target_position
			moving = false
			

## When the player is clicked...
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1: # left click
		show_allowed_spaces()

func show_allowed_spaces():
	if Globals.in_combat == false:
		# Use combat speed
		pass
	else:
		# Use unlimited speed (unless interrupted)
		pass
	print("Click based movement is not yet implemented!")
