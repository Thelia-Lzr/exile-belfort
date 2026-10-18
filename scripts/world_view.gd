## <summary>三维地图视图。负责正交相机、六边形地块、射线拾取、建筑实例、选中轮廓和建造预览。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortWorld
extends Node3D

## <summary>某批材料落地时发出；监听者播放经节流处理的落地音效。</summary>
signal material_landed
## <summary>地图中一座新建筑完成拼装时发出，供主控制器播放声音。</summary>
signal building_finished

## <summary>建筑类型到可复用 PackedScene 场景的映射。</summary>
const BUILDING_SCENES = {
	"town": preload("res://models/buildings/town.tscn"), "house": preload("res://models/buildings/house.tscn"),
	"farm": preload("res://models/buildings/farm.tscn"), "sawmill": preload("res://models/buildings/sawmill.tscn"),
	"quarry": preload("res://models/buildings/quarry.tscn"), "market": preload("res://models/buildings/market.tscn"),
	"workshop": preload("res://models/buildings/workshop.tscn")
}
## <summary>资源类型到可复用 PackedScene 场景的映射。</summary>
const RESOURCE_SCENES = {
	"gold": preload("res://models/resources/gold.tscn"), "food": preload("res://models/resources/food.tscn"),
	"wood": preload("res://models/resources/wood.tscn"), "stone": preload("res://models/resources/stone.tscn")
}
## <summary>不同地形的基础颜色。</summary>
const GROUND_COLORS = {"grass": Color("91a77a"), "forest": Color("567a60"), "hill": Color("a99c85"), "water": Color("487f91")}
## <summary>工坊冲击波传播速度，单位为世界单位每秒。</summary>
const IMPACT_WAVE_SPEED = 24.0
## <summary>单次波峰的最大抬升高度，较此前 0.34 的幅度加倍。</summary>
const IMPACT_WAVE_AMPLITUDE = 0.68

## <summary>规则模型对象，作为游戏数据的唯一来源。</summary>
var state: BelfortState
## <summary>正交 Camera3D 对象，保持远近物体的屏幕大小一致。</summary>
var camera: Camera3D
## <summary>所有地块、装饰和已建建筑的父节点。</summary>
var map_root: Node3D
## <summary>点击或悬停轮廓的父节点。</summary>
var selection_root: Node3D
## <summary>建造幽灵模型及有效性轮廓的父节点。</summary>
var preview_root: Node3D
## <summary>建筑锚点到已实例化三维节点的映射。</summary>
var building_nodes: Dictionary = {}
## <summary>地块到树木、岩石等自然装饰节点的映射。</summary>
var decoration_nodes: Dictionary = {}
## <summary>每个地块坐标到独立 StaticBody3D 对象的映射。</summary>
var tile_nodes: Dictionary = {}
## <summary>可复用的六边形厚地块网格。</summary>
var hex_mesh: ArrayMesh
## <summary>可复用的六边形边框网格。</summary>
var ring_mesh: ArrayMesh
## <summary>正交镜头在地图平面上的观察中心。</summary>
var focus = Vector3(-1.5, 0, 0)
## <summary>当前正交相机尺寸，数值越小画面越近。</summary>
var zoom = 22.0
## <summary>镜头缩放的目标尺寸。</summary>
var target_zoom = 22.0
## <summary>相机当前水平朝向，单位弧度。</summary>
var yaw = 0.44
## <summary>相机水平转向的目标角度。</summary>
var target_yaw = 0.44
## <summary>全局动态效果开关，控制建造、完工与界面动画。</summary>
var dynamic_effects = true
## <summary>缓存上次预览参数，仅变化时重建幽灵模型。</summary>
var preview_key = ""

