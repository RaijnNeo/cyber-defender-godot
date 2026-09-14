extends Node2D

# ─── BATTLE DATA ──────────────────────────────────────────
const XP_MIN = 30   
const XP_MAX = 75   

var player_hp_max = 100
var player_hp     = 100
var enemy_hp_max  = 100
var enemy_hp      = 100
var player_turn         = true
var battle_active       = true
var total_damage_taken  : int = 0   

enum InputMode { NONE, WAIT_CONFIRM, WAIT_ATTACK }
var input_mode : InputMode = InputMode.NONE
var confirmed  : bool      = false

# ─── ENEMY ROSTER ─────────────────────────────────────────
const ENEMY_ROSTER = [
	{
		"name":      "Trojan Horse", "type": "Malware",
		"hp_min": 90, "hp_max": 115, "atk_min": 18, "atk_max": 31,
		"weak": "Antivirus", "strong": "Firewall",
		"tip": "Use Antivirus for bonus damage!",
		"sprite": "res://Sprites/malwares/trojan2.png",
		"can_heal": false, "heal_amt": 0, "heal_chance": 0.0,
		"can_steal": false, "steal_chance":0.0,
		"can_skip": false, "skip_chance": 0.0,
	},
	{
		"name": "Worm", "type": "Malware",
		"hp_min": 80, "hp_max": 105, "atk_min": 12, "atk_max": 22,
		"weak": "Firewall", "strong": "SQL Inject",
		"tip": "Worms spread fast — use Firewall to stop it!",
		"sprite": "res://Sprites/malwares/worm.png",
		"can_heal": true, "heal_amt": 15, "heal_chance": 0.20,
		"can_steal": false, "steal_chance":0.0,
		"can_skip": false, "skip_chance": 0.0,
	},
	{
		"name": "Spyware", "type": "Malware",
		"hp_min": 75, "hp_max": 100, "atk_min": 14, "atk_max": 22,
		"weak": "Brute Force", "strong": "Antivirus",
		"tip": "Spyware siphons your HP — hit it hard with Brute Force!",
		"sprite": "res://Sprites/malwares/spyware.png",
		"can_heal": false, "heal_amt": 0, "heal_chance": 0.0,
		"can_steal": true, "steal_chance":0.60,
		"can_skip": false, "skip_chance": 0.0,
	},
	{
		"name": "Adware", "type": "Malware",
		"hp_min": 75, "hp_max": 100, "atk_min": 14, "atk_max": 24,
		"weak": "SQL Inject", "strong": "Brute Force",
		"tip": "Adware floods your screen — SQL Inject cuts through the noise!",
		"sprite": "res://Sprites/malwares/adware.png",
		"can_heal": false, "heal_amt": 0, "heal_chance": 0.0,
		"can_steal": false, "steal_chance":0.0,
		"can_skip": true, "skip_chance": 0.30,
	},
]

var enemy_data = {}

# ─── ATTACKS ──────────────────────────────────────────────
var attacks = [
	{ "name": "Firewall",    "damage": 15, "desc": "You raised a Firewall!\nBlocked and struck back!" },
	{ "name": "Antivirus",   "damage": 20, "desc": "You unleashed Antivirus protocols!" },
	{ "name": "SQL Inject",  "damage": 25, "desc": "You injected malicious queries into the enemy!" },
	{ "name": "Brute Force", "damage": 18, "desc": "You hammered the enemy with Brute Force!" },
]

# ─── PATCHES ──────────────────────────────────────────────
var patches = [
	{ "name": "Security Patch", "heal": 15, "desc": "A basic patch was applied!\nRestored 15 HP." },
	{ "name": "Hotfix",         "heal": 25, "desc": "Emergency Hotfix deployed!\nRestored 25 HP." },
	{ "name": "Firewall Reset", "heal": 20, "desc": "Firewall systems reset!\nRestored 20 HP." },
	{ "name": "System Restore", "heal": 35, "desc": "Full System Restore!\nRestored 35 HP." },
]
var patch_thresholds = [35, 60, 80, 100]

var tex_attack_normal       : Texture2D
var tex_attack_back_pressed : Texture2D
var tex_attack_pressed      : Array[Texture2D] = []

