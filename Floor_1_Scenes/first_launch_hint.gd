extends CanvasLayer

const SAVE_KEY  = "user://hint_overworld.cfg"
const PANEL_W   = 420
const PANEL_H   = 340
const BORDER_W  = 4

var pages : Array = []

@onready var _overlay     : ColorRect      = $Overlay
@onready var _panel       : PanelContainer = $Panel
@onready var _title_lbl   : Label          = $Panel/VBox/TitleLabel
@onready var _divider_top : Label          = $Panel/VBox/DividerTop
@onready var _content_box : VBoxContainer  = $Panel/VBox/ContentBox
@onready var _divider_bot : Label          = $Panel/VBox/DividerBot
@onready var _prev_btn    : Button         = $Panel/VBox/NavRow/PrevBtn
@onready var _page_lbl    : Label          = $Panel/VBox/NavRow/PageLbl
@onready var _next_btn    : Button         = $Panel/VBox/NavRow/NextBtn
@onready var _ok_btn      : Button         = $Panel/VBox/OkBtn
@onready var _tab_btn     : Button         = $TabBtn

var _font           : Font
var _cur_page       : int   = 0
var _panel_open_x   : float = 0.0
var _panel_closed_x : float = 0.0
var _panel_target_x : float = 0.0

# ----------------------------------------------------------------
func _ready():
	add_to_group("hint_ui")
	
	_font           = load("res://Sprites/PressStart2P.ttf")
	_panel_closed_x = -PANEL_W - 20.0

	_overlay.visible = false
	_tab_btn.visible = false
	_set_panel_x(_panel_closed_x)

	_apply_styles()
	_connect_signals()
	_build_pages() 
	_load_page(0)

	call_deferred("_init_position")

func _init_position():
	var sw        = get_viewport().get_visible_rect().size.x
	_panel_open_x = (sw / 2.0) - (PANEL_W / 2.0)

	var cfg = ConfigFile.new()
	if cfg.load(SAVE_KEY) != OK or not cfg.get_value("hint", "seen", false):
		_mark_seen()
		_open_panel()
	else:
		_tab_btn.visible = true

func _mark_seen():
	var cfg = ConfigFile.new()
	cfg.set_value("hint", "seen", true)
	cfg.save(SAVE_KEY)

# ── DYNAMIC PAGE BUILDER ──────────────────────────────────────────
func _build_pages():
	pages.clear()
	
	pages.append({
		"title": "-- MISSION --",
		"color": Color(0.1, 0.9, 1.0),
		"lines": [
			"",
			"You are ADMIN.",
			"",
			"The system is under attack!",
			"",
			"Cyber threats have infected",
			"the circuit board network.",
			"",
			"Navigate the board to restore the",
			"system and neutralize all threats.",
			"",
			"Good luck, Agent.",
		]
	})
	pages.append({
		"title": "-- MOVEMENT --",
		"color": Color(0.2, 1.0, 0.35),
		"lines": [
			"JOYSTICK",
			"Move your agent around.",
			"",
			"RED / CORRUPTED TILES",
			"Walking on them triggers",
			"a battle encounter.",
			"",
			"TAP DIALOGUE BOX",
			"Advances the text.",
			"",
			"TAP [ ? ] BUTTON",
			"Reopens this guide.",
		]
	})
	pages.append({
		"title": "-- SYSTEM HP --",
		"color": Color(1.0, 0.35, 0.35),
		"lines": [
			"SYSTEM HP",
			"",
			"Tracks PCB integrity.",
			"",
			"It drops after every",
			"battle you fight.",
			"",
			"DEFEATING enemies",
			"restores System HP.",
			"",
			"If it hits zero,",
			"encounter rate triples!",
			"",
			"WARNING: Malware attacks",
			"overnight! Each day you",
			"are offline, the system",
			"loses 25 HP.",
		]
	})
	pages.append({
		"title": "-- MAINFRAME --",
		"color": Color(0.2, 1.0, 0.6),
		"lines": [
			"REPAIR TERMINAL",
			"",
			"Located top-right",
			"of the PCB.",
			"",
			"Walk into its radius",
			"and tap the label to",
			"restore 30 System HP.",
			"",
			"Note: The terminal requires",
			"5 minutes to recharge",
			"between uses!"
		]
	})

	var cfg = ConfigFile.new()
	cfg.load(SAVE_KEY)
	
	if cfg.get_value("hint", "unlocked_subroutine", false):
		pages.append({
			"title": "-- SUB-ROUTINE --", "color": Color(0.9, 0.8, 0.2),
			"lines": [
				"DATA CACHE UNLOCKED",
				"",
				"Mainframe power has been", 
				"routed to local caches.", 
				"", 
				"These offline terminals", 
				"now provide tactical buffs.",
				"",
				"Find it on the bottom-left",
				"of the PCB."
			]
		})
		
	if cfg.get_value("hint", "unlocked_overclock", false):
		pages.append({
			"title": "-- OVERCLOCK --", "color": Color(1.0, 0.5, 0.0),
			"lines": [
				"COMBAT OVERCLOCK", 
				"",
				"Accessing a Data Cache", 
				"grants a massive damage boost.", 
				"", 
				"This buff is temporary.", 
				"It expires after 3 battles.", 
				"", 
				"Caches require 10 minutes", 
				"to recharge."
			]
		})

