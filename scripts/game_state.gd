## <summary>游戏规则与存档模型。使用 RefCounted 自动管理内存；不依赖窗口、声音或三维场景，便于单独学习和测试。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortState
extends RefCounted

## <summary>六边形地块世界半径，扩大为 1.25 以提升模型可读性。</summary>
const CELL_RADIUS = 1.25
## <summary>地图列数，沿用原版的 23 列。</summary>
const WIDTH = 23
## <summary>地图行数，沿用原版的 17 行。</summary>
const HEIGHT = 17
## <summary>新聚落地图向外延伸七圈，总计 1 + 3r(r+1) = 169 格。</summary>
const MAP_RADIUS = 7
const MAP_CENTER = Vector2i(10, 8)
## <summary>可建建筑顺序，同时对应数字快捷键 1 到 6。</summary>
const ORDER = ["house", "farm", "sawmill", "quarry", "market", "workshop"]
## <summary>资源内部键到中文名称的映射。</summary>
const RESOURCE_NAMES = {"gold": "金币", "food": "粮食", "wood": "木材", "stone": "石材"}
## <summary>地形内部键到中文名称的映射。</summary>
const TERRAIN_NAMES = {"grass": "草原", "forest": "森林", "hill": "丘陵", "water": "水域"}
## <summary>允许使用的势力配色列表。</summary>
const COLORS = ["#d1ad70", "#6599c2", "#b97468", "#82ac80", "#ad83c2", "#d0a76e"]
## <summary>建筑规则表，含名称、费用、回合产出、人口增长和地形提示。</summary>
const CATALOG = {
	"town": {"name": "市政厅", "cost": {}, "yield": {"gold": 3, "food": 2}, "population": 0, "hint": "聚落的中心", "tag": "中心"},
	"house": {"name": "帐篷", "cost": {"wood": 12, "stone": 5}, "yield": {"gold": 2}, "population": 1, "hint": "占据相邻三格 · 草原 / 森林", "tag": "居住"},
	"farm": {"name": "农场", "cost": {"wood": 9}, "yield": {"food": 5}, "population": 0, "hint": "草原 / 森林 · 保障粮食", "tag": "生产"},
	"sawmill": {"name": "伐木场", "cost": {"wood": 5, "stone": 4}, "yield": {"wood": 5}, "population": 0, "hint": "仅限森林 · 供应木材", "tag": "生产"},
	"quarry": {"name": "矿场", "cost": {"wood": 9}, "yield": {"stone": 4}, "population": 0, "hint": "仅限丘陵 · 开采石材", "tag": "生产"},
	"market": {"name": "市场", "cost": {"wood": 16, "stone": 12}, "yield": {"gold": 7}, "population": 0, "hint": "草原 / 森林 · 发展贸易", "tag": "经济"},
	"workshop": {"name": "工坊", "cost": {"wood": 20, "stone": 16, "gold": 15}, "yield": {"wood": 2, "stone": 2}, "population": 0, "hint": "草原 / 森林 · 综合生产", "tag": "生产"}
}

## <summary>二维地形数组，通过 terrain[行][列] 读取内部地形键。</summary>
var terrain: Array = []
## <summary>以建筑锚点 Vector2i 为键的建筑记录字典。</summary>
var buildings: Dictionary = {} # anchor -> {type, rotation, cells}
## <summary>地块到所属建筑锚点的映射，使三格帐篷只结算一次收益。</summary>
var occupied: Dictionary = {} # cell -> anchor (multi-tile buildings counted once)
## <summary>当前四类资源数量，键为 gold、food、wood、stone。</summary>
var resources = {"gold": 65, "food": 30, "wood": 65, "stone": 32}
## <summary>当前聚落人口，用于计算粮食消耗和增长。</summary>
var population = 5
## <summary>当前回合数，从 1 开始。</summary>
var turn = 1
## <summary>当前势力的旗帜标识、名称、颜色和背景。</summary>
var faction = {"id": "exiles", "name": "贝尔福流亡者", "color": "#d1ad70", "description": "在陌生的土地上，建立自己的家园。"}
## <summary>行动记录字符串数组，存档保留最近十五条。</summary>
var journal: Array = []
## <summary>本回合建造快照栈，保存锚点、扣费前资源和日志长度。</summary>
var undo_stack: Array = []
## <summary>新存档使用六边形；无此字段的旧存档保留矩形边界。</summary>
var map_shape = "hex7"

