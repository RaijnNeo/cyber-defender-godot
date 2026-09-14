extends CanvasLayer

# --- Node References ---
@onready var bg = $BG
@onready var center = $Center

@onready var main_panel = $Center/MainPanel
@onready var split = $Center/MainPanel/Split

# Left Column Nodes
@onready var id_card = $Center/MainPanel/Split/Left/IDCard
@onready var mission_label = $Center/MainPanel/Split/Left/IDCard/MissionLabel
@onready var avatar = $Center/MainPanel/Split/Left/IDCard/Avatar
@onready var name_label = $Center/MainPanel/Split/Left/IDCard/Name
@onready var level_label = $Center/MainPanel/Split/Left/IDCard/Level
@onready var xp_box = $Center/MainPanel/Split/Left/IDCard/XPBox
@onready var xp_bar = $Center/MainPanel/Split/Left/IDCard/XPBox/XPBar

# Right Column Nodes
@onready var right_col = $Center/MainPanel/Split/Right # NEW: To adjust spacing!
@onready var skills_bg = $Center/MainPanel/Split/Right/Skills
@onready var stats_box = $Center/MainPanel/Split/Right/Skills/Stats

# Malware Icons & Labels
@onready var icon_worm = $Center/MainPanel/Split/Right/Skills/Stats/Worms/Icon
@onready var count_worm = $Center/MainPanel/Split/Right/Skills/Stats/Worms/Count
@onready var icon_adware = $Center/MainPanel/Split/Right/Skills/Stats/Adware/Icon
@onready var count_adware = $Center/MainPanel/Split/Right/Skills/Stats/Adware/Count
@onready var icon_spyware = $Center/MainPanel/Split/Right/Skills/Stats/Spyware/Icon
@onready var count_spyware = $Center/MainPanel/Split/Right/Skills/Stats/Spyware/Count
@onready var icon_trojan = $Center/MainPanel/Split/Right/Skills/Stats/Trojan/Icon
@onready var count_trojan = $Center/MainPanel/Split/Right/Skills/Stats/Trojan/Count

@onready var badges_box = $Center/MainPanel/Split/Right/Badges
@onready var badge_1 = $Center/MainPanel/Split/Right/Badges/B1
@onready var badge_2 = $Center/MainPanel/Split/Right/Badges/B2
@onready var badge_3 = $Center/MainPanel/Split/Right/Badges/B3
@onready var badges_title = $Center/MainPanel/Split/Right/Label # Update path if you moved it

# Dynamic label for total kills
var label_total_kills : Label

# ── Badge tooltip ──────────────────────────────────────────────────────
var _tooltip_panel  : PanelContainer
var _tooltip_label  : Label
var _hold_timer     : SceneTreeTimer
var _hold_badge_idx : int = -1   # which badge finger is holding

# [earned_tooltip, locked_tooltip]
const BADGE_TOOLTIPS = [
	[
		"PCB SECTOR CLEARED\nCompleted Floor 1.\nSystem breach contained.",
		"[ LOCKED ]\nReach LV 10 and enter\nthe Hazard Zone.",
	],
	[
		"HAZARD ZONE CLEARED\nCompleted Floor 2.\nFirewall breach neutralized.",
		"[ LOCKED ]\nComplete Floor 2 first.",
	],
	[
		"DATA CORE CLEARED\nCompleted Floor 3.\nSystem fully restored.",
		"[ LOCKED ]\nComplete Floor 3 first.",
	],
]

func _badge_earned(idx: int) -> bool:
	match idx:
		0: return GameData.pcb_sector_cleared
		1: return GameData.hazard_zone_cleared
		2: return GameData.deep_blue_cleared
	return false

# Assets
var tex_badge_pcb = preload("res://Sprites/sub_menu/badge_pcb.png")
var tex_badge_datacore = preload("res://Sprites/sub_menu/badge_datacore.png")
var tex_badge_firewall = preload("res://Sprites/sub_menu/badge_firewall.png")

var pixel_font = preload("res://Sprites/PressStart2P.ttf")

func _ready():
	setup_layout_math()
	update_profile_data()
	_build_tooltip()
	_setup_badge_inputs()

func setup_layout_math():
	# --- BACKGROUND & CENTER ALIGNMENT ---
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7) 
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	main_panel.custom_minimum_size = Vector2(860, 480) 
	main_panel.size = Vector2(860, 480)
	
	# --- SPLIT CONTAINER (The Main Layout) ---
	split.set_anchors_preset(Control.PRESET_CENTER)
	split.custom_minimum_size = Vector2(760, 360) 
	split.add_theme_constant_override("separation", 40)

