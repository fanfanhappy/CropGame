extends Node2D

const TILE := 48
const GRID_W := 18
const GRID_H := 12
const ORIGIN := Vector2(144, 96)
const FARM_RECT := Rect2i(2, 1, 10, 9)
const GRASS_SOURCE := Rect2(0, 80, 16, 16)

@export var use_procedural_grass := true
@export var show_demo_environment := false
var grass_texture: Texture2D = preload("res://assets/tilesets/grass/tileset_grass.png")

var player_pos := Vector2(ORIGIN.x + TILE * 6.5, ORIGIN.y + TILE * 6.5)
var facing := Vector2i(0, 1)
var move_speed := 210.0
var day := 1
var coins := 120
var seeds := 8
var stamina := 100
var max_stamina := 100
var weather := "晴天"
var weather_options := ["晴天", "多云", "小雨"]
var message := "欢迎来到小溪农场！用鼠标指向地块并点击进行种田。"
var message_time := 6.0
var soil: Dictionary = {}
var crops: Dictionary = {}
var watered_soil: Dictionary = {}
var water_layer: TileMapLayer
var grass_layer: TileMapLayer
var soil_layer: TileMapLayer
var player_node: Node2D
@onready var save_manager: Node = get_node_or_null("SaveManager")
@onready var inventory: Node = get_node_or_null("Inventory")
@onready var crop_container: Node2D = get_node_or_null("Crops") as Node2D
var water_frame := 0
var water_anim_time := 0.0
var hover_cell := Vector2i(-1, -1)

var grass_color := Color("#83b56a")
var grass_dark := Color("#6aa05b")
var soil_color := Color("#9b6b49")
var tilled_color := Color("#6f4939")
var water_color := Color("#5da9c5")
var cream := Color("#fff4d6")

func _ready() -> void:
	water_layer = get_node_or_null("WaterLayer") as TileMapLayer
	grass_layer = get_node_or_null("GrassLayer") as TileMapLayer
	soil_layer = get_node_or_null("SoilLayer") as TileMapLayer
	player_node = get_node_or_null("Player") as Node2D
	if player_node != null:
		player_node.position = player_pos
	for y in range(GRID_H):
		for x in range(GRID_W):
			soil[Vector2i(x, y)] = false
	queue_redraw()

func _process(delta: float) -> void:
	if water_layer != null:
		water_anim_time += delta
		if water_anim_time >= 0.24:
			water_anim_time = 0.0
			water_frame = (water_frame + 1) % 4
			for water_cell in water_layer.get_used_cells():
				water_layer.set_cell(water_cell, 0, Vector2i(water_frame, 0), 0)
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		var next_pos := player_pos + input_dir * move_speed * delta
		if is_walkable_world(next_pos):
			player_pos = next_pos
		if abs(input_dir.x) > abs(input_dir.y):
			facing = Vector2i(sign(input_dir.x), 0)
		else:
			facing = Vector2i(0, sign(input_dir.y))
	var movement_rect := get_movement_rect()
	var min_pos := movement_rect.position
	var max_pos := movement_rect.end
	player_pos.x = clamp(player_pos.x, min_pos.x, max_pos.x)
	player_pos.y = clamp(player_pos.y, min_pos.y, max_pos.y)
	if player_node != null:
		player_node.position = player_pos
		player_node.set_motion(facing, input_dir.length() > 0.0)
	hover_cell = grid_at_world(get_global_mouse_position())
	message_time = max(0.0, message_time - delta)
	if Input.is_key_pressed(KEY_T):
		if not get_meta("t_down", false):
			set_meta("t_down", true)
			start_new_day()
	if Input.is_key_pressed(KEY_F5):
		save_progress()
	if Input.is_key_pressed(KEY_F9):
		load_progress()
	else:
		set_meta("t_down", false)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if try_chop_tree(get_global_mouse_position()):
			return
		if stamina <= 0:
			show_message("体力耗尽了，按 T 进入下一天恢复体力。")
			return
		interact(hover_cell)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		water_soil(hover_cell)

func grid_at_world(pos: Vector2) -> Vector2i:
	if grass_layer != null:
		return grass_layer.local_to_map(grass_layer.to_local(pos))
	return Vector2i.ZERO

