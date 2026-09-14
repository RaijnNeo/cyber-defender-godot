extends Node

# ─── GAME DATA SINGLETON ──────────────────────────────────
# Autoload as "GameData" in Project Settings → Autoload.
#
# Tracks: XP, level, enemies defeated, hint flags,
#         player position restore, system HP, and kill counts.

const SAVE_PATH = "user://save.cfg"
const MAX_LEVEL = 30

# ─── PLAYER DATA ──────────────────────────────────────────
var player_name: String = ""
var level               : int  = 1
var current_xp          : int  = 0
var enemies_defeated    : int  = 0
var hint_overworld_seen : bool = false
var hint_battle_seen    : bool = false
var last_player_pos     : Vector2 = Vector2.ZERO
var last_login_date     : String  = ""   # "YYYY-MM-DD" format
var last_terminal_time  : float = 0.0
var mainframe_cooldown_end    : float = 0.0
var cache_cooldown_end        : float = 0.0
var mainframe_cooldown_end_f2 : float = 0.0   # Floor 2 repair terminal
var cache_cooldown_end_f2     : float = 0.0   # Floor 2 data cache
var terminal_b_online_f2      : bool  = false  # Floor 2 Terminal B unlock
var blast_door_open           : bool  = false  # Floor 2 blast door state
var overclock_battles_left : int = 0

# --- KILL COUNTS (NEW) ---
var worm_kills: int = 0
var adware_kills: int = 0
var trojan_kills: int = 0
var spyware_kills: int = 0

# ─── ROOM PROGRESSION (Badges) (NEW) ───
var pcb_sector_cleared: bool = false
var deep_blue_cleared: bool = false
var hazard_zone_cleared: bool = false

var current_floor_scene  : String = "res://Floor_1_Scenes/game.tscn"
var terminal_b_online    : bool   = false  # persists Terminal B unlock across scenes


# ─── SYSTEM HP ────────────────────────────────────────────
# System HP is the PCB's overall health shown in the overworld HUD.
# It is separate from the player's battle HP.
#
# How it changes:
#   - Decreases after every battle by 50% of total damage taken
#     (65% in Room 2, 80% in Room 3)
#   - Increases by SYSTEM_HEAL_PER_KILL each time an enemy is defeated
#   - Fully restored only at the base terminal in the overworld
#   - Never goes below 0
#
# When system_hp reaches 0:
#   - Encounter rate triples (13% → 35%)
#   - Visual warning shown in overworld
#   - No permanent stat loss — just increased pressure

const SYSTEM_HP_MAX        : int   = 100
const SYSTEM_HEAL_PER_KILL : int   = 12   # HP restored per enemy defeated
const SYSTEM_DAMAGE_ROOM1  : float = 0.25 # 25% of damage taken → system damage
const SYSTEM_DAMAGE_ROOM2  : float = 0.65
const SYSTEM_DAMAGE_ROOM3  : float = 0.80
const ENCOUNTER_RATE_NORMAL   : float = 0.13
const ENCOUNTER_RATE_CRITICAL : float = 0.35

# Daily boot drain — applied once per calendar day
const BOOT_DRAIN_PER_DAY : int = 25   # HP lost per missed day
const BOOT_DRAIN_MAX     : int = 75   # cap at 3 days regardless

var system_hp : int = SYSTEM_HP_MAX

# Current room (1, 2, or 3) — set by each room scene on _ready
var current_room : int = 1

# ─── SIGNALS ──────────────────────────────────────────────

signal level_up(new_level: int)
signal daily_boot_drain(damage: int, days_missed: int)  # fired on login if new day
signal system_hp_changed(new_hp: int)
signal system_critical()     # fires when system_hp hits 0
signal overclock_changed(charges: int)

# ─── READY ────────────────────────────────────────────────
func _ready():
	load_data()
	# Badge flags are loaded from save in load_data() — do NOT reset them here

# ─── XP REQUIRED FOR NEXT LEVEL ───────────────────────────
func xp_to_next_level() -> int:
	if level >= MAX_LEVEL:
		return 0
	return level * 100

func get_xp_to_next_level() -> int:
	return xp_to_next_level()

