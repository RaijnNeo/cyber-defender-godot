extends CanvasLayer

# ================================================================
# CYBER DEFENDER — Player Stats HUD (overworld only)
# ================================================================

const PANEL_W  = 200
const BORDER_W = 4
const BAR_W    = 160

@onready var _tab_btn      : Button         = $TabBtn
@onready var _panel        : PanelContainer = $Panel
@onready var _kill_count   : Label          = $Panel/VBox/KillCount
@onready var _kill_title   : Label          = $Panel/VBox/KillTitle
@onready var _sys_title    : Label          = $Panel/VBox/SysTitle
@onready var _sys_bar_fill : PanelContainer = $Panel/VBox/SysBarBG/SysBarFill
@onready var _sys_hp_sub   : Label          = $Panel/VBox/SysHPSub
@onready var _lvl_num      : Label          = $Panel/VBox/LvlNum
@onready var _bar_fill     : PanelContainer = $Panel/VBox/BarBG/BarFill
@onready var _lvl_sub      : Label          = $Panel/VBox/LvlSub
@onready var _lock_note    : Label          = $Panel/VBox/LockNote

var _font           : Font
var _is_open        : bool  = false
var _panel_open_x   : float = 0.0
var _panel_closed_x : float = 0.0
var _panel_target_x : float = 0.0
var _close_btn      : Button = null
var _overclock_lbl  : Label = null 

# ── READY ──────────────────────────────────────────────────
func _ready():
	_font = load("res://Sprites/PressStart2P.ttf")
	call_deferred("_init_ui")
	GameData.system_hp_changed.connect(_on_system_hp_changed)
	GameData.overclock_changed.connect(_on_overclock_changed)

func _init_ui():
	var sw = get_viewport().get_visible_rect().size.x
	_panel_open_x   = sw - PANEL_W
	_panel_closed_x = sw + 10.0
	_panel_target_x = _panel_closed_x
	_apply_styles()
	_build_close_button()
	_connect_signals()
	_refresh_display()
	_set_panel_x(_panel_closed_x)

func _build_close_button():
	var vbox = _panel.get_node_or_null("VBox")
	if vbox == null:
		return
	var row = HBoxContainer.new()
	row.name = "CloseRow"
	row.add_theme_constant_override("separation", 0)
	vbox.add_child(row)
	vbox.move_child(row, 0)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_close_btn = Button.new()
	_close_btn.text = "[X]"
	_close_btn.custom_minimum_size = Vector2(36, 18)
	_close_btn.add_theme_font_override("font", _font)
	_close_btn.add_theme_font_size_override("font_size", 7)
	_close_btn.add_theme_color_override("font_color",         Color(1.0, 0.3, 0.3))
	_close_btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.6, 0.6))
	_close_btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	_close_btn.add_theme_stylebox_override("normal",  _make_sb(Color(0.04,0.08,0.16), Color(1.0,0.3,0.3,0.5), 2, 4))
	_close_btn.add_theme_stylebox_override("hover",   _make_sb(Color(0.18,0.05,0.05), Color(1.0,0.3,0.3),     2, 4))
	_close_btn.add_theme_stylebox_override("pressed", _make_sb(Color(1.0,0.3,0.3),    Color(1.0,0.3,0.3),     2, 4))
	_close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(_close_btn)
	_close_btn.pressed.connect(_close_panel)

