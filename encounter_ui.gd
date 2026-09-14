extends CanvasLayer

const ENCOUNTER_MESSAGES = [
	"A malware has been spotted!",
	"You encountered a wild malware!",
	"You stepped into a dangerous zone!",
	"Malware detected!"
]

const TYPEWRITER_SPEED = 0.04

@onready var dialogue_box  = $DialogueBox
@onready var dialogue_text = $DialogueBox/DialogueText
@onready var dialogue   : AudioStreamPlayer2D = $dlg_sfx

var is_displaying = false
var confirmed     = false
var waiting       = false   # true while _wait_for_confirm is active

func _ready():
	dialogue_box.visible      = false
	# Pass — lets input bubble up to _input() while still being hittable
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_PASS

func show_encounter(message: String = ""):
	if message == "":
		message = ENCOUNTER_MESSAGES[randi() % ENCOUNTER_MESSAGES.size()]

	dialogue_box.visible = true
	is_displaying        = true
	dialogue_text.text   = ""
	
	dialogue.play()

	for i in range(message.length()):
		dialogue_text.text += message[i]
		await get_tree().create_timer(TYPEWRITER_SPEED).timeout

	is_displaying = false

	await _wait_for_confirm()

	var bg_music = get_tree().current_scene.get_node_or_null("BGMusic")
	if bg_music:
		bg_music.stop()

	TransitionManager.battle_transition("res://battle_scene.tscn")

# ─── WAIT FOR CONFIRM ─────────────────────────────────────
func _wait_for_confirm():
	confirmed = false
	waiting   = true
	while not confirmed:
		await get_tree().process_frame
	waiting = false

# ─── UNIFIED INPUT ────────────────────────────────────────
# Accepts: touch (mobile), left click, Space, Enter, Z (PC)
func _input(event):
	if not waiting:
		return

	var accepted = false

	# Touch — mobile
	if event is InputEventScreenTouch and event.pressed:
		accepted = true

	# Left mouse click — PC testing
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accepted = true

	# Keyboard — Space, Enter, Z
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
			accepted = true

	if accepted:
		confirmed = true
		get_viewport().set_input_as_handled()
