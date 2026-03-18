## Spawns entities as scenes from the entities layer of the loaded tilemap
extends Node

var entity_lookup = {
	1: [preload("res://scenes/world/enemy.tscn"), ["fireworm"], "fireworm"],
	2: [preload("res://scenes/world/enemy.tscn"), ["crawler"], "crawler"],
	3: [preload("res://scenes/world/enemy.tscn"), ["glowcrushsheller"], "glowcrushsheller"],
	4: [preload("res://scenes/world/enemy.tscn"), ["ghost"], "ghost"],
	5: [preload("res://scenes/world/enemy.tscn"), ["pepperjelly"], "pepperjelly"],
	9: [preload("res://scenes/world/item.tscn"), ["item"], "item"],
	10: [preload("res://scenes/world/shop.tscn"), ["shop"], "shop"],
}

var entities := []

func _ready() -> void:
	Globals.entity_manager = self

func spawn_entities() -> void:
	var layer = Globals.get_map_layer(Globals.active_map, "entities") as TileMapLayer
	
	for cell in layer.get_used_cells():
		var source_id = layer.get_cell_source_id(cell)

		if source_id in entity_lookup:
			var scene_data = entity_lookup[source_id] # [0] is preload, [1] is vargs, [2] is name
			print("Spawning ", scene_data[2], " at ", cell)
			var instance = scene_data[0].instantiate()
			instance.callv("initialize", scene_data[1])

			instance.position = layer.map_to_local(cell)
			add_child(instance)
			entities.append(instance)
