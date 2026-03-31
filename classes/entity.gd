# entity.gd
extends Node2D
class_name entity

#region Constants

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

const SLIDE_SPEED := 300.0

#endregion


#region Enums

enum AttackType {
	TILE,
	LINE,
	LINE_REVERSE,
	BOOMERANG,
	ARC_45,
	ARC_90,
	ARC_180,
	CIRCLE,
	SQUARE,
}

#endregion


#region Stats

var max_health := 10
var health := 10
var armor := 1
var flying := false

var attacks_per_turn := 2
var bonus_actions_per_turn := 0
var speed := 4

var has_heal := false
var has_defend := false
var has_special := false
var specials_per_combat := 1

#endregion


#region Utility / AI
var readable_name = "unnamed"

var ai_type := "melee"
var sight_range := 6

var spawn_order := 0
var forced_engaged := false
var active_in_combat := false

#endregion


#region Shared movement state

var last_tile_pos := Vector2i.ZERO
var target_position := Vector2.ZERO
var sliding := false

var movement_queue: Array[Vector2i] = []

var reachable_tiles := {}
var movement_came_from := {}

#endregion


#region Combat data

var has_melee := true
var melee_range := 2
var melee_hits_flying := false
var melee_damage := Vector2i(1, 5)
var melee_attack_type := AttackType.TILE
var melee_attack_pierce := 0

var has_ranged := true
var ranged_range := 4
var ranged_hits_flying := true
var ranged_damage := Vector2i(1, 3)
var ranged_attack_type := AttackType.LINE
var ranged_attack_pierce := 1

var special_range := 6
var special_hits_flying := true
var special_damage := Vector2i(4, 8)
var special_attack_type := AttackType.ARC_45
var special_attack_pierce := 0

#endregion


#region Combat resources

var attacks_used := 0
var bonus_actions_used := 0
var tiles_moved := 0
var specials_used := 0
var paid_movement_bank := 0

var temp_attacks := 0
var temp_bonus_actions := 0
var temp_armor := 0

#endregion


#region Lifecycle

## Initializes cached tile position and health UI state.
func _ready() -> void:
	last_tile_pos = Globals.get_tile_pos(position)
	target_position = position
	update_health_bar()

#endregion


#region Archetypes

## Applies the default ranged archetype stats and combat options.
func load_ranged_archetype() -> void:
	attacks_per_turn = 2
	bonus_actions_per_turn = 0
	speed = 4
	has_special = false
	specials_per_combat = 1

	has_melee = true
	melee_range = 1
	melee_attack_type = AttackType.TILE
	melee_damage = Vector2i(1, 3)
	melee_attack_pierce = 1

	has_ranged = true
	ranged_range = 6
	ranged_attack_type = AttackType.LINE
	ranged_damage = Vector2i(1, 4)
	ranged_attack_pierce = 1

	has_heal = false
	has_defend = false
	ai_type = "ranged"

## Applies the default melee archetype stats and combat options.
func load_melee_archetype() -> void:
	attacks_per_turn = 2
	bonus_actions_per_turn = 0
	speed = 4
	has_special = false
	specials_per_combat = 1

	has_melee = true
	melee_range = 1
	melee_attack_type = AttackType.TILE
	melee_damage = Vector2i(2, 5)
	melee_attack_pierce = 1

	has_ranged = false
	ranged_range = 0
	ranged_attack_type = AttackType.TILE
	ranged_damage = Vector2i.ZERO
	ranged_attack_pierce = 0

	has_heal = false
	has_defend = false
	ai_type = "melee"

## Applies a ranged healer archetype variant.
func load_healer_archetype() -> void:
	load_ranged_archetype()
	bonus_actions_per_turn = 1
	has_heal = true
	has_defend = false

## Applies a melee defender archetype variant.
func load_defender_archetype() -> void:
	load_melee_archetype()
	bonus_actions_per_turn = 1
	has_heal = false
	has_defend = true

#endregion


#region Identity helpers

## Returns true if this entity is currently registered as a player.
func is_player_entity() -> bool:
	return Globals.entity_manager != null and self in Globals.entity_manager.players

## Returns true if this entity is currently registered as an enemy.
func is_enemy_entity() -> bool:
	return Globals.entity_manager != null and self in Globals.entity_manager.enemies

#endregion


#region Resource helpers

## Returns the number of attacks remaining this turn.
func get_attacks_remaining() -> int:
	return maxi(attacks_per_turn + temp_attacks - attacks_used, 0)

