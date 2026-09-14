extends CanvasLayer

@onready var name_edit = $Panel/VBoxContainer/NameEdit
@onready var confirm_btn = $Panel/VBoxContainer/ConfirmBtn

func _ready():
	# Automatically put the typing cursor in the box so they don't have to click it
	name_edit.grab_focus()

func _on_confirm_btn_pressed():
	# .strip_edges() removes accidental spaces at the start/end
	$ButtonSfx.play()
	var entered_name = name_edit.text.strip_edges()
	
	if entered_name == "":
		# Don't let them submit an empty name!
		name_edit.placeholder_text = "ENTER A NAME"
		return
		
	# Save to the global autoload
	GameData.player_name = entered_name
	GameData.save_data()
	
	# Play your button sound
	MusicManager.play_button_click()
	
	# Destroy the popup, returning them to the main menu
	queue_free()

func _on_name_edit_text_submitted(_new_text):
	# This allows the player to just press the "Enter" key on their keyboard
	_on_confirm_btn_pressed()