func is_walkable_world(pos: Vector2) -> bool:
	var cell := grid_at_world(pos)
	if grass_layer == null or grass_layer.get_cell_source_id(cell) == -1:
		return false
	if water_layer != null and water_layer.get_cell_source_id(cell) != -1:
		return false
	return true

func tile_center(cell: Vector2i) -> Vector2:
	if grass_layer != null:
		return grass_layer.to_global(grass_layer.map_to_local(cell))
	return ORIGIN + Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)

func tile_rect(cell: Vector2i) -> Rect2:
	var tile_size := Vector2(TILE, TILE)
	if grass_layer != null and grass_layer.tile_set != null:
		tile_size = Vector2(grass_layer.tile_set.tile_size)
	return Rect2(tile_center(cell) - tile_size * 0.5, tile_size)

func get_movement_rect() -> Rect2:
	if grass_layer != null:
		var used_rect := grass_layer.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			var tile_size := Vector2(TILE, TILE)
			if grass_layer.tile_set != null:
				tile_size = Vector2(grass_layer.tile_set.tile_size)
			var first_cell := grass_layer.to_global(grass_layer.map_to_local(used_rect.position))
			var last_cell := grass_layer.to_global(grass_layer.map_to_local(used_rect.position + used_rect.size - Vector2i.ONE))
			var half_tile := tile_size * 0.5
			return Rect2(first_cell - half_tile, (last_cell - first_cell) + tile_size).grow(-4.0)
	var fallback_min := ORIGIN + Vector2(TILE * 0.35, TILE * 0.35)
	var fallback_max := ORIGIN + Vector2(TILE * (GRID_W - 0.35), TILE * (GRID_H - 0.35))
	return Rect2(fallback_min, fallback_max - fallback_min)

func interact(target: Vector2i) -> void:
	if target.x < 0 or target.y < 0:
		return
	if grass_layer == null or grass_layer.get_cell_source_id(target) == -1:
		show_message("这里不是草地，不能在水面或空地上耕作。")
		return
	if not soil.has(target):
		soil[target] = false
	if crops.has(target):
		var crop: Dictionary = crops[target]
		if crop.growth >= 3:
				crops.erase(target)
				play_player_action("harvest")
				coins += 35
				seeds += 1
				if inventory != null and inventory.has_method("add_item"):
					inventory.add_item("crop", 1)
				show_message("收获成功！获得 35 金币和 1 颗种子。")
		elif crop.watered:
			show_message("这株作物今天已经浇过水了。")
		else:
			crop.watered = true
			play_player_action("water")
			if soil_layer != null:
				soil_layer.set_cells_terrain_connect([target], 0, 1)
			crops[target] = crop
			show_message("浇水完成，明天它会继续生长。")
		return
	if not soil[target]:
		if not spend_stamina(8): return
		soil[target] = true
		play_player_action("hoe")
		if soil_layer != null:
			soil_layer.set_cells_terrain_connect([target], 0, 0)
		show_message("土地已翻松，左键播种，右键浇水。")
		return
	if seeds > 0:
		if not spend_stamina(2): return
		seeds -= 1
		crops[target] = {"growth": 0, "watered": watered_soil.get(target, false), "days_growing": 0, "crop_id": "tomato"}
		watered_soil.erase(target)
		if crops[target].watered:
			show_message("种子已种下，这块地已经浇过水了。")
		else:
			show_message("种下了一颗种子，右键浇水。")
		return
	else:
		show_message("种子用完了，去商店购买一些吧。")

func water_soil(target: Vector2i) -> void:
	if target.x < 0 or target.y < 0 or grass_layer == null or grass_layer.get_cell_source_id(target) == -1:
		return
	if not soil.get(target, false):
		show_message("先用左键把这块草地翻成耕地。")
		return
	if crops.has(target):
		if not spend_stamina(4): return
		var crop: Dictionary = crops[target]
		if crop.watered:
			show_message("这块土地今天已经浇过水了。")
			return
		crop.watered = true
		crops[target] = crop
	else:
		if not spend_stamina(3): return
		if watered_soil.get(target, false):
			show_message("这块土地今天已经浇过水了。")
			return
		watered_soil[target] = true
	if soil_layer != null:
		soil_layer.set_cells_terrain_connect([target], 0, 1)
	play_player_action("water")
	show_message("浇水完成，可以继续播种。")