# --- ID CARD (LEFT COLUMN) CENTERING FIX ---
	id_card.custom_minimum_size = Vector2(400, 220)
	
	# SHIFTED LEFT: X moved from 45 to 20
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.position = Vector2(20, 75) 
	
	# SHIFTED LEFT: X moved from 155 to 130 to follow the avatar
	name_label.position = Vector2(130, 78) 
	level_label.position = Vector2(130, 105) 
	apply_pixel_font(name_label, 16)
	apply_pixel_font(level_label, 10)
	
	# --- XP BAR: THE "STAY INSIDE" FIX ---
	# SHIFTED LEFT: X moved to 130
	xp_box.position = Vector2(130, 133) 
	xp_box.custom_minimum_size = Vector2(240, 14) # Increased box width to give bar more room
	xp_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Bar is now 220px wide, sitting perfectly inside the 240px container
	xp_bar.position = Vector2(10, 1) 
	xp_bar.custom_minimum_size = Vector2(220, 12)
	
	mission_label.position = Vector2(30, 280) 
	mission_label.custom_minimum_size = Vector2(380, 80)
	mission_label.size = Vector2(380, 80)
	
	# Give it a brighter Cyan to make it pop against the dark background
	mission_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9)) 
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	apply_pixel_font(mission_label, 12) 
	
	update_mission_text()

func update_mission_text():
	var floor_num = GameData.current_room # Pulls from GameData[cite: 4]
	var text_out = ""
	
	match floor_num:
		1:
			text_out = "OBJECTIVE: Locate the Sector 01 terminal and stabilize the hardware."
		2:
			text_out = "OBJECTIVE: Breach the Deep Blue Datacore and bypass encryption."
		3:
			text_out = "OBJECTIVE: Purge the Hazard Zone and restore the system core."
			
	# Optional: Add a "Cyber" color tint
	mission_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0)) 
	mission_label.text = text_out

	# --- SKILL PANEL (RIGHT COLUMN) ---
	right_col.add_theme_constant_override("separation", 25)
	
	skills_bg.custom_minimum_size = Vector2(240, 220) 
	
	stats_box.position = Vector2(20, 20)
	stats_box.custom_minimum_size = Vector2(200, 180)
	stats_box.add_theme_constant_override("separation", 8) 
	
	# Malware Icons Formatting
	var all_icons = [icon_worm, icon_adware, icon_spyware, icon_trojan]
	var all_counts = [count_worm, count_adware, count_spyware, count_trojan]
	
	for i in range(all_icons.size()):
		all_icons[i].custom_minimum_size = Vector2(28, 28)
		all_icons[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		all_icons[i].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED 
		apply_pixel_font(all_counts[i], 12)
		all_counts[i].vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Total Kills Label
	if not label_total_kills:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10) 
		stats_box.add_child(spacer)
		
		label_total_kills = Label.new()
		stats_box.add_child(label_total_kills)
		apply_pixel_font(label_total_kills, 12)
		label_total_kills.add_theme_color_override("font_color", Color(0, 1, 0.8))
	
	# --- BADGES ---
	badges_box.alignment = BoxContainer.ALIGNMENT_CENTER
	badges_box.add_theme_constant_override("separation", 20)

	# Force each badge TextureRect to match the 80x80 holder size.
	# Without this the 2048px source textures render at full size.
	for badge in [badge_1, badge_2, badge_3]:
		badge.custom_minimum_size = Vector2(80, 80)
		badge.size                = Vector2(80, 80)
		badge.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
