extends CanvasLayer

# ═══════════════════════════════════════════════════════════
# CYBER DEFENDER — System Boot Loading Screen
# Mobile-ready: scales font, progress bar, and layout
# to the actual screen size at runtime.
#
# Scene tree:
#   LoadingScreen  (CanvasLayer, layer=100)
#     BG           (ColorRect)       full screen black
#     ScanLines    (ColorRect)       full screen, alpha overlay
#     MarginBox    (MarginContainer) full screen, adds padding
#       Terminal   (PanelContainer)  grows to fill MarginBox
#         VBox     (VBoxContainer)   fills Terminal
#           HeaderRow   (HBoxContainer)
#             HeaderLabel (Label)
#             BlinkCursor (Label)   "█"
#           LogScroll   (ScrollContainer)
#             LogContainer (VBoxContainer)
#           ProgressRow (HBoxContainer)
#             ProgressText (Label)  "LOADING  "
#             ProgressBar  (Label)  dynamic bar
#           StatusLabel (Label)
# ═══════════════════════════════════════════════════════════

const NEXT_SCENE = "res://MainMenu.tscn"

# ── Boot lines: [delay, text, status_key, color_key] ──────
# status_key : "ok" | "warn" | "fail" | ""
# color_key  : "green" | "cyan" | "yellow" | "red" | "white"
const BOOT_LINES = [
	[0.10, "CYBER DEFENDER OS  v1.0.0", "", "cyan"],
	[0.08, "Copyright (c) Universidad de Manila — CCS", "", "white"],
	[0.20, "------------------------------------------------", "", "cyan"],
	[0.15, "Performing POST (Power-On Self Test)...", "", "white"],
	[0.30, "  CPU Core integrity check", "ok", "green"],
	[0.20, "  RAM allocation        4096 MB", "ok", "green"],
	[0.20, "  Storage mount         /dev/system", "ok", "green"],
	[0.20, "------------------------------------------------", "", "cyan"],
	[0.15, "Loading KERNEL modules...", "", "white"],
	[0.20, "  kernel.net.firewall", "ok", "green"],
	[0.20, "  kernel.crypto.aes256", "ok", "green"],
	[0.20, "  kernel.threat.scanner", "ok", "green"],
	[0.20, "  kernel.patch.manager", "ok", "green"],
	[0.20, "------------------------------------------------", "", "cyan"],
	[0.15, "Mounting THREAT DATABASE...", "", "white"],
	[0.30, "  Trojan Horse          [INDEXED]", "ok", "green"],
	[0.20, "  Worm.Propagator       [INDEXED]", "ok", "green"],
	[0.20, "  Spyware.KeyLogger     [INDEXED]", "ok", "green"],
	[0.20, "  Adware.Injector       [INDEXED]", "ok", "green"],
	[0.20, "  Ransomware.CryptoLock [INDEXED]", "ok", "green"],
	[0.20, "------------------------------------------------", "", "cyan"],
	[0.15, "Running SECURITY DIAGNOSTICS...", "", "white"],
	[0.30, "  Intrusion detection system", "ok", "green"],
	[0.25, "  Packet inspection engine", "ok", "green"],
	[0.25, "  Vulnerability scanner", "warn", "yellow"],
	[0.15, "    >> WARNING: 3 unpatched vulnerabilities", "", "yellow"],
	[0.15, "    >> Countermeasures armed. Proceed with caution.", "", "yellow"],
	[0.35, "  Brute force protection", "ok", "green"],
	[0.20, "------------------------------------------------", "", "cyan"],
	[0.20, "Loading GAME ENGINE...", "", "white"],
	[0.30, "  Asset pipeline        [READY]", "ok", "green"],
	[0.20, "  Audio subsystem       [READY]", "ok", "green"],
	[0.20, "  Renderer              [READY]", "ok", "green"],
	[0.20, "  Input manager         [READY]", "ok", "green"],
	[0.20, "------------------------------------------------", "", "cyan"],
	[0.40, "ALL SYSTEMS NOMINAL.  DEPLOYING AGENT...", "", "cyan"],
]

const STATUS_TAG = {
	"ok":   ["  [ OK ]", Color(0.2,  1.0,  0.3)],
	"warn": ["  [WARN]", Color(1.0,  0.9,  0.1)],
	"fail": ["  [FAIL]", Color(1.0,  0.2,  0.2)],
	"":     ["",         Color(1.0,  1.0,  1.0)],
}
const LINE_COLORS = {
	"green":  Color(0.2,  1.0,  0.35),
	"cyan":   Color(0.1,  0.9,  1.0),
	"yellow": Color(1.0,  0.9,  0.1),
	"red":    Color(1.0,  0.2,  0.2),
	"white":  Color(0.85, 0.85, 0.85),
}

