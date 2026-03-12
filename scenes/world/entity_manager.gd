## Spawns entities as scenes from the entities layer of the loaded tilemap
extends Node

var entity_lookup = {
	1: preload("res://scenes/world/enemy.tscn"),
	2: preload("res://scenes/world/item.tscn"),
	3: preload("res://scenes/world/shop.tscn"),
}

var entities := []

func spawn_entities() -> void:
	var layer = Globals.get_map_layer(Globals.active_map, "entities") as TileMapLayer
	
	for cell in layer.get_used_cells():
		var source_id = layer.get_cell_source_id(cell)

		if source_id in entity_lookup:
			var scene = entity_lookup[source_id]
			print("Spawning ", scene, " at ", cell)
			var instance = scene.instantiate()

			instance.position = layer.map_to_local(cell)
			add_child(instance)
			entities.append(instance)
