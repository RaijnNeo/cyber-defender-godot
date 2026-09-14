extends AnimatableBody2D

func _ready():
	$AnimatedSprite2D.play("run")
	print("Area2D monitoring: ", $Area2D.monitoring)
	print("Area2D collision mask: ", $Area2D.collision_mask)

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		# 1. Stop movement and lock input
		body.is_moving = false
		body.input_locked = true

		# 2. Figure out bounce direction (opposite of travel)
		var bounce_dir = Vector2.ZERO
		if body.last_direction == "up":    bounce_dir = Vector2(0, 16)
		elif body.last_direction == "down": bounce_dir = Vector2(0, -16)
		elif body.last_direction == "left": bounce_dir = Vector2(16, 0)
		elif body.last_direction == "right": bounce_dir = Vector2(-16, 0)

		# 3. Snap to the exact centre of the tile behind them
		var raw_push = body.position + bounce_dir
		var snapped_pos = (raw_push / 16).floor() * 16 + Vector2(8, 8)

		body.target_pos = snapped_pos

		# 4. Smooth slide back
		var tween = get_tree().create_tween()
		tween.tween_property(body, "position", snapped_pos, 0.2).set_trans(Tween.TRANS_SINE)

		# 5. Unlock controls after slide — but only if not in an encounter
		tween.tween_callback(func():
			# Guard: don't unlock if _trigger_encounter locked us during the bounce
			if not body.get_meta("in_encounter", false):
				body.input_locked = false
		)
