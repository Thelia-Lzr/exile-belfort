## <summary>无窗口规则测试入口。覆盖原版地图、建造限制、资源结算、撤销、饥荒及新旧存档兼容。失败时以非零状态退出。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
extends SceneTree

## <summary>当前测试已执行的检查数量。</summary>
var checks = 0

## <summary>测试脚本的 SceneTree 初始化入口，将测试延迟到场景树可用后执行。</summary>
## <returns>无返回值；通过 call_deferred 调用 run。</returns>
func _initialize() -> void:
	call_deferred("run")

## <summary>累加检查次数；条件失败时记录错误并以非零状态结束。</summary>
## <param name="condition">本次检查应满足的布尔表达式。</param>
## <param name="message">显示的中文反馈或测试失败说明。</param>
## <returns>无返回值；成功继续执行后续检查。</returns>
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAILED: " + message)
		quit(1)
		assert(condition, message)

## <summary>执行当前测试脚本中的规则或真实场景集成用例。</summary>
## <returns>无返回值；全部通过时输出检查数并以状态 0 退出。</returns>
func run() -> void:
	## <summary>规则模型对象，作为游戏数据的唯一来源。</summary>
	var state = BelfortState.new()
	state.reset()
	var visible_cells = 0
	var outer_ring = 0
	for y in range(BelfortState.HEIGHT):
		for x in range(BelfortState.WIDTH):
			var cell = Vector2i(x, y)
			if state.contains_cell(cell):
				visible_cells += 1
				if BelfortState.hex_distance(cell, BelfortState.MAP_CENTER) == 7:
					outer_ring += 1
	check(visible_cells == 169 and outer_ring == 42, "radius seven hex has 169 cells and 42 edge cells")
	check(not state.contains_cell(Vector2i(0, 0)), "rectangle corner excluded from playable hex")
	check(state.placement_error(Vector2i(0, 0), "farm", 0) == "建筑占地超出地图边界", "hidden cells cannot be built on")
	check(state.terrain.size() == 17 and state.terrain[0].size() == 23, "original map dimensions")
	check(state.resources == {"gold": 65, "food": 30, "wood": 65, "stone": 32}, "original starting economy")
	check(state.income().gold == 3 and state.income().food == 0, "town income minus population consumption")
	## <summary>建筑锚点坐标，即记录建筑的主地块。</summary>
	var anchor = Vector2i(10, 8)
	## <summary>测试中已出现的帐篷旋转签名数组。</summary>
	var seen: Array = []
	for direction in range(6):
		## <summary>一座建筑覆盖的所有地块坐标数组。</summary>
		var cells = state.footprint(anchor, "house", direction)
		check(cells.size() == 3 and cells[1] in BelfortState.neighbors(cells[2]), "triangular three-cell tent")
		## <summary>足迹坐标序列的字符串，用于检测方向是否重复。</summary>
		var signature = str(cells)
		check(signature not in seen, "all six rotations are distinct")
		seen.append(signature)
	check(not state.placement_error(Vector2i(0, 0), "house", 3).is_empty(), "edge footprint rejected")
	check(not state.placement_error(anchor, "farm", 0).is_empty(), "occupied tile rejected")
	for y in range(5, 12):
		for x in range(6, 16):
			state.terrain[y][x] = "grass"
	state.resources = {"gold": 1000, "food": 1000, "wood": 1000, "stone": 1000}
	for type in BelfortState.ORDER:
		## <summary>动画最终位置或找到的合法建筑地块。</summary>
		var target = find_site(state, type)
		check(target != Vector2i(-1, -1), "valid connected site for " + type)
		## <summary>操作前的资源快照或鼠标对应地图位置。</summary>
		var before = state.resources.duplicate()
		check(state.place(target, type, 0).is_empty(), "place " + type)
		for key in BelfortState.CATALOG[type].cost:
			check(state.resources[key] == before[key] - BelfortState.CATALOG[type].cost[key], "exact cost " + type + key)
	check(state.buildings.size() == 7 and state.occupied.size() == 9, "tent cells do not duplicate buildings")
	## <summary>用于预览或核对的回合收入字典。</summary>
	var income = state.income()
	check(income.gold == 12 and income.wood == 7 and income.stone == 6 and income.food == 5 and income.population == 1, "all six building yields")
	## <summary>回合结算前的资源快照。</summary>
	var before_round = state.resources.duplicate()
	state.next_turn()
	check(state.population == 6 and state.turn == 2 and state.undo_stack.is_empty(), "turn population and undo boundary")
	for key in state.resources:
		check(state.resources[key] == before_round[key] + income[key], "turn settlement " + key)
	## <summary>从规则模型导出的可序列化存档字典。</summary>
	var exported = state.to_data()
	## <summary>用于验证存档导入结果的独立规则模型。</summary>
	var loaded = BelfortState.new()
	check(loaded.load_data(JSON.parse_string(JSON.stringify(exported))).is_empty(), "native JSON roundtrip")
	check(loaded.occupied == state.occupied and loaded.resources == state.resources, "loaded state equals original")
	check(loaded.faction.id == state.faction.id, "faction flag roundtrip")
	check(loaded.map_shape == "hex7", "hex boundary survives save roundtrip")
	## <summary>载入失败前的完整状态字符串快照。</summary>
	var snapshot = JSON.stringify(loaded.to_data())
	for field in ["resources", "terrain", "buildings", "population", "turn"]:
		## <summary>测试中故意破坏字段的存档副本。</summary>
		var damaged = exported.duplicate(true)
		damaged[field] = "broken"
		check(not loaded.load_data(damaged).is_empty(), "reject malformed " + field)
		check(JSON.stringify(loaded.to_data()) == snapshot, "transactional load preserves state " + field)
	## <summary>转换为原版 v0.6 格式的测试存档。</summary>
	var legacy = exported.duplicate(true)
	legacy.version = "0.6"
	legacy.erase("map_shape")
	legacy.buildings = []
	for cell in state.occupied:
		## <summary>占地格所属的建筑锚点。</summary>
		var building_anchor = state.occupied[cell]
		legacy.buildings.append({"x": cell.x, "y": cell.y, "type": state.buildings[building_anchor].type if cell == building_anchor else "tent_part"})
	check(loaded.load_data(legacy).is_empty(), "import original v0.6 tent parts")
	check(loaded.occupied == state.occupied, "legacy multi-tile ownership reconstructed")
	check(loaded.map_shape == "rectangle" and loaded.contains_cell(Vector2i(0, 0)), "legacy rectangle remains available without cropping")
	## <summary>动画最终位置或找到的合法建筑地块。</summary>
	var target = find_site(loaded, "farm")
	## <summary>撤销测试中建造前的资源快照。</summary>
	var before_undo = loaded.resources.duplicate()
	check(loaded.place(target, "farm", 0).is_empty(), "build before undo")
	check(loaded.undo() == target and loaded.resources == before_undo and not loaded.occupied.has(target), "undo refunds cost and occupancy")
	loaded.population = 100
	loaded.resources.food = 0
	## <summary>当前回合是否发生粮食不足的标志或结算结果。</summary>
	var starving = loaded.next_turn()
	check(starving.starving and loaded.population == 100 and loaded.resources.food == 0, "starvation stops growth and clamps food")
	loaded.resources.wood = 0
	## <summary>失败建造前的序列化状态，用于检查无副作用。</summary>
	var unchanged = JSON.stringify(loaded.to_data())
	check(not loaded.place(find_site_ignoring_cost(loaded, "farm"), "farm", 0).is_empty(), "insufficient resources rejected")
	check(JSON.stringify(loaded.to_data()) == unchanged, "failed build has no side effects")
	## <summary>本次读写的完整文件路径。</summary>
	var path = "user://test_roundtrip.json"
	check(state.save_to(path) == OK, "atomic file save")
	check(loaded.load_data(JSON.parse_string(FileAccess.get_file_as_string(path))).is_empty(), "file reload")
	DirAccess.remove_absolute(path)
	print("MODEL TESTS PASSED: ", checks)
	quit(0)

