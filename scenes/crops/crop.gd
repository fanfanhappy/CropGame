class_name FarmCrop
extends Node2D

signal crop_harvested
signal growth_stage_changed(growth_stage: int)

@export var crop_name := "作物"
@export var growth_duration_days := 3
@export var harvest_value := 35
@export var max_growth_stage := 3
var growth_stage := 0
var watered_today := false

func water() -> void:
	watered_today = true

func advance_day() -> void:
	if watered_today:
		growth_stage = mini(growth_stage + 1, max_growth_stage)
		growth_stage_changed.emit(growth_stage)
	watered_today = false

func is_fully_grown() -> bool:
	return growth_stage >= max_growth_stage

func harvest() -> int:
	if not is_fully_grown():
		return 0
	crop_harvested.emit()
	return harvest_value
