extends Control

const SAVE_PATH = "user://settings.cfg"

@onready var play_btn: Button = $VBox/PlayBtn
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var volume_slider: HSlider = $VBox/VolumeCenter/VolumeRow/VolumeSlider

func _ready() -> void:
	play_btn.pressed.connect(_start_game)

	var stream = music_player.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music_player.play()

	var bus = AudioServer.get_bus_index("Master")
	var saved_volume = _load_volume()
	AudioServer.set_bus_volume_db(bus, linear_to_db(saved_volume))
	volume_slider.value = saved_volume

	volume_slider.value_changed.connect(func(val):
		AudioServer.set_bus_volume_db(bus, linear_to_db(val))
		_save_volume(val)
	)

func _save_volume(val: float) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "volume", val)
	cfg.save(SAVE_PATH)

func _load_volume() -> float:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return cfg.get_value("audio", "volume", 1.0)
	return 1.0

func _start_game() -> void:
	GameData.current_level_index = 0
	get_tree().change_scene_to_file("res://scenes/KitchenLevel.tscn")
