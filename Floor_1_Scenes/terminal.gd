extends Area2D

# ── EXPORT VARIABLES ───────────────────────────────────────────────
@export var is_main_terminal : bool = false
@export var floor_id         : int  = 1    # Set to 2 for Floor 2 terminals
var cooldown_seconds : float = 300.0 

var is_online : bool = false
var player_in_range : bool = false
var is_on_cooldown : bool = false
var is_displaying_message : bool = false 

@onready var terminal_sprite = $TerminalSprite
@onready var ring_sprite = $RingSprite
@onready var interact_label = $InteractLabel
@onready var err_sfx   : AudioStreamPlayer2D = $err_sfx   

# ── INITIALIZATION ────────────────────────────────────────────────
func _ready():
	if not is_main_terminal:
		add_to_group("sub_terminals")
		# Restore online state from GameData per floor — keeps floors independent
		is_online = GameData.terminal_b_online_f2 if floor_id == 2 else GameData.terminal_b_online
		cooldown_seconds = 600.0 # 10 Minutes
	else:
		is_online = true
		cooldown_seconds = 300.0 # 5 Minutes

	# NEW: Check if it should be on cooldown the moment the map loads!
	if GameData.get_cooldown_left(is_main_terminal, floor_id) > 0:
		is_on_cooldown = true

	update_visuals()

# ── REAL-TIME UPDATES ─────────────────────────────────────────────
func _process(_delta):
	# NEW: Always ask GameData for the true time remaining
	var time_left = GameData.get_cooldown_left(is_main_terminal, floor_id)
	
	if time_left > 0:
		is_on_cooldown = true
		if player_in_range and not is_displaying_message:
			var minutes = int(time_left) / 60
			var seconds = int(time_left) % 60
			interact_label.text = "[RECHARGING: %d:%02d]" % [minutes, seconds]
	elif is_on_cooldown:
		# Time just ran out! Turn it back on.
		is_on_cooldown = false
		update_visuals()

# ── PROXIMITY DETECTION ───────────────────────────────────────────
func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		update_visuals()

func _on_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		update_visuals()

# ── VISUAL STATE MACHINE ──────────────────────────────────────────
func update_visuals():
	if is_displaying_message:
		interact_label.visible = player_in_range
		ring_sprite.visible = (player_in_range and not is_on_cooldown)
		return

	if player_in_range:
		interact_label.visible = true
		ring_sprite.visible = not is_on_cooldown 
	else:
		ring_sprite.visible = false
		interact_label.visible = false

	if is_on_cooldown:
		terminal_sprite.play("offline")
		interact_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5)) 
		return

	if not is_online:
		terminal_sprite.play("offline")
		ring_sprite.modulate = Color(1, 0.2, 0.2, 0.8) 
		interact_label.text = "[... OFFLINE]"
		interact_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2)) 
	else:
		if is_main_terminal:
			interact_label.text = "[REPAIR TERMINAL]"
		else:
			interact_label.text = "[DATA CACHE]"
			
		interact_label.add_theme_color_override("font_color", Color(0, 1, 1)) 
		
		if player_in_range:
			terminal_sprite.play("glow")
			ring_sprite.modulate = Color(0, 1, 1, 1.0) 
		else:
			terminal_sprite.play("online")

# ── DYNAMIC ON-SCREEN FEEDBACK ────────────────────────────────────
func show_system_message(msg: String, color: Color, duration: float = 1.5):
	is_displaying_message = true
	interact_label.text = msg
	interact_label.add_theme_color_override("font_color", color)
	
	await get_tree().create_timer(duration).timeout
	
	is_displaying_message = false
	update_visuals()

# ── INTERACTION LOGIC (KEYBOARD & MOUSE) ──────────────────────────
func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("ui_accept"): 
		attempt_interaction()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_mouse = get_local_mouse_position()
		var label_rect = interact_label.get_rect()
		var clicked_text = interact_label.visible and label_rect.has_point(local_mouse)
		
		var tex = terminal_sprite.sprite_frames.get_frame_texture(terminal_sprite.animation, terminal_sprite.frame)
		var sprite_rect = Rect2()
		
		if terminal_sprite.centered:
			sprite_rect = Rect2(terminal_sprite.position - (tex.get_size() / 2), tex.get_size())
		else:
			sprite_rect = Rect2(terminal_sprite.position + terminal_sprite.offset, tex.get_size())
			
		var clicked_sprite = sprite_rect.has_point(local_mouse)

		if clicked_text or clicked_sprite:
			get_viewport().set_input_as_handled() 
			if player_in_range:
				attempt_interaction()

# ── ROUTING THE INTERACTION ───────────────────────────────────────
func attempt_interaction():
	# ─── ADD YOUR NEW SOUND EFFECT HERE ───
	
	if is_displaying_message:
		err_sfx.play()  # Terminal busy — same rejection sound as cooldown
		return 

	if is_on_cooldown:
		err_sfx.play()
		show_system_message("[STILL RECHARGING]", Color(1, 0.2, 0.2))
		return

	if is_main_terminal:
		MusicManager.play_terminal_click() 
		handle_terminal_A()
	elif is_online:
		handle_terminal_B()
	else:
		err_sfx.play()
		show_system_message("[REQUIRES MAINFRAME]", Color(1, 0.2, 0.2))

# ── TERMINAL EFFECTS ──────────────────────────────────────────────
func handle_terminal_A():
	get_tree().call_group("sub_terminals", "turn_online")
	get_tree().call_group("hint_ui", "trigger_new_entry", "unlocked_subroutine")

	if GameData.system_hp >= GameData.SYSTEM_HP_MAX:
		show_system_message("[SYSTEM NOMINAL]", Color(0, 1, 1))
		return
		
	GameData.heal_system_hp(30)
	await show_system_message("[SYSTEM RESTORED]", Color(0.2, 1.0, 0.4)) 
	start_cooldown()

func handle_terminal_B():
	MusicManager.play_terminal_click()
	GameData.add_xp(25) 
	GameData.activate_overclock_buff() 
	GameData.heal_system_hp(15)
	
	get_tree().call_group("hint_ui", "trigger_new_entry", "unlocked_overclock")
	await show_system_message("[OVERCLOCK ACTIVATED]", Color(1.0, 0.5, 0.0))
	start_cooldown()

# ── COOLDOWN TIMER ────────────────────────────────────────────────
func start_cooldown():
	# NEW: Tell GameData to start the persistent timer
	GameData.set_terminal_cooldown(is_main_terminal, cooldown_seconds, floor_id)
	is_on_cooldown = true
	update_visuals()

# ── METROIDVANIA UNLOCK TRIGGER ───────────────────────────────────
func turn_online():
	if not is_online:
		is_online = true
		# Persist per floor so floors don't share unlock state
		if floor_id == 2:
			GameData.terminal_b_online_f2 = true
		else:
			GameData.terminal_b_online = true
		GameData.save_data()
		update_visuals()
