## <summary>程序化低多边形模型工厂。组合盒体、圆柱和三角屋顶，生成原创建筑与资源模型；静态缓存复用网格及材质。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortModels
extends RefCounted

## <summary>按颜色和金属度缓存的材质字典。</summary>
static var materials: Dictionary = {}
## <summary>按形状及尺寸缓存的网格字典。</summary>
static var mesh_cache: Dictionary = {}

## <summary>按颜色及金属度查找或创建共享三维材质。</summary>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <param name="metallic">材质金属度，0 为非金属，1 为金属。</param>
## <returns>可复用的 StandardMaterial3D 资源；调用者不应直接改动共享属性。</returns>
static func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	## <summary>字典字段、缓存键或当前设置名称。</summary>
	var key = str(color) + str(metallic)
	if not materials.has(key):
		## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
		var result = StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.82
		result.metallic = metallic
		materials[key] = result
	return materials[key]

## <summary>创建网格实例、赋予材质、加入父节点并设置局部位置。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="mesh">要显示的 Mesh 网格资源。</param>
## <param name="pos">相对父节点的 Vector3 局部位置。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <param name="label">部件节点名称；动画系统依据这些语义名称识别部件。</param>
## <returns>已加入父节点的 MeshInstance3D 对象。</returns>
static func part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, label: String = "Part") -> MeshInstance3D:
	## <summary>新建的 MeshInstance3D 网格实例。</summary>
	var instance = MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = pos
	return instance

## <summary>复用对应尺寸的 BoxMesh，创建木梁、墙体、台面等盒形部件。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="pos">相对父节点的 Vector3 局部位置。</param>
## <param name="size">盒体或屋顶尺寸，使用世界单位。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <param name="label">部件节点名称；动画系统依据这些语义名称识别部件。</param>
## <returns>已加入父节点的盒形 MeshInstance3D。</returns>
static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, label: String = "Timber") -> MeshInstance3D:
	## <summary>字典字段、缓存键或当前设置名称。</summary>
	var key = "box" + str(size)
	if not mesh_cache.has(key):
		## <summary>可复用的网格几何资源。</summary>
		var mesh = BoxMesh.new()
		mesh.size = size
		mesh_cache[key] = mesh
	return part(parent, mesh_cache[key], pos, color, label)

## <summary>创建低边数圆柱或圆锥，用于树木、金币、木料和机械部件。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="pos">相对父节点的 Vector3 局部位置。</param>
## <param name="radius">底部圆半径，使用世界单位。</param>
## <param name="height">模型高度，使用世界单位。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <param name="top">顶部圆半径；负数表示与底部半径相同，0 生成圆锥。</param>
## <param name="label">部件节点名称；动画系统依据这些语义名称识别部件。</param>
## <returns>已加入父节点的圆柱或圆锥 MeshInstance3D。</returns>
static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1.0, label: String = "Cylinder") -> MeshInstance3D:
	## <summary>字典字段、缓存键或当前设置名称。</summary>
	var key = "cylinder" + str(radius) + str(height) + str(top)
	if not mesh_cache.has(key):
		## <summary>可复用的网格几何资源。</summary>
		var mesh = CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top < 0 else top
		mesh.height = height
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh_cache[key] = mesh
	return part(parent, mesh_cache[key], pos, color, label)

## <summary>按三角柱顶点构造屋顶，使用 Godot 顺时针三角形绕序。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="pos">相对父节点的 Vector3 局部位置。</param>
## <param name="size">盒体或屋顶尺寸，使用世界单位。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <param name="label">部件节点名称；动画系统依据这些语义名称识别部件。</param>
## <returns>已加入父节点的三角屋顶网格实例。</returns>
static func roof(parent: Node3D, pos: Vector3, size: Vector3, color: Color, label: String = "Roof") -> MeshInstance3D:
	## <summary>字典字段、缓存键或当前设置名称。</summary>
	var key = "roof" + str(size)
	if not mesh_cache.has(key):
		## <summary>当前列坐标或模型半宽。</summary>
		var x = size.x / 2.0
		## <summary>模型在前后方向的半深度。</summary>
		var z = size.z / 2.0
		## <summary>程序化屋顶的基础顶点数组。</summary>
		var vertices = [Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(0, size.y, -z), Vector3(-x, 0, z), Vector3(x, 0, z), Vector3(0, size.y, z)]
		## <summary>屋顶三角面使用的顶点索引数组。</summary>
		var faces = [0, 2, 1, 3, 4, 5, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 4, 0, 1, 4, 0, 4, 3]
		## <summary>逐顶点构造三角形网格的 SurfaceTool 对象。</summary>
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in range(0, faces.size(), 3):
			for offset in [0, 2, 1]:
				surface.add_vertex(vertices[faces[index + offset]])
		surface.generate_normals()
		mesh_cache[key] = surface.commit()
	return part(parent, mesh_cache[key], pos, color, label)