## <summary>创建共享六边形网格、地图父节点、正交相机、太阳光与环境，准备接收规则数据。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	hex_mesh = _prism(BelfortState.CELL_RADIUS * 0.975, -0.80, 0.0)
	ring_mesh = _ring()
	map_root = Node3D.new()
	map_root.name = "Map"
	add_child(map_root)
	selection_root = Node3D.new()
	selection_root.name = "Selection"
	add_child(selection_root)
	preview_root = Node3D.new()
	preview_root.name = "ConstructionPreview"
	add_child(preview_root)
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 180.0
	camera.current = true
	add_child(camera)
	## <summary>提供方向光和阴影的太阳光节点。</summary>
	var sun = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.7
	sun.shadow_opacity = 0.65
	sun.shadow_blur = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	add_child(sun)
	## <summary>将环境资源加入三维世界的节点。</summary>
	var environment_node = WorldEnvironment.new()
	## <summary>控制背景、环境光和色调映射的 Environment 资源。</summary>
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("152c34")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c2ccd0")
	environment.ambient_light_energy = 0.4
	environment.tonemap_exposure = 0.95
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	_update_camera()

## <summary>每帧平滑插值相机缩放和朝向，再更新相机变换。</summary>
## <param name="delta">本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。</param>
## <returns>无返回值；修改显示或交互状态，不推进游戏回合。</returns>
func _process(delta: float) -> void:
	zoom = lerpf(zoom, target_zoom, 1.0 - exp(-delta * 12))
	yaw = lerp_angle(yaw, target_yaw, 1.0 - exp(-delta * 10))
	_update_camera()

## <summary>根据当前焦点、水平朝向和正交尺寸更新相机位置及朝向。</summary>
## <returns>无返回值；相机继续观察地图平面的 focus。</returns>
func _update_camera() -> void:
	camera.size = zoom
	## <summary>镜头移动方向、射线方向或帐篷方向档位。</summary>
	var direction = Vector3(sin(yaw) * 28, 34, cos(yaw) * 28)
	camera.position = focus + direction
	camera.look_at(focus, Vector3.UP)

## <summary>将镜头恢复到市政厅附近的默认缩放与斜俯视角度。</summary>
## <returns>无返回值；修改镜头目标焦点和目标角度。</returns>
func home() -> void:
	focus = BelfortState.cell_position(Vector2i(10, 8))
	target_zoom = 32.0 if state.map_shape == "hex7" else 44.0
	target_yaw = 0.44

## <summary>把屏幕方向的拖动换算成地图平面移动，并限制移动范围。</summary>
## <param name="delta">本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。</param>
## <returns>无返回值；改变镜头 focus。</returns>
func pan(delta: Vector2) -> void:
	## <summary>将屏幕拖动距离换算为世界距离的比例。</summary>
	var factor = zoom / maxf(1.0, get_viewport().size.y)
	## <summary>相机在地图平面上的左右方向单位向量。</summary>
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	## <summary>相机在地图平面上的前后方向单位向量。</summary>
	var forward = Vector3(sin(yaw), 0, cos(yaw))
	focus -= right * delta.x * factor
	focus -= forward * delta.y * factor * 1.35
	focus.x = clampf(focus.x, -25, 25)
	focus.z = clampf(focus.z, -17, 17)

## <summary>围绕鼠标指向的地图位置缩放，减少缩放时地块漂移。</summary>
## <param name="direction">缩放方向或幅度，正数拉远，负数拉近。</param>
## <param name="pointer">相对三维子视口左上角的二维像素坐标。</param>
## <returns>无返回值；更新相机尺寸和焦点，缩放限制在 10 到 60。</returns>
func zoom_at(direction: float, pointer: Vector2) -> void:
	## <summary>操作前的资源快照或鼠标对应地图位置。</summary>
	var before = ground_point(pointer)
	target_zoom = clampf(target_zoom * pow(1.12, direction), 10.0, 60.0)
	# Anchor zoom at cursor; camera size is updated immediately for exact picking.
	zoom = target_zoom
	_update_camera()
	## <summary>相机缩放后鼠标对应的地图平面位置。</summary>
	var after = ground_point(pointer)
	focus += before - after
	_update_camera()

## <summary>将子视口鼠标位置投影到 Y=0 地图平面。</summary>
## <param name="pointer">相对三维子视口左上角的二维像素坐标。</param>
## <returns>世界 Vector3；没有交点时使用当前镜头焦点。</returns>
func ground_point(pointer: Vector2) -> Vector3:
	## <summary>射线起点或测试中的市政厅坐标。</summary>
	var origin = camera.project_ray_origin(pointer)
	## <summary>镜头移动方向、射线方向或帐篷方向档位。</summary>
	var direction = camera.project_ray_normal(pointer)
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	return result if result != null else focus

