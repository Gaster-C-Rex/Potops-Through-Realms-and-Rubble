# globals.gd
extends Node

const TILE_SIZE = 64
const USER_MAP_DIR = "user://maps"
const RES_MAP_DIR = "res://assets/maps"
const ENEMY_DIR = "user://enemies"
const AUDIO_DIR = "res://assets/audio"

const SONG_BATTLE := "Battle (Loop).wav"
const SONG_CHAR_SELECT := "Character_Select(Loop).wav"
const SONG_CONSTRUCT_SITE := "Construction-Site.wav"
const SONG_EXPLORE := "Explorationv2 (Loop).wav"
const SONG_WORKSHOP := "Work-Shopped.wav"

enum AttackType { # HACK: this should only be declared in one place
	TILE,         # and can easily create desyncs
	LINE,
	LINE_REVERSE,
	BOOMERANG,
	ARC_45,
	ARC_90,
	ARC_180,
	CIRCLE,
	SQUARE,
}

# In the future, load this from a JSON
const PLAYER_OPTIONS = {
	"Default": {
		"properties": {
			"max_health": 12, 
			"health": 12,
			"armor": 1,
			"speed": 4,
			"flying": false,
			"attacks_per_turn": 2,
			"bonus_actions_per_turn": 0,
			"has_heal": true,
			"has_defend": true,
			"has_melee": true,
			"has_ranged": true,
			"has_special": true,
			"specials_per_combat": 1,
			"melee_range": 1,
			"melee_hits_flying": true, # To avoid confusion for now
			"melee_damage": Vector2i(2, 6),
			"melee_attack_type": AttackType.TILE,
			"melee_attack_pierce": 1,
			"ranged_range": 5,
			"ranged_hits_flying": true,
			"ranged_damage": Vector2i(1, 5),
			"ranged_attack_type": AttackType.LINE,
			"ranged_attack_pierce": 1,
			"special_range": 6,
			"special_hits_flying": true,
			"special_damage": Vector2i(4, 8),
			"special_attack_type": AttackType.ARC_45,
			"special_attack_pierce": 0, # unlimited
		},
		"texture_path": "res://assets/sprites/players/Potop-Idles.png",
		"type": "Default",
		"readable_name": "Potop",
	},
	"Marble": {
		"properties": {
			"max_health": 15, 
			"health": 15,
			"armor": 2,
			"speed": 3,
			"flying": false,
			"attacks_per_turn": 1,
			"bonus_actions_per_turn": 1,
			"has_heal": false,
			"has_defend": true,
			"has_melee": true,
			"has_ranged": false,
			"has_special": true,
			"specials_per_combat": 1,
			"melee_range": 1,
			"melee_hits_flying": true, # To avoid confusion for now
			"melee_damage": Vector2i(1, 4),
			"melee_attack_type": AttackType.TILE,
			"melee_attack_pierce": 1,
			"special_range": 3,
			"special_hits_flying": true,
			"special_damage": Vector2i(4, 8),
			"special_attack_type": AttackType.CIRCLE,
			"special_attack_pierce": 0, # unlimited
		},
		"texture_path": "res://assets/sprites/players/Marble-Idles.png",
		"type": "Marble",
		"readable_name": "Marble Potop",
	},
	"Fire": {
		"properties": {
			"max_health": 10, 
			"health": 10,
			"armor": 0,
			"speed": 4,
			"flying": false,
			"attacks_per_turn": 3,
			"bonus_actions_per_turn": 0,
			"has_heal": false,
			"has_defend": false,
			"has_melee": true,
			"has_ranged": true,
			"has_special": true,
			"specials_per_combat": 1,
			"melee_range": 2,
			"melee_hits_flying": true, # To avoid confusion for now
			"melee_damage": Vector2i(3, 9),
			"melee_attack_type": AttackType.ARC_180,
			"melee_attack_pierce": 2,
			"ranged_range": 6,
			"ranged_hits_flying": true,
			"ranged_damage": Vector2i(2, 9),
			"ranged_attack_type": AttackType.ARC_90,
			"ranged_attack_pierce": 2,
			"special_range": 8,
			"special_hits_flying": true,
			"special_damage": Vector2i(6, 12),
			"special_attack_type": AttackType.BOOMERANG,
			"special_attack_pierce": 0, # unlimited
		},
		"texture_path": "res://assets/sprites/players/Fiery-Idles.png",
		"type": "Fire",
		"readable_name": "Fiery Potop",
	},
	"Flying": {
		"properties": {
			"max_health": 10, 
			"health": 10,
			"armor": 1,
			"speed": 6,
			"flying": true, # shocker, I know
			"attacks_per_turn": 2,
			"bonus_actions_per_turn": 0,
			"has_heal": true,
			"has_defend": true,
			"has_melee": false,
			"has_ranged": true,
			"has_special": true,
			"specials_per_combat": 1,
			"ranged_range": 5,
			"ranged_hits_flying": true,
			"ranged_damage": Vector2i(2, 5),
			"ranged_attack_type": AttackType.TILE,
			"ranged_attack_pierce": 1,
			"special_range": 6,
			"special_hits_flying": true,
			"special_damage": Vector2i(4, 8),
			"special_attack_type": AttackType.LINE_REVERSE,
			"special_attack_pierce": 2, # unlimited
		},
		"texture_path": "res://assets/sprites/players/Flutter-Idles.png",
		"type": "Flying",
		"readable_name": "Flutter Potop",
	},
}

