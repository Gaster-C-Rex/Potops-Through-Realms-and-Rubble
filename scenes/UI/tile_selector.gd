extends Sprite2D

func _process(_delta):
	var mouse = get_global_mouse_position()
	global_position = Globals.get_tile_center(mouse)