# ── Node refs ─────────────────────────────────────────────
@onready var log_container  : VBoxContainer  = $MarginBox/Terminal/VBox/LogScroll/LogContainer
@onready var log_scroll     : ScrollContainer= $MarginBox/Terminal/VBox/LogScroll
@onready var progress_bar   : Label          = $MarginBox/Terminal/VBox/ProgressRow/ProgressBar
@onready var status_label   : Label          = $MarginBox/Terminal/VBox/StatusLabel
@onready var blink_cursor   : Label          = $MarginBox/Terminal/VBox/HeaderRow/BlinkCursor
@onready var header_label   : Label          = $MarginBox/Terminal/VBox/HeaderRow/HeaderLabel

# ── Runtime state ─────────────────────────────────────────
var _font         : Font
var _blink_timer  : float = 0.0
var _cursor_vis   : bool  = true
var _font_size    : int   = 11    # recalculated in _ready
var _bar_chars    : int   = 28    # recalculated in _ready

const CHAR_FILL  = "█"
const CHAR_EMPTY = "░"

# ──────────────────────────────────────────────────────────
func _ready():
	_font = load("res://Sprites/PressStart2P.ttf")

	# ── Scale font size based on screen width ─────────────
	# PressStart2P is a large font — 11px looks fine on
	# 1152×648 but needs to be bigger on a phone where the
	# viewport is scaled up to fill physical pixels.
	# We target roughly 1.2% of screen width per font unit.
	var sw = ProjectSettings.get_setting("display/window/size/viewport_width")
	# Phone screens are typically 1080–1440px physical but
	# Godot renders at viewport size (1152). The OS then
	# upscales to fill the screen, so our font just needs
	# to be readable at viewport resolution.
	# Rule of thumb for PressStart2P on mobile: min 12px.
	_font_size = max(12, int(sw * 0.013))   # ~15px at 1152w
	_bar_chars = max(16, int(sw / 52))       # ~22 chars at 1152w

	_apply_font(header_label,  _font_size)
	_apply_font(blink_cursor,  _font_size)
	_apply_font(progress_bar,  _font_size)
	_apply_font(status_label,  _font_size - 1)

	_update_progress_bar(0.0)
	_boot_sequence()

# ──────────────────────────────────────────────────────────
func _process(delta):
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer = 0.0
		_cursor_vis  = not _cursor_vis
		blink_cursor.visible = _cursor_vis

# ──────────────────────────────────────────────────────────
func _apply_font(lbl: Label, size: int):
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", size)

# ──────────────────────────────────────────────────────────
func _boot_sequence():
	var total = BOOT_LINES.size()

	for idx in range(total):
		var entry      = BOOT_LINES[idx]
		var delay      : float  = entry[0]
		var text       : String = entry[1]
		var status_key : String = entry[2]
		var color_key  : String = entry[3]

		await get_tree().create_timer(delay).timeout

		# ── Build line HBox ───────────────────────────────
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 0)

		var lbl = Label.new()
		lbl.text = text
		lbl.add_theme_color_override("font_color", LINE_COLORS.get(color_key, Color.WHITE))
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", _font_size)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Clip long lines rather than wrap — keeps terminal feel
		lbl.clip_text = true
		hbox.add_child(lbl)

		if status_key != "":
			var tag_info = STATUS_TAG[status_key]
			var tag = Label.new()
			tag.text = tag_info[0]
			tag.add_theme_color_override("font_color", tag_info[1])
			tag.add_theme_font_override("font", _font)
			tag.add_theme_font_size_override("font_size", _font_size)
			hbox.add_child(tag)

		log_container.add_child(hbox)

		# ── Auto-scroll to bottom ─────────────────────────
		await get_tree().process_frame
		log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

		# ── Progress ──────────────────────────────────────
		_update_progress_bar(float(idx + 1) / float(total))

	# ── Done ──────────────────────────────────────────────
	await get_tree().create_timer(0.4).timeout

	status_label.text = ">> SYSTEM READY.  LAUNCHING..."
	status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.35))

	# Flash bar 3×
	for _i in range(3):
		progress_bar.modulate = Color(0.2, 1.0, 0.35)
		await get_tree().create_timer(0.15).timeout
		progress_bar.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.15).timeout

	await get_tree().create_timer(0.6).timeout

	if TransitionManager:
		TransitionManager.fade_to_scene(NEXT_SCENE)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)

# ──────────────────────────────────────────────────────────
func _update_progress_bar(pct: float):
	var filled  = int(pct * _bar_chars)
	var empty   = _bar_chars - filled
	var bar_str = "[" + CHAR_FILL.repeat(filled) + CHAR_EMPTY.repeat(empty) + "]"
	var pct_str = "  %3d%%" % int(pct * 100)
	progress_bar.text = bar_str + pct_str

	if pct < 0.5:
		progress_bar.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	elif pct < 0.85:
		progress_bar.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	else:
		progress_bar.add_theme_color_override("font_color", Color(0.2, 1.0, 0.35))