## <summary>重置地图、建筑和经济为原版初始状态，保留已选择的势力身份。</summary>
## <returns>无返回值；修改当前模型并清空本回合撤销记录。</returns>
func reset() -> void:
	map_shape = "hex7"
	terrain = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_map.json"))
	buildings.clear()
	occupied.clear()
	resources = {"gold": 65, "food": 30, "wood": 65, "stone": 32}
	population = 5
	turn = 1
	undo_stack.clear()
	journal = ["抵达贝尔福。市政厅已经建立，新的生活由此开始。"]
	_register(Vector2i(10, 8), "town", 0, [Vector2i(10, 8)])

## <summary>判断二维地块坐标是否位于 23×17 地图内。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>布尔值，true 表示地图内，false 表示地图外。</returns>
static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

## <summary>将奇数行偏移坐标转换为轴坐标，返回两格间的六边形距离。</summary>
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq = (a.x - (a.y - (a.y & 1)) / 2) - (b.x - (b.y - (b.y & 1)) / 2)
	var dr = a.y - b.y
	return int(max(abs(dq), abs(dr), abs(dq + dr)))

## <summary>统一地图显示、建造与拾取的有效边界，兼容旧矩形地图。</summary>
func contains_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and (map_shape == "rectangle" or hex_distance(cell, MAP_CENTER) <= MAP_RADIUS)

## <summary>将奇数行错位六边形坐标换算为世界 XZ 平面位置。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>Vector3 世界坐标；Y 固定为 0，实际地形高差由视图添加。</returns>
static func cell_position(cell: Vector2i) -> Vector3:
	return Vector3(sqrt(3.0) * (cell.x + 0.5 * (cell.y % 2) - 11.25), 0, 1.5 * (cell.y - 8)) * CELL_RADIUS

## <summary>按顺时针返回六个邻格坐标，保留地图外坐标以便边界验证。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>包含六个 Vector2i 的数组。</returns>
static func neighbors(cell: Vector2i) -> Array:
	# Clockwise ring: E, SE, SW, W, NW, NE. Exactly six rotations.
	## <summary>六边形邻格的坐标偏移数组。</summary>
	var offsets = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)]
	if cell.y % 2 == 1:
		offsets = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result: Array = []
	for offset in offsets:
		result.append(cell + offset)
	return result

## <summary>根据建筑类型和六方向档位计算全部占地；帐篷为相邻三格。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <param name="rotation">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <returns>Vector2i 数组，第一格始终是建筑锚点。</returns>
func footprint(cell: Vector2i, type: String, rotation: int) -> Array:
	if type != "house":
		return [cell]
	## <summary>围绕锚点排列的六个邻格或测试轮廓网格。</summary>
	var ring = neighbors(cell)
	return [cell, ring[posmod(rotation, 6)], ring[posmod(rotation + 1, 6)]]

## <summary>读取地块地形，地图外统一按水域处理。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>grass、forest、hill 或 water 地形标识。</returns>
func terrain_at(cell: Vector2i) -> String:
	return terrain[cell.y][cell.x] if contains_cell(cell) else "water"

## <summary>由任意占地格找到完整建筑，而不把帐篷附属格当成独立建筑。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>建筑字典，包含 type、rotation、cells；空地返回空字典。</returns>
func building_at(cell: Vector2i) -> Dictionary:
	return buildings.get(occupied.get(cell, Vector2i(-1, -1)), {})

## <summary>比较当前资源与建筑费用，汇总短缺的资源数量。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>中文短缺说明；资源足够时返回空字符串。</returns>
func missing_cost(type: String) -> String:
	## <summary>资源不足的中文原因列表。</summary>
	var missing: Array = []
	for key in CATALOG[type].cost:
		## <summary>某项建造费用仍缺少的数量或合并说明。</summary>
		var shortage = int(CATALOG[type].cost[key]) - int(resources[key])
		if shortage > 0:
			missing.append("%s缺 %d" % [RESOURCE_NAMES[key], shortage])
	return "、".join(missing)

