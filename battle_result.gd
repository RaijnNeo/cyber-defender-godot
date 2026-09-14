extends CanvasLayer

# ─── BATTLE RESULT OVERLAY ────────────────────────────────
# Scene tree: battle_result.tscn
#
#   CanvasLayer  "BattleResult"
#   ├── Backdrop     (ColorRect)
#   └── Panel        (PanelContainer)
#       └── VBox     (VBoxContainer)
#           ├── TitleLabel    (Label)
#           ├── Separator     (HSeparator)
#           ├── XPLabel       (Label)
#           ├── LevelLabel    (Label)
#           ├── SysDmgLabel   (Label)   ← NEW: shows system HP damage
#           └── ContinueBTN   (Button)

const COLOR_VICTORY  = Color(0.10, 0.80, 0.30)
const COLOR_DEFEAT   = Color(0.90, 0.15, 0.15)
const COLOR_XP       = Color(0.95, 0.85, 0.20)
const COLOR_LEVEL_UP = Color(0.20, 0.90, 1.00)
const COLOR_SYS_DMG  = Color(1.00, 0.40, 0.40)
const COLOR_SYS_HEAL = Color(0.20, 1.00, 0.50)

@onready var backdrop     : ColorRect      = $Backdrop
@onready var panel        : PanelContainer = $Panel
@onready var title_label  : Label          = $Panel/VBox/TitleLabel
@onready var xp_label     : Label          = $Panel/VBox/XPLabel
@onready var level_label  : Label          = $Panel/VBox/LevelLabel
@onready var sys_dmg_label: Label          = $Panel/VBox/SysDmgLabel
@onready var continue_btn : Button         = $Panel/VBox/ContinueBTN

func _ready():
	layer            = 10
	visible          = false
	backdrop.color   = Color(0, 0, 0, 0)
	panel.modulate.a = 0.0
	continue_btn.pressed.connect(_on_continue_pressed)

func show_result(victory: bool, xp: int = 0, levels_up: int = 0):
	visible = true

	# ── System HP info ─────────────────────────────────────
	var sys_ratio = float(GameData.system_hp) / float(GameData.SYSTEM_HP_MAX)
	var sys_color : Color
	if sys_ratio > 0.5:
		sys_color = COLOR_SYS_HEAL
	elif sys_ratio > 0.25:
		sys_color = COLOR_XP
	else:
		sys_color = COLOR_SYS_DMG

	sys_dmg_label.visible = true
	if GameData.system_hp <= 0:
		sys_dmg_label.text = "SYSTEM CRITICAL!\nSECTOR COMPROMISED"
		sys_dmg_label.add_theme_color_override("font_color", COLOR_SYS_DMG)
	else:
		sys_dmg_label.text = "SYSTEM HP: " + str(GameData.system_hp) + " / " + str(GameData.SYSTEM_HP_MAX)
		sys_dmg_label.add_theme_color_override("font_color", sys_color)

	if victory:
		title_label.text = ">> VICTORY <<"
		title_label.add_theme_color_override("font_color", COLOR_VICTORY)
		xp_label.text    = "+ " + str(xp) + " XP EARNED"
		xp_label.add_theme_color_override("font_color", COLOR_XP)

		if levels_up > 0:
			level_label.visible = true
			level_label.text    = "LEVEL UP!   LV " + str(GameData.level)
			level_label.add_theme_color_override("font_color", COLOR_LEVEL_UP)
		else:
			level_label.visible = false
			var needed = GameData.xp_to_next_level()
			if needed > 0:
				xp_label.text += "\n" + str(GameData.current_xp) + " / " + str(needed) + " XP"
	else:
		title_label.text = ">> DEFEATED <<"
		title_label.add_theme_color_override("font_color", COLOR_DEFEAT)
		xp_label.text    = "SYSTEM COMPROMISED\nNO XP GAINED"
		xp_label.add_theme_color_override("font_color", COLOR_DEFEAT)
		level_label.visible = false

	panel.pivot_offset = panel.size / 2.0
	panel.scale        = Vector2(0.8, 0.8)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "color",       Color(0,0,0,0.65), 0.35)
	tween.tween_property(panel,    "modulate:a",   1.0,               0.30)
	tween.tween_property(panel,    "scale",        Vector2(1.0,1.0),  0.30) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

func _on_continue_pressed():
	continue_btn.disabled = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(backdrop, "color",      Color(0,0,0,0), 0.25)
	tween.tween_property(panel,    "modulate:a", 0.0,            0.25)
	await tween.finished
	TransitionManager.fade_to_scene(GameData.current_floor_scene)
