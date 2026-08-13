extends Node

const SETTINGS_PATH := "user://sky_ball_run.cfg"
const DEFAULT_MASTER_VOLUME := 0.78
const DEFAULT_MUSIC_ENABLED := true
const DEFAULT_FULLSCREEN := false

var master_volume := DEFAULT_MASTER_VOLUME
var music_enabled := DEFAULT_MUSIC_ENABLED
var fullscreen := DEFAULT_FULLSCREEN

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		master_volume = DEFAULT_MASTER_VOLUME
		music_enabled = DEFAULT_MUSIC_ENABLED
		fullscreen = DEFAULT_FULLSCREEN
		save_settings()
		return
	master_volume = clamp(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	music_enabled = bool(config.get_value("audio", "music_enabled", DEFAULT_MUSIC_ENABLED))
	fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)

func apply_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(max(master_volume, 0.0001)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	save_settings()
	apply_settings()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	save_settings()
	apply_settings()