## <summary>向三维世界发射物理射线，从命中地块的 metadata 中读取坐标。</summary>
## <param name="pointer">相对三维子视口左上角的二维像素坐标。</param>
## <returns>命中的 Vector2i 地块；没有命中返回 (-1, -1)。</returns>
func pick(pointer: Vector2) -> Vector2i:
	## <summary>射线起点或测试中的市政厅坐标。</summary>
	var origin = camera.project_ray_origin(pointer)
	var direction = camera.project_ray_normal(pointer)
	var plane_hit = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if plane_hit == null:
		return Vector2i(-1, -1)
	## <summary>物理射线查询参数。</summary>
	# 只查询地图附近的短线段，避免长射线在硬边凸碰撞体上产生浮点漏选。
	var query = PhysicsRayQueryParameters3D.create(plane_hit - direction * 8.0, plane_hit + direction * 8.0, 1)
	## <summary>物理射线的碰撞结果字典。</summary>
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	return hit.collider.get_meta("cell", Vector2i(-1, -1))

## <summary>从规则模型重建地图、装饰和建筑，用于新游戏或读取存档。</summary>
## <param name="new_state">用于生成地图的完整 BelfortState 模型。</param>
## <returns>无返回值；旧地图节点释放，已有建筑不播放建造动画。</returns>
func rebuild(new_state: BelfortState) -> void:
	state = new_state
	_clear(map_root)
	_clear(selection_root)
	_clear(preview_root)
	preview_key = ""
	building_nodes.clear()
	decoration_nodes.clear()
	tile_nodes.clear()
	for y in range(BelfortState.HEIGHT):
		for x in range(BelfortState.WIDTH):
			if state.contains_cell(Vector2i(x, y)):
				_create_tile(Vector2i(x, y))
	_draw_river()
	for anchor in state.buildings:
		spawn_building(anchor, false)

## <summary>将某个父节点的全部子节点移出树并排队释放。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <returns>无返回值；父节点本身保留。</returns>
func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

## <summary>返回指定地形相对地图平面的高度差。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>世界单位浮点数；丘陵略高，水面略低。</returns>
func elevation(cell: Vector2i) -> float:
	match state.terrain_at(cell):
		"hill": return 0.12
		"water": return -0.16
	return 0.0