## <summary>依次校验建筑种类、边界、占用、地形、连接关系和费用。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <param name="rotation">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <returns>空字符串表示可建造；非空字符串解释第一个失败原因。</returns>
func placement_error(cell: Vector2i, type: String, rotation: int) -> String:
	if type not in ORDER:
		return "请选择可建造的建筑"
	## <summary>一座建筑覆盖的所有地块坐标数组。</summary>
	var cells = footprint(cell, type, rotation)
	for part in cells:
		if not contains_cell(part):
			return "建筑占地超出地图边界"
		if occupied.has(part):
			return "地块已被建筑占用"
		if terrain_at(part) == "water":
			return "水域无法建造"
		if type == "house" and terrain_at(part) == "hill":
			return "帐篷不能建在丘陵"
	## <summary>当前地块的地形内部标识。</summary>
	var ground = terrain_at(cell)
	if type == "sawmill" and ground != "forest":
		return "伐木场需要森林地块"
	if type == "quarry" and ground != "hill":
		return "矿场需要丘陵地块"
	if type in ["farm", "market", "workshop"] and ground == "hill":
		return "该建筑需要草原或森林"
	## <summary>待建建筑是否接触已有聚落的标志。</summary>
	var connected = false
	for part in cells:
		for neighbor in neighbors(part):
			if occupied.has(neighbor):
				connected = true
	if not connected:
		return "必须连接已有建筑，逐步扩展聚落"
	## <summary>某项建造费用仍缺少的数量或合并说明。</summary>
	var shortage = missing_cost(type)
	return "资源不足：" + shortage if not shortage.is_empty() else ""

## <summary>登记建筑锚点与占地所有权，不扣除资源；供初始化和载入内部使用。</summary>
## <param name="anchor">建筑主地块坐标，其余占地格归属于该锚点。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <param name="rotation">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <param name="cells">该建筑需要占用的 Vector2i 地块数组，第一格为锚点。</param>
## <returns>无返回值；更新 buildings 与 occupied 两张表。</returns>
func _register(anchor: Vector2i, type: String, rotation: int, cells: Array) -> void:
	buildings[anchor] = {"type": type, "rotation": rotation, "cells": cells.duplicate()}
	for cell in cells:
		occupied[cell] = anchor

## <summary>执行一次经过完整校验的建造，保存撤销快照后扣费并登记占地。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <param name="rotation">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <returns>空字符串表示成功；失败返回原因且不修改游戏状态。</returns>
func place(cell: Vector2i, type: String, rotation: int) -> String:
	## <summary>规则或文件操作返回的错误说明。</summary>
	var error = placement_error(cell, type, rotation)
	if not error.is_empty():
		return error
	undo_stack.append({"anchor": cell, "resources": resources.duplicate(), "log_size": journal.size()})
	for key in CATALOG[type].cost:
		resources[key] -= CATALOG[type].cost[key]
	_register(cell, type, posmod(rotation, 6), footprint(cell, type, rotation))
	journal.append("第 %d 回合 · 建成%s [%d, %d]" % [turn, CATALOG[type].name, cell.x + 1, cell.y + 1])
	return ""

## <summary>撤销本回合最近一次建造并精确退还资源。</summary>
## <returns>被撤销的锚点坐标；没有可撤销操作时返回 (-1, -1)。</returns>
func undo() -> Vector2i:
	if undo_stack.is_empty():
		return Vector2i(-1, -1)
	## <summary>当前待处理的操作标识或撤销快照。</summary>
	var action = undo_stack.pop_back()
	## <summary>建筑锚点坐标，即记录建筑的主地块。</summary>
	var anchor: Vector2i = action.anchor
	for cell in buildings[anchor].cells:
		occupied.erase(cell)
	buildings.erase(anchor)
	resources = action.resources
	journal.resize(action.log_size)
	return anchor

## <summary>计算下回合资源净变化、食物消耗及可增长人口，不修改库存。</summary>
## <returns>字典，包含 gold、food、wood、stone、population、consumption。</returns>
func income() -> Dictionary:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = {"gold": 0, "food": 0, "wood": 0, "stone": 0, "population": 0, "consumption": ceili(population / 4.0)}
	for building in buildings.values():
		## <summary>当前建筑、势力或存档字段的详细信息。</summary>
		var info = CATALOG[building.type]
		for key in info["yield"]:
			result[key] += info["yield"][key]
		result.population += info.population
	result.food -= result.consumption
	return result

