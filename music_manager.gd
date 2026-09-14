extends Node

@onready var bgm_player = $BGMPlayer
@onready var button_sfx = $ButtonSFX
@onready var terminal_sfx = $TerminalSFX
@onready var hints_sfx = $HintsSFX # <--- 1. Add the new reference

# ─── MUSIC ──────────────────────────────────────────────────────────
func play_menu_music():
	if not bgm_player.playing:
		bgm_player.play()

func stop_music():
	bgm_player.stop()

# ─── SOUND EFFECTS ──────────────────────────────────────────────────
func play_button_click():
	button_sfx.play()

func play_terminal_click():
	terminal_sfx.play()

func play_hint_sfx(): # <--- 2. Add the new function
	hints_sfx.play()
