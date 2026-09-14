class_name FarmSaveManager
extends Node

@export var save_path := "user://farm_save.json"
signal game_saved
signal game_loaded

func save_game(game_state: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(game_state))
	game_saved.emit()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path): return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		game_loaded.emit()
		return parsed
	return {}