## <summary>创建一个可拾取六边形地块，并按地形加入树木、岩石或水纹。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>无返回值；将地块和装饰注册进地图节点。</returns>
func _create_tile(cell: Vector2i) -> void:
	## <summary>当前地块的地形内部标识。</summary>
	var ground = state.terrain_at(cell)
	## <summary>地块中心加上地形高差后的三维位置。</summary>
	var position_3d = BelfortState.cell_position(cell)
	position_3d.y = elevation(cell)
	## <summary>同时承载六边形显示与碰撞的 StaticBody3D 节点。</summary>
	var tile = StaticBody3D.new()
	tile.name = "Hex_%d_%d" % [cell.x, cell.y]
	tile.set_meta("cell", cell)
	tile.collision_layer = 1
	tile.collision_mask = 0
	map_root.add_child(tile)
	tile.position = position_3d
	tile_nodes[cell] = tile
	## <summary>只用于装饰外观的独立随机数生成器，不改变游戏规则。</summary>
	var random = RandomNumberGenerator.new()
	random.seed = 2087 + cell.x * 311 + cell.y * 971
	## <summary>当前模型或反馈状态使用的颜色。</summary>
	var color: Color = GROUND_COLORS[ground]
	color = color.lightened(random.randf_range(-0.035, 0.035))
	var ground_mesh = BelfortModels.part(tile, hex_mesh, Vector3.ZERO, color, "Ground")
	var ground_material = BelfortModels.material(color).duplicate() as StandardMaterial3D
	ground_material.vertex_color_use_as_albedo = true
	ground_mesh.material_override = ground_material
	## <summary>地块六边形凸碰撞资源。</summary>
	var shape = ConvexPolygonShape3D.new()
	## <summary>构造凸六边形碰撞体的顶点数组。</summary>
	var points = PackedVector3Array()
	for index in range(6):
		## <summary>当前圆周位置的弧度角。</summary>
		var angle = -PI / 2 + index * TAU / 6
		for height in [-0.80, 0.0]:
			points.append(Vector3(cos(angle) * BelfortState.CELL_RADIUS * 0.975, height, sin(angle) * BelfortState.CELL_RADIUS * 0.975))
	shape.points = points
	## <summary>让地块能被物理射线命中的碰撞形状节点。</summary>
	var collider = CollisionShape3D.new()
	collider.shape = shape
	tile.add_child(collider)
	## <summary>某个地块的自然装饰父节点。</summary>
	var decoration = Node3D.new()
	tile.add_child(decoration)
	decoration_nodes[cell] = decoration
	if ground == "forest":
		for index in range(3):
			## <summary>射线投影坐标或模型局部位置。</summary>
			var point = Vector3(random.randf_range(-0.47, 0.47), 0, random.randf_range(-0.45, 0.45))
			## <summary>当前模型高度。</summary>
			var height = random.randf_range(0.75, 1.35)
			BelfortModels.cylinder(decoration, point + Vector3(0, height * 0.25, 0), 0.045, height * 0.5, Color("71563e"), -1, "TreeTrunk")
			BelfortModels.cylinder(decoration, point + Vector3(0, height * 0.62, 0), 0.31, height * 0.75, Color("315b48"), 0, "PineCrown")
			BelfortModels.cylinder(decoration, point + Vector3(0, height * 0.85, 0), 0.23, height * 0.65, Color("507b53"), 0, "PineTop")
	elif ground == "hill":
		for index in range(3):
			## <summary>低多边形石块或丘陵装饰网格。</summary>
			var rock = BelfortModels.cylinder(decoration, Vector3(random.randf_range(-0.4, 0.4), 0.22, random.randf_range(-0.4, 0.4)), random.randf_range(0.25, 0.4), random.randf_range(0.35, 0.8), Color("c0b59f"), 0.02, "RockOutcrop")
			rock.rotation.y = random.randf() * TAU
	elif ground == "water":
		for index in range(3):
			BelfortModels.box(decoration, Vector3(0, 0.012, (index - 1) * 0.29), Vector3(0.65 - abs(index - 1) * 0.2, 0.015, 0.018), Color("92bfca"), "WaterRipple")
	elif random.randf() < 0.35:
		for index in range(2):
			BelfortModels.cylinder(decoration, Vector3(random.randf_range(-0.5, 0.5), 0.09, random.randf_range(-0.4, 0.4)), 0.035, 0.18, Color("72865a"), 0, "GrassTuft")

## <summary>复原原版沿共享六边形边界绘制的装饰河流。</summary>
## <returns>无返回值；河流仅为视觉装饰，不引入额外可占用地块。</returns>
func _draw_river() -> void:
	for y in range(2, BelfortState.HEIGHT - 2):
		## <summary>当前列坐标或模型半宽。</summary>
		var x = mini(BelfortState.WIDTH - 2, 4 + floori(y / 3.0))
		if not state.contains_cell(Vector2i(x, y)) or not state.contains_cell(Vector2i(x + 1, y)):
			continue
		BelfortModels.box(tile_nodes[Vector2i(x, y)], Vector3(0.866 * BelfortState.CELL_RADIUS, 0.025, 0), Vector3(0.12, 0.026, 1.05 * BelfortState.CELL_RADIUS), Color("69a2b5"), "RiverEdge")

