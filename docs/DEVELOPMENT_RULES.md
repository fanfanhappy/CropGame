# 小溪农场开发约定

> 本文件以“纯节点驱动架构设计指南（Node-Centric / Godot Way）”为唯一准则。此前的其他架构约定均已被本规范取代。

本项目采用纯节点驱动架构（Node-Centric / Godot Way）。核心原则是：一切皆节点，万物皆场景，通过树状层级、节点脚本和信号协作。

## 一、场景优先

- 地图由 `TileMapLayer` 和场景节点组成，不在脚本中绘制地图。
- 角色、作物、工具、动物、NPC、建筑和特效都创建为独立场景。
- 场景树表达对象的组成、父子关系和显示层级。
- 能在编辑器中完成的内容，不用代码运行时生成。

## 二、节点职责

- 节点脚本只负责自身行为和状态。
- 父节点负责组织子节点，不代替子节点实现全部逻辑。
- 角色处理移动和输入，作物处理生长，土地处理耕作状态。
- 不创建一个脚本管理整个游戏所有对象的“上帝对象”。

## 三、信号通信

- 不直接依赖其他节点的内部变量。
- 节点之间优先通过信号通知事件，例如 `watered`、`harvested`、`day_changed`。
- 需要查找节点时使用明确的节点路径、分组或导出的节点引用。
- 信号连接关系应尽量在场景或节点自身中清晰可见。

## 四、地图和瓦片

- 草地、水面、耕地、道路使用独立的 `TileMapLayer`。
- Terrain Set 和自动拼接在 TileSet 编辑器中配置。
- 干耕地和湿润耕地使用素材瓦片，不使用代码颜色覆盖。
- 所有地图坐标通过 TileMapLayer 的 `local_to_map()` 和 `map_to_local()` 转换。
- 不写死地图范围、地图坐标或素材的显示位置。

## 五、素材和资源

- 图片放在 `assets/tilesets` 或对应功能目录。
- TileSet 资源放在 `scenes/farm/tilesets`，与农田场景保持可见关联。
- 场景放在 `scenes`，脚本放在 `scripts`。
- 每份素材先整理归档，再连接到场景和逻辑。
- 不覆盖用户在编辑器中配置好的 TileSet、Terrain 和地图数据。

## 六、编辑器优先

- 地图布局、碰撞、图层顺序、节点引用和素材选择尽量在编辑器完成。
- 代码只处理运行时行为、输入、状态变化、信号和存档。
- 新功能先设计场景树，再编写节点脚本。
- 修改后在 Godot 中重新加载场景并运行验证。

## 七、当前项目目标结构

```text
scenes/world/main.tscn
├─ GrassLayer       TileMapLayer
├─ WaterLayer       TileMapLayer
├─ SoilLayer        TileMapLayer
├─ Player           独立角色场景
├─ Crops            作物场景容器
└─ WorldObjects     建筑、树木和装饰
```

后续新增功能必须优先遵守以上约定；如果为了快速验证而临时使用代码绘制或集中式逻辑，验证完成后应迁移回节点和场景结构。

## 八、场景资产优先的目录哲学

本项目不按传统业务域拆分目录，而是按场景资产和实体类型组织。`.tscn` 场景文件是架构的绝对核心，用于承载预制体、节点层级、可视化配置和可复用对象。

- 每个可复用实体优先创建为独立 `.tscn` 场景。
- 目录名称描述实体类型和场景用途，例如 `actors`、`crops`、`props`、`world`、`ui`。
- 同一实体的场景、专属脚本、动画和资源应尽量放在相邻目录，方便拖拽、复制和并行编辑。
- 主场景负责组装节点，不负责把所有实体细节写进一个脚本。
- 需要变体时复制或继承场景，而不是在脚本里堆叠大量分支。
- 节点树、导出的节点引用、信号连接和资源挂载关系优先在编辑器中完成。
- 脚本文件是场景行为的附属物，不是项目结构的中心。
- 临时测试场景、旧版本场景和可恢复备份应放入明确的 `legacy` 或 `backups` 目录，不参与主流程。

