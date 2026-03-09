extends Button

var map_id: int

func initialize(label: String, id: int):
	label.capitalize()
	text = label.left(30)
	map_id = id


func _on_pressed() -> void:
	SignalBus.map_chosen.emit(map_id)