func trigger_new_entry(unlock_key: String):
	var cfg = ConfigFile.new()
	cfg.load(SAVE_KEY)
	
	if cfg.get_value("hint", unlock_key, false):
		return
		
	cfg.set_value("hint", unlock_key, true)
	cfg.save(SAVE_KEY)
	
	_build_pages()
	_open_panel()
	_load_page(pages.size() - 1) 

# ----------------------------------------------------------------
func _apply_styles():
	var fs  = 10
	var fsm = 9

	_overlay.color        = Color(0, 0, 0, 0.72)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_panel.set_anchor(SIDE_LEFT,   0)
	_panel.set_anchor(SIDE_RIGHT,  0)
	_panel.set_anchor(SIDE_TOP,    0.5)
	_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_panel.set_offset(SIDE_TOP,    -(PANEL_H / 2.0))
	_panel.set_offset(SIDE_BOTTOM,  (PANEL_H / 2.0))

	var ps = StyleBoxFlat.new()
	ps.bg_color              = Color(0.04, 0.08, 0.16)
	ps.border_color          = Color(0.05, 0.75, 1.0)
	ps.set_border_width_all(BORDER_W)
	ps.set_corner_radius_all(0)
	ps.content_margin_left   = 18
	ps.content_margin_right  = 18
	ps.content_margin_top    = 26
	ps.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", ps)

	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", _font)
	_title_lbl.add_theme_font_size_override("font_size", fs + 1)

	for div in [_divider_top, _divider_bot]:
		div.text                 = "* * * * * * * * * * * * * *"
		div.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		div.clip_text            = true
		div.add_theme_font_override("font", _font)
		div.add_theme_font_size_override("font_size", 7)
		div.add_theme_color_override("font_color", Color(0.05, 0.75, 1.0, 0.5))

	_content_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 6)

	_page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_page_lbl.add_theme_font_override("font", _font)
	_page_lbl.add_theme_font_size_override("font_size", fsm)
	_page_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	_style_btn(_prev_btn, fsm, false)
	_style_btn(_next_btn, fsm, false)
	_style_btn(_ok_btn,   fsm, true)
	_ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_tab_btn.text                = "?"
	_tab_btn.custom_minimum_size = Vector2(28, 52)
	_tab_btn.set_anchor(SIDE_LEFT,   0)
	_tab_btn.set_anchor(SIDE_RIGHT,  0)
	_tab_btn.set_anchor(SIDE_TOP,    0.5)
	_tab_btn.set_anchor(SIDE_BOTTOM, 0.5)
	_tab_btn.set_offset(SIDE_LEFT,   6)
	_tab_btn.set_offset(SIDE_RIGHT,  34)
	_tab_btn.set_offset(SIDE_TOP,   -26)
	_tab_btn.set_offset(SIDE_BOTTOM, 26)
	_tab_btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var ts  = _make_sb(Color(0.04, 0.08, 0.16), Color(0.05, 0.75, 1.0), BORDER_W, 8)
	var tsh = _make_sb(Color(0.06, 0.14, 0.28), Color(0.2,  1.0,  0.4), BORDER_W, 8)
	var tsp = _make_sb(Color(0.05, 0.75, 1.0),  Color(0.05, 0.75, 1.0), BORDER_W, 8)
	_tab_btn.add_theme_stylebox_override("normal",  ts)
	_tab_btn.add_theme_stylebox_override("hover",   tsh)
	_tab_btn.add_theme_stylebox_override("pressed", tsp)
	_tab_btn.add_theme_stylebox_override("focus",   tsh)
	_tab_btn.add_theme_font_override("font", _font)
	_tab_btn.add_theme_font_size_override("font_size", 10)
	_tab_btn.add_theme_color_override("font_color",          Color(0.05, 0.75, 1.0))
	_tab_btn.add_theme_color_override("font_hover_color",   Color(0.2,  1.0,  0.4))
	_tab_btn.add_theme_color_override("font_pressed_color", Color(1.0,  1.0,  1.0))

