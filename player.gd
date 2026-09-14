extends CharacterBody2D

# ─── TILE-BASED MOVEMENT SYSTEM ───────────────────────────
const TILE_SIZE = 16
const MOVE_SPEED = 4.0
const ENCOUNTER_CHANCE = 0.12

@onready var anim = $AnimatedSprite2D

var is_moving      = false
var target_pos     = Vector2.ZERO
var last_direction = "down"
var input_locked   = false

@onready var camera = $Camera2D

var ui_canvas: CanvasLayer

func _ready():
	MusicManager.stop_music()
	
	var scene_path = get_tree().current_scene.scene_file_path
	GameData.current_floor_scene = scene_path
	
	add_to_group("player")
	var hud = preload("res://player_hud.tscn").instantiate()
	add_child(hud)
	
	if not get_tree().root.has_node("FirstLaunchHint"):
		var hint = preload("res://Floor_1_Scenes/first_launch_hint.tscn").instantiate()
		get_tree().root.add_child(hint)    
	if get_tree().current_scene.scene_file_path == "res://floor_2.tscn":
		if not get_tree().root.has_node("Floor2Hint"):
			var hint2 = preload("res://Floor_2_Scenes/floor2_hint.tscn").instantiate()
			get_tree().root.add_child(hint2)

	if GameData.last_player_pos != Vector2.ZERO:
		position   = GameData.last_player_pos
		target_pos = position
		GameData.last_player_pos = Vector2.ZERO
	else:
		position = (position / TILE_SIZE).floor() * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		target_pos = position

	if get_tree().root.has_node("FirstLaunchHint"):
		get_tree().root.get_node("FirstLaunchHint").visible = true
	if get_tree().root.has_node("BattleHint"):
		get_tree().root.get_node("BattleHint").visible = false
	_create_exit_button()
	
	_cinematic_zoom_out()

func _cinematic_zoom_out():
	if not camera: return # Safety check just in case

	# 1. Save the target zoom (whatever you set it to in the Inspector)
	var target_zoom = camera.zoom
	
	# 2. Instantly zoom the camera WAY in on the player
	# (Multiply by 2.5 to zoom in. Increase this number to start even closer!)
	camera.zoom = target_zoom * 2.5 
	
	# 3. Create a Tween to animate it back out
	var tween = create_tween()
	
	# 4. Make the animation smooth (Starts fast, slows down as it finishes)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	# 5. Animate the "zoom" property back to target_zoom over 1.5 seconds
	tween.tween_property(camera, "zoom", target_zoom, 2)

func _physics_process(delta):
	if input_locked:
		return
	if is_moving:
		_process_movement(delta)
	else:
		_process_input()


func _process_movement(delta):
	position.x = move_toward(position.x, target_pos.x, TILE_SIZE * MOVE_SPEED * delta)
	position.y = move_toward(position.y, target_pos.y, TILE_SIZE * MOVE_SPEED * delta)
	if position == target_pos:
		position = target_pos
		is_moving = false
		_check_encounter()


func _process_input():
	var direction = Vector2.ZERO
	var joystick = get_parent().get_node_or_null("MobileUI/VirtualJoystick")
	
	if joystick and joystick.is_pressed:
		var joy = joystick.output
		if abs(joy.x) > abs(joy.y):
			if joy.x > 0.1:
				direction = Vector2.RIGHT
				last_direction = "right"
			elif joy.x < -0.1:
				direction = Vector2.LEFT
				last_direction = "left"
		else:
			if joy.y > 0.1:
				direction = Vector2.DOWN
				last_direction = "down"
			elif joy.y < -0.1:
				direction = Vector2.UP
				last_direction = "up"
	
	if direction == Vector2.ZERO:
		if Input.is_action_pressed("ui_right"):
			direction = Vector2.RIGHT
			last_direction = "right"
		elif Input.is_action_pressed("ui_left"):
			direction = Vector2.LEFT
			last_direction = "left"
		elif Input.is_action_pressed("ui_down"):
			direction = Vector2.DOWN
			last_direction = "down"
		elif Input.is_action_pressed("ui_up"):
			direction = Vector2.UP
			last_direction = "up"

	if direction == Vector2.ZERO:
		_play_idle()
		return

	_play_walk()
	var next_pos = position + direction * TILE_SIZE
	if _is_tile_blocked(next_pos):
		return
	target_pos = next_pos
	is_moving = true


func _is_tile_blocked(world_pos: Vector2) -> bool:
	var tilemap = get_parent().get_node_or_null("TileMap")
	if tilemap == null:
		return false
	var tile_pos = tilemap.local_to_map(world_pos - Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0))
	var source_id = tilemap.get_cell_source_id(0, tile_pos)
	if source_id == -1:
		return true
	var tile_data = tilemap.get_cell_tile_data(0, tile_pos)
	if tile_data == null:
		return false
	if tile_data.get_collision_polygons_count(0) > 0:
		return true
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position       = world_pos
	query.exclude        = [self]
	query.collision_mask = 1
	var result = space.intersect_point(query)
	return result.size() > 0


