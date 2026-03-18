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
var melee_attack_width := 0 # Only matters for line and boomerang

var has_ranged := true
var ranged_range := 4
var ranged_hits_flying := true
var ranged_damage := Vector2i(1, 3)
var ranged_attack_type := AttackType.LINE
var ranged_attack_pierce := 1 # 1 means pierce only 1 enemy
var ranged_attack_width := 1 # Only matters for line and boomerang

enum AttackType {
	TILE, # hits a single tile
	LINE, # hits number of targets according to pierce along a line
	LINE_REVERSE, # hits number of targets according to pierce, starting from end of range
	BOOMERANG, # pierces targets to and from range
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
## width: 1 (default) = normal line. 2+ = thick line.
func get_attack_affected_tiles(
		tile_pos: Vector2i,
		cursor_tile_pos: Vector2i,
		attack_name: String
	) -> Array[Vector2i]:
	
	var attack_range: int
	var attack_type: AttackType
	var pierces: int
	var width: int
	
	# Which set of variables to use
	match attack_name:
		"melee":
			attack_range = melee_range
			attack_type = melee_attack_type
			pierces = melee_attack_pierce
			width = melee_attack_width
		"ranged":
			attack_range = ranged_range
			attack_type = ranged_attack_type
			pierces = ranged_attack_pierce
			width = ranged_attack_width
	
	# If the cursor is WAY out of range, snap our end tile to the closest tile in range
	var end_tile := _get_clamped_line_endpoint(tile_pos, cursor_tile_pos, attack_range)
	if end_tile == tile_pos:
		return []
	
	# Our return array. It will be an array of tile positions that are attacked.
	# If a tile appears more than once, it means it got hit more than once.
	var result: Array[Vector2i] = []

	match attack_type:
		AttackType.TILE:
			result.append(end_tile)

		AttackType.LINE:
			result.append_array(_get_line_tiles(
				tile_pos,
				cursor_tile_pos,
				end_tile,
				pierces,
				width,
				false
			))

		AttackType.LINE_REVERSE:
			result.append_array(_get_line_tiles(
				tile_pos,
				cursor_tile_pos,
				end_tile,
				pierces,
				width,
				true
			))

		AttackType.BOOMERANG:
			result.append_array(_get_boomerang_tiles(
				tile_pos,
				cursor_tile_pos,
				end_tile,
				pierces,
				width
			))

		AttackType.ARC_45:
			var forward := (end_tile - tile_pos)
			result.append_array(_get_arc_tiles(tile_pos, forward, attack_range, 45.0))

		AttackType.ARC_90:
			var forward := (end_tile - tile_pos)
			result.append_array(_get_arc_tiles(tile_pos, forward, attack_range, 90.0))

		AttackType.ARC_180:
			var forward := (end_tile - tile_pos)
			result.append_array(_get_arc_tiles(tile_pos, forward, attack_range, 180.0))

		AttackType.CIRCLE:
			for x in range(-attack_range, attack_range + 1):
				for y in range(-attack_range, attack_range + 1):
					var offset := Vector2i(x, y)
					if Vector2(offset).length() <= float(attack_range):
						result.append(tile_pos + offset)

		AttackType.SQUARE:
			for x in range(-attack_range, attack_range + 1):
				for y in range(-attack_range, attack_range + 1):
					result.append(tile_pos + Vector2i(x, y))

	return result

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

func _get_path_tangent(path: Array[Vector2i], index: int) -> Vector2i:
	if path.size() <= 1:
		return Vector2i.RIGHT

	if index == 0:
		return path[1] - path[0]
	elif index == path.size() - 1:
		return path[index] - path[index - 1]

	var a := path[index] - path[index - 1]
	var b := path[index + 1] - path[index]

	var sum := a + b
	if sum == Vector2i.ZERO:
		return b
	return sum

func _get_perpendicular_from_tangent(tangent: Vector2i) -> Vector2i:
	var tx := sign(tangent.x) as int
	var ty := sign(tangent.y) as int
	return Vector2i(-ty, tx)

func _get_row_tiles_for_path(
		center: Vector2i,
		tangent: Vector2i,
		tile_pos: Vector2i,
		cursor_tile_pos: Vector2i,
		width: int
	) -> Array[Vector2i]:
	var row: Array[Vector2i] = []

	if width <= 1:
		row.append(center)
		return row

	var perp := _get_perpendicular_from_tangent(tangent)
	if perp == Vector2i.ZERO:
		row.append(center)
		return row

	if width % 2 == 1:
		var half: int = width / 2
		for o in range(-half, half + 1):
			row.append(center + perp * o)
		return row

