extends Area2D

signal switch_activated 

var is_pressed = false
@onready var sprite = $Sprite

func _ready():
	# Restore switch state so it stays green after returning from battle
	if GameData.blast_door_open:
		is_pressed = true
		sprite.frame = 1
	else:
		sprite.frame = 0 # Red/Locked

func _on_body_entered(body):
	# The moment the player touches the Area2D, trigger the switch
	if body.is_in_group("player") and not is_pressed:
		press_switch()

func press_switch():
	is_pressed = true
	
	# 1. Play your terminal click sound here if you want audio feedback
	# MusicManager.play_terminal_click() 
	
	# 2. Change visuals to Cyan/Unlocked
	sprite.frame = 1 
	
	# 3. Signal the Blast Door to open
	switch_activated.emit()