## <summary>实例化规则模型中的建筑，在每个占地格放置建筑并隐藏自然装饰。</summary>
## <param name="anchor">建筑主地块坐标，其余占地格归属于该锚点。</param>
## <param name="animate">是否播放建造拼装动画；读取存档时传 false。</param>
## <returns>无返回值；按 animate 和动态开关决定是否播放材料下落。</returns>
func spawn_building(anchor: Vector2i, animate: bool) -> void:
	## <summary>一条建筑或存档记录。</summary>
	var record = state.buildings[anchor]
	## <summary>一座多格建筑或一组模型的父节点。</summary>
	var group = Node3D.new()
	group.name = "Building_%d_%d" % [anchor.x, anchor.y]
	map_root.add_child(group)
	group.position = BelfortState.cell_position(anchor)
	building_nodes[anchor] = group
	## <summary>当前循环中的序号，从 0 开始。</summary>
	var index = 0
	for cell in record.cells:
		decoration_nodes[cell].visible = false
		## <summary>一座建筑的 BelfortBuildingVisual 实例。</summary>
		var visual: BelfortBuildingVisual = BUILDING_SCENES[record.type].instantiate()
		visual.flag_color = Color(state.faction.color)
		visual.flag_texture = load("res://assets/icons/flag_" + state.faction.get("id", "exiles") + ".svg")
		group.add_child(visual)
		visual.set_meta("cell", cell)
		visual.position = BelfortState.cell_position(cell) - group.position + Vector3(0, elevation(cell) + 0.02, 0)
		visual.rotation.y = -record.rotation * PI / 3
		visual.set_dynamic(dynamic_effects)
		## <summary>将建筑材料落地事件转发为地图级信号。</summary>
		## <returns>无返回值；通过信号或对象属性产生效果。</returns>
		visual.material_landed.connect(func(): material_landed.emit())
		visual.workshop_slam.connect(func(): impact_wave(cell))
		if index == 0:
			## <summary>将建筑完工事件转发为地图级信号。</summary>
			## <returns>无返回值；通过信号或对象属性产生效果。</returns>
			visual.construction_finished.connect(func(): building_finished.emit())
		if animate and dynamic_effects:
			visual.construct()
		index += 1
	## <summary>建筑类型到其周边可展示资源种类的映射。</summary>
	var resource_types = {"town": ["gold", "food"], "house": ["food"], "farm": ["food"], "sawmill": ["wood"], "quarry": ["stone"], "market": ["gold", "food"], "workshop": ["wood", "stone"]}
	for resource_index in range(resource_types[record.type].size()):
		## <summary>当前资源模型的内部类型。</summary>
		var resource_type = resource_types[record.type][resource_index]
		## <summary>摆放在建筑旁的资源模型实例。</summary>
		var prop: BelfortResourceVisual = RESOURCE_SCENES[resource_type].instantiate()
		group.add_child(prop)
		prop.set_meta("cell", anchor)
		prop.position = Vector3(-0.65 + resource_index * 0.43, elevation(anchor) + 0.02, 0.66)
		prop.scale = Vector3.ONE * 0.65
		prop.set_dynamic(dynamic_effects)
		if animate and dynamic_effects:
			prop.scale = Vector3.ZERO
			var reveal = prop.create_tween()
			prop.set_meta("reveal_tween", reveal)
			reveal.tween_property(prop, "scale", Vector3.ONE * 0.65, 0.3).set_delay(2.0 if record.type == "workshop" else 1.8)
	if record.type == "town":
		_add_banner(group)

## <summary>在市政厅上方添加始终面向相机的聚落名称。</summary>
## <param name="group">接收聚落名称标牌的建筑父节点。</param>
## <returns>无返回值；将 Label3D 加入建筑父节点。</returns>
func _add_banner(group: Node3D) -> void:
	## <summary>面向相机显示聚落名称的 Label3D。</summary>
	var banner = Label3D.new()
	banner.name = "SettlementBanner"
	banner.text = state.faction.name
	banner.font_size = 38
	banner.pixel_size = 0.009
	banner.position = Vector3(0, 2.5, 0)
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.modulate = Color("f5dfab")
	banner.outline_size = 9
	group.add_child(banner)