const ATK_REGIONS = [
	Rect2(10,  10, 227, 45),   
	Rect2(243, 10, 227, 45),   
	Rect2(10,  61, 227, 45),   
	Rect2(243, 61, 227, 45),   
]
const BACK_REGION = Rect2(10, 110, 460, 28)

# ─── NODE REFERENCES ──────────────────────────────────────
@onready var player_name_label = $UI/PlayerPanel/PlayerName
@onready var player_sprite     = $Player
@onready var enemy_sprite      = $Enemy
@onready var player_hpbar_fill = $UI/PlayerPanel/HPBarFill
@onready var enemy_hpbar_fill  = $UI/EnemyPanel/HPBarFill
@onready var dialogue_label    = $UI/DialogueBox/DialogueLabel
@onready var command_menu      = $UI/Control
@onready var dialogue_box      = $UI/DialogueBox
@onready var attack_menu       = $UI/AttackMenu
@onready var attack_menu_bg    = $UI/AttackMenu/BG
@onready var enemy_name_label : Label = $UI/EnemyPanel/EnemyName
@onready var enemy_hp_label   : Label = $UI/EnemyPanel/EnemyHPLabel
@onready var sfx_damage : Array[AudioStreamPlayer2D] = []   
@onready var sfx_heal   : AudioStreamPlayer2D = $SFX4
@onready var option_btn   : AudioStreamPlayer2D = $BTL_BTN
@onready var exe_btn   : AudioStreamPlayer2D = $exe_sfx
@onready var dialogue   : AudioStreamPlayer2D = $dlg_sfx
var player_hp_label : Label # NEW!

const TYPEWRITER_SPEED = 0.03

# ─── READY ────────────────────────────────────────────────
func _ready():
	if GameData.player_name == "":
		player_name_label.text = "GUEST_USER"
	else:
		player_name_label.text = GameData.player_name
	
	if not get_tree().root.has_node("BattleHint"):
		var hint = preload("res://battle_hint.tscn").instantiate()
		get_tree().root.add_child.call_deferred(hint)
		hint.visible = true
	else:
		get_tree().root.get_node("BattleHint").visible = true
	if get_tree().root.has_node("FirstLaunchHint"):
		get_tree().root.get_node("FirstLaunchHint").visible = false
		
	dialogue_box.visible  = false
	dialogue_label.text   = ""
	command_menu.visible  = false
	attack_menu.visible   = false
	player_sprite.play("idle")
	
	# ── DYNAMICALLY CREATE PLAYER HP LABEL ──
	player_hp_label = Label.new()
	player_hp_label.add_theme_font_override("font", load("res://Sprites/PressStart2P.ttf"))
	player_hp_label.add_theme_font_size_override("font_size", 9)
	player_hp_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0))
	player_hp_label.position = Vector2(208, 141) # Matches Enemy UI offset exactly!
	player_hp_label.size = Vector2(80, 23)
	player_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_label.z_index = 10
	$UI/PlayerPanel.add_child(player_hp_label)

	tex_attack_normal       = load("res://Sprites/UI/attack_menu.png")
	tex_attack_back_pressed = load("res://Sprites/UI/attack_menu_back_pressed.png")
	for i in range(4):
		tex_attack_pressed.append(load("res://Sprites/UI/attack_menu_pressed%d.png" % i))
	attack_menu_bg.texture = tex_attack_normal
	sfx_damage = [$SFX1, $SFX2, $SFX3]

	enemy_data            = ENEMY_ROSTER[randi() % ENEMY_ROSTER.size()].duplicate()
	enemy_data["scanned"] = false
	enemy_hp_max = randi_range(enemy_data["hp_min"], enemy_data["hp_max"])
	enemy_hp     = enemy_hp_max
	enemy_sprite.texture  = load(enemy_data["sprite"])
	enemy_name_label.text = enemy_data["name"].to_upper()

	_update_hp_bar(player_hpbar_fill, player_hp, player_hp_max)
	_update_hp_bar(enemy_hpbar_fill,  enemy_hp,  enemy_hp_max)
	_update_enemy_hp_label()
	_update_player_hp_label()

	await get_tree().create_timer(1.5).timeout
	await _show_dialogue("You are faced against a " + enemy_data["name"] + "!")
	await _show_dialogue("What will you do?")
	command_menu.visible = true

