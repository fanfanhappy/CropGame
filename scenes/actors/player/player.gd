class_name Player
extends Node2D

@onready var main_sprite: AnimatedSprite2D = %ActionSprite
var direction_row := 0
var is_moving := false
var current_action := ""
var action_time_left := 0.0

func _process(delta: float) -> void:
	if main_sprite == null or main_sprite.sprite_frames == null:
		return
	if action_time_left > 0.0:
		action_time_left -= delta
		if action_time_left <= 0.0:
			current_action = ""
	var direction_name: String = ["down", "up", "left", "right"][direction_row]
	var animation_name := ((current_action + "_") if current_action != "" else ("walk_" if is_moving else "idle_")) + direction_name
	if main_sprite.sprite_frames.has_animation(animation_name):
		if main_sprite.animation != animation_name:
			main_sprite.play(animation_name)
		elif not is_moving:
			main_sprite.pause()
		else:
			main_sprite.play()
	else:
		var fallback_name := ("walk_" if is_moving else "idle_") + direction_name
		if main_sprite.sprite_frames.has_animation(fallback_name):
			main_sprite.play(fallback_name)

func set_motion(direction: Vector2i, moving: bool) -> void:
	is_moving = moving
	if direction == Vector2i(0, 1):
		direction_row = 0
	elif direction == Vector2i(0, -1):
		direction_row = 1
	elif direction == Vector2i(-1, 0):
		direction_row = 2
	elif direction == Vector2i(1, 0):
		direction_row = 3
	if main_sprite != null and main_sprite.sprite_frames != null:
		main_sprite.frame = direction_row * 8

func play_action(action_name: String, duration := 0.6) -> void:
	current_action = action_name
	action_time_left = duration