## <summary>移除撤销对应的建筑节点，并恢复已空出的自然装饰。</summary>
## <param name="anchor">建筑主地块坐标，其余占地格归属于该锚点。</param>
## <returns>无返回值；规则数据应先由模型 undo 更新。</returns>
func remove_building(anchor: Vector2i) -> void:
	if building_nodes.has(anchor):
		## <summary>一座多格建筑或一组模型的父节点。</summary>
		var group = building_nodes[anchor]
		map_root.remove_child(group)
		group.queue_free()
		building_nodes.erase(anchor)
	for cell in decoration_nodes:
		decoration_nodes[cell].visible = not state.occupied.has(cell)

## <summary>重建某格或其所属整座建筑的金色选中轮廓。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>无返回值；无效坐标会清除选中显示。</returns>
func select(cell: Vector2i) -> void:
	_clear(selection_root)
	if not state.contains_cell(cell):
		return
	## <summary>一座建筑覆盖的所有地块坐标数组。</summary>
	var cells = state.building_at(cell).get("cells", [cell])
	for part in cells:
		_highlight(selection_root, part, Color("f3d188"))

## <summary>按地块、建筑、方向、资源和占地变化更新建造幽灵模型。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <param name="rotation_value">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <returns>无返回值；有效位置用绿色，无效位置用红色，参数未变化时复用预览。</returns>
func preview(cell: Vector2i, type: String, rotation_value: int) -> void:
	## <summary>字典字段、缓存键或当前设置名称。</summary>
	var key = str(cell) + type + str(rotation_value) + str(state.resources) + str(state.occupied.size())
	if key == preview_key:
		return
	preview_key = key
	_clear(preview_root)
	if type.is_empty() or not state.contains_cell(cell):
		return
	## <summary>当前地块是否满足全部建造规则。</summary>
	var valid = state.placement_error(cell, type, rotation_value).is_empty()
	## <summary>当前模型或反馈状态使用的颜色。</summary>
	var color = Color("91e7c2") if valid else Color("ed8772")
	## <summary>表示可建或不可建状态的半透明材质。</summary>
	var ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(color, 0.4)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in state.footprint(cell, type, rotation_value):
		if not state.contains_cell(part):
			continue
		_highlight(preview_root, part, color)
		## <summary>尚未建造的半透明建筑模型。</summary>
		var ghost = BelfortModels.building(type)
		preview_root.add_child(ghost)
		ghost.position = BelfortState.cell_position(part) + Vector3(0, elevation(part) + 0.03, 0)
		ghost.rotation.y = -rotation_value * PI / 3
		_override_ghost(ghost, ghost_material)

## <summary>递归替换预览网格材质，并关闭预览的投影。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="ghost_material">用于显示绿色或红色半透明建筑的独立材质。</param>
## <returns>无返回值；只作用于独立的幽灵模型实例。</returns>
func _override_ghost(parent: Node, ghost_material: Material) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			child.material_override = ghost_material
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_override_ghost(child, ghost_material)

## <summary>在指定地块上方生成一圈不受光照影响的彩色六边形轮廓。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <returns>无返回值；轮廓加入调用者提供的父节点。</returns>
func _highlight(parent: Node3D, cell: Vector2i, color: Color) -> void:
	## <summary>新建的 MeshInstance3D 网格实例。</summary>
	var instance = BelfortModels.part(parent, ring_mesh, BelfortState.cell_position(cell) + Vector3(0, elevation(cell) + 0.045, 0), color, "HexOutline")
	## <summary>用于让地块轮廓清晰可见的不受光材质。</summary>
	var glow = StandardMaterial3D.new()
	glow.albedo_color = color
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = glow
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("cell", cell)

## <summary>启用或关闭当前对象的持续动态效果，关闭时恢复静止姿态。</summary>
## <param name="enabled">true 启用动态效果；false 停止并恢复静止姿态。</param>
## <returns>无返回值；三维地图版本会递归通知所有建筑与资源组件。</returns>
func set_dynamic(enabled: bool) -> void:
	dynamic_effects = enabled
	for group in building_nodes.values():
		for child in group.get_children():
			if child.has_method("set_dynamic"):
				child.set_dynamic(enabled)
			if not enabled and child is BelfortResourceVisual and child.has_meta("reveal_tween"):
				var reveal: Tween = child.get_meta("reveal_tween")
				if reveal.is_valid():
					reveal.kill()
				child.scale = Vector3.ONE * 0.65
	if not enabled:
		for node in map_root.find_children("*", "Node3D", true, false) + selection_root.get_children() + preview_root.get_children():
			if node.has_meta("press_rest_y"):
				var feedback: Tween = node.get_meta("press_tween")
				if feedback.is_valid():
					feedback.kill()
				node.position.y = node.get_meta("press_rest_y")
		for glow in map_root.find_children("ImpactOutline", "MeshInstance3D", true, false):
			glow.queue_free()