## Returns the number of bonus actions remaining this turn.
func get_bonus_actions_remaining() -> int:
	return maxi(bonus_actions_per_turn + temp_bonus_actions - bonus_actions_used, 0)

## Returns the number of special uses remaining this combat.
func get_special_remaining() -> int:
	return maxi(specials_per_combat - specials_used, 0)

## Returns the movement chunk size gained when paying with an attack.
func get_paid_movement_chunk_size() -> int:
	return maxi(speed / 2, 1)

## Returns remaining free movement tiles for this turn.
func get_free_movement_remaining() -> int:
	return maxi(speed - tiles_moved, 0)

## Returns remaining paid movement capacity including unused paid bank.
func get_paid_movement_remaining() -> int:
	return paid_movement_bank + get_attacks_remaining() * get_paid_movement_chunk_size()

## Returns total remaining movement capacity for this turn.
func get_total_movement_remaining() -> int:
	return get_free_movement_remaining() + get_paid_movement_remaining()

## Returns true if the named attack can currently be used.
func can_use_attack(attack_name: String) -> bool:
	match attack_name:
		"melee":
			return has_melee and get_attacks_remaining() > 0
		"ranged":
			return has_ranged and get_attacks_remaining() > 0
		"special":
			return can_use_special()

	return false

## Returns true if the named bonus ability can currently be used.
func can_use_bonus_ability(ability_name: String) -> bool:
	if ability_name == "defend" and not has_defend:
		return false

	if ability_name == "heal" and not has_heal:
		return false

	if get_bonus_actions_remaining() > 0:
		return true

	return get_attacks_remaining() > 0

## Returns true if the entity can currently use its special.
func can_use_special() -> bool:
	return has_special and get_special_remaining() > 0

## Spends one attack if available.
func spend_attack() -> bool:
	if get_attacks_remaining() <= 0:
		return false

	attacks_used += 1
	return true

## Spends a bonus action first, or an attack if no bonus actions remain.
func spend_bonus_or_attack() -> bool:
	if get_bonus_actions_remaining() > 0:
		bonus_actions_used += 1
		return true

	if get_attacks_remaining() > 0:
		attacks_used += 1
		return true

	return false

## Spends one special use if available.
func spend_special() -> bool:
	if not can_use_special():
		return false

	specials_used += 1
	return true

## Adds temporary attacks for the current turn.
func add_temp_attack(amount: int = 1) -> void:
	temp_attacks += amount

## Adds temporary bonus actions for the current turn.
func add_temp_bonus_action(amount: int = 1) -> void:
	temp_bonus_actions += amount

## Returns armor including temporary defend bonuses.
func get_effective_armor() -> int:
	return armor + temp_armor

## Returns true if the named attack can hit flying targets.
func attack_hits_flying(attack_name: String) -> bool:
	match attack_name:
		"melee":
			return melee_hits_flying
		"ranged":
			return ranged_hits_flying
		"special":
			return special_hits_flying

	return false

## Resets per-turn resources and temporary buffs.
func reset_turn_resources() -> void:
	attacks_used = 0
	bonus_actions_used = 0
	tiles_moved = 0
	paid_movement_bank = 0

	temp_attacks = 0
	temp_bonus_actions = 0
	temp_armor = 0

## Resets per-combat resources.
func reset_combat_resources() -> void:
	specials_used = 0

## Spends movement using free tiles first, then paid movement chunks.
func spend_movement(distance: int) -> bool:
	var remaining := distance

	var free_available := get_free_movement_remaining()
	var free_used := mini(remaining, free_available)
	tiles_moved += free_used
	remaining -= free_used

	while remaining > 0:
		if paid_movement_bank <= 0:
			if not spend_attack():
				return false
			paid_movement_bank += get_paid_movement_chunk_size()

		var paid_used := mini(remaining, paid_movement_bank)
		tiles_moved += paid_used
		paid_movement_bank -= paid_used
		remaining -= paid_used

	return true

#endregion


#region Shared movement / pathfinding

## Moves this entity toward its target position while sliding and calls an optional callback on finish.
func process_sliding(delta: float, on_finished: Callable = Callable()) -> void:
	if not sliding:
		return

	position = position.move_toward(target_position, SLIDE_SPEED * delta)

	if position.distance_to(target_position) < SLIDE_SPEED * delta:
		position = target_position
		sliding = false

		if on_finished.is_valid():
			on_finished.call()

