extends CharacterBody2D

@export var speed = 100 # Speed of travel to the next tile
@export var grid_size = 32 # the size of the tiles of the plane
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
		position = position.move_toward(target_position, speed * delta)
		# Check to see if its close enough to stop and snap position
		if position.distance_to(target_position) < speed * delta:
			position = target_position
			moving = false
			
