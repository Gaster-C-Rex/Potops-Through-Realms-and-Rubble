## The camera controller automatically calculates the bounds of the current map
## to set scrolling limits. It currently follows around the player node. It will
## need to be able to toggle a fixed and scrolling mode for combat sequences.

extends Camera2D

## Sets the camera's limit variables to the given rectangle
func apply_limits(limiting_rect: Rect2) -> void:
	limit_left = limiting_rect.position.x
	limit_right = limiting_rect.size.x
	limit_top = limiting_rect.position.y
	limit_bottom = limiting_rect.size.y