## <summary>结算建筑产出、人口粮食消耗和增长，推进回合并清空撤销栈。</summary>
## <returns>包含 gain 和 starving 的字典；starving 表示是否因缺粮停止增长。</returns>
func next_turn() -> Dictionary:
	## <summary>本回合各资源净收益及人口增长信息。</summary>
	var gain = income()
	## <summary>当前回合是否发生粮食不足的标志或结算结果。</summary>
	var starving = resources.food + gain.food < 0
	for key in resources:
		resources[key] = maxi(0, resources[key] + gain[key])
	if not starving:
		population += gain.population
	turn += 1
	undo_stack.clear()
	if starving:
		journal.append("粮食不足，人口停止增长。请优先建设农场。")
	journal.append("第 %d 回合 · 金币 %+d / 粮食 %+d / 木材 %+d / 石材 %+d" % [turn, gain.gold, gain.food, gain.wood, gain.stone])
	return {"gain": gain, "starving": starving}

## <summary>把 Vector2i 键和占地转换成 JSON 可保存的数据结构。</summary>
## <returns>包含版本、地图、建筑、资源、人口、回合、势力和日志的字典。</returns>
func to_data() -> Dictionary:
	## <summary>供 JSON 序列化的建筑记录数组。</summary>
	var records: Array = []
	for anchor in buildings:
		## <summary>当前遍历或查询到的建筑记录。</summary>
		var building = buildings[anchor]
		## <summary>一座建筑覆盖的所有地块坐标数组。</summary>
		var cells: Array = []
		for cell in building.cells:
			cells.append([cell.x, cell.y])
		records.append({"x": anchor.x, "y": anchor.y, "type": building.type, "rotation": building.rotation, "cells": cells})
	return {"version": "godot-2", "map_shape": map_shape, "terrain": terrain.duplicate(true), "buildings": records, "resources": resources.duplicate(), "population": population, "turn": turn, "faction": faction.duplicate(), "log": journal.slice(-15)}

## <summary>先写入临时文件，再原子重命名，降低中断导致存档损坏的风险。</summary>
## <param name="path">待读写文件路径，可使用 user:// 或绝对路径。</param>
## <returns>Godot Error 错误码，OK 表示写入成功。</returns>
func save_to(path: String) -> Error:
	## <summary>当前打开的文件访问对象。</summary>
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_data(), "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

## <summary>安全验证载入的数值是否为有限整数且落在允许范围内。</summary>
## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
## <param name="minimum">允许的最小整数，包含此边界。</param>
## <param name="maximum">允许的最大整数，包含此边界。</param>
## <returns>布尔值；字符串、无穷数、非整数或越界值均返回 false。</returns>
static func whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