func _is_tap(event) -> bool:
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false

func _input(event):
	if not _is_tap(event):
		if input_mode == InputMode.WAIT_CONFIRM:
			if event is InputEventKey and event.pressed:
				if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_Z:
					confirmed  = true
					input_mode = InputMode.NONE
					get_viewport().set_input_as_handled()
		return

	var pos = event.position

	match input_mode:
		InputMode.WAIT_CONFIRM:
			confirmed  = true
			input_mode = InputMode.NONE
			get_viewport().set_input_as_handled()

		InputMode.WAIT_ATTACK:
			var menu_rect = attack_menu.get_global_rect()
			if not menu_rect.has_point(pos):
				return

			var local   = pos - menu_rect.position
			var scale_x = 480.0 / menu_rect.size.x
			var scale_y = 148.0 / menu_rect.size.y
			var img_pos = Vector2(local.x * scale_x, local.y * scale_y)
			get_viewport().set_input_as_handled()

			if BACK_REGION.has_point(img_pos):
				exe_btn.play()
				input_mode = InputMode.NONE
				_set_attack_texture(tex_attack_back_pressed)
				await get_tree().create_timer(0.2).timeout
				attack_menu.visible  = false
				command_menu.visible = true
				_set_attack_texture(tex_attack_normal)
				return

			for i in range(4):
				if ATK_REGIONS[i].has_point(img_pos):
					exe_btn.play()
					input_mode = InputMode.NONE
					await _do_attack(i)
					return

# ─── HP BAR ───────────────────────────────────────────────
func _update_hp_bar(bar_fill: Sprite2D, current_hp: int, max_hp: int):
	var ratio = clamp(float(current_hp) / float(max_hp), 0.0, 1.0)
	bar_fill.region_rect = Rect2(0, 0, 1035.0 * ratio, 95)
	if ratio > 0.75: bar_fill.modulate = Color(0.25, 0.74, 0.24)
	elif ratio > 0.5: bar_fill.modulate = Color(0.97, 0.88, 0.11)
	elif ratio > 0.25: bar_fill.modulate = Color(0.98, 0.56, 0.14)
	else: bar_fill.modulate = Color(0.99, 0.15, 0.12)

func _update_enemy_hp_label():
	enemy_hp_label.text = str(max(0, enemy_hp)) + " / " + str(enemy_hp_max)

func _update_player_hp_label():
	if is_instance_valid(player_hp_label):
		player_hp_label.text = str(max(0, player_hp)) + " / " + str(player_hp_max)

# ─── VISUAL FLASHES ───────────────────────────────────────
func _flash_damage(sprite: Node2D):
	sprite.modulate = Color(1.0, 0.2, 0.2)
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0)
	await get_tree().create_timer(0.10).timeout
	sprite.modulate = Color(1.0, 0.2, 0.2)
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0)

func _flash_heal(sprite: Node2D):
	sprite.modulate = Color(0.4, 1.0, 0.4)
	await get_tree().create_timer(0.20).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0)
	await get_tree().create_timer(0.10).timeout
	sprite.modulate = Color(0.4, 1.0, 0.4)
	await get_tree().create_timer(0.20).timeout
	sprite.modulate = Color(1.0, 1.0, 1.0)

func _set_attack_texture(tex: Texture2D):
	attack_menu_bg.texture = tex

func _show_dialogue(message: String):
	dialogue.play()
	dialogue_box.visible = true
	dialogue_label.text  = ""
	for i in range(message.length()):
		dialogue_label.text += message[i]
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout
	await _wait_for_confirm()

func _show_dialogue_no_wait(message: String):
	dialogue.play()
	dialogue_box.visible = true
	dialogue_label.text  = ""
	for i in range(message.length()):
		dialogue_label.text += message[i]
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout

func _wait_for_confirm():
	confirmed  = false
	input_mode = InputMode.WAIT_CONFIRM
	while not confirmed:
		await get_tree().process_frame
	input_mode = InputMode.NONE

func _on_execute_pressed():
	option_btn.play()
	if not battle_active or not player_turn: return
	command_menu.visible = false
	dialogue_box.visible = false
	_set_attack_texture(tex_attack_normal)
	attack_menu.visible  = true
	input_mode           = InputMode.WAIT_ATTACK