## Starts the next queued movement step if not already sliding.
func process_movement_queue() -> void:
	if sliding:
		return

	if movement_queue.is_empty():
		return

	var next_tile: Vector2i = movement_queue.pop_front()
	start_slide_to_tile(next_tile)

## Begins sliding to the specified tile and records the previous tile.
func start_slide_to_tile(next_tile: Vector2i) -> void:
	var previous_tile := Globals.get_tile_pos(position)
	last_tile_pos = previous_tile

	on_step_started(previous_tile, next_tile)

	target_position = Globals.get_tile_center(next_tile, "tile")
	sliding = true

## Hook called when a movement step begins.
func on_step_started(_previous_tile: Vector2i, _next_tile: Vector2i) -> void:
	pass

## Returns true if the tile is in bounds, not blocked by obstacles, and not occupied.
func walkable(tile_pos: Vector2i, obstacles: TileMapLayer) -> bool:
	if not Globals.tile_in_bounds(tile_pos):
		return false

	if obstacles and obstacles.get_cell_source_id(tile_pos) != -1:
		return false

	if _tile_has_blocking_entity(tile_pos):
		return false

	return true

## Returns true if another entity blocks movement on the given tile.
func _tile_has_blocking_entity(tile_pos: Vector2i) -> bool:
	for ent in Globals.entity_manager.entities:
		if ent == self:
			continue

		if Globals.get_tile_pos(ent.position) != tile_pos:
			continue

		if not Globals.in_combat:
			if is_player_entity() and ent is entity and ent.is_player_entity():
				continue

		return true

	return false

## Finds a walkable path to the target tile using breadth-first search.
func pathfind_to_space(target_tile_pos: Vector2i, ignore_obstacles: bool = false) -> Array[Vector2i]:
	var obstacles: TileMapLayer = null

	if not ignore_obstacles:
		obstacles = Globals.get_map_layer(Globals.active_map, "obstacles")

	var start_tile_pos := Globals.get_tile_pos(position)

	if start_tile_pos == target_tile_pos:
		return []

	var came_from := {}
	var visited := {}
	var queue: Array[Vector2i] = []

	visited[start_tile_pos] = true
	queue.push_back(start_tile_pos)

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()

		for direction in CARDINAL_DIRECTIONS:
			var neighbor := current + direction

			if visited.has(neighbor):
				continue

			if not walkable(neighbor, obstacles):
				continue

			visited[neighbor] = true
			came_from[neighbor] = current

			if neighbor == target_tile_pos:
				return _build_path_from_came_from(start_tile_pos, target_tile_pos, came_from)

			queue.push_back(neighbor)

	return []

## Computes reachable combat tiles and predecessor data for current movement.
func get_combat_movement_data() -> Dictionary:
	var obstacles: TileMapLayer = Globals.get_map_layer(Globals.active_map, "obstacles")
	var start_tile := Globals.get_tile_pos(position)
	var move_points_left := get_total_movement_remaining()

	var distances := {}
	var came_from := {}
	var queue: Array[Vector2i] = []

	distances[start_tile] = 0
	queue.push_back(start_tile)

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_dist: int = distances[current]

		if current_dist >= move_points_left:
			continue

		for direction in CARDINAL_DIRECTIONS:
			var neighbor := current + direction

			if distances.has(neighbor):
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

