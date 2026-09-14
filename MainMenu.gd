extends Node2D

# 1. Preload your new Settings scene (Change this path if you saved it in a different folder!)
const SETTINGS_SCENE = preload("res://Settings.tscn")
const PROFILE_SCENE = preload("res://profile_menu.tscn")
const NAME_INPUT_SCENE = preload("res://name_input.tscn")

# ─── NAVIGATION SIGNALS ──────────────────────────────────────────

func _on_start_pressed():
	MusicManager.play_button_click()
	# Use your existing TransitionManager to smoothly fade to the difficulty screen
	TransitionManager.fade_to_scene("res://difficulty_selection.tscn")

func _on_settings_pressed():
	MusicManager.play_button_click()
	# Instantiate the Settings overlay and add it to the screen
	var settings_menu = SETTINGS_SCENE.instantiate()
	add_child(settings_menu)
	
	# Optional: Play a cool terminal 'beep' sound here if you have one!

func _on_profile_pressed():
	MusicManager.play_button_click()
	var profile_menu = PROFILE_SCENE.instantiate()
	add_child(profile_menu)
	print("SYSTEM: Profile menu is currently locked or under construction.")

func _on_quit_pressed():
	# Safely exits the application
	MusicManager.play_button_click()
	print("SYSTEM: Shutting down...")
	get_tree().quit()

# Note: Since you removed the Handbook button from your UI, 
# you can completely delete the `_on_handbook_pressed()` function if it is still in your script!

func _ready():
	# Start the persistent background music
	MusicManager.play_menu_music()
	if GameData.player_name == "":
		var name_popup = NAME_INPUT_SCENE.instantiate()
		add_child(name_popup)