# ─── EXECUTE ATTACK ───────────────────────────────────────
func _do_attack(index: int):
	if not battle_active: return

	_set_attack_texture(tex_attack_pressed[index])
	await get_tree().create_timer(0.25).timeout

	attack_menu.visible  = false
	dialogue_box.visible = true

	var atk      = attacks[index]
	var base_dmg = atk["damage"]

	# ── Randomise ±20% of base damage every hit ──────────────────────
	# e.g. SQL Inject base 25 → rolls between 20 and 30 each time
	var variance = int(base_dmg * 0.2)
	var damage   = base_dmg + randi_range(-variance, variance)

	# ── OVERCLOCK BUFF (applied to randomised base) ──────────────────
	if GameData.overclock_battles_left > 0:
		damage = int(damage * 1.35)
		await _show_dialogue("[OVERCLOCK ACTIVE] Attack power boosted by 35%!")

	if atk["name"] == enemy_data["weak"]:
		damage = int(damage * 1.5)
		await _show_dialogue(atk["desc"])
		await _show_dialogue("Super effective!\n" + enemy_data["name"] + " took " + str(damage) + " damage!")
	elif atk["name"] == enemy_data["strong"]:
		damage = int(damage * 0.5)
		await _show_dialogue(atk["desc"])
		await _show_dialogue(enemy_data["name"] + " resisted! Only " + str(damage) + " damage dealt.")
	else:
		await _show_dialogue(atk["desc"])
		await _show_dialogue(enemy_data["name"] + " took " + str(damage) + " damage!")

	_flash_damage(enemy_sprite)
	sfx_damage[randi() % sfx_damage.size()].play()
	enemy_hp = max(0, enemy_hp - damage)
	_update_hp_bar(enemy_hpbar_fill, enemy_hp, enemy_hp_max)
	_update_enemy_hp_label()

	if enemy_hp <= 0:
		await _show_dialogue(enemy_data["name"] + " has been neutralized!  You win!")
		battle_active = false
		command_menu.visible = false
		dialogue_box.visible = false
		
		# ── DECREMENT OVERCLOCK ON WIN ──
		if GameData.overclock_battles_left > 0:
			GameData.overclock_battles_left -= 1
			GameData.save_data()
			
		var xp_earned   = randi_range(XP_MIN, XP_MAX)
		var levels_up   = GameData.add_xp(xp_earned)
		
		# PASS ENEMY NAME TO GAMEDATA
		GameData.add_enemy_defeated(enemy_data["name"])
		
		GameData.damage_system_hp(total_damage_taken)
		await get_tree().create_timer(0.5).timeout
		await _show_result(true, xp_earned, levels_up)
		return

	await _enemy_turn()

func _on_patches_pressed():
	option_btn.play()
	if not battle_active or not player_turn: return
	command_menu.visible = false

	var roll  = randi_range(0, 99)
	var patch : Dictionary
	if roll < patch_thresholds[0]: patch = patches[0]
	elif roll < patch_thresholds[1]: patch = patches[1]
	elif roll < patch_thresholds[2]: patch = patches[2]
	else: patch = patches[3]

	await _show_dialogue("Deploying patches...")
	await _show_dialogue("You got: " + patch["name"] + "!")

	var healed = min(patch["heal"], player_hp_max - player_hp)
	player_hp  = min(player_hp_max, player_hp + patch["heal"])

	_flash_heal(player_sprite)
	sfx_heal.play()
	_update_hp_bar(player_hpbar_fill, player_hp, player_hp_max)
	_update_player_hp_label()
	await _show_dialogue(patch["desc"])

	if healed == 0:
		await _show_dialogue("But HP is already full!")

	await _enemy_turn()

