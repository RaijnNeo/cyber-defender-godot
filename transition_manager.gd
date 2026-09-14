extends Node

# ─── TRANSITION MANAGER ───────────────────────────────────
# fade_to_scene()     — simple black fade (menus)
# battle_transition() — fade out → split bars → scene loads already covered → bars open

@onready var color_rect  = $CanvasLayer/ColorRect
@onready var top_rect    = $CanvasLayer/TopRect
@onready var bottom_rect = $CanvasLayer/BottomRect

const SCREEN_W = 1152.0
const SCREEN_H = 648.0

func _ready():
	# Full screen fade overlay — invisible at start
	color_rect.modulate.a = 0
	color_rect.size       = Vector2(SCREEN_W, SCREEN_H)
	color_rect.position   = Vector2(0, 0)

	# Split bars — start OFF screen
	top_rect.size          = Vector2(SCREEN_W, SCREEN_H / 2.0)
	top_rect.position      = Vector2(0, -SCREEN_H / 2.0)
	top_rect.modulate.a    = 1

	bottom_rect.size       = Vector2(SCREEN_W, SCREEN_H / 2.0)
	bottom_rect.position   = Vector2(0, SCREEN_H)
	bottom_rect.modulate.a = 1


# ─── SIMPLE FADE TRANSITION ───────────────────────────────
func fade_to_scene(path: String):
	# Use tween_callback so the scene change is guaranteed to fire
	# even when called from an Autoload context (no await needed).
	color_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.5)


# ─── BATTLE SPLIT TRANSITION ──────────────────────────────
func battle_transition(path: String):

	# ── Phase 1: ColorRect fades to black — covers overworld + dialogue ──
	var tween_fade_out = create_tween()
	tween_fade_out.set_trans(Tween.TRANS_LINEAR)
	tween_fade_out.tween_property(color_rect, "modulate:a", 1.0, 0.5)
	await tween_fade_out.finished

	# ── Phase 2: Snap bars to CENTER while still fully black ──
	# Bars are now covering the screen — ColorRect no longer needed
	top_rect.position    = Vector2(0, 0)
	bottom_rect.position = Vector2(0, SCREEN_H / 2.0)

	# Hide ColorRect — bars are covering everything now
	color_rect.modulate.a = 0

	# ── Phase 3: Change scene — bars are already covering screen ──
	# Battle scene loads BEHIND the bars — no flash visible
	get_tree().change_scene_to_file(path)

	# ── Phase 4: Wait for scene to fully load ──
	await get_tree().create_timer(0.6, true).timeout

	# ── Phase 5: Bars slide OUT revealing battle scene ──
	var tween_out = create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(top_rect, "position", Vector2(0, -SCREEN_H / 2.0), 1.7)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	tween_out.tween_property(bottom_rect, "position", Vector2(0, SCREEN_H), 1.7)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	await tween_out.finished

	# ── Reset bars off screen for next use ──
	top_rect.position    = Vector2(0, -SCREEN_H / 2.0)
	bottom_rect.position = Vector2(0, SCREEN_H)
