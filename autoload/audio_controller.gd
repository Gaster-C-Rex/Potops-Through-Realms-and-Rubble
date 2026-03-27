extends Node

@onready var background_music: AudioStreamPlayer = $BackgroundMusic

##Loads data from file to be played
func load_music_data(path: String):
	var file = FileAccess.open(path, FileAccess.READ)

	if path.to_lower().ends_with(".wav"):
		background_music.pitch_scale = 2.0 #pitch correcting
		var sound = AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.data = file.get_buffer(file.get_length())
		return sound

	if path.to_lower().ends_with(".mp3"):
		background_music.pitch_scale = 1.0
		var sound = AudioStreamMP3.new()
		sound.data = file.get_buffer(file.get_length())
		return sound

	if path.to_lower().ends_with(".ogg"):
		background_music.pitch_scale = 1.0
		var sound = AudioStreamOggVorbis.new()
		sound.data = file.get_buffer(file.get_length())
		return sound

	return null

##Plays background music
func play_bg_music(path: String):
	background_music.stream = load_music_data(path)
	background_music.play()

func stop_bg_music() -> void:
	background_music.stop()