## 九、实体类型目录

```text
scenes/
├─ world/       世界、地图和关卡组装场景
├─ actors/      玩家、动物、NPC 等可移动实体
├─ crops/       作物、种子和成长阶段场景
├─ props/       树木、建筑、石头、工具等场景
├─ farm/        农田、土地状态和农场专用场景
├─ ui/          界面和交互面板场景
└─ legacy/      旧场景和恢复用备份
```

当前主世界场景与其专属脚本已共同放在 `scenes/world/`；共享 TileSet 资源放在 `scenes/farm/tilesets/`，素材仍按图集类型归档在 `assets/tilesets/`。

## 十、命名规范

命名以“上下文自明、层级稳定、编辑器可寻址”为原则。文件系统名称与节点名称采用不同风格，避免把引擎默认名称直接当作实体名称。

### 文件和目录

- 目录、场景（`.tscn`）、脚本（`.gd`）、资源（`.tres` / `.res`）和美术音频素材统一使用小写 `snake_case`，不得出现空格、中文或连字符。
- 脚本文件通常与对应场景同名；若使用 `class_name`，类名使用 PascalCase，文件名仍保持小写 `snake_case`。
- 贴图建议使用“类别_描述_状态或方向”结构，例如 `spr_player_walk_down.png`、`tileset_soil_wet.png`；音频使用 `sfx_` 或 `bgm_` 前缀。
- 可复用场景、专属脚本和资源尽量相邻；旧版本放在 `legacy/` 或 `backups/`，不参与主流程。

### 场景树节点

- 场景根节点和内部子节点使用 PascalCase，并体现实体或职责，例如 `FarmGame`、`Player`、`VisualBody`、`InteractionCollider`、`GrowthTickTimer`。
- 不保留 `Sprite2D`、`Area2D`、`CollisionShape2D`、`Timer` 等默认名称作为自定义实体名。
- 需要跨层级访问的核心节点启用 Unique Name，使用明确名称，例如 `%PlayerRoot`、`%CurrentMap`、`%UICanvas`。
- 节点名不得包含层级信息（如 `ChildOfPlayer`），以便场景移动和复用。

### 脚本标识符、信号和分组

- 变量、属性、函数和信号使用小写 `snake_case`；私有方法以单下划线开头；常量使用 `UPPER_SNAKE_CASE`。
- 动作函数以动词开头（`plant_seed()`、`water_plot()`），查询函数以 `is_` 或 `has_` 开头。
- 信号使用过去式描述已发生事件，例如 `crop_harvested`、`water_level_changed`、`player_entered_zone`。
- 节点组使用小写 `snake_case`，采用“范围_实体类型”结构，例如 `farm_plots`、`growing_crops`、`saveable_entities`。

### 状态和领域词汇

- 枚举类型使用 PascalCase，枚举值使用 `UPPER_SNAKE_CASE`，例如 `TileState.WATERED`、`PlayerAction.HOEING`。
- 统一使用以下词汇：地块 `Plot` / `Tile`、翻地 `Till`、浇水 `Water`、收获 `Harvest`、作物 `Crop`、种子 `Seed`、杂草 `Weed`、体力 `Stamina`、背包 `Inventory`、快捷栏 `Hotbar`。
- 避免使用 `Cell`、`GridBlock`、`Land`、`Dig`、`Plow`、`Irrigate`、`Pour`、`Pick`、`Collect`、`Plant`（动词歧义）等替代词。

### 防崩塌红线

- 禁止空格、中文、连字符和无意义缩写（如 `mgr`、`ctrl`、`p_node`）。
- 不得用 `input`、`process`、`position`、`scale` 等引擎属性或方法名作为自定义标识符。
- 新建节点、场景和资源时，先按本节命名，再在编辑器中连接引用和信号。