# ── STYLES ─────────────────────────────────────────────────
func _apply_styles():
	var fsm = 8
	
	_panel.set_anchor(SIDE_LEFT,   0)
	_panel.set_anchor(SIDE_RIGHT,  0)
	_panel.set_anchor(SIDE_TOP,    0.5) 
	_panel.set_anchor(SIDE_BOTTOM, 0.5) 
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH 
	_panel.set_offset(SIDE_TOP,    0)
	_panel.set_offset(SIDE_BOTTOM, 0)
	_set_panel_x(_panel_closed_x)

	var ps = StyleBoxFlat.new()
	ps.bg_color     = Color(0.04, 0.08, 0.16, 0.97)
	ps.border_color = Color(0.05, 0.75, 1.0)
	ps.set_border_width_all(BORDER_W)
	ps.set_corner_radius_all(0)
	ps.content_margin_left   = 10
	ps.content_margin_right  = 10
	ps.content_margin_top    = 6  # <-- REDUCED FROM 12: Shifts the whole stack UP!
	ps.content_margin_bottom = 28 
	_panel.add_theme_stylebox_override("panel", ps)

	var vbox = _panel.get_node_or_null("VBox")
	if vbox:
		vbox.add_theme_constant_override("separation", 6)
		
		# ── NEW: INVISIBLE SPACER ──
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 14) # Forces 14px of breathing room
		vbox.add_child(spacer)
		
		# ── OVERCLOCK LABEL CREATION ──
		_overclock_lbl = Label.new()
		_style_lbl(_overclock_lbl, 8, Color(1.0, 0.5, 0.0))
		vbox.add_child(_overclock_lbl)
		# NOTE: We are NOT calling move_child here. It will perfectly append to the very bottom!

	_kill_title.text = "MALWARE\nKILLED"
	_style_lbl(_kill_title, fsm, Color(0.45, 0.45, 0.45))
	_style_lbl(_kill_count, 16,  Color(0.1,  0.9,  1.0))

	# System HP section
	_sys_title.text = "SYSTEM HP"
	_style_lbl(_sys_title,  fsm, Color(0.45, 0.45, 0.45))
	_style_lbl(_sys_hp_sub, fsm, Color(0.6,  0.6,  0.6))

	var sys_bar_bg = _sys_bar_fill.get_parent()
	if sys_bar_bg:
		sys_bar_bg.custom_minimum_size   = Vector2(BAR_W, 8)
		sys_bar_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var bgs = StyleBoxFlat.new()
		bgs.bg_color     = Color(0.08, 0.12, 0.20)
		bgs.border_color = Color(0.05, 0.75, 1.0, 0.4)
		bgs.set_border_width_all(1)
		bgs.set_corner_radius_all(0)
		bgs.set_content_margin_all(0)
		sys_bar_bg.add_theme_stylebox_override("panel", bgs)

	_sys_bar_fill.custom_minimum_size = Vector2(0, 8)
	_sys_bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	_style_lbl(_lvl_num,   9,   Color(0.2, 1.0, 0.4))
	_style_lbl(_lvl_sub,   fsm, Color(0.6, 0.6, 0.6))
	_style_lbl(_lock_note, 7,   Color(0.5, 0.5, 0.5))
	_lock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for path in ["$Panel/VBox/KillSub", "$Panel/VBox/LvlTitle"]:
		var n = get_node_or_null(path)
		if n:
			_style_lbl(n, fsm, Color(0.45, 0.45, 0.45))

	for path in ["$Panel/VBox/Divider1", "$Panel/VBox/Divider2", "$Panel/VBox/Divider3"]:
		var n = get_node_or_null(path)
		if n:
			n.text      = "* * * * * * * * * *"
			n.clip_text = true
			_style_lbl(n, 7, Color(0.05, 0.75, 1.0, 0.35))

	var bar_bg = get_node_or_null("$Panel/VBox/BarBG")
	if bar_bg:
		bar_bg.custom_minimum_size   = Vector2(BAR_W, 8)
		bar_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var bgs2 = StyleBoxFlat.new()
		bgs2.bg_color     = Color(0.08, 0.12, 0.20)
		bgs2.border_color = Color(0.05, 0.75, 1.0, 0.4)
		bgs2.set_border_width_all(1)
		bgs2.set_corner_radius_all(0)
		bgs2.set_content_margin_all(0)
		bar_bg.add_theme_stylebox_override("panel", bgs2)

	_bar_fill.custom_minimum_size = Vector2(0, 8)
	_bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bfs = StyleBoxFlat.new()
	bfs.bg_color = Color(0.2, 1.0, 0.4)
	bfs.set_border_width_all(0)
	bfs.set_corner_radius_all(0)
	bfs.set_content_margin_all(0)
	_bar_fill.add_theme_stylebox_override("panel", bfs)

	# Tab button
	_tab_btn.text                = "[<<]"
	_tab_btn.custom_minimum_size = Vector2(36, 48)
	_tab_btn.set_anchor(SIDE_LEFT,   1)
	_tab_btn.set_anchor(SIDE_RIGHT,  1)
	_tab_btn.set_anchor(SIDE_TOP,    0.5)
	_tab_btn.set_anchor(SIDE_BOTTOM, 0.5)
	_tab_btn.set_offset(SIDE_LEFT,   -42)
	_tab_btn.set_offset(SIDE_RIGHT,  -6)
	_tab_btn.set_offset(SIDE_TOP,    -32)
	_tab_btn.set_offset(SIDE_BOTTOM,  32)
	_tab_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_btn.add_theme_stylebox_override("normal",  _make_sb(Color(0.04,0.08,0.16), Color(0.05,0.75,1.0), BORDER_W, 6))
	_tab_btn.add_theme_stylebox_override("hover",   _make_sb(Color(0.06,0.14,0.28), Color(0.2, 1.0, 0.4), BORDER_W, 6))
	_tab_btn.add_theme_stylebox_override("pressed", _make_sb(Color(0.05,0.75,1.0),  Color(0.05,0.75,1.0), BORDER_W, 6))
	_tab_btn.add_theme_stylebox_override("focus",   _make_sb(Color(0.06,0.14,0.28), Color(0.2, 1.0, 0.4), BORDER_W, 6))
	_tab_btn.add_theme_font_override("font", _font)
	_tab_btn.add_theme_font_size_override("font_size", 9)
	_tab_btn.add_theme_color_override("font_color",         Color(0.05, 0.75, 1.0))
	_tab_btn.add_theme_color_override("font_hover_color",   Color(0.2,  1.0,  0.4))
	_tab_btn.add_theme_color_override("font_pressed_color", Color(1.0,  1.0,  1.0))

