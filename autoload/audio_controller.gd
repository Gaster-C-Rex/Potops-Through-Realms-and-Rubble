extends Node

@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var current_music: AudioStream = null

func play_bg_music(stream: AudioStream) -> void:
	if stream == null:
		push_error("play_bg_music got null stream")
		return

	current_music = stream
	background_music.stream = current_music
	background_music.play()

func stop_bg_music() -> void:
	current_music = null
	background_music.stop()

func _on_background_music_finished() -> void:
	if current_music == null:
		return

	background_music.stream = current_music
	background_music.play()