func play_player_action(action_name: String) -> void:
	if player_node != null and player_node.has_method("play_action"):
		player_node.play_action(action_name)

func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		show_message("体力不足，按 T 进入下一天恢复体力。")
		return false
	stamina -= amount
	return true

func try_chop_tree(world_pos: Vector2) -> bool:
	for tree in get_tree().get_nodes_in_group("interactable_props"):
		if not tree.visible or tree.global_position.distance_to(world_pos) > 42.0:
			continue
		if tree.has_method("chop"):
			var tree_felled: bool = tree.chop()
			play_player_action("chop")
			if tree_felled and inventory != null and inventory.has_method("add_item"):
				inventory.add_item("wood", 1)
			show_message("获得 1 木材。" if tree.visible else "树被砍倒了，获得 1 木材。")
			return true
	return false

func start_new_day() -> void:
	day += 1
	stamina = max_stamina
	weather = weather_options[(day - 1) % weather_options.size()]
	for crop_node in get_tree().get_nodes_in_group("growing_crops"):
		if crop_node.has_method("advance_day"):
			crop_node.advance_day()
	for cell in crops.keys().duplicate():
		var crop: Dictionary = crops[cell]
		if crop.watered or weather == "小雨":
			crop.growth = min(3, crop.growth + 1)
			crop.days_growing = int(crop.get("days_growing", 0)) + 1
			if soil_layer != null:
				soil_layer.set_cells_terrain_connect([cell], 0, 0)
		else:
			show_message("有作物因为缺水，今天没有成长。")
		crop.watered = false
		crops[cell] = crop
	for cell in watered_soil.keys().duplicate():
		watered_soil.erase(cell)
		if soil_layer != null:
			soil_layer.set_cells_terrain_connect([cell], 0, 0)
		show_message("新的一天：%s。雨天会自动浇水。" % weather)
	save_progress()

func save_progress() -> void:
	if save_manager != null and save_manager.has_method("save_game"):
		save_manager.save_game({"day": day, "coins": coins, "seeds": seeds, "stamina": stamina})
		show_message("进度已保存。")

func load_progress() -> void:
	if save_manager == null or not save_manager.has_method("load_game"): return
	var state: Dictionary = save_manager.load_game()
	if state.is_empty():
		show_message("没有找到存档。")
		return
	day = int(state.get("day", day))
	coins = int(state.get("coins", coins))
	seeds = int(state.get("seeds", seeds))
	stamina = int(state.get("stamina", stamina))
	show_message("进度已读取。")

func show_message(text: String) -> void:
	message = text
	message_time = 4.0

func _draw() -> void:
	# 地图视觉由 TileMapLayer 负责；这里只保留运行时角色、作物和界面。
	draw_rect(Rect2(0, 0, 1152, 86), Color("#244b4c"))
	draw_rect(Rect2(0, 86, 1152, 26), Color("#3b7770"))
	for cell in crops.keys():
		draw_crop(cell, crops[cell])
	if hover_cell.x >= 0 and hover_cell.y >= 0 and grass_layer != null and grass_layer.get_cell_source_id(hover_cell) != -1:
		var hover_rect := tile_rect(hover_cell)
		var fill_color := Color("#ffe69a", 0.28)
		var border_color := Color("#fff0a8", 0.95)
		if crops.has(hover_cell):
			var hovered_crop: Dictionary = crops[hover_cell]
			if hovered_crop.growth >= 3:
				fill_color = Color("#f4c95d", 0.34)
				border_color = Color("#fff1a6", 1.0)
			elif hovered_crop.watered:
				fill_color = Color("#76c9df", 0.28)
				border_color = Color("#a8e8f2", 1.0)
		elif soil.get(hover_cell, false):
			if watered_soil.get(hover_cell, false):
				fill_color = Color("#76c9df", 0.28)
				border_color = Color("#a8e8f2", 1.0)
			else:
				fill_color = Color("#ad805c", 0.28)
				border_color = Color("#e6b17d", 1.0)
		draw_rect(hover_rect, fill_color, true)
		draw_rect(hover_rect, border_color, false, 3.0)
	draw_overlay_interface()

