extends CanvasLayer

# ═══════════════════════════════════════════════════════════
# CYBER DEFENDER — Intro Scene
# Plays intro.ogv before transitioning to the loading screen.
# Skip on any input (tap / click / key / gamepad).
# ═══════════════════════════════════════════════════════════

const NEXT_SCENE = "res://loading_screen.tscn"

@onready var video_player : VideoStreamPlayer = $VideoPlayer
@onready var skip_label   : Label             = $SkipLabel

var _transitioning : bool = false


func _ready() -> void:
	# Load the video — must be placed at res://intro.ogv
	var stream = load("res://Sprites/Intro/intro.ogv")
	if stream == null:
		push_error("IntroScene: res://Sprites/Intro/intro.ogv not found — skipping to loading screen.")
		_go_to_loading()
		return

	video_player.stream       = stream
	video_player.expand       = true   # fill the VideoStreamPlayer rect
	video_player.finished.connect(_on_video_finished)
	video_player.play()


func _input(event: InputEvent) -> void:
	# Any key, click, touch, or gamepad button skips the intro
	if _transitioning:
		return
	var skip := false
	if event is InputEventKey         and event.pressed:  skip = true
	if event is InputEventMouseButton and event.pressed:  skip = true
	if event is InputEventScreenTouch and event.pressed:  skip = true
	if event is InputEventJoypadButton and event.pressed: skip = true
	if skip:
		_go_to_loading()


func _on_video_finished() -> void:
	_go_to_loading()


func _go_to_loading() -> void:
	if _transitioning:
		return
	_transitioning = true
	video_player.stop()

	# Fade out then load — use TransitionManager if available
	if TransitionManager:
		TransitionManager.fade_to_scene(NEXT_SCENE)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)
