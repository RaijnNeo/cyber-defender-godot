extends Node2D

# ─── PCB BACKGROUND GENERATOR ─────────────────────────────
# Procedurally draws a circuit board background
# Attach this script to a Node2D named "PCBBackground"
# Place it as the FIRST child in your scene so it renders behind everything

# ─── COLORS ───────────────────────────────────────────────
const COLOR_BASE       = Color(0.04, 0.08, 0.06)       # Very dark green-black base
const COLOR_BOARD      = Color(0.06, 0.12, 0.09)       # Slightly lighter PCB green
const COLOR_TRACE      = Color(0.0,  0.85, 0.45, 0.6)  # Neon green circuit traces
const COLOR_TRACE_DIM  = Color(0.0,  0.5,  0.3,  0.3)  # Dimmer background traces
const COLOR_NODE       = Color(0.0,  1.0,  0.6)        # Bright green node points
const COLOR_CYAN       = Color(0.0,  0.85, 1.0,  0.5)  # Cyan accent traces
const COLOR_CHIP_BG    = Color(0.08, 0.08, 0.12)       # Dark chip body
const COLOR_CHIP_EDGE  = Color(0.0,  0.7,  0.4,  0.8)  # Chip border
const COLOR_CHIP_TEXT  = Color(0.0,  1.0,  0.5,  0.6)  # Chip label color
const COLOR_GLOW       = Color(0.0,  1.0,  0.5,  0.08) # Subtle glow overlay

# ─── SETTINGS ─────────────────────────────────────────────
const SCREEN_W = 480   # Match your Godot project viewport width
const SCREEN_H = 270   # Match your Godot project viewport height

# Trace grid spacing — traces snap to this grid like a real PCB
const GRID = 24

# How many of each element to draw
const NUM_TRACES      = 40
const NUM_NODES       = 30
const NUM_CHIPS       = 6
const NUM_CAPACITORS  = 8

# ─── RANDOM SEED ──────────────────────────────────────────
# Change this number to get a different PCB layout
const SEED = 42

var rng = RandomNumberGenerator.new()

# ─── DRAW ─────────────────────────────────────────────────
# _draw() is Godot's built-in function for 2D drawing
# It runs once when the node is ready
func _draw():
	rng.seed = SEED

	_draw_base()
	_draw_grid_lines()
	_draw_traces()
	_draw_nodes()
	_draw_chips()
	_draw_capacitors()
	_draw_scanline_overlay()


# ── BASE BOARD ─────────────────────────────────────────────
func _draw_base():
	# Fill entire screen with the dark PCB base color
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), COLOR_BASE)

	# Draw a slightly lighter inner board area with a small margin
	draw_rect(Rect2(4, 4, SCREEN_W - 8, SCREEN_H - 8), COLOR_BOARD)


# ── FAINT GRID ─────────────────────────────────────────────
func _draw_grid_lines():
	# Subtle dot grid — real PCBs have a design grid
	var grid_color = Color(0.0, 0.4, 0.2, 0.15)
	var x = GRID
	while x < SCREEN_W:
		var y = GRID
		while y < SCREEN_H:
			draw_circle(Vector2(x, y), 0.8, grid_color)
			y += GRID
		x += GRID


# ── CIRCUIT TRACES ─────────────────────────────────────────
func _draw_traces():
	# Traces are the copper lines connecting components on a PCB
	# We draw them on the grid so they look intentional, not random
	for i in range(NUM_TRACES):
		var is_cyan = rng.randi_range(0, 5) == 0   # 1 in 6 chance of cyan trace
		var is_dim  = rng.randi_range(0, 2) == 0   # 1 in 3 chance of dim trace

		var color: Color
		if is_cyan:
			color = COLOR_CYAN
		elif is_dim:
			color = COLOR_TRACE_DIM
		else:
			color = COLOR_TRACE

		# Snap start point to grid
		var sx = rng.randi_range(0, (SCREEN_W / GRID) - 1) * GRID
		var sy = rng.randi_range(0, (SCREEN_H / GRID) - 1) * GRID

		# Traces go either horizontal or vertical (like real PCB traces)
		var horizontal = rng.randi_range(0, 1) == 0
		var length = rng.randi_range(2, 8) * GRID  # Length snapped to grid units

		var ex: float
		var ey: float
		if horizontal:
			ex = clamp(sx + length, 0, SCREEN_W)
			ey = sy
		else:
			ex = sx
			ey = clamp(sy + length, 0, SCREEN_H)

		var width = rng.randi_range(1, 2)  # 1 or 2 pixel wide trace
		draw_line(Vector2(sx, sy), Vector2(ex, ey), color, width)

		# Sometimes add a 90-degree bend (L-shaped trace)
		if rng.randi_range(0, 2) == 0:
			var bend_len = rng.randi_range(1, 4) * GRID
			var bx: float
			var by_: float
			if horizontal:
				bx = ex
				by_ = clamp(ey + bend_len, 0, SCREEN_H)
			else:
				bx = clamp(ex + bend_len, 0, SCREEN_W)
				by_ = ey
			draw_line(Vector2(ex, ey), Vector2(bx, by_), color, width)


