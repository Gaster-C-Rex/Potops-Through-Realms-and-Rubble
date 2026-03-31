extends Node

@onready var background_music: AudioStreamPlayer = $BackgroundMusic

##Loads data from file to be played
func load_music_data(path: String) -> AudioStream: 
	if path.to_lower().ends_with(".wav"):
		var sound := AudioStreamWAV.load_from_file(path)
		if sound == null:
			push_error("Failed to load WAV: %s" % path)
			return null

		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_begin = 0
		# ugliest one-liner in the whole codebase, enjoy!
		sound.loop_end = sound.data.size() / ((2 if sound.stereo else 1) * (2 if sound.format == AudioStreamWAV.FORMAT_16_BITS else 1))
		return sound

	return null

##Plays background music
func play_bg_music(path: String):
	print("Attempting to play music??")
	background_music.stream = load_music_data(path)
	
	background_music.play()

##Stops background music
func stop_bg_music() -> void:
	background_music.stop()