func _play_walk():
	var target_anim = "walk_" + last_direction
	if anim.animation != target_anim:
		anim.play(target_anim)
	elif not anim.is_playing():
		anim.play(target_anim)

func _play_idle():
	var target_anim = "walk_" + last_direction
	if anim.animation != target_anim:
		anim.play(target_anim)
	anim.pause()


func _check_encounter():
	var tilemap = get_parent().get_node_or_null("TileMap")
	if tilemap == null:
		return
	var tile_pos = tilemap.local_to_map(position - Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0))
	var tile_data = tilemap.get_cell_tile_data(0, tile_pos)
	if tile_data == null:
		return
	var is_encounter_tile = tile_data.get_custom_data("encounter")
	if is_encounter_tile:
		var roll = randf()
		if roll < GameData.get_encounter_rate():
			_trigger_encounter()


func _trigger_encounter():
	input_locked = true
	set_meta("in_encounter", true)   # Flag so shuttle tween doesn't re-unlock us
	anim.pause()
	GameData.last_player_pos = position
	GameData.save_data()
	var encounter_ui = get_parent().get_node_or_null("EncounterUI")
	if encounter_ui:
		await encounter_ui.show_encounter()
	set_meta("in_encounter", false)
	input_locked = false


func enter_battle_stance():
	input_locked = true
	velocity = Vector2.ZERO
	anim.play("walk_down")
	anim.pause()


# ─── OVERWORLD UI (Settings & Exit) ──────────────────────────────
func _create_exit_button():
	# Check if it already exists to avoid duplicates
	if get_node_or_null("OverworldUICanvas"):
		return
	
	# 1. Create ONLY ONE CanvasLayer and assign it to the variable
	ui_canvas = CanvasLayer.new() 
	ui_canvas.name = "OverworldUICanvas"
	ui_canvas.layer = 5
	add_child(ui_canvas)

# --- EXIT BUTTON (The Reference) ---
	var btn_exit = TextureButton.new()
	btn_exit.texture_normal  = load("res://Sprites/UI/btn_x.png")
	btn_exit.texture_pressed = load("res://Sprites/UI/btn_x_pressed.png")
	btn_exit.ignore_texture_size = true
	btn_exit.custom_minimum_size = Vector2(48, 48) # Standard size
	
	btn_exit.set_anchor(SIDE_LEFT, 1); btn_exit.set_anchor(SIDE_RIGHT, 1)
	btn_exit.set_anchor(SIDE_TOP, 0); btn_exit.set_anchor(SIDE_BOTTOM, 0)
	
	btn_exit.set_offset(SIDE_LEFT, -68)
	btn_exit.set_offset(SIDE_RIGHT, -10)
	btn_exit.set_offset(SIDE_TOP, 8) # Starts at 8px down
	btn_exit.set_offset(SIDE_BOTTOM, 58)
	
	ui_canvas.add_child(btn_exit)
	btn_exit.pressed.connect(_on_exit_pressed)

	# --- SETTINGS BUTTON (The Fix) ---
	var btn_settings = TextureButton.new()
	btn_settings.texture_normal = load("res://Sprites/Buttons/btn_settings_normal.png")
	btn_settings.texture_pressed = load("res://Sprites/Buttons/btn_settings_pressed_in.png")
	btn_settings.ignore_texture_size = true
	
	# We bump this to 68 to really fill that space
	btn_settings.custom_minimum_size = Vector2(80, 80) 
	
	btn_settings.set_anchor(SIDE_LEFT, 1); btn_settings.set_anchor(SIDE_RIGHT, 1)
	btn_settings.set_anchor(SIDE_TOP, 0); btn_settings.set_anchor(SIDE_BOTTOM, 0)
	
	# Shifted further left to account for the size increase
	# Exit is at -68, so we start this at -142 (-68 - 68 - 6 gap)
	btn_settings.set_offset(SIDE_LEFT, -120)
	btn_settings.set_offset(SIDE_RIGHT, -74)
	
	# THE FIX: We move the top down to 12. 
	# This accounts for the larger box and aligns the bottom of the buttons.
	btn_settings.set_offset(SIDE_TOP, 16) 
	btn_settings.set_offset(SIDE_BOTTOM, 80)
	
	ui_canvas.add_child(btn_settings)
	btn_settings.pressed.connect(_on_settings_pressed)
	
func _on_settings_pressed():
	if get_tree().root.has_node("Settings"):
		return
	
	MusicManager.play_button_click()
	
	# HIDE the overworld buttons
	if ui_canvas:
		ui_canvas.visible = false
		
	var settings_scene = preload("res://Settings.tscn").instantiate()
	settings_scene.name = "Settings"
	get_tree().root.add_child(settings_scene)
	
	# Connect to the 'tree_exited' signal so buttons reappear when settings is closed
	settings_scene.tree_exited.connect(func(): if ui_canvas: ui_canvas.visible = true)

func _on_exit_pressed():
	MusicManager.play_button_click()
	TransitionManager.fade_to_scene("res://mainmenu.tscn")

func exit_battle_stance():
	input_locked = false