## <summary>沿已有聚落寻找合法测试建造位置；按需调整测试地形。</summary>
## <param name="state">要展示或测试的规则模型。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>合法 Vector2i 坐标；无可用位置返回 (-1, -1)。</returns>
func find_site(state: BelfortState, type: String) -> Vector2i:
	for anchor in state.occupied.keys():
		for candidate in BelfortState.neighbors(anchor):
			if not BelfortState.in_bounds(candidate) or state.occupied.has(candidate):
				continue
			if type == "sawmill": state.terrain[candidate.y][candidate.x] = "forest"
			elif type == "quarry": state.terrain[candidate.y][candidate.x] = "hill"
			if state.placement_error(candidate, type, 0).is_empty():
				return candidate
	return Vector2i(-1, -1)

## <summary>暂时提供测试用木材寻找位置，然后恢复原资源。</summary>
## <param name="state">要展示或测试的规则模型。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>用于资源不足测试的 Vector2i 地块坐标。</returns>
func find_site_ignoring_cost(state: BelfortState, type: String) -> Vector2i:
	## <summary>临时修改前的原始资源快照。</summary>
	var previous = state.resources.duplicate()
	state.resources.wood = 9999
	## <summary>动画最终位置或找到的合法建筑地块。</summary>
	var target = find_site(state, type)
	state.resources = previous
	return target
