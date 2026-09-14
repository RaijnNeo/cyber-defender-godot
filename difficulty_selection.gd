extends Node2D

# ── Node refs ──────────────────────────────────────────────────────────

var _font : Font

# ── CanvasLayer that hosts both panels (always viewport-space) ─────────
var _ui_layer     : CanvasLayer

var _overlay_inter : ColorRect
var _panel_inter   : PanelContainer

var _overlay_adv   : ColorRect
var _panel_adv     : PanelContainer

# ─────────────────────────────────────────────────────────────────────
func _ready():
	_font = load("res://Sprites/PressStart2P.ttf")

	# CanvasLayer sits on top of everything, independent of the 2D camera
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_build_intermediate_panel()
	_build_advanced_panel()

# ── HELPERS ───────────────────────────────────────────────────────────
func _make_overlay(layer: CanvasLayer) -> ColorRect:
	var ov          = ColorRect.new()
	ov.color        = Color(0, 0, 0, 0.78)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.visible      = false
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ov)
	return ov

func _make_panel(layer: CanvasLayer, border_color: Color) -> PanelContainer:
	# Wrapper fills the entire viewport so we can centre inside it
	var wrapper = Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.visible = false
	layer.add_child(wrapper)

	var pc = PanelContainer.new()
	# Anchor to the centre of the wrapper (= centre of screen)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Shift left/up by half the panel width so it's truly centred
	pc.set_offset(SIDE_LEFT,   -220)
	pc.set_offset(SIDE_RIGHT,   220)
	pc.set_offset(SIDE_TOP,    -180)
	pc.set_offset(SIDE_BOTTOM,  180)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sb            = StyleBoxFlat.new()
	sb.bg_color       = Color(0.04, 0.07, 0.16)
	sb.border_color   = border_color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.content_margin_left   = 24
	sb.content_margin_right  = 24
	sb.content_margin_top    = 24
	sb.content_margin_bottom = 24
	pc.add_theme_stylebox_override("panel", sb)

	wrapper.add_child(pc)
	# Return the wrapper so show/hide toggles both together
	# Caller gets the PanelContainer; we stash wrapper ref on it
	pc.set_meta("wrapper", wrapper)
	return pc

func _make_label(text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lbl = Label.new()
	lbl.text                  = text
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment  = align
	lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

func _make_ok_btn(panel: PanelContainer, overlay: ColorRect) -> Button:
	var btn = Button.new()
	btn.text = "[ OK ]"
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color",         Color(0.1, 0.9, 0.4))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0))
	var sb_n          = StyleBoxFlat.new()
	sb_n.bg_color     = Color(0.04, 0.08, 0.16)
	sb_n.border_color = Color(0.1, 0.9, 0.4)
	sb_n.set_border_width_all(3)
	sb_n.set_content_margin_all(10)
	var sb_h          = sb_n.duplicate()
	sb_h.bg_color     = Color(0.06, 0.18, 0.06)
	var sb_p          = sb_n.duplicate()
	sb_p.bg_color     = Color(0.1, 0.9, 0.4)
	btn.add_theme_stylebox_override("normal",  sb_n)
	btn.add_theme_stylebox_override("hover",   sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus",   sb_h)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size   = Vector2(160, 36)
	btn.pressed.connect(func():
		MusicManager.play_button_click()
		if panel.has_meta("wrapper"):
			panel.get_meta("wrapper").visible = false
		overlay.visible = false
	)
	return btn

func _wire_overlay_dismiss(overlay: ColorRect, panel: PanelContainer):
	overlay.gui_input.connect(func(ev):
		if (ev is InputEventMouseButton and ev.pressed) or \
		   (ev is InputEventScreenTouch and ev.pressed):
			MusicManager.play_button_click()
			if panel.has_meta("wrapper"):
				panel.get_meta("wrapper").visible = false
			overlay.visible = false
	)

# ── INTERMEDIATE: level 10 gate ───────────────────────────────────────
func _build_intermediate_panel():
	_overlay_inter = _make_overlay(_ui_layer)
	_panel_inter   = _make_panel(_ui_layer, Color(1.0, 0.5, 0.0))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.alignment             = BoxContainer.ALIGNMENT_CENTER

	vbox.add_child(_make_label("-- ACCESS DENIED --", 11, Color(1.0, 0.5, 0.0)))
	vbox.add_child(_make_label("* * * * * * * * * * * * *", 7, Color(1.0, 0.5, 0.0, 0.45)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label("HAZARD ZONE is locked.", 8, Color(0.85, 0.85, 0.85)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label("REQUIREMENT:", 8, Color(1.0, 0.85, 0.3)))
	vbox.add_child(_make_label(
		"Reach LEVEL 10 in Floor 1\nbefore entering this sector.",
		8, Color(0.85, 0.85, 0.85)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label(
		"Current threats exceed\nyour clearance level.",
		8, Color(1.0, 0.4, 0.4)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label("* * * * * * * * * * * * *", 7, Color(1.0, 0.5, 0.0, 0.45)))
	vbox.add_child(_make_ok_btn(_panel_inter, _overlay_inter))

	_panel_inter.add_child(vbox)
	_wire_overlay_dismiss(_overlay_inter, _panel_inter)

# ── ADVANCED: under development ───────────────────────────────────────
func _build_advanced_panel():
	_overlay_adv = _make_overlay(_ui_layer)
	_panel_adv   = _make_panel(_ui_layer, Color(0.0, 0.85, 1.0))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.alignment             = BoxContainer.ALIGNMENT_CENTER

	vbox.add_child(_make_label("-- UNDER DEVELOPMENT --", 10, Color(0.0, 0.9, 1.0)))
	vbox.add_child(_make_label("* * * * * * * * * * * * *", 7, Color(0.0, 0.85, 1.0, 0.45)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label("ROOM 3  DATA CORE", 8, Color(1.0, 0.85, 0.3)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label(
		"This sector is currently\nbeing constructed.",
		8, Color(0.85, 0.85, 0.85)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label("STATUS:", 8, Color(1.0, 0.85, 0.3)))
	vbox.add_child(_make_label("[ IN PROGRESS ]", 8, Color(0.0, 0.9, 1.0)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label(
		"Check back in a future\nupdate.",
		8, Color(0.85, 0.85, 0.85)))
	vbox.add_child(_make_label("", 8, Color(0, 0, 0, 0)))
	vbox.add_child(_make_label("* * * * * * * * * * * * *", 7, Color(0.0, 0.85, 1.0, 0.45)))
	vbox.add_child(_make_ok_btn(_panel_adv, _overlay_adv))

	_panel_adv.add_child(vbox)
	_wire_overlay_dismiss(_overlay_adv, _panel_adv)

# ── BUTTON HANDLERS ───────────────────────────────────────────────────
func _on_beginner_pressed():
	MusicManager.play_button_click()
	TransitionManager.fade_to_scene("res://Floor_1_Scenes/game.tscn")

func _on_intermediate_pressed() -> void:
	MusicManager.play_button_click()
	if GameData.intermediate_unlocked():
		GameData.pcb_sector_cleared = true
		GameData.save_data()
		TransitionManager.fade_to_scene("res://Floor_2_Scenes/floor_2.tscn")
	else:
		_overlay_inter.visible = true
		_panel_inter.get_meta("wrapper").visible = true

func _on_advance_pressed() -> void:
	MusicManager.play_button_click()
	_overlay_adv.visible = true
	_panel_adv.get_meta("wrapper").visible = true

func _on_back_pressed() -> void:
	MusicManager.play_button_click()
	get_tree().change_scene_to_file("res://MainMenu.tscn")