## <summary>组合基础几何体，生成指定资源的完整三维模型。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>尚未加入场景树的 Node3D 根节点；调用者负责 add_child。</returns>
static func resource_model(type: String) -> Node3D:
	## <summary>程序化模型的根节点。</summary>
	var root = Node3D.new()
	root.name = type.capitalize() + "Resource"
	match type:
		"gold":
			for index in range(5):
				## <summary>资源模型中的一枚金币网格。</summary>
				var coin = cylinder(root, Vector3(0.04 * (index % 2), 0.035 + index * 0.055, 0), 0.19, 0.05, Color("eac56b"), -1, "Coin")
				coin.material_override = material(Color("eac56b"), 0.65)
			box(root, Vector3(0, 0.32, 0), Vector3(0.05, 0.015, 0.23), Color("a77936"), "CoinStamp")
		"food":
			cylinder(root, Vector3(0, 0.19, 0), 0.19, 0.38, Color("c9b483"), 0.14, "GrainSack")
			cylinder(root, Vector3(0, 0.39, 0), 0.12, 0.06, Color("7b684d"), 0.08, "SackTie")
			for index in range(4):
				## <summary>麦穗模型中的茎秆位置。</summary>
				var stem = Vector3((index - 1.5) * 0.055, 0.55, 0)
				box(root, stem, Vector3(0.018, 0.35, 0.018), Color("b5a35c"), "WheatStem")
				cylinder(root, stem + Vector3(0, 0.17, 0), 0.04, 0.15, Color("e5cb79"), 0.02, "WheatHead")
		"wood":
			for index in range(3):
				## <summary>水平摆放的木料圆柱网格。</summary>
				var timber_log = cylinder(root, Vector3((index % 2) * 0.23 - 0.1, 0.11 + floori(index / 2.0) * 0.18, 0), 0.12, 0.65, Color("aa8057"), -1, "Log")
				timber_log.rotation.x = PI / 2
				## <summary>木材模型中的浅色切面网格。</summary>
				var end = cylinder(root, timber_log.position + Vector3(0, 0, 0.33), 0.103, 0.012, Color("dfbd87"), -1, "CutEnd")
				end.rotation.x = PI / 2
		"stone":
			for index in range(3):
				## <summary>低多边形石块或丘陵装饰网格。</summary>
				var rock = cylinder(root, Vector3((index % 2) * 0.25 - 0.1, 0.12 + floori(index / 2.0) * 0.17, 0), 0.17, 0.25, Color("a4b2b6"), 0.12, "StoneBlock")
				rock.rotation.y = index * 0.4
	return root

