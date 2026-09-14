class_name FarmTree
extends Node2D

@export var hit_points := 3
var is_chopped := false

func chop() -> bool:
	if is_chopped:
		return false
	hit_points -= 1
	if hit_points <= 0:
		is_chopped = true
		visible = false
	return true

func _draw() -> void:
	draw_rect(Rect2(-7, 18, 14, 38), Color("#72513e"))
	draw_circle(Vector2(-22, 12), 27, Color("#477c57"))
	draw_circle(Vector2(10, 2), 32, Color("#5d9963"))
	draw_circle(Vector2(28, 21), 23, Color("#477c57"))