var trades = [
		{"result": "basic armor",
		"price": {
			"stick": 10,
			"clay": 10,
		}},
		{"result": "armored mask",
		"price": {
			"stick": 10,
			"clay": 10,
			"orange gem": 3,
		}},
		{"result": "cat armor",
		"price": {
			"stick": 10,
			"clay": 10,
			"purple gem": 3,
		}},
		{"result": "wood sword",
		"price": {
			"stick": 10,
			"clay": 10,
		}},
		{"result": "iron dagger",
		"price": {
			"stick": 10,
			"clay": 10,
			"red gem": 3,
		}},
		{"result": "steel longsword",
		"price": {
			"stick": 10,
			"clay": 10,
			"green gem": 3,
		}},
		{"result": "trinket1",
		"price": {
			"red gem": 3,
			"orange gem": 3,
		}},
		{"result": "trinket2",
		"price": {
			"stick": 5,
			"purple gem": 3,
		}},
		{"result": "trinket3",
		"price": {
			"clay": 5,
			"green gem": 3,
		}},
	]

const item_textures = {
	"stick": preload("uid://dn0uygqqwbuhu"),
	"clay": preload("uid://dayrdffv4kuiv"),
	"orange gem": preload("uid://dcrsg21ao58gg"),
	"red gem": preload("uid://ble8qvgwdat7d"),
	"green gem": preload("uid://3kyd70o5lyxa"),
	"purple gem": preload("uid://c0n6uxx30tw1p"),
	"basic armor": preload("uid://cxkshl3ftxjam"),
	"armored mask": preload("uid://bmsiwd5j1xlek"),
	"cat armor": preload("uid://bxvk32xljwakf"),
	"wood sword": preload("uid://blewm41axu87h"),
	"iron dagger": preload("uid://c12bmkw7jfxi7"),
	"steel longsword": preload("uid://bvpbxgb3s0mqe"),
}

# Add items to this dict as they become available
const EQUIPMENT_OPTIONS = {
	"None": {},
	"basic armor": {
		"armor": 1,
	},
	"armored mask": {
		"armor": 2,
	},
	"cat armor": {
		"armor": 2,
		"speed": 1,
	},
	"wood sword": {
		"melee_damage": Vector2i(1, 1)
	},
	"iron dagger": {
		"melee_damage": Vector2i(1, 3)
	},
	"steel longsword": {
		"melee_damage": Vector2i(2, 5)
	},
}

# List of exactly 3 equipment items
var equipped = ["None", "None", "None"]

# List of exactly 3 player stat blocks
var party = [{}, {}, {}]

# unused as of new combat system
#enum Popup_Option {
	#MELEE_ATTACK,
	#RANGED_ATTACK
#}

var active_map: Node2D
var active_map_id: int
var active_player: Node
var active_canvas_layer: CanvasLayer
var entity_manager: Node
var game_log: RichTextLabel
var active_camera: Camera2D

var combat_ui: Control
var melee_attack_count: RichTextLabel
var ranged_attack_count: RichTextLabel
var move_count: RichTextLabel
var defend_count: RichTextLabel
var heal_count: RichTextLabel
var special_count: RichTextLabel
var player_health_bar: TextureProgressBar
var tile_selector: Sprite2D
var portrait: TextureRect

var in_combat := false

var levels := []
var items := []
var potops := []
var enemies := {}
var audio := {}

# var inventory := {} # Simple "item": count

var inventory := { # NOTE: For testing only! Comment out in release!
	"stick": 50,
	"clay": 50,
	"orange gem": 6,
	"red gem": 6,
	"green gem": 6,
	"purple gem": 6,
}

var common_gems := ["orange gem", "red gem"]
var rare_gems := ["green gem", "purple gem"]

## Initializes user folders, loads enemy data, and sets the minimum window size.
func _ready() -> void:
	ensure_user_folders()
	load_enemies()
	print(enemies)
	load_audio()
	print(audio)
	get_window().min_size = Vector2i(720, 480)

## Ensures required user data folders exist.
func ensure_user_folders() -> void:
	var folders = [
		"user://maps",
		"user://maps/tiles",
		"user://enemies",
		"user://audio"
	]

	for folder in folders:
		if not DirAccess.dir_exists_absolute(folder):
			DirAccess.make_dir_recursive_absolute(folder)