func _style_btn(btn: Button, size: int, green_accent: bool):
	var accent = Color(0.2, 1.0, 0.4) if green_accent else Color(0.05, 0.75, 1.0)
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color",         accent)
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0))
	var sn = _make_sb(Color(0.04, 0.08, 0.16), Color(0.05, 0.75, 1.0), BORDER_W - 1, 8)
	var sh = _make_sb(Color(0.06, 0.14, 0.28), Color(0.2,  1.0,  0.4), BORDER_W - 1, 8)
	var sp = _make_sb(accent,                   accent,                  BORDER_W - 1, 8)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus",   sh)

func _make_sb(bg: Color, border: Color, bw: int, margin: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margin)
	return s

# ----------------------------------------------------------------
func _connect_signals():
	_prev_btn.pressed.connect(_prev_page)
	_next_btn.pressed.connect(_next_page)
	_ok_btn.pressed.connect(_close_panel)
	_tab_btn.pressed.connect(_open_panel)
	_overlay.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or \
		   (ev is InputEventScreenTouch and ev.pressed):
			_close_panel()
	)

# ----------------------------------------------------------------
func _process(delta):
	var current_scene = get_tree().current_scene
	var in_overworld  = current_scene != null and current_scene.scene_file_path == "res://Floor_1_Scenes/game.tscn"
	
	# ── THE FIX: Hide the entire CanvasLayer at once ──
	self.visible = in_overworld
	
	if not in_overworld:
		return # Stop doing math if we aren't in the room
		
	# ── Sliding Animation Math ──
	var cur  = _panel.get_offset(SIDE_LEFT)
	var diff = _panel_target_x - cur
	if abs(diff) > 0.5:
		_set_panel_x(cur + diff * 14.0 * delta)
	else:
		_set_panel_x(_panel_target_x)

func _set_panel_x(x: float):
	_panel.set_offset(SIDE_LEFT,  x)
	_panel.set_offset(SIDE_RIGHT, x + PANEL_W)

func _open_panel():
	MusicManager.play_hint_sfx()
	_panel_target_x  = _panel_open_x
	_overlay.visible = true
	_tab_btn.visible = false

func _close_panel():
	MusicManager.play_hint_sfx()
	_panel_target_x  = _panel_closed_x
	_overlay.visible = false
	_tab_btn.visible = true

# ----------------------------------------------------------------
func _load_page(idx: int):
	_cur_page = idx
	var page  = pages[idx]
	var fsm   = 9

	_title_lbl.text = page["title"]
	_title_lbl.add_theme_color_override("font_color", page["color"])

	for c in _content_box.get_children():
		c.queue_free()

	for line in page["lines"]:
		var lbl = Label.new()
		lbl.text                  = line
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", fsm)
		if line == "":
			lbl.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		elif line == line.to_upper() and line.length() > 2:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		_content_box.add_child(lbl)

	_page_lbl.text     = "%d / %d" % [idx + 1, pages.size()]
	_prev_btn.disabled = (idx == 0)
	_next_btn.disabled = (idx == pages.size() - 1)

func _prev_page():
	MusicManager.play_hint_sfx()
	if _cur_page > 0:
		_load_page(_cur_page - 1)

func _next_page():
	MusicManager.play_hint_sfx()
	if _cur_page < pages.size() - 1:
		_load_page(_cur_page + 1)