func _draw_legacy_environment() -> void:
	# 天空与地面
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 720)), Color("#d5ecdc"))
	draw_rect(Rect2(0, 0, 1152, 86), Color("#244b4c"))
	draw_rect(Rect2(0, 86, 1152, 26), Color("#3b7770"))
	if not show_demo_environment:
		draw_player()
		draw_overlay_interface()
		return
	# 小溪
	draw_rect(Rect2(720, ORIGIN.y, 250, TILE * GRID_H), Color("#6bb8c8"))
	for y in range(GRID_H):
		var wave_x := 740.0 + (y % 2) * 22.0
		draw_line(Vector2(wave_x, ORIGIN.y + y * TILE + 18), Vector2(wave_x + 28, ORIGIN.y + y * TILE + 18), Color("#a5deca"), 3.0)
	# 草地网格与农田
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell := Vector2i(x, y)
			var rect := Rect2(ORIGIN + Vector2(x * TILE, y * TILE), Vector2(TILE, TILE))
			var base := grass_color if (x + y) % 2 == 0 else grass_dark
			if FARM_RECT.has_point(cell):
				base = tilled_color if soil[cell] else Color("#a87952")
				if crops.has(cell) and crops[cell].watered:
					base = Color("#6a5147")
			draw_rect(rect, base)
			if use_procedural_grass and not FARM_RECT.has_point(cell):
				# 使用导入的草地瓦片图集中的完整草地块作为底纹。
				draw_texture_rect_region(grass_texture, rect, GRASS_SOURCE)
			draw_rect(rect, Color("#ffffff", 0.08), false, 1.0)
	# 目标格高亮
	var target := grid_at_world(player_pos) + facing
	if target.x >= 0 and target.y >= 0 and target.x < GRID_W and target.y < GRID_H:
		draw_rect(Rect2(ORIGIN + Vector2(target.x * TILE, target.y * TILE), Vector2(TILE, TILE)), Color("#ffe69a", 0.45), false, 3.0)
	# 作物
	for cell in crops.keys():
		draw_crop(cell, crops[cell])
	# 小路、房屋和树
	draw_rect(Rect2(48, 624, 560, 48), Color("#c3a276"))
	draw_rect(Rect2(96, 126, 110, 102), Color("#d58d63"))
	draw_colored_polygon(PackedVector2Array([Vector2(82, 126), Vector2(151, 78), Vector2(220, 126)]), Color("#7a4b4a"))
	draw_rect(Rect2(118, 178, 32, 50), Color("#6b4f45"))
	draw_rect(Rect2(164, 154, 28, 26), Color("#bce6df"))
	draw_tree(Vector2(645, 190))
	draw_tree(Vector2(638, 435))
	# 玩家
	draw_player()
	# 顶栏
	draw_string(ThemeDB.fallback_font, Vector2(28, 39), "小溪农场", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, cream)
	draw_string(ThemeDB.fallback_font, Vector2(28, 68), "第 %d 天" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c5e9d1"))
	draw_string(ThemeDB.fallback_font, Vector2(910, 38), "金币 %d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffe7a3"))
	draw_string(ThemeDB.fallback_font, Vector2(910, 68), "种子 %d" % seeds, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d7f0cf"))
	# 底部操作提示
	draw_rect(Rect2(24, 678, 1104, 34), Color("#244b4c", 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(40, 701), "WASD / 方向键 移动    左键 翻地/播种/收获    右键 浇水    T 进入下一天", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cream)
	if message_time > 0:
		draw_rect(Rect2(250, 28, 610, 44), Color("#fff4d6", 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(270, 57), message, HORIZONTAL_ALIGNMENT_LEFT, 570, 16, Color("#244b4c"))

func draw_crop(cell: Vector2i, crop: Dictionary) -> void:
	var center := tile_center(cell)
	var stage: int = crop.growth
	if stage == 0:
		draw_circle(center + Vector2(0, 8), 6, Color("#e0bc78"))
	elif stage == 1:
		draw_line(center + Vector2(0, 12), center + Vector2(0, -4), Color("#426f48"), 4)
		draw_circle(center + Vector2(-6, -4), 7, Color("#74b85f"))
		draw_circle(center + Vector2(6, -7), 7, Color("#8bc96a"))
	elif stage == 2:
		draw_line(center + Vector2(0, 14), center + Vector2(0, -11), Color("#3f7043"), 5)
		draw_circle(center + Vector2(-9, -8), 9, Color("#69ad56"))
		draw_circle(center + Vector2(9, -10), 9, Color("#82c660"))
		draw_circle(center + Vector2(0, -17), 7, Color("#e8c85e"))
	else:
		draw_line(center + Vector2(0, 16), center + Vector2(0, -13), Color("#42733e"), 5)
		draw_circle(center + Vector2(-10, -8), 10, Color("#6caf4b"))
		draw_circle(center + Vector2(10, -9), 10, Color("#7fc55a"))
		draw_circle(center + Vector2(0, -18), 10, Color("#f19b55"))
		draw_circle(center + Vector2(0, -18), 5, Color("#ffd878"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-12, 28), "可收获", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fff0a8"))
	if crop.watered:
		draw_arc(center + Vector2(0, 19), 8, PI, TAU, 12, Color("#8bd2e5"), 2)

func draw_tree(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-7, 22), Vector2(14, 38)), Color("#72513e"))
	draw_circle(pos + Vector2(-22, 16), 27, Color("#477c57"))
	draw_circle(pos + Vector2(10, 5), 32, Color("#5d9963"))
	draw_circle(pos + Vector2(28, 25), 23, Color("#477c57"))

func draw_player() -> void:
	draw_circle(player_pos + Vector2(0, 13), 15, Color("#3a4a57", 0.25))
	draw_rect(Rect2(player_pos + Vector2(-12, -8), Vector2(24, 29)), Color("#e37e61"))
	draw_circle(player_pos + Vector2(0, -15), 13, Color("#f3bd8b"))
	draw_rect(Rect2(player_pos + Vector2(-16, -28), Vector2(32, 8)), Color("#d8a24c"))
	draw_rect(Rect2(player_pos + Vector2(-10, -35), Vector2(20, 9)), Color("#d8a24c"))
	draw_circle(player_pos + Vector2(-5, -16), 2, Color("#244b4c"))
	draw_circle(player_pos + Vector2(5, -16), 2, Color("#244b4c"))

func draw_overlay_interface() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(28, 39), "小溪农场", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, cream)
	draw_string(ThemeDB.fallback_font, Vector2(28, 68), "第 %d 天" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c5e9d1"))
	draw_string(ThemeDB.fallback_font, Vector2(910, 38), "金币 %d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffe7a3"))
	draw_string(ThemeDB.fallback_font, Vector2(910, 68), "种子 %d" % seeds, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d7f0cf"))
	var wood_count := 0
	var crop_count := 0
	if inventory != null and "items" in inventory:
		wood_count = int(inventory.items.get("wood", 0))
		crop_count = int(inventory.items.get("crop", 0))
	draw_string(ThemeDB.fallback_font, Vector2(470, 38), "木材 %d  作物 %d" % [wood_count, crop_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffe7a3"))
	draw_string(ThemeDB.fallback_font, Vector2(700, 38), "体力 %d/%d" % [stamina, max_stamina], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffd59a"))
	draw_string(ThemeDB.fallback_font, Vector2(700, 68), "天气 %s" % weather, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c5e9d1"))
	draw_rect(Rect2(24, 678, 1104, 34), Color("#244b4c", 0.92))
	draw_string(ThemeDB.fallback_font, Vector2(40, 701), "WASD / 方向键 移动    左键 翻地/播种/收获    右键 浇水    T 下一天    F5 保存    F9 读档", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cream)
	if message_time > 0:
		draw_rect(Rect2(250, 28, 610, 44), Color("#fff4d6", 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(270, 57), message, HORIZONTAL_ALIGNMENT_LEFT, 570, 16, Color("#244b4c"))