## Loads map scenes from the given directory and stores them in levels.
func load_maps(map_dir: String) -> bool:
	print("Scanning for map files...")

	if not levels.is_empty():
		var cleaned_levels := []

		for map in levels:
			if map != null:
				cleaned_levels.append(map)

		levels = cleaned_levels

	var dir := DirAccess.open(map_dir)

	if dir == null:
		print("Failed to open directory: ", map_dir)
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	var tilemap_creator = preload("res://addons/YATI/TilemapCreator.gd").new()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tmx"):
			var full_path := map_dir + "/" + file_name
			print("Found map file: ", full_path)

			var map: Node2D = tilemap_creator.create(full_path)

			if map.has_node("entities"):
				map.get_node("entities").visible = false

			levels.append(map)

		file_name = dir.get_next()

	dir.list_dir_end()

	if levels.is_empty():
		print("No maps detected! Add .tmx map files to: ", OS.get_user_data_dir(), "/maps")
		return false

	return true

## Loads enemy JSON data files from the enemy directory.
func load_enemies() -> bool:
	print("Scanning for enemy data...")
	enemies.clear()

	var dir := DirAccess.open(ENEMY_DIR)

	if dir == null:
		print("Failed to open directory: ", ENEMY_DIR)
		print("No enemies detected! Add data to the json file at: ", OS.get_user_data_dir(), "/enemies")
		return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := ENEMY_DIR + "/" + file_name
			var data = parse_data(FileAccess.get_file_as_string(full_path))

			if data == null:
				print("Please add data to ", file_name)
				return false

			if typeof(data) != TYPE_DICTIONARY:
				print("Enemy data is not a dictionary, please follow the instructions")
				return false

			if data.keys().is_empty():
				print("Please add data to ", file_name)
				return false

			enemies[file_name] = data

		file_name = dir.get_next()

	dir.list_dir_end()
	return true

## Loads audio files from the audio directory.
func load_audio() -> bool:
	print("Scanning for audio files...")

	var dir := DirAccess.open(AUDIO_DIR)

	if dir == null:
		print("Failed to open directory: ", AUDIO_DIR)
		print("No audio detected! Add audio files at: ", OS.get_user_data_dir(), "/audio")
		return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and (file_name.to_lower().ends_with(".ogg")
		or file_name.to_lower().ends_with(".mp3") or file_name.to_lower().ends_with(".wav")):
				var full_path := AUDIO_DIR + "/" + file_name
				audio[file_name] = full_path

		file_name = dir.get_next()

	dir.list_dir_end()
	if audio.is_empty():
		return false
	return true

## Parses a JSON string and returns the decoded data or null on failure.
func parse_data(data: String):
	var json := JSON.new()
	var error := json.parse(data)

	if error == OK:
		return json.data

	print("JSON Parse Error: ", json.get_error_message(), " in ", data, " at line ", json.get_error_line())
	return null

## Converts global or tile coordinates to the center point of a tile.
func get_tile_center(coords: Vector2, system := "global") -> Vector2:
	if system == "global":
		return Vector2(
			floor(coords.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
			floor(coords.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2
		)

	if system == "tile":
		return Vector2(
			coords.x * TILE_SIZE + TILE_SIZE / 2,
			coords.y * TILE_SIZE + TILE_SIZE / 2
		)

	return coords

## Converts world coordinates to tile coordinates.
func get_tile_pos(coords: Vector2) -> Vector2i:
	return Vector2i(
		floor(coords.x / TILE_SIZE),
		floor(coords.y / TILE_SIZE)
	)

## Returns true if the given tile is within the active map bounds.
func tile_in_bounds(tile_pos: Vector2) -> bool:
	if active_map:
		var tilemaplayer: TileMapLayer = get_map_layer(active_map, "background")
		var map_rect := tilemaplayer.get_used_rect()
		return map_rect.has_point(tile_pos)

	return true

## Returns the named tilemap layer from the given map.
func get_map_layer(map: Node2D, layer: String):
	if map.has_node(layer):
		return map.get_node(layer)

	push_warning("Tilemap does not have a layer named \"", layer, "\"")
	return null

## Calculates the pixel-space rectangle covered by the map background tiles.
func calculate_map_pixel_rect(map: Node2D) -> Rect2:
	var tilemaplayer: TileMapLayer = get_map_layer(map, "background")
	var tile_rect := tilemaplayer.get_used_rect()
	return Rect2(tile_rect.position * TILE_SIZE, tile_rect.size * TILE_SIZE)

## Appends a message to the game log and prints it to stdout.
func send_to_game_log(message) -> void:
	if game_log:
		game_log.append_text("\n" + str(message))
	else:
		push_warning("Race condition: Log not yet defined")

	print(message)

## Clears the game log if it is available.
func clear_game_log() -> void:
	if game_log:
		game_log.clear()
	else:
		push_warning("Race condition: Log not yet defined")

## Starts the game by loading the world scene.
func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/world/game.tscn")

## Returns to the main menu scene.
func exit_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

##
func get_audio(audio_name: StringName):
	return audio[audio_name]
