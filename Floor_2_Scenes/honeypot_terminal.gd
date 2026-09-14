extends Area2D

var player_in_range = false
var trap_sprung = false

@onready var terminal_sprite = $TerminalSprite
@onready var ring_sprite = $RingSprite
@onready var interact_label = $InteractLabel

var normal_text = "[REPAIR TERMINAL]"
var glitch_texts = [
	"[R€P@IR T£RMINAL]",
	"[R#PAIR T#RM!NAL]",
	"[ R E P A I R ??? ]",
	"[DATA CORRUPTED]"
]

# --- GLITCH TIMING ---
# Instead of rolling every frame (60x/sec = too fast to read),
# we glitch on a timer: hold each state for a human-readable duration.
var glitch_timer = 0.0
var glitch_hold_duration = 0.0   # how long to hold the current state
var is_currently_glitched = false

func _ready():
	ring_sprite.visible = false
	interact_label.visible = false
	terminal_sprite.play("default")

func _process(delta):
	if trap_sprung or not player_in_range:
		return

	glitch_timer -= delta

	if glitch_timer <= 0.0:
		if is_currently_glitched:
			# Return to normal — hold normal text for 1.5–3 seconds
			interact_label.text = normal_text
			interact_label.add_theme_color_override("font_color", Color(0, 1, 1))
			is_currently_glitched = false
			glitch_hold_duration = randf_range(0.5, 1.2)
		else:
			# 30% chance to actually glitch when the timer expires
			if randf() < 0.50:
				interact_label.text = glitch_texts.pick_random()
				interact_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
				is_currently_glitched = true
				# Hold the glitch long enough to read: 0.4–0.8 seconds
				glitch_hold_duration = randf_range(0.3, 0.5)
			else:
				# Stay normal a bit longer
				glitch_hold_duration = randf_range(0.5, 1.2)

		glitch_timer = glitch_hold_duration

# --- PROXIMITY DETECTION ---
func _on_body_entered(body):
	if body.is_in_group("player") and not trap_sprung:
		player_in_range = true
		ring_sprite.visible = true
		interact_label.visible = true
		interact_label.text = normal_text
		interact_label.add_theme_color_override("font_color", Color(0, 1, 1))
		ring_sprite.modulate = Color(0, 1, 1, 1.0)
		# Reset glitch timer so it starts fresh on entry
		glitch_timer = randf_range(0.5, 1.0)
		is_currently_glitched = false

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		ring_sprite.visible = false
		interact_label.visible = false

# --- INTERACT: keyboard (Space/Enter) ---
func _unhandled_input(event):
	if player_in_range and not trap_sprung and event.is_action_pressed("ui_accept"):
		trigger_ambush()

# --- INTERACT: mobile touch (tap the Area2D) ---
# The scene already has [connection signal="input_event" ... method="_on_input_event"]
# so this will fire when the player taps the terminal on mobile.
func _on_input_event(_viewport, event, _shape_idx):
	if player_in_range and not trap_sprung:
		if event is InputEventScreenTouch and event.pressed:
			trigger_ambush()
		# Also handle mouse click for PC testing without spacebar
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			trigger_ambush()

# --- THE AMBUSH ---
func trigger_ambush():
	trap_sprung = true
	player_in_range = false

	ring_sprite.visible = false
	interact_label.text = "[ SYSTEM COMPROMISED ]"
	interact_label.add_theme_color_override("font_color", Color(1, 0, 0))

	terminal_sprite.pause()
	terminal_sprite.frame = 7

	$err_sfx.play()

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_trigger_encounter"):
		player._trigger_encounter()
