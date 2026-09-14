extends StaticBody2D

@onready var solid_wall = $SolidWall
@onready var sprite = $Sprite
@onready var hint_label = $HintLabel
@onready var proximity_zone = $ProximityZone

var is_open = false

func _ready():
	# Restore state: stay open after battles, close only after full reset/main menu
	if GameData.blast_door_open:
		# Silently open without animation (returning from battle)
		is_open = true
		sprite.frame = 7   # last frame of open animation
		sprite.pause()
		hint_label.visible = false
		solid_wall.set_deferred("disabled", true)
		proximity_zone.set_deferred("monitoring", false)
	else:
		sprite.frame = 0
		sprite.pause()
		hint_label.visible = false

# --- PROXIMITY DETECTION ---
func _on_proximity_zone_body_entered(body):
	# Only show the hint if the door is still locked!
	if not is_open and body.is_in_group("player"):
		hint_label.visible = true

func _on_proximity_zone_body_exited(body):
	if body.is_in_group("player"):
		hint_label.visible = false

# --- UNLOCK SEQUENCE ---
# This function is triggered by the OverrideSwitch's signal
func open_door():
	is_open = true
	GameData.blast_door_open = true
	GameData.save_data()
	
	# 1. Hide the label immediately if they are standing next to it
	hint_label.visible = false
	
	# 2. Disable the physics collision and the proximity trigger
	solid_wall.set_deferred("disabled", true)
	proximity_zone.set_deferred("monitoring", false) 
	
	# 3. Play the 7-frame sci-fi bulkhead opening animation
	sprite.play("default")
