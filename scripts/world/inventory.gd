class_name FarmInventory
extends Node

signal inventory_changed
var items: Dictionary = {"seed": 8}

func add_item(item_id: String, amount: int = 1) -> void:
	items[item_id] = int(items.get(item_id, 0)) + amount
	inventory_changed.emit()

func remove_item(item_id: String, amount: int = 1) -> bool:
	if int(items.get(item_id, 0)) < amount: return false
	items[item_id] -= amount
	inventory_changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return int(items.get(item_id, 0)) >= amount