## <summary>通过 SurfaceTool 构造带厚度的六边形地块，顶面法线朝上。</summary>
## <param name="radius">底部圆半径，使用世界单位。</param>
## <param name="bottom">六边形底面高度，单位为世界单位。</param>
## <param name="top">地块顶面的高度，单位为世界单位。</param>
## <returns>ArrayMesh 网格资源，可被所有地图格复用。</returns>
func _prism(radius: float, bottom: float, top: float) -> ArrayMesh:
	## <summary>逐顶点构造三角形网格的 SurfaceTool 对象。</summary>
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in range(6):
		## <summary>当前六边形边起点的弧度角。</summary>
		var angle_a = -PI / 2 + index * TAU / 6
		## <summary>当前六边形边终点的弧度角。</summary>
		var angle_b = -PI / 2 + (index + 1) * TAU / 6
		## <summary>当前六边形边或三角面的第一个顶点。</summary>
		var a = Vector3(cos(angle_a) * radius, top, sin(angle_a) * radius)
		## <summary>当前六边形边或三角面的第二个顶点。</summary>
		var b = Vector3(cos(angle_b) * radius, top, sin(angle_b) * radius)
		## <summary>六边形边起点对应的底面顶点。</summary>
		var low_a = Vector3(a.x, bottom, a.z)
		## <summary>六边形边终点对应的底面顶点。</summary>
		var low_b = Vector3(b.x, bottom, b.z)
		for vertex in [Vector3(0, top, 0), a * Vector3(0.97, 1, 0.97), b * Vector3(0.97, 1, 0.97)]:
			surface.set_color(Color.WHITE)
			surface.add_vertex(vertex)
		var rim_a = Vector3(a.x, top - 0.09, a.z)
		var rim_b = Vector3(b.x, top - 0.09, b.z)
		for vertex in [a * Vector3(0.97, 1, 0.97), rim_b, b * Vector3(0.97, 1, 0.97), a * Vector3(0.97, 1, 0.97), rim_a, rim_b]:
			surface.set_color(Color("c5c6b8"))
			surface.add_vertex(vertex)
		for vertex in [rim_a, low_b, rim_b, rim_a, low_a, low_b]:
			surface.set_color(Color("777d77").lightened(0.04 * (index % 2)))
			surface.add_vertex(vertex)
		for vertex in [Vector3(0, bottom, 0), low_b, low_a]:
			surface.set_color(Color("484e4a"))
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

## <summary>构造略有宽度的六边形轮廓三角网格。</summary>
## <returns>ArrayMesh 轮廓资源，顶面法线朝上。</returns>
func _ring() -> ArrayMesh:
	## <summary>逐顶点构造三角形网格的 SurfaceTool 对象。</summary>
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(6):
		## <summary>当前六边形边起点的弧度角。</summary>
		var angle_a = -PI / 2 + index * TAU / 6
		## <summary>当前六边形边终点的弧度角。</summary>
		var angle_b = -PI / 2 + (index + 1) * TAU / 6
		## <summary>当前六边形边或三角面的第一个顶点。</summary>
		var a = Vector3(cos(angle_a), 0, sin(angle_a)) * BelfortState.CELL_RADIUS
		## <summary>当前六边形边或三角面的第二个顶点。</summary>
		var b = Vector3(cos(angle_b), 0, sin(angle_b)) * BelfortState.CELL_RADIUS
		for vertex in [a, b, b * 0.91, a, b * 0.91, a * 0.91]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