# ── NODE POINTS ────────────────────────────────────────────
func _draw_nodes():
	# Nodes are the junction points where traces meet
	# On a real PCB these are vias or solder pads
	for i in range(NUM_NODES):
		# Snap to grid
		var x = rng.randi_range(0, (SCREEN_W / GRID) - 1) * GRID
		var y = rng.randi_range(0, (SCREEN_H / GRID) - 1) * GRID

		var is_large = rng.randi_range(0, 3) == 0  # 1 in 4 is a larger pad

		if is_large:
			# Large solder pad — outer ring + inner dot
			draw_circle(Vector2(x, y), 5.0, Color(0.0, 0.5, 0.3, 0.4))
			draw_circle(Vector2(x, y), 3.0, COLOR_NODE)
			draw_circle(Vector2(x, y), 1.5, Color(0.8, 1.0, 0.9))
		else:
			# Small via
			draw_circle(Vector2(x, y), 2.5, COLOR_NODE)
			draw_circle(Vector2(x, y), 1.0, Color(0.8, 1.0, 0.9))


# ── CHIPS ──────────────────────────────────────────────────
func _draw_chips():
	# IC chips — rectangular components with pins on the sides
	for i in range(NUM_CHIPS):
		# Snap position to grid
		var x = rng.randi_range(1, (SCREEN_W / GRID) - 5) * GRID
		var y = rng.randi_range(1, (SCREEN_H / GRID) - 4) * GRID

		# Chip size snapped to grid (2–4 grid units wide, 2–3 tall)
		var w = rng.randi_range(2, 4) * GRID
		var h = rng.randi_range(2, 3) * GRID

		# Make sure chip stays on screen
		x = clamp(x, 8, SCREEN_W - w - 8)
		y = clamp(y, 8, SCREEN_H - h - 8)

		# Chip body
		draw_rect(Rect2(x, y, w, h), COLOR_CHIP_BG)

		# Chip border — bright green outline
		draw_rect(Rect2(x, y, w, h), COLOR_CHIP_EDGE, false, 1.5)

		# Notch on top-left corner (IC orientation marker)
		var notch_color = Color(0.0, 0.8, 0.5, 0.5)
		draw_arc(Vector2(x + 6, y), 4, 0, PI, 8, notch_color, 1.0)

		# Pin legs on left and right sides
		var pin_count = int(h / GRID)
		var pin_color = Color(0.0, 0.9, 0.5, 0.7)
		for p in range(pin_count):
			var py = y + GRID * 0.5 + p * GRID
			# Left pins
			draw_line(Vector2(x - 6, py), Vector2(x, py), pin_color, 1.5)
			draw_circle(Vector2(x - 6, py), 1.5, pin_color)
			# Right pins
			draw_line(Vector2(x + w, py), Vector2(x + w + 6, py), pin_color, 1.5)
			draw_circle(Vector2(x + w + 6, py), 1.5, pin_color)

		# Chip label text — cybersecurity themed
		var labels = ["FW-01", "AV-02", "CPU", "GPU", "RAM", "ROM",
					  "I/O", "NET", "SEC", "ENC", "DEC", "SYS"]
		var label = labels[i % labels.size()]

		# Draw label as small pixel-style dots (since draw_string needs a font)
		# We'll draw a simple rectangle placeholder for the label area
		var label_color = Color(0.0, 1.0, 0.5, 0.25)
		draw_rect(Rect2(x + 4, y + h/2 - 4, w - 8, 8), label_color)


# ── CAPACITORS ─────────────────────────────────────────────
func _draw_capacitors():
	# Capacitors — small cylindrical components, drawn as circles with a line
	for i in range(NUM_CAPACITORS):
		var x = rng.randi_range(1, (SCREEN_W / GRID) - 2) * GRID
		var y = rng.randi_range(1, (SCREEN_H / GRID) - 2) * GRID

		x = clamp(x, 8, SCREEN_W - 8)
		y = clamp(y, 8, SCREEN_H - 8)

		var radius = rng.randi_range(4, 7)
		var cap_color = Color(0.0, 0.7, 0.4, 0.6)
		var cap_top   = Color(0.0, 1.0, 0.6, 0.4)

		# Capacitor body
		draw_circle(Vector2(x, y), radius, COLOR_CHIP_BG)
		draw_arc(Vector2(x, y), radius, 0, TAU, 16, cap_color, 1.5)

		# Polarity line on top (+ marker)
		draw_line(
			Vector2(x, y - radius + 2),
			Vector2(x, y + radius - 2),
			cap_top, 1.0
		)
		draw_line(
			Vector2(x - radius + 2, y),
			Vector2(x + radius - 2, y),
			cap_top, 1.0
		)

		# Two wire leads going down
		var lead_color = Color(0.0, 0.8, 0.4, 0.5)
		draw_line(
			Vector2(x - 3, y + radius),
			Vector2(x - 3, y + radius + 6),
			lead_color, 1.0
		)
		draw_line(
			Vector2(x + 3, y + radius),
			Vector2(x + 3, y + radius + 6),
			lead_color, 1.0
		)


# ── SCANLINE OVERLAY ───────────────────────────────────────
func _draw_scanline_overlay():
	# Subtle horizontal scanlines — gives it that old CRT/retro monitor feel
	# Every other line gets a very faint dark stripe
	var line_color = Color(0.0, 0.0, 0.0, 0.12)
	var y = 0
	while y < SCREEN_H:
		draw_line(Vector2(0, y), Vector2(SCREEN_W, y), line_color, 1.0)
		y += 2

	# Vignette effect — darker corners, lighter center
	# Drawn as 4 gradient-like transparent rectangles at screen edges
	var vignette = Color(0.0, 0.0, 0.0, 0.35)
	var v = 20  # vignette thickness
	draw_rect(Rect2(0, 0, SCREEN_W, v), vignette)           # top
	draw_rect(Rect2(0, SCREEN_H - v, SCREEN_W, v), vignette) # bottom
	draw_rect(Rect2(0, 0, v, SCREEN_H), vignette)           # left
	draw_rect(Rect2(SCREEN_W - v, 0, v, SCREEN_H), vignette) # right