# ── HELPERS ────────────────────────────────────────────────
func _style_lbl(lbl: Label, size: int, color: Color):
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _make_sb(bg: Color, border: Color, bw: int, margin: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margin)
	return s

# ── SIGNALS ────────────────────────────────────────────────
func _connect_signals():
	_tab_btn.pressed.connect(_toggle_panel)

func _toggle_panel():
	if _is_open: _close_panel()
	else:        _open_panel()

func _open_panel():
	MusicManager.play_hint_sfx()
	_is_open        = true
	_panel_target_x = _panel_open_x
	_tab_btn.text   = "[>>]"
	_refresh_display() # Force refresh to show current Overclock state

func _close_panel():
	MusicManager.play_hint_sfx()
	_is_open        = false
	_panel_target_x = _panel_closed_x
	_tab_btn.text   = "[<<]"

# ── PROCESS ────────────────────────────────────────────────
func _process(delta):
	var cur  = _panel.get_offset(SIDE_LEFT)
	var diff = _panel_target_x - cur
	if abs(diff) > 0.5:
		_set_panel_x(cur + diff * 14.0 * delta)
	else:
		_set_panel_x(_panel_target_x)

func _set_panel_x(x: float):
	_panel.set_offset(SIDE_LEFT,  x)
	_panel.set_offset(SIDE_RIGHT, x + PANEL_W)

# ── SIGNAL HANDLERS ─────────────────────────────────────────
func _on_system_hp_changed(_new_hp: int):
	_refresh_display()

func _on_overclock_changed(_charges: int):
	_refresh_display()

# ── PUBLIC API ─────────────────────────────────────────────
func add_kill(count: int = 1):
	for i in range(count):
		GameData.add_enemy_defeated()
	GameData.add_xp(count * 50)
	_refresh_display()

func add_xp(amount: int):
	GameData.add_xp(amount)
	_refresh_display()

# ── BAR FILL HELPER ────────────────────────────────────────
func _set_bar_fill(fill: PanelContainer, ratio: float, color: Color):
	var target_w = int(BAR_W * clamp(ratio, 0.0, 1.0))
	fill.custom_minimum_size = Vector2(target_w, 8)

	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(0)
	fill.add_theme_stylebox_override("panel", s)

# ── REFRESH ────────────────────────────────────────────────
func _refresh_display():
	_kill_count.text = "%03d" % GameData.enemies_defeated
	_lvl_num.text    = "LV. %02d" % GameData.level

	# ── System HP bar ─────────────────────────────────────
	var sys_ratio  = clamp(float(GameData.system_hp) / float(GameData.SYSTEM_HP_MAX), 0.0, 1.0)
	_sys_hp_sub.text = str(GameData.system_hp) + " / " + str(GameData.SYSTEM_HP_MAX)
	
	var sys_color : Color
	if sys_ratio > 0.5:
		sys_color = Color(0.2, 1.0, 0.4)
	elif sys_ratio > 0.25:
		sys_color = Color(1.0, 0.85, 0.1)
	else:
		sys_color = Color(1.0, 0.2, 0.2)
		
	_set_bar_fill(_sys_bar_fill, sys_ratio, sys_color)

	# ── XP bar ─────────────────────────────────────────────
	var needed = GameData.xp_to_next_level()
	var xp_ratio = clamp(float(GameData.current_xp) / float(needed), 0.0, 1.0) if needed > 0 else 1.0
	
	var xp_color : Color
	if GameData.advanced_unlocked():
		xp_color = Color(1.0, 0.4, 0.2)
	elif GameData.intermediate_unlocked():
		xp_color = Color(1.0, 0.85, 0.1)
	else:
		xp_color = Color(0.2, 1.0, 0.4)
		
	_set_bar_fill(_bar_fill, xp_ratio, xp_color)

	if needed <= 0:
		_lvl_sub.text = "MAX LEVEL"
	else:
		_lvl_sub.text = "%d / %d XP" % [GameData.current_xp, needed]

	if GameData.advanced_unlocked():
		_lock_note.text = "ALL MODES\nUNLOCKED!"
		_lock_note.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	elif GameData.intermediate_unlocked():
		_lock_note.text = "INTERMEDIATE\nUNLOCKED!\nAdv. at LV 20"
		_lock_note.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		_lock_note.text = "Intermediate\nunlocks\nat LV 10"
		_lock_note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	# ── UPDATE OVERCLOCK LABEL ──
	if _overclock_lbl:
		if GameData.overclock_battles_left > 0:
			_overclock_lbl.visible = true
			# Fixed formatting: Removes the extra trailing lines!
			_overclock_lbl.text = "\n[OVERCLOCK ACTIVE]\n%d BATTLES LEFT" % GameData.overclock_battles_left
		else:
			_overclock_lbl.visible = false
