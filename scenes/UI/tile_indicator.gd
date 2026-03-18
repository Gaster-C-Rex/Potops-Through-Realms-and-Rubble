extends Sprite2D

func set_type(type):
	# Make sure this instance has its own AtlasTexture
	if texture:
		texture = texture.duplicate()
	var atlas := texture as AtlasTexture
	match type:
		"red":
			atlas.region = Rect2(0, 0, 64, 64)
		"green":
			atlas.region = Rect2(128, 0, 64, 64)
		"blue":
			atlas.region = Rect2(64, 0, 64, 64)
