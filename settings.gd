extends CanvasLayer

@onready var master_slider = $Panel/VBoxContainer/MasterHBox/MasterSlider
@onready var music_slider = $Panel/VBoxContainer/MusicHBox/MusicSlider
@onready var sfx_slider = $Panel/VBoxContainer/SFXHBox/SFXSlider

# Get the internal ID numbers for Godot's audio buses
var master_bus = AudioServer.get_bus_index("Master")
var music_bus  = AudioServer.get_bus_index("Music")
var sfx_bus    = AudioServer.get_bus_index("SFX")

func _ready():
	# Load current volumes when the settings menu opens
	_init_slider(master_slider, master_bus)
	_init_slider(music_slider, music_bus)
	_init_slider(sfx_slider, sfx_bus)

func _init_slider(slider: HSlider, bus_idx: int):
	# Godot uses Decibels (dB). We convert the dB back to a 0.0 to 1.0 slider value.
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))

# ─── VOLUME CONTROL SIGNALS ─────────────────────────────────────────

func _on_master_slider_value_changed(value):
	# Convert the 0.0 to 1.0 slider value into Decibels and apply it
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(value))

func _on_music_slider_value_changed(value):
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))

func _on_sfx_slider_value_changed(value):
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))

# ─── BUTTON SIGNALS ─────────────────────────────────────────────────

func _on_format_drive_btn_pressed():
	MusicManager.play_button_click()
	print("SYSTEM: Resetting all data and rebooting...")
	
	# 1. Wipe the save file
	MusicManager.stop_music()
	GameData.reset_data()
	
	# 2. Transition back to the loading screen
	# Replace "res://loading_screen.tscn" with your actual loading scene path
	TransitionManager.fade_to_scene("res://loading_screen.tscn")
	
	# 3. Remove the settings menu so it doesn't stay on top of the loading screen.
	queue_free()

func _on_quit_pressed():
	MusicManager.play_button_click()
	queue_free()