func _enemy_turn():
	player_turn = false
	await get_tree().create_timer(0.8).timeout

	if enemy_data.get("can_heal", false) and randf() < enemy_data["heal_chance"]:
		var healed = min(enemy_data["heal_amt"], enemy_hp_max - enemy_hp)
		enemy_hp   = min(enemy_hp_max, enemy_hp + enemy_data["heal_amt"])
		_flash_heal(enemy_sprite)
		sfx_heal.play()
		_update_hp_bar(enemy_hpbar_fill, enemy_hp, enemy_hp_max)
		_update_enemy_hp_label()
		await _show_dialogue(enemy_data["name"] + " regenerates!\n+" + str(healed) + " HP!")

	var enemy_damage = randi_range(enemy_data["atk_min"], enemy_data["atk_max"])

	if enemy_data.get("can_steal", false) and randf() < enemy_data["steal_chance"]:
		var heal_amt = randi_range(5, 15)
		var actual_heal = min(heal_amt, enemy_hp_max - enemy_hp)
		enemy_hp = min(enemy_hp_max, enemy_hp + heal_amt)
		
		_flash_damage(player_sprite)
		sfx_damage[randi() % sfx_damage.size()].play()
		total_damage_taken += enemy_damage
		player_hp = max(0, player_hp - enemy_damage)
		_update_hp_bar(player_hpbar_fill, player_hp, player_hp_max)
		_update_player_hp_label()
		
		_flash_heal(enemy_sprite)
		sfx_heal.play()
		_update_hp_bar(enemy_hpbar_fill, enemy_hp, enemy_hp_max)
		_update_enemy_hp_label()
		
		await _show_dialogue("The Spyware siphons your credentials!")
		await _show_dialogue("It dealt " + str(enemy_damage) + " damage and healed itself for " + str(actual_heal) + " HP!")
	else:
		await _show_dialogue(enemy_data["name"] + " attacks!")
		await _show_dialogue("You took " + str(enemy_damage) + " damage!")
		_flash_damage(player_sprite)
		sfx_damage[randi() % sfx_damage.size()].play()
		total_damage_taken += enemy_damage
		player_hp = max(0, player_hp - enemy_damage)
		_update_hp_bar(player_hpbar_fill, player_hp, player_hp_max)
		_update_player_hp_label()

	if enemy_data.get("can_skip", false) and player_hp > 0 and randf() < enemy_data["skip_chance"]:
		await _show_dialogue(enemy_data["name"] + " floods your screen with pop-ups!")
		await _show_dialogue("Your interface is overwhelmed!\nYou lost your next turn!")
		await get_tree().create_timer(0.8).timeout
		await _enemy_turn()
		return

	if player_hp <= 0:
		await _show_dialogue("You have been defeated...  System compromised!")
		battle_active = false
		command_menu.visible = false
		dialogue_box.visible = false
		GameData.damage_system_hp(total_damage_taken)
		await get_tree().create_timer(0.5).timeout
		await _show_result(false, 0, 0)
		return

	player_turn          = true
	dialogue_box.visible = false
	await _show_dialogue("What will you do?")
	command_menu.visible = true

func _on_knowledges_pressed():
	option_btn.play()
	if not battle_active: return
	command_menu.visible = false

	if not enemy_data["scanned"]:
		enemy_data["scanned"] = true
		await _show_dialogue("SCANNING " + enemy_data["name"].to_upper() + "...")
		await _show_dialogue(
			enemy_data["name"].to_upper() + "\n" +
			"Type:      " + enemy_data["type"] + "\n" +
			"Weak to:   " + enemy_data["weak"] + "\n" +
			"Strong vs: " + enemy_data["strong"]
		)
		await _show_dialogue("TIP: " + enemy_data["tip"])
	else:
		await _show_dialogue(
			"[ALREADY SCANNED]\n" +
			enemy_data["name"].to_upper() + "\n" +
			"Weak to:   " + enemy_data["weak"] + "\n" +
			"Strong vs: " + enemy_data["strong"]
		)

	await _enemy_turn()

func _on_run_pressed():
	option_btn.play()
	if not battle_active: return
	battle_active        = false
	command_menu.visible = false

	if randf() < 0.5:
		await _show_dialogue("You tried to run but couldn't escape!")
		battle_active        = true
		command_menu.visible = true
		return

	await _show_dialogue_no_wait("Disconnecting...  Running away!")
	await get_tree().create_timer(1.2).timeout
	TransitionManager.fade_to_scene(GameData.current_floor_scene)

func _show_result(victory: bool, xp: int, levels_up: int):
	var result = preload("res://battle_result.tscn").instantiate()
	add_child(result)
	await result.show_result(victory, xp, levels_up)