# Apply the retro font and center the text
		apply_pixel_font(badges_title, 14)
		badges_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Give it some breathing room from the slots above it
		badges_title.custom_minimum_size.y = 30 
	
	# If it's in a VBoxContainer, this will snap it to the middle
		badges_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func update_profile_data():
	name_label.text = GameData.player_name
	level_label.text = "LVL " + str(GameData.level) + ": " + get_rank_title(GameData.level)
	
	xp_bar.max_value = GameData.get_xp_to_next_level()
	xp_bar.value = GameData.current_xp
	
	count_worm.text = "Worms: " + str(GameData.worm_kills)
	count_adware.text = "Adware: " + str(GameData.adware_kills)
	count_spyware.text = "Spyware: " + str(GameData.spyware_kills)
	count_trojan.text = "Trojan: " + str(GameData.trojan_kills)
	
	# Update our dynamically created total kills label!
	# GameData.enemies_defeated tracks TOTAL enemies in your singleton
	label_total_kills.text = "TOTAL KILLS: " + str(GameData.enemies_defeated)
	
	# Auto-award PCB badge if player has reached level 10
	# (covers the case where they leveled up before the badge logic existed)
	if GameData.level >= 10 and not GameData.pcb_sector_cleared:
		GameData.pcb_sector_cleared = true
		GameData.save_data()

	var holder_tex = load("res://Sprites/sub_menu/badge_holder_empty.png")
	badge_1.texture = tex_badge_pcb    if GameData.pcb_sector_cleared  else holder_tex
	badge_2.texture = tex_badge_firewall if GameData.hazard_zone_cleared else holder_tex
	badge_3.texture = tex_badge_datacore if GameData.deep_blue_cleared   else holder_tex


func get_rank_title(level: int) -> String:
	if level >= 30: return "INCIDENT COMMANDER"
	if level >= 20: return "CYBER SPECIALIST"
	if level >= 10: return "SYSTEM ANALYST"
	return "SCRIPT KIDDIE"


# --- HELPER FUNCTION ---
func apply_pixel_font(lbl: Label, font_size: int):
	lbl.add_theme_font_override("font", pixel_font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	

# ── TOOLTIP PANEL (built once, reused for all badges) ─────────────────
func _build_tooltip():
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb           = StyleBoxFlat.new()
	sb.bg_color      = Color(0.04, 0.07, 0.16)
	sb.border_color  = Color(0.0, 0.85, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left   = 10
	sb.content_margin_right  = 10
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	_tooltip_panel.add_theme_stylebox_override("panel", sb)

	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_override("font", pixel_font)
	_tooltip_label.add_theme_font_size_override("font_size", 7)
	_tooltip_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_tooltip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_tooltip_label.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip_label.add_theme_constant_override("shadow_offset_y", 1)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_panel.add_child(_tooltip_label)

	# Add to the CanvasLayer root so it always floats on top
	add_child(_tooltip_panel)

func _show_tooltip(badge_idx: int, anchor_node: Control):
	if badge_idx < 0 or badge_idx >= BADGE_TOOLTIPS.size():
		return
	var earned = _badge_earned(badge_idx)
	var tip_pair = BADGE_TOOLTIPS[badge_idx]
	_tooltip_label.text = tip_pair[0] if earned else tip_pair[1]
	# Style: cyan border if earned, grey if locked
	var sb = _tooltip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = Color(0.0, 0.85, 1.0) if earned else Color(0.4, 0.4, 0.5)
	_tooltip_panel.visible = true

	# Position above the badge, centred on it
	await get_tree().process_frame   # let panel size itself first
	var badge_global = anchor_node.get_global_rect()
	var tip_size     = _tooltip_panel.size
	var tx = badge_global.position.x + badge_global.size.x * 0.5 - tip_size.x * 0.5
	var ty = badge_global.position.y - tip_size.y - 8
	# Clamp so it doesn't clip off screen
	var vp = get_viewport().get_visible_rect().size
	tx = clamp(tx, 4, vp.x - tip_size.x - 4)
	ty = clamp(ty, 4, vp.y - tip_size.y - 4)
	_tooltip_panel.position = Vector2(tx, ty)

func _hide_tooltip():
	_tooltip_panel.visible = false
	_hold_badge_idx = -1

# ── BADGE INPUT WIRING ────────────────────────────────────────────────
func _setup_badge_inputs():
	var badges = [badge_1, badge_2, badge_3]
	for i in range(badges.size()):
		var badge = badges[i]
		# TextureRect doesn't emit mouse signals by default
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx = i   # capture for lambda

		# PC: hover enter → show, hover exit → hide
		badge.mouse_entered.connect(func():
			_show_tooltip(idx, badge)
		)
		badge.mouse_exited.connect(func():
			_hide_tooltip()
		)

		# Mobile: long-press → show, release → hide
		badge.gui_input.connect(func(event):
			if event is InputEventScreenTouch:
				if event.pressed:
					_hold_badge_idx = idx
					# Show after 0.35s hold
					_hold_timer = get_tree().create_timer(0.35)
					_hold_timer.timeout.connect(func():
						if _hold_badge_idx == idx:
							_show_tooltip(idx, badge)
					)
				else:
					_hide_tooltip()
		)

func _on_close_btn_pressed() -> void:
	MusicManager.play_button_click()
	queue_free()
