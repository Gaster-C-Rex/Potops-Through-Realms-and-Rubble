extends Node2D

class_name entity

var health := 10
var armor := 1 # Damage reduction per hit
var speed := 4 # Number of tiles this unit can move per turn
var has_melee := true
var melee_hits_flying := false
var melee_damage := Vector2i(1, 5) # 1-5 damage per hit
var melee_range := Melee_Range_Type.ONE_SQUARE
var has_ranged := false
var ranged_hits_flying := false
var attack_range := 4
var ranged_damage: Vector2i
var flying := false

enum Range_Attack_Type{ # Which tiles the attack targets
	TILE, # Hits only the selected tile
	LINE_PIERCE, # All tiles within line of length attack range
	LINE_SINGLE, # Hits the first target within line of length attack range
	LINE_PIERCE_REVERSE, # Starts from end of range and returns to attacker
	LINE_SINGLE_REVERSE, # Starts from end of range and hits first target
	BOOMERANG, # Pierces to range end and back again
	CIRCLE, # All tiles within euclidean distance of attack range
	ARC_45, # Stretches out to attack range and spreads 45 degrees
	ARC_90, # Stretches out to attack range and spreads 90 degrees
	SQUARE, # All tiles within square of radius attack range
	THICK_LINE, # 3 tile wide line of length attack range
}

enum Melee_Range_Type{ # Which tiles the attacker can reach
	ONE, # Only directly cardinally adjacent tiles
	ONE_SQUARE, # All adjacent tiles
	TWO, # Two in each cardinal direction and two in each diaganol
	#xoxox
	#oxxxo
	#xxPxx Looks like a star shape
	#oxxxo
	#xoxox
	TWO_SQUARE, # All adjacent tiles with radius of 2
}

enum Melee_Attack_Type{
	TILE, # Hits only the selected tile
	ALL, # Hits all tiles in range
	DIRECTIONAL, # Hits all tiles in a cardinal direction
}