## <summary>在临时模型中校验完整存档，并兼容原版 tent_part 格式；通过后整体提交。</summary>
## <param name="data">从 JSON 解析出的存档对象，使用前会进行完整校验。</param>
## <returns>成功返回空字符串；失败返回中文原因且当前游戏保持原状。</returns>
func load_data(data: Variant) -> String:
	# Validate into a temporary state; bad files never partially replace a game.
	if not data is Dictionary:
		return "存档必须是 JSON 对象"
	for key in ["terrain", "buildings", "resources", "population", "turn"]:
		if not data.has(key):
			return "存档缺少字段：" + key
	if not data.terrain is Array or data.terrain.size() != HEIGHT:
		return "地图高度无效"
	for row in data.terrain:
		if not row is Array or row.size() != WIDTH:
			return "地图宽度无效"
		for ground in row:
			if not ground is String or not TERRAIN_NAMES.has(ground):
				return "未知地形"
	if not data.resources is Dictionary:
		return "资源格式无效"
	for key in resources:
		if not whole_number(data.resources.get(key), 0, 100000000):
			return "资源数值无效：" + key
	if not whole_number(data.population, 0, 10000000) or not whole_number(data.turn, 1, 10000000):
		return "人口或回合无效"
	if not data.buildings is Array or data.buildings.size() > WIDTH * HEIGHT:
		return "建筑列表无效"
	## <summary>只用于验证存档的临时规则模型，验证成功后再整体替换。</summary>
	var staged = BelfortState.new()
	if data.get("map_shape", "rectangle") not in ["hex7", "rectangle"]:
		return "地图形状无效"
	staged.map_shape = data.get("map_shape", "rectangle")
	staged.terrain = data.terrain.duplicate(true)
	## <summary>旧版存档中尚未归属到帐篷的 tent_part 地块。</summary>
	var legacy_parts: Dictionary = {}
	for record in data.buildings:
		if not record is Dictionary or not whole_number(record.get("x"), 0, WIDTH - 1) or not whole_number(record.get("y"), 0, HEIGHT - 1):
			return "建筑坐标无效"
		## <summary>建筑或资源的内部类型字符串。</summary>
		var type = record.get("type", "")
		if not type is String or (not CATALOG.has(type) and type != "tent_part"):
			return "未知建筑类型"
		## <summary>建筑锚点坐标，即记录建筑的主地块。</summary>
		var anchor = Vector2i(int(record.x), int(record.y))
		if staged.occupied.has(anchor) or legacy_parts.has(anchor):
			return "建筑占地重复"
		if type == "tent_part":
			legacy_parts[anchor] = true
			continue
		if not whole_number(record.get("rotation", 0), 0, 5):
			return "建筑方向无效"
		## <summary>当前建筑旋转档位，0 到 5 对应六个 60 度方向。</summary>
		var rotation_value = int(record.get("rotation", 0))
		## <summary>一座建筑覆盖的所有地块坐标数组。</summary>
		var cells: Array = [anchor]
		if record.has("cells"):
			if not record.cells is Array or record.cells.size() != (3 if type == "house" else 1):
				return "建筑占地数量无效"
			cells.clear()
			for pair in record.cells:
				if not pair is Array or pair.size() != 2 or not whole_number(pair[0], 0, WIDTH - 1) or not whole_number(pair[1], 0, HEIGHT - 1):
					return "建筑占地坐标无效"
				## <summary>当前待查询、占用或绘制的地块坐标。</summary>
				var cell = Vector2i(int(pair[0]), int(pair[1]))
				if cells.has(cell) or staged.occupied.has(cell):
					return "建筑占地重叠"
				cells.append(cell)
			if cells[0] != anchor or (type == "house" and cells != footprint(anchor, type, rotation_value)):
				return "建筑占地与方向不匹配"
		for cell in cells:
			if not staged.contains_cell(cell):
				return "建筑占地超出地图边界"
			if staged.terrain_at(cell) == "water":
				return "建筑不能占用水域"
		staged._register(anchor, type, rotation_value, cells)
	# Original v0.6 stored the other two tent cells as tent_part records.
	for anchor in staged.buildings:
		## <summary>当前遍历或查询到的建筑记录。</summary>
		var building = staged.buildings[anchor]
		if building.type == "house" and building.cells.size() == 1:
			## <summary>是否找到旧版帐篷的两格附属占地。</summary>
			var found = false
			for direction in range(6):
				## <summary>一座建筑覆盖的所有地块坐标数组。</summary>
				var cells = footprint(anchor, "house", direction)
				if legacy_parts.has(cells[1]) and legacy_parts.has(cells[2]):
					legacy_parts.erase(cells[1])
					legacy_parts.erase(cells[2])
					staged._register(anchor, "house", direction, cells)
					found = true
					break
			if not found:
				return "旧存档的帐篷占地不完整"
	if not legacy_parts.is_empty():
		return "存档存在无归属的帐篷占地"
	for cell in staged.occupied:
		if not staged.contains_cell(cell) or staged.terrain_at(cell) == "water":
			return "建筑占地超出地图边界或位于水域"
	## <summary>存档中的市政厅数量，合法存档必须恰好为一座。</summary>
	var towns = 0
	for building in staged.buildings.values():
		if building.type == "town":
			towns += 1
	if towns != 1:
		return "存档需要且只能有一个市政厅"
	terrain = staged.terrain
	map_shape = staged.map_shape
	buildings = staged.buildings
	occupied = staged.occupied
	for key in resources:
		resources[key] = int(data.resources[key])
	population = int(data.population)
	turn = int(data.turn)
	journal = []
	if data.get("log") is Array:
		for line in data.log.slice(-15):
			journal.append(str(line).left(250))
	if data.get("faction") is Dictionary:
		## <summary>当前建筑、势力或存档字段的详细信息。</summary>
		var info = data.faction
		faction = {"id": info.get("id") if info.get("id") in ["exiles", "foresters", "guild", "cinder"] else "exiles", "name": str(info.get("name", "贝尔福流亡者")).left(24), "description": str(info.get("description", "")).left(160), "color": info.get("color") if info.get("color") in COLORS else COLORS[0]}
	undo_stack.clear()
	return ""