## <summary>让独立地块及其上已完工的建筑、资源和轮廓短暂下压再回弹。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>无返回值；关闭动态效果时保持静止，正在拼装的建筑不叠加点击动画。</returns>
func press_cell(cell: Vector2i) -> void:
	if not dynamic_effects or not tile_nodes.has(cell):
		return
	_pulse_node(tile_nodes[cell])
	## <summary>一条建筑或存档记录。</summary>
	var record = state.building_at(cell)
	if not record.is_empty():
		## <summary>建筑锚点坐标，即记录建筑的主地块。</summary>
		var anchor: Vector2i = state.occupied[cell]
		for child in building_nodes[anchor].get_children():
			if child.get_meta("cell", Vector2i(-1, -1)) == cell:
				if child is BelfortBuildingVisual and child.constructing:
					continue
				_pulse_node(child)
	for parent in [selection_root, preview_root]:
		for child in parent.get_children():
			if child.get_meta("cell", Vector2i(-1, -1)) == cell:
				_pulse_node(child)

## <summary>取消旧的点击 Tween，从固定原始高度播放下压及回弹，避免连续点击导致地块越陷越深。</summary>
## <param name="node">要播放点击反馈的 Node3D 对象。</param>
## <returns>无返回值；Tween 与目标节点绑定，目标释放时自动结束。</returns>
func _pulse_node(node: Node3D, delay: float = 0.0, strength: float = 0.16, wave: bool = false) -> void:
	## <summary>该物体上一次点击反馈 Tween，用于取消尚未结束的下压。</summary>
	var previous_tween = node.get_meta("press_tween") if node.has_meta("press_tween") else null
	if previous_tween is Tween and previous_tween.is_valid():
		previous_tween.kill()
	## <summary>点击反馈开始前的静止高度，重复点击时避免累积下沉。</summary>
	var base_y = float(node.get_meta("press_rest_y", node.position.y))
	node.set_meta("press_rest_y", base_y)
	node.position.y = base_y
	## <summary>控制本次属性插值或回调时序的 Tween 对象。</summary>
	var tween = node.create_tween()
	node.set_meta("press_tween", tween)
	tween.tween_interval(delay)
	if wave:
		# 单一波峰：抬起后平滑归位，不产生负向波谷或弹性余波。
		tween.tween_property(node, "position:y", base_y + strength, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "position:y", base_y, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	tween.tween_property(node, "position:y", base_y - strength, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", base_y, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## <summary>工坊触地后以距离控制延迟，地块、建筑、资源和轮廓同步起伏，形成水波状传播。</summary>
func impact_wave(origin_cell: Vector2i) -> void:
	if not dynamic_effects:
		return
	for cell in tile_nodes:
		var distance = BelfortState.cell_position(cell).distance_to(BelfortState.cell_position(origin_cell))
		if distance > 24.0:
			continue
		var delay = distance / IMPACT_WAVE_SPEED
		var strength = IMPACT_WAVE_AMPLITUDE * exp(-distance * 0.12)
		_pulse_node(tile_nodes[cell], delay, strength, true)
		var record = state.building_at(cell)
		if not record.is_empty():
			for child in building_nodes[state.occupied[cell]].get_children():
				if child.get_meta("cell", Vector2i(-1, -1)) == cell:
					# 正在拼装的部件在自己的局部空间运动，父节点随地面起伏。
					_pulse_node(child, delay, strength, true)
		for parent in [selection_root, preview_root]:
			for child in parent.get_children():
				if child.get_meta("cell", Vector2i(-1, -1)) == cell:
					_pulse_node(child, delay, strength, true)
		var glow = BelfortModels.part(tile_nodes[cell], ring_mesh, Vector3(0, 0.028, 0), Color.WHITE, "ImpactOutline")
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.55, 0.92, 0.91, 0.0)
		glow.material_override = material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fade = glow.create_tween()
		fade.tween_interval(delay)
		fade.tween_property(material, "albedo_color:a", 0.45 * exp(-distance * 0.1), 0.08)
		fade.tween_property(material, "albedo_color:a", 0.0, 0.38)
		fade.tween_callback(glow.queue_free)