## <summary>组合基础几何体，生成指定建筑的完整可拆分材料几何。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <param name="flag_color">市政厅旗帜的势力基础色。</param>
## <returns>尚未加入场景树的 Geometry 根节点，内部部件有语义名称供动画识别。</returns>
static func building(type: String, flag_color: Color = Color("d1ad70")) -> Node3D:
	## <summary>程序化模型的根节点。</summary>
	var root = Node3D.new()
	root.name = "Geometry"
	## <summary>木梁、支柱和台面使用的木材颜色。</summary>
	var timber = Color("886449")
	## <summary>墙体和基础使用的浅石材颜色。</summary>
	var stone = Color("d5c7ac")
	## <summary>模型门洞、绳索等使用的深色。</summary>
	var dark = Color("273b3d")
	## <summary>屋顶使用的砖红色。</summary>
	var red = Color("a45b49")
	## <summary>机械棚顶使用的灰绿色。</summary>
	var teal = Color("517b73")
	if type != "farm" and type != "house":
		box(root, Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.1), Color("8a9691"), "Foundation")
	match type:
		"town":
			box(root, Vector3(0, 0.48, 0), Vector3(0.95, 0.74, 0.83), stone, "StoneWalls")
			roof(root, Vector3(0, 0.85, 0), Vector3(1.25, 0.48, 1.12), red)
			box(root, Vector3(0, 0.35, 0.425), Vector3(0.21, 0.48, 0.025), dark, "Door")
			for side in [-1, 1]:
				box(root, Vector3(side * 0.3, 0.55, 0.43), Vector3(0.15, 0.2, 0.025), Color("e8c98b"), "Window")
			cylinder(root, Vector3(0.44, 1.32, 0), 0.025, 1.25, timber, -1, "FlagPole")
			box(root, Vector3(0.7, 1.72, 0), Vector3(0.5, 0.3, 0.025), flag_color, "Flag")
		"house":
			box(root, Vector3(0, 0.035, 0), Vector3(1.05, 0.07, 0.85), timber, "TentPlatform")
			roof(root, Vector3(0, 0.07, 0), Vector3(1.1, 0.72, 0.88), Color("dcc29a"), "TentCloth")
			roof(root, Vector3(0, 0.08, 0.449), Vector3(0.31, 0.38, 0.02), dark, "TentDoor")
			box(root, Vector3(0, 0.79, 0), Vector3(0.055, 0.05, 1.02), timber, "RidgePole")
			for side in [-1, 1]:
				cylinder(root, Vector3(side * 0.65, 0.08, 0.47), 0.024, 0.16, timber, -1, "TentStake")
		"farm":
			box(root, Vector3(0, 0.035, 0), Vector3(1.28, 0.07, 1.28), Color("796446"), "SoilBed")
			for row in range(5):
				box(root, Vector3((row - 2) * 0.23, 0.08, 0), Vector3(0.07, 0.04, 1.12), Color("b79557"), "Furrow")
				for column in range(4):
					cylinder(root, Vector3((row - 2) * 0.23, 0.24, (column - 1.5) * 0.26), 0.035, 0.29, Color("d0b66c"), 0.01, "Crop")
		"sawmill":
			for side in [-1, 1]:
				box(root, Vector3(side * 0.45, 0.48, 0), Vector3(0.1, 0.75, 0.1), timber, "Support")
			roof(root, Vector3(0, 0.84, 0), Vector3(1.18, 0.31, 1.02), teal)
			box(root, Vector3(0, 0.35, 0), Vector3(0.85, 0.12, 0.55), timber, "SawTable")
			## <summary>伐木场可旋转的锯片网格。</summary>
			var blade = cylinder(root, Vector3(0, 0.52, 0.05), 0.22, 0.035, Color("c7d1cf"), -1, "SawBlade")
			blade.rotation.x = PI / 2
			for index in range(8):
				## <summary>锯片边缘的小齿网格。</summary>
				var tooth = box(blade, Vector3(cos(index * TAU / 8) * 0.21, 0, sin(index * TAU / 8) * 0.21), Vector3(0.085, 0.04, 0.085), Color("c7d1cf"), "SawTooth")
				tooth.rotation.y = index * TAU / 8
		"quarry":
			box(root, Vector3(-0.35, 0.66, -0.2), Vector3(0.11, 1.2, 0.11), timber, "CranePost")
			box(root, Vector3(0, 1.24, -0.2), Vector3(0.95, 0.11, 0.11), timber, "CraneArm")
			box(root, Vector3(0.4, 0.89, -0.2), Vector3(0.025, 0.65, 0.025), dark, "CraneRope")
			box(root, Vector3(0.4, 0.55, -0.2), Vector3(0.24, 0.18, 0.22), Color("a7b2b5"), "CraneLoad")
			for index in range(4):
				cylinder(root, Vector3((index % 2) * 0.39 - 0.2, 0.24, floori(index / 2.0) * 0.4), 0.24, 0.35, Color("a6afb0"), 0.16, "QuarriedRock")
		"market":
			for side in [-1, 1]:
				box(root, Vector3(side * 0.47, 0.5, 0), Vector3(0.07, 0.86, 0.07), timber, "StallPost")
			for stripe in range(5):
				roof(root, Vector3((stripe - 2) * 0.23, 0.89, 0), Vector3(0.23, 0.25, 1.12), Color("d9ae6c") if stripe % 2 == 0 else Color("eee0bf"), "Awning")
			box(root, Vector3(0, 0.36, 0.34), Vector3(1.12, 0.39, 0.25), timber, "Counter")
			for index in range(4):
				cylinder(root, Vector3((index - 1.5) * 0.24, 0.61, 0.34), 0.09, 0.13, Color("b17b55") if index % 2 == 0 else Color("b8b879"), 0.065, "Goods")
		"workshop":
			box(root, Vector3(-0.1, 0.46, 0), Vector3(0.84, 0.7, 0.85), stone, "WorkshopWalls")
			roof(root, Vector3(-0.1, 0.81, 0), Vector3(1.0, 0.3, 1.02), teal)
			box(root, Vector3(0.44, 0.83, -0.2), Vector3(0.24, 1.4, 0.24), Color("9b7d65"), "Chimney")
			## <summary>工坊可旋转的齿轮网格。</summary>
			var gear = cylinder(root, Vector3(-0.08, 0.48, 0.45), 0.23, 0.045, Color("c6a467"), -1, "Gear")
			gear.rotation.x = PI / 2
			for index in range(8):
				box(gear, Vector3(cos(index * TAU / 8) * 0.22, 0, sin(index * TAU / 8) * 0.22), Vector3(0.11, 0.05, 0.11), Color("c6a467"), "GearTooth")
			box(root, Vector3(-0.1, 0.25, 0.43), Vector3(0.25, 0.2, 0.03), Color("d58e4f"), "Furnace")
	return root