	var rel := cursor_tile_pos - tile_pos
	var side := sign(rel.x * perp.x + rel.y * perp.y) as int
	if side == 0:
		side = 1

	if side > 0:
		for o in range(0, width):
			row.append(center + perp * o)
	else:
		for o in range(-width + 1, 1):
			row.append(center + perp * o)

	return row

func _get_line_tiles(
		tile_pos: Vector2i,
		cursor_tile_pos: Vector2i,
		end_tile: Vector2i,
		pierces: int,
		width: int,
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

	for i in range(path.size()):
		var center := path[i]
		var tangent := _get_path_tangent(path, i)
		var row := _get_row_tiles_for_path(center, tangent, tile_pos, cursor_tile_pos, width)

		if _row_has_obstacle(row):
			if reverse:
				continue
			break

		out.append_array(row)

		if pierces > 0:
			hits_used += _row_entity_hits(row)
			if hits_used >= pierces:
				break

	return out

func _get_boomerang_tiles(
		tile_pos: Vector2i,
		cursor_tile_pos: Vector2i,
		end_tile: Vector2i,
		pierces: int,
		width: int
	) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hits_used := 0

	var path := _get_line_path(tile_pos, end_tile)
	if path.size() <= 1:
		return out

	path.remove_at(0)

	var reached_count := 0

	for i in range(path.size()):
		var center := path[i]
		var tangent := _get_path_tangent(path, i)
		var row := _get_row_tiles_for_path(center, tangent, tile_pos, cursor_tile_pos, width)

		if _row_has_obstacle(row):
			break

		out.append_array(row)
		reached_count += 1

		if pierces > 0:
			hits_used += _row_entity_hits(row)
			if hits_used >= pierces:
				return out

	for i in range(reached_count - 2, -1, -1):
		var center := path[i]
		var tangent := _get_path_tangent(path, i)
		var row := _get_row_tiles_for_path(center, tangent, tile_pos, cursor_tile_pos, width)

		if _row_has_obstacle(row):
			continue

		out.append_array(row)

		if pierces > 0:
			hits_used += _row_entity_hits(row)
			if hits_used >= pierces:
				break

	return out

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
	
func _get_step_direction(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var delta := to_tile - from_tile
	return Vector2i(sign(delta.x), sign(delta.y))

func _has_entity_at_tile(tile: Vector2i) -> bool:
	for ent in Globals.entity_manager.entities:
		if Globals.get_tile_pos(ent.position) == tile:
			return true
	return false

func _is_obstacle(tile: Vector2i) -> bool:
	var obstacles = Globals.get_map_layer(Globals.active_map, "obstacles")
	if obstacles == null:
		return false
	return obstacles.get_cell_source_id(tile) != -1

func _get_row_tiles(center: Vector2i, step: Vector2i, tile_pos: Vector2i, cursor_tile_pos: Vector2i, width: int) -> Array[Vector2i]:
	var row: Array[Vector2i] = []
	if width <= 1:
		row.append(center)
		return row
	var perp := _get_perpendicular(step)

	if width % 2 == 1:
		var half := width / 2
		for o in range(-half, half + 1):
			row.append(center + perp * o)
		return row
	# Even width: bias to one side using cursor position.
	# Example width 2 => offsets [0, 1] or [-1, 0]
	# Example width 4 => offsets [0, 1, 2, 3] shifted to one side
	var rel := cursor_tile_pos - tile_pos
	var side := sign(rel.x * perp.x + rel.y * perp.y) as int
	if side == 0:
		side = 1
	if side > 0:
		for o in range(0, width):
			row.append(center + perp * o)
	else:
		for o in range(-width + 1, 1):
			row.append(center + perp * o)
	return row
	
func _row_has_obstacle(row: Array[Vector2i]) -> bool:
	for tile in row:
		if _is_obstacle(tile):
			return true
	return false

func _row_entity_hits(row: Array[Vector2i]) -> int:
	var hits := 0
	for tile in row:
		if _has_entity_at_tile(tile):
			hits += 1
	return hits

func _get_perpendicular(step: Vector2i) -> Vector2i:
	return Vector2i(-step.y, step.x)

func _get_clamped_target_tile(from_tile: Vector2i, cursor_tile_pos: Vector2i, attack_range: int) -> Vector2i:
	var delta := cursor_tile_pos - from_tile
	var distance := maxi(abs(delta.x), abs(delta.y))
	if distance == 0:
		return from_tile

	if distance <= attack_range:
		return cursor_tile_pos

	var step := _get_step_direction(from_tile, cursor_tile_pos)
	return from_tile + step * attack_range