# ─── ADD XP ───────────────────────────────────────────────
func add_xp(amount: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	current_xp += amount
	var levels_gained = 0
	while level < MAX_LEVEL and current_xp >= xp_to_next_level():
		current_xp -= xp_to_next_level()
		level      += 1
		levels_gained += 1
		emit_signal("level_up", level)
	save_data()
	return levels_gained

# ─── ADD ENEMY DEFEATED ───────────────────────────────────
# UPDATE: Now takes the enemy name to track specific kills
func add_enemy_defeated(enemy_name: String = ""):
	enemies_defeated += 1
	
	# Track specific kills
	match enemy_name:
		"Worm": worm_kills += 1
		"Adware": adware_kills += 1
		"Trojan Horse": trojan_kills += 1
		"Spyware": spyware_kills += 1
	
	# Each kill heals system HP
	heal_system_hp(SYSTEM_HEAL_PER_KILL)
	save_data()

# ─── SYSTEM HP ────────────────────────────────────────────
func get_encounter_rate() -> float:
	if system_hp <= 0:
		return ENCOUNTER_RATE_CRITICAL
	return ENCOUNTER_RATE_NORMAL

func heal_system_hp(amount: int):
	var old = system_hp
	system_hp = min(SYSTEM_HP_MAX, system_hp + amount)
	if system_hp != old:
		emit_signal("system_hp_changed", system_hp)
	save_data()

func damage_system_hp(total_battle_damage: int):
	# Called after battle ends — applies room-scaled portion of damage taken
	var multiplier : float
	match current_room:
		2:       multiplier = SYSTEM_DAMAGE_ROOM2
		3:       multiplier = SYSTEM_DAMAGE_ROOM3
		_:       multiplier = SYSTEM_DAMAGE_ROOM1
	var sys_dmg = int(total_battle_damage * multiplier)
	system_hp   = max(0, system_hp - sys_dmg)
	emit_signal("system_hp_changed", system_hp)
	if system_hp <= 0:
		emit_signal("system_critical")
	save_data()

func restore_system_hp_full():
	# Called by the base terminal
	system_hp = SYSTEM_HP_MAX
	emit_signal("system_hp_changed", system_hp)
	save_data()

# ─── DAILY BOOT DRAIN ─────────────────────────────────────
# Called from load_data() — compares today vs saved date.
# Returns the damage dealt (0 if same day or first launch).
func _apply_daily_boot_drain() -> int:
	var today = Time.get_date_string_from_system()   # "YYYY-MM-DD"

	# First ever launch — no saved date, skip drain
	if last_login_date == "":
		last_login_date = today
		return 0

	# Same day — no drain (handles quick app switches)
	if last_login_date == today:
		return 0

	# Calculate days missed
	var saved  = Time.get_datetime_dict_from_datetime_string(last_login_date, false)
	var now    = Time.get_datetime_dict_from_datetime_string(today, false)
	var saved_unix = Time.get_unix_time_from_datetime_dict(saved)
	var now_unix   = Time.get_unix_time_from_datetime_dict(now)
	var days_missed = int((now_unix - saved_unix) / 86400)
	days_missed     = max(1, days_missed)   # at least 1

	# Apply drain — capped at BOOT_DRAIN_MAX
	var drain   = min(days_missed * BOOT_DRAIN_PER_DAY, BOOT_DRAIN_MAX)
	system_hp   = max(0, system_hp - drain)
	last_login_date = today

	if system_hp <= 0:
		emit_signal("system_critical")
	emit_signal("system_hp_changed", system_hp)
	emit_signal("daily_boot_drain", drain, days_missed)
	return drain

# ─── cooldown ─────────────────────────────────────

func set_terminal_cooldown(is_main: bool, duration: float, floor_id: int = 1):
	var current_time = Time.get_unix_time_from_system()
	if floor_id == 2:
		if is_main: mainframe_cooldown_end_f2 = current_time + duration
		else:        cache_cooldown_end_f2     = current_time + duration
	else:
		if is_main: mainframe_cooldown_end = current_time + duration
		else:        cache_cooldown_end     = current_time + duration
	save_data()

func get_cooldown_left(is_main: bool, floor_id: int = 1) -> float:
	var current_time = Time.get_unix_time_from_system()
	var end_time : float
	if floor_id == 2:
		end_time = mainframe_cooldown_end_f2 if is_main else cache_cooldown_end_f2
	else:
		end_time = mainframe_cooldown_end if is_main else cache_cooldown_end
	return max(0.0, end_time - current_time)

# ─── DIFFICULTY UNLOCKS ───────────────────────────────────
func intermediate_unlocked() -> bool:
	return level >= 10

func advanced_unlocked() -> bool:
	return level >= 20

# ─── SAVE, LOAD, & RESET ─────────────────────────────────────────────────
func save_data() -> int:
	var cfg = ConfigFile.new()
	cfg.set_value("player", "player_name", player_name)
	cfg.set_value("player", "level",                  level)
	cfg.set_value("player", "current_xp",             current_xp)
	cfg.set_value("player", "enemies_defeated",       enemies_defeated)
	cfg.set_value("player", "hint_overworld_seen",    hint_overworld_seen)
	cfg.set_value("player", "hint_battle_seen",       hint_battle_seen)
	cfg.set_value("player", "last_player_pos_x",      last_player_pos.x)
	cfg.set_value("player", "last_player_pos_y",      last_player_pos.y)
	cfg.set_value("player", "overclock_battles",      overclock_battles_left) # NEW!
	cfg.set_value("system", "system_hp",              system_hp)
	cfg.set_value("system", "last_login_date",        last_login_date)
	cfg.set_value("player", "last_terminal_time",     last_terminal_time)
	cfg.set_value("system", "mainframe_cooldown_end", mainframe_cooldown_end)
	cfg.set_value("system", "cache_cooldown_end",     cache_cooldown_end)
	
	# Save Kill Counts
	cfg.set_value("kills", "worm_kills", worm_kills)
	cfg.set_value("kills", "adware_kills", adware_kills)
	cfg.set_value("kills", "trojan_kills", trojan_kills)
	cfg.set_value("kills", "spyware_kills", spyware_kills)
	
	# Save Terminal B online state (both floors)
	cfg.set_value("system", "terminal_b_online",    terminal_b_online)
	cfg.set_value("system", "terminal_b_online_f2", terminal_b_online_f2)
	cfg.set_value("system", "blast_door_open",      blast_door_open)
	cfg.set_value("system", "mainframe_cooldown_end_f2", mainframe_cooldown_end_f2)
	cfg.set_value("system", "cache_cooldown_end_f2",     cache_cooldown_end_f2)
	
	# Save Badge States
	cfg.set_value("badges", "pcb_sector_cleared", pcb_sector_cleared)
	cfg.set_value("badges", "deep_blue_cleared", deep_blue_cleared)
	cfg.set_value("badges", "hazard_zone_cleared", hazard_zone_cleared)
	
	return cfg.save(SAVE_PATH)

func load_data():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_name = cfg.get_value("player", "player_name", "")
	level                  = cfg.get_value("player", "level",                  1)
	current_xp             = cfg.get_value("player", "current_xp",             0)
	enemies_defeated       = cfg.get_value("player", "enemies_defeated",       0)
	hint_overworld_seen    = cfg.get_value("player", "hint_overworld_seen",    false)
	hint_battle_seen       = cfg.get_value("player", "hint_battle_seen",       false)
	overclock_battles_left = cfg.get_value("player", "overclock_battles",      0) # NEW!
	last_terminal_time     = cfg.get_value("player", "last_terminal_time",     0.0)
	mainframe_cooldown_end = cfg.get_value("system", "mainframe_cooldown_end", 0.0)
	cache_cooldown_end     = cfg.get_value("system", "cache_cooldown_end",     0.0)
	
	# Load Kill Counts
	worm_kills = cfg.get_value("kills", "worm_kills", 0)
	adware_kills = cfg.get_value("kills", "adware_kills", 0)
	trojan_kills = cfg.get_value("kills", "trojan_kills", 0)
	spyware_kills = cfg.get_value("kills", "spyware_kills", 0)
	
	# Load Terminal B online state (both floors)
	terminal_b_online    = cfg.get_value("system", "terminal_b_online",    false)
	terminal_b_online_f2 = cfg.get_value("system", "terminal_b_online_f2", false)
	blast_door_open      = cfg.get_value("system", "blast_door_open",      false)
	mainframe_cooldown_end_f2 = cfg.get_value("system", "mainframe_cooldown_end_f2", 0.0)
	cache_cooldown_end_f2     = cfg.get_value("system", "cache_cooldown_end_f2",     0.0)
	
	# Load Badge States
	pcb_sector_cleared = cfg.get_value("badges", "pcb_sector_cleared", false)
	deep_blue_cleared = cfg.get_value("badges", "deep_blue_cleared", false)
	hazard_zone_cleared = cfg.get_value("badges", "hazard_zone_cleared", false)
	
	
	var px = cfg.get_value("player", "last_player_pos_x", 0.0)
	var py = cfg.get_value("player", "last_player_pos_y", 0.0)
	last_player_pos = Vector2(px, py)
	system_hp = cfg.get_value("system", "system_hp", SYSTEM_HP_MAX)
	last_login_date = cfg.get_value("system", "last_login_date", "")
	_apply_daily_boot_drain()

func reset_data():
	player_name = ""
	level                  = 1
	current_xp             = 0
	enemies_defeated       = 0
	hint_overworld_seen    = false
	hint_battle_seen       = false
	last_player_pos        = Vector2.ZERO
	system_hp              = 70  
	last_login_date        = ""
	overclock_battles_left = 0 
	
	mainframe_cooldown_end = 0.0
	cache_cooldown_end     = 0.0
	last_terminal_time     = 0.0
	
	worm_kills = 0
	adware_kills = 0
	trojan_kills = 0
	spyware_kills = 0
	
	pcb_sector_cleared  = false
	deep_blue_cleared   = false
	hazard_zone_cleared = false
	terminal_b_online      = false
	terminal_b_online_f2   = false
	blast_door_open        = false
	mainframe_cooldown_end_f2 = 0.0
	cache_cooldown_end_f2     = 0.0
	
	# ─── WIPE THE HINT UI FILE ───────────────────────────────
	# Delete the file entirely so the hint opens fresh the next
	# time the player enters the overworld — but NOT on MainMenu
	# or DifficultySelection (that guard lives in first_launch_hint.gd).
	var hint_path = "user://hint_overworld.cfg"
	if FileAccess.file_exists(hint_path):
		DirAccess.remove_absolute(hint_path)
	# Also wipe the battle hint file
	var battle_hint_path = "user://hint_battle.cfg"
	if FileAccess.file_exists(battle_hint_path):
		DirAccess.remove_absolute(battle_hint_path)
	
	# Save the main game data
	save_data()

func activate_overclock_buff():
	overclock_battles_left = 3
	emit_signal("overclock_changed", overclock_battles_left)
	save_data()
	
func _input(event):
	if not (event is InputEventKey and event.pressed):
		return

	match event.keycode:
		KEY_F9:
			MusicManager.stop_music()
			reset_data()
			# call_deferred fires after _input fully returns — same as settings queue_free()
			TransitionManager.call_deferred("fade_to_scene", "res://loading_screen.tscn")
			print("DEBUG: Save data wiped! Returning to loading screen.")

		KEY_F10:
			# Add 500 XP — enough to level up quickly
			var gained = add_xp(500)
			print("DEBUG: +500 XP added. Levels gained: %d | Now: Level %d, XP %d/%d" 				% [gained, level, current_xp, xp_to_next_level()])

		KEY_F7:
			# Jump one level directly, keep XP at 0
			if level < MAX_LEVEL:
				level += 1
				current_xp = 0
				emit_signal("level_up", level)
				save_data()
				print("DEBUG: Level forced to %d." % level)
			else:
				print("DEBUG: Already at max level %d." % MAX_LEVEL)

		KEY_F6:
			# Add 25 System HP (for testing terminal heal without waiting)
			heal_system_hp(25)
			print("DEBUG: +25 System HP. Now: %d/%d" % [system_hp, SYSTEM_HP_MAX])

		KEY_F5:
			# Drain 25 System HP (for testing critical state)
			system_hp = max(0, system_hp - 25)
			emit_signal("system_hp_changed", system_hp)
			if system_hp <= 0:
				emit_signal("system_critical")
			save_data()
			print("DEBUG: -25 System HP. Now: %d/%d" % [system_hp, SYSTEM_HP_MAX])