## Returns all in-bounds tiles within a Manhattan movement radius.
func get_tiles_in_movement_radius(center: Vector2i, move_range: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	for x in range(-move_range, move_range + 1):
		for y in range(-move_range, move_range + 1):
			var offset := Vector2i(x, y)

			if absi(offset.x) + absi(offset.y) <= move_range:
				var tile := center + offset
				if Globals.tile_in_bounds(tile):
					tiles.append(tile)

	return tiles

## Builds a path to a cached reachable tile if still within movement limits.
func pathfind_to_reachable_space(target_tile_pos: Vector2i) -> Array[Vector2i]:
	if not reachable_tiles.has(target_tile_pos):
		return []

	var start_tile_pos := Globals.get_tile_pos(position)
	var path := _build_path_from_came_from(start_tile_pos, target_tile_pos, movement_came_from)

	if path.size() > get_total_movement_remaining():
		return []

	return path

## Reconstructs a path from a came_from dictionary.
func _build_path_from_came_from(start_tile_pos: Vector2i, target_tile_pos: Vector2i, came_from: Dictionary) -> Array[Vector2i]:
	var current := target_tile_pos
	var reversed_path: Array[Vector2i] = []

	while current != start_tile_pos:
		if not came_from.has(current):
			return []

		reversed_path.append(current)
		current = came_from[current]

	reversed_path.reverse()
	return reversed_path

## Replaces the movement queue with a copy of the given path.
func follow_path(path: Array[Vector2i]) -> void:
	movement_queue = path.duplicate()

## Returns Manhattan distance from this entity to another entity.
func get_distance_to_entity(other: entity) -> int:
	var my_tile := Globals.get_tile_pos(position)
	var other_tile := Globals.get_tile_pos(other.position)
	return absi(my_tile.x - other_tile.x) + absi(my_tile.y - other_tile.y)

## Returns Manhattan distance from this entity to a tile.
func get_distance_to_tile(tile: Vector2i) -> int:
	var my_tile := Globals.get_tile_pos(position)
	return absi(my_tile.x - tile.x) + absi(my_tile.y - tile.y)

#endregion


#region Line of sight

## Returns true if this entity has line of sight to the target tile.
func has_line_of_sight_to_tile(target_tile: Vector2i, max_range: int = -1) -> bool:
	var my_tile := Globals.get_tile_pos(position)

	if my_tile == target_tile:
		return true

	var dist := absi(my_tile.x - target_tile.x) + absi(my_tile.y - target_tile.y)
	if max_range >= 0 and dist > max_range:
		return false

	return _has_clear_attack_path(my_tile, target_tile)

## Returns true if this entity has line of sight to another entity.
func has_line_of_sight_to_entity(other: entity, max_range: int = -1) -> bool:
	return has_line_of_sight_to_tile(Globals.get_tile_pos(other.position), max_range)

#endregion


#region Damage / combat helpers

## Applies the named attack to all valid entities occupying the targeted tiles.
func apply_attack_to_targets(targeted_tiles: Array[Vector2i], attack_name: String) -> Array:
	var attacked_entities: Array = []
	var possible_targets: Array = Globals.entity_manager.enemies

	if is_enemy_entity():
		possible_targets = Globals.entity_manager.get_living_players()

	for tile in targeted_tiles:
		for ent in possible_targets:
			if ent == self:
				continue

			if Globals.get_tile_pos(ent.position) != tile:
				continue

			if ent.flying and not attack_hits_flying(attack_name):
				continue

			if ent not in attacked_entities:
				attacked_entities.append(ent)

	for ent in attacked_entities:
		ent.take_damage(self, attack_name)

	return attacked_entities

## Applies damage from the given attacker and attack type, then handles death.
func take_damage(attacker: entity, attack_name: String) -> void:
	var damage_range := Vector2i.ZERO

	match attack_name:
		"melee":
			damage_range = attacker.melee_damage
		"ranged":
			damage_range = attacker.ranged_damage
		"special":
			damage_range = attacker.special_damage
		_:
			return

	var rolled := randi_range(damage_range.x, damage_range.y)
	var damage_taken := maxi(rolled - get_effective_armor(), 0)

	health -= damage_taken
	health = maxi(health, 0)

	if attacker == Globals.active_player:
		forced_engaged = true

	update_health_bar()
	Globals.send_to_game_log("%s took %s %s damage and now has %s health" % [
		readable_name,
		damage_taken,
		attack_name,
		health
	])

	if health <= 0:
		die()

## Removes this entity through the entity manager or frees it directly.
func die() -> void:
	if is_player_entity():
		Globals.entity_manager.kill_player(self)
		return

	if Globals.entity_manager:
		Globals.entity_manager.kill(self)
	else:
		queue_free()

## Uses defend if available and grants temporary armor.
func defend() -> bool:
	if not can_use_bonus_ability("defend"):
		return false

	if not spend_bonus_or_attack():
		return false

	temp_armor += 1
	Globals.send_to_game_log("%s defends and gains +1 armor until their next turn" % readable_name)
	return true

## Uses heal if available and restores health.
func heal_self() -> bool:
	if not can_use_bonus_ability("heal"):
		return false

	if not spend_bonus_or_attack():
		return false

	health += 3
	health = mini(health, max_health)
	update_health_bar()
	Globals.send_to_game_log("%s heals and now has %s health" % [readable_name, health])
	return true

## Spends and logs the use of a special ability.
func use_special() -> bool:
	if not spend_special():
		return false

	Globals.send_to_game_log("%s used special" % readable_name)
	return true

#endregion


#region Attack shape code

## Returns the tiles affected by the named attack toward the cursor tile.
func get_attack_affected_tiles(tile_pos: Vector2i, cursor_tile_pos: Vector2i, attack_name: String) -> Array[Vector2i]:
	var attack_range: int
	var attack_type: AttackType
	var pierces: int

	match attack_name:
		"melee":
			attack_range = melee_range
			attack_type = melee_attack_type
			pierces = melee_attack_pierce
		"ranged":
			attack_range = ranged_range
			attack_type = ranged_attack_type
			pierces = ranged_attack_pierce
		"special":
			attack_range = special_range
			attack_type = special_attack_type
			pierces = special_attack_pierce
		_:
			return []

	var end_tile := _get_clamped_line_endpoint(tile_pos, cursor_tile_pos, attack_range)
	if end_tile == tile_pos:
		return []

	var result: Array[Vector2i] = []

	match attack_type:
		AttackType.TILE:
			if Globals.tile_in_bounds(end_tile) and not _is_obstacle(end_tile):
				result.append(end_tile)

		AttackType.LINE:
			result.append_array(_get_line_tiles(tile_pos, end_tile, pierces, false))

		AttackType.LINE_REVERSE:
			result.append_array(_get_line_tiles(tile_pos, end_tile, pierces, true))

		AttackType.BOOMERANG:
			result.append_array(_get_boomerang_tiles(tile_pos, end_tile, pierces))

		AttackType.ARC_45:
			var forward_45 := end_tile - tile_pos
			result.append_array(_filter_tiles_blocked_by_walls(tile_pos, _get_arc_tiles(tile_pos, forward_45, attack_range, 45.0)))

		AttackType.ARC_90:
			var forward_90 := end_tile - tile_pos
			result.append_array(_filter_tiles_blocked_by_walls(tile_pos, _get_arc_tiles(tile_pos, forward_90, attack_range, 90.0)))

		AttackType.ARC_180:
			var forward_180 := end_tile - tile_pos
			result.append_array(_filter_tiles_blocked_by_walls(tile_pos, _get_arc_tiles(tile_pos, forward_180, attack_range, 180.0)))

		AttackType.CIRCLE:
			result.append_array(_filter_tiles_blocked_by_walls(tile_pos, _get_circle_tiles(tile_pos, attack_range)))

		AttackType.SQUARE:
			result.append_array(_filter_tiles_blocked_by_walls(tile_pos, _get_square_tiles(tile_pos, attack_range)))

	return result

## Clamps a cursor direction to the attack's maximum range.
func _get_clamped_line_endpoint(from_tile: Vector2i, cursor_tile_pos: Vector2i, attack_range: int) -> Vector2i:
	var delta := cursor_tile_pos - from_tile
	if delta == Vector2i.ZERO:
		return from_tile

	var delta_vector := Vector2(delta)
	var dist := delta_vector.length()

	if dist <= float(attack_range):
		return cursor_tile_pos

	var clamped := delta_vector.normalized() * float(attack_range)
	return from_tile + Vector2i(roundi(clamped.x), roundi(clamped.y))

## Returns the tile path between two points using Bresenham line stepping.
func _get_line_path(start_tile: Vector2i, end_tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	var x0 := start_tile.x
	var y0 := start_tile.y
	var x1 := end_tile.x
	var y1 := end_tile.y

	var dx := absi(x1 - x0)
	var sx := -1
	if x0 < x1:
		sx = 1

	var dy := -absi(y1 - y0)
	var sy := -1
	if y0 < y1:
		sy = 1

	var err := dx + dy

	while true:
		out.append(Vector2i(x0, y0))

		if x0 == x1 and y0 == y1:
			break

		var e2 := 2 * err

		if e2 >= dy:
			err += dy
			x0 += sx

		if e2 <= dx:
			err += dx
			y0 += sy

	return out

## Returns tiles affected by a line attack, optionally in reverse order.
func _get_line_tiles(tile_pos: Vector2i, end_tile: Vector2i, pierces: int, reverse: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hits_used := 0
	var path := _get_line_path(tile_pos, end_tile)

	if path.size() <= 1:
		return out

	path.remove_at(0)

	if reverse:
		path.reverse()

	for tile in path:
		if not Globals.tile_in_bounds(tile):
			if reverse:
				continue
			break

		if _is_obstacle(tile):
			if reverse:
				continue
			break

		out.append(tile)

		if pierces > 0 and _has_entity_at_tile(tile):
			hits_used += 1
			if hits_used >= pierces:
				break

	return out

## Returns tiles affected by a boomerang attack, stopping return if a wall is hit outbound.
func _get_boomerang_tiles(tile_pos: Vector2i, end_tile: Vector2i, pierces: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hits_used := 0
	var hit_wall := false
	var path := _get_line_path(tile_pos, end_tile)

	if path.size() <= 1:
		return out

	path.remove_at(0)
	var reached_count := 0

	for i in range(path.size()):
		var tile := path[i]

		if not Globals.tile_in_bounds(tile):
			hit_wall = true
			break

		if _is_obstacle(tile):
			hit_wall = true
			break

		out.append(tile)
		reached_count += 1

		if pierces > 0 and _has_entity_at_tile(tile):
			hits_used += 1
			if hits_used >= pierces:
				return out

	if hit_wall:
		return out

	for i in range(reached_count - 2, -1, -1):
		var tile := path[i]

		if not Globals.tile_in_bounds(tile):
			continue

		if _is_obstacle(tile):
			continue

		out.append(tile)

		if pierces > 0 and _has_entity_at_tile(tile):
			hits_used += 1
			if hits_used >= pierces:
				break

	return out

## Returns tiles inside an arc centered on the forward direction.
func _get_arc_tiles(tile_pos: Vector2i, forward: Vector2i, attack_range: int, arc_degrees: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	if forward == Vector2i.ZERO:
		return out

	var forward_vec := Vector2(forward).normalized()
	var half_arc := deg_to_rad(arc_degrees * 0.5)

	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var offset := Vector2i(x, y)

			if offset == Vector2i.ZERO:
				continue

			var v := Vector2(offset)
			if v.length() > float(attack_range):
				continue

			var dir := v.normalized()
			var angle := acos(clamp(forward_vec.dot(dir), -1.0, 1.0))

			if angle <= half_arc:
				out.append(tile_pos + offset)

	return out

## Returns tiles inside a circular attack radius.
func _get_circle_tiles(tile_pos: Vector2i, attack_range: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var offset := Vector2i(x, y)

			if offset == Vector2i.ZERO:
				continue

			if Vector2(offset).length() <= float(attack_range):
				out.append(tile_pos + offset)

	return out

## Returns tiles inside a square attack radius.
func _get_square_tiles(tile_pos: Vector2i, attack_range: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var offset := Vector2i(x, y)

			if offset == Vector2i.ZERO:
				continue

			out.append(tile_pos + offset)

	return out

## Filters out tiles blocked by walls or line-of-sight obstruction.
func _filter_tiles_blocked_by_walls(origin_tile: Vector2i, tiles: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for tile in tiles:
		if not Globals.tile_in_bounds(tile):
			continue

		if _is_obstacle(tile):
			continue

		if _has_clear_attack_path(origin_tile, tile):
			out.append(tile)

	return out

## Returns true if a line path between two tiles is unobstructed.
func _has_clear_attack_path(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	var path := _get_line_path(from_tile, to_tile)

	if path.is_empty():
		return false

	for i in range(1, path.size()):
		if _is_obstacle(path[i]):
			return false

	return true

## Returns true if any other entity occupies the given tile.
func _has_entity_at_tile(tile: Vector2i) -> bool:
	for ent in Globals.entity_manager.entities:
		if ent == self:
			continue

		if Globals.get_tile_pos(ent.position) == tile:
			return true

	return false

## Returns true if the given tile contains an obstacle.
func _is_obstacle(tile: Vector2i) -> bool:
	var obstacles = Globals.get_map_layer(Globals.active_map, "obstacles")

	if obstacles == null:
		return false

	return obstacles.get_cell_source_id(tile) != -1

#endregion


#region UI helpers

## Updates this entity's world and player health bars.
func update_health_bar() -> void:
	if has_node("%HealthBar"):
		var bar: TextureProgressBar = %HealthBar as TextureProgressBar
		bar.max_value = max_health
		bar.value = health
		bar.visible = health < max_health

	if self == Globals.active_player and Globals.player_health_bar:
		Globals.player_health_bar.max_value = max_health
		Globals.player_health_bar.value = health

#endregion
