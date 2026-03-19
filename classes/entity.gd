## I'm not doing any more vector work for at least a week

extends Node2D

class_name entity

# Stats
var health := 10
var armor := 1 # Damage reduction per hit
var speed := 4 # Number of tiles this unit can move per turn
var flying := false

# Combat
var has_melee := true
var melee_range := 2
var melee_hits_flying := false
var melee_damage := Vector2i(1, 5) # 1-5 damage per hit
var melee_attack_type := AttackType.TILE
var melee_attack_pierce := 0 # 0 is unlimited pierce

var has_ranged := true
var ranged_range := 4
var ranged_hits_flying := true
var ranged_damage := Vector2i(1, 3)
var ranged_attack_type := AttackType.LINE
var ranged_attack_pierce := 1 # 1 means pierce only 1 enemy

enum AttackType {
	TILE, # hits a single tile
	LINE, # hits targets along a line until blocked or pierce is used
	LINE_REVERSE, # hits along a line starting from the far end
	BOOMERANG, # hits on the way out and back
	ARC_45, # all targets in 45 degree arc
	ARC_90, # all targets in 90 degree arc
	ARC_180, # all targets in semicircle
	CIRCLE, # all targets in radius range
	SQUARE, # all targets in square radius range
}

## Returns a list of all tiles that would be affected by an attack.
## tile_pos is the attacker tile.
## pierces: 0 = unlimited entity pierces. 1 = stop after first entity hit.
## 2+ = stop after that many entity hits
func get_attack_affected_tiles(
		tile_pos: Vector2i,
		cursor_tile_pos: Vector2i,
		attack_name: String
	) -> Array[Vector2i]:

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
		_:
			return []

	# If the cursor is WAY out of range, snap our end tile to the closest tile in range
	var end_tile := _get_clamped_line_endpoint(tile_pos, cursor_tile_pos, attack_range)
	if end_tile == tile_pos:
		return []

	# Our return array. It will be an array of tile positions that are attacked.
	# If a tile appears more than once, it means it got hit more than once.
	var result: Array[Vector2i] = []

	match attack_type:
		AttackType.TILE:
			if Globals.tile_in_bounds(end_tile) and not _is_obstacle(end_tile):
				result.append(end_tile)

		AttackType.LINE:
			result.append_array(_get_line_tiles(
				tile_pos,
				end_tile,
				pierces,
				false
			))

		AttackType.LINE_REVERSE:
			result.append_array(_get_line_tiles(
				tile_pos,
				end_tile,
				pierces,
				true
			))

		AttackType.BOOMERANG:
			result.append_array(_get_boomerang_tiles(
				tile_pos,
				end_tile,
				pierces
			))

		AttackType.ARC_45:
			var forward_45 := end_tile - tile_pos
			result.append_array(_filter_tiles_blocked_by_walls(
				tile_pos,
				_get_arc_tiles(tile_pos, forward_45, attack_range, 45.0)
			))

		AttackType.ARC_90:
			var forward_90 := end_tile - tile_pos
			result.append_array(_filter_tiles_blocked_by_walls(
				tile_pos,
				_get_arc_tiles(tile_pos, forward_90, attack_range, 90.0)
			))

		AttackType.ARC_180:
			var forward_180 := end_tile - tile_pos
			result.append_array(_filter_tiles_blocked_by_walls(
				tile_pos,
				_get_arc_tiles(tile_pos, forward_180, attack_range, 180.0)
			))

		AttackType.CIRCLE:
			result.append_array(_filter_tiles_blocked_by_walls(
				tile_pos,
				_get_circle_tiles(tile_pos, attack_range)
			))

		AttackType.SQUARE:
			result.append_array(_filter_tiles_blocked_by_walls(
				tile_pos,
				_get_square_tiles(tile_pos, attack_range)
			))

	return result

## Clamps a target tile to attack_range tiles away from from_tile.
## If cursor_tile_pos is already in range, returns it unchanged.
func _get_clamped_line_endpoint(from_tile: Vector2i, cursor_tile_pos: Vector2i, attack_range: int) -> Vector2i:
	var delta := cursor_tile_pos - from_tile
	if delta == Vector2i.ZERO:
		return from_tile

	var delta_v := Vector2(delta)
	var dist := delta_v.length()
	if dist <= float(attack_range):
		return cursor_tile_pos

	var clamped := delta_v.normalized() * float(attack_range)
	return from_tile + Vector2i(roundi(clamped.x), roundi(clamped.y))

## Returns all tiles along a line from start_tile to end_tile, inclusive.
func _get_line_path(start_tile: Vector2i, end_tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	var x0 := start_tile.x
	var y0 := start_tile.y
	var x1 := end_tile.x
	var y1 := end_tile.y

	var dx := abs(x1 - x0) as int
	var sx := 1 if x0 < x1 else -1
	var dy := -abs(y1 - y0) as int
	var sy := 1 if y0 < y1 else -1
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

## Returns the tiles hit by a line attack.
## reverse = true means start checking from the far end.
func _get_line_tiles(
		tile_pos: Vector2i,
		end_tile: Vector2i,
		pierces: int,
		reverse: bool
	) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hits_used := 0

	var path := _get_line_path(tile_pos, end_tile)
	if path.size() <= 1:
		return out

	path.remove_at(0) # remove attacker tile

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

## Returns the tiles hit by a boomerang attack.
## The attack travels outward until blocked, then comes back along the same path.
## Returns the tiles hit by a boomerang attack.
## The attack travels outward until blocked, then comes back along the same path.
## If it hits a wall on the way out, it does NOT return.
func _get_boomerang_tiles(
		tile_pos: Vector2i,
		end_tile: Vector2i,
		pierces: int
	) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hits_used := 0
	var hit_wall := false

	var path := _get_line_path(tile_pos, end_tile)
	if path.size() <= 1:
		return out
	path.remove_at(0) # remove attacker tile

	var reached_count := 0

	# Outgoing phase
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
	# If we hit a wall on the way out, do NOT return
	if hit_wall:
		return out

	# Return phase
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

## Returns all tiles in an arc in front of tile_pos.
## This only generates candidate tiles; wall blocking is applied separately.
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

## Returns all tiles in a circle around tile_pos.
## This only generates candidate tiles; wall blocking is applied separately.
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

## Returns all tiles in a square around tile_pos.
## This only generates candidate tiles; wall blocking is applied separately.
func _get_square_tiles(tile_pos: Vector2i, attack_range: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var offset := Vector2i(x, y)
			if offset == Vector2i.ZERO:
				continue
			out.append(tile_pos + offset)

	return out

## Filters a candidate tile list so only tiles with a clear path from origin_tile remain.
## Obstacle tiles themselves are excluded.
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

## Returns true if there is a clear line from from_tile to to_tile with no wall in the way.
## The destination tile must also be non-obstructed.
func _has_clear_attack_path(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	var path := _get_line_path(from_tile, to_tile)
	if path.is_empty():
		return false

	# Skip the starting tile.
	for i in range(1, path.size()):
		if _is_obstacle(path[i]):
			return false

	return true

## Returns true if any entity other than self is standing on tile.
func _has_entity_at_tile(tile: Vector2i) -> bool:
	for ent in Globals.entity_manager.entities:
		if ent == self:
			continue
		if Globals.get_tile_pos(ent.position) == tile:
			return true
	return false

## Returns true if tile contains an obstacle.
func _is_obstacle(tile: Vector2i) -> bool:
	var obstacles = Globals.get_map_layer(Globals.active_map, "obstacles")
	if obstacles == null:
		return false
	return obstacles.get_cell_source_id(tile) != -1
