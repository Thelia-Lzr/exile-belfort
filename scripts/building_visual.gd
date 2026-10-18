## <summary>可复用建筑视觉组件。kind 决定建筑种类；负责材料下落拼装、落地尘土以及建成后的循环动画。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortBuildingVisual
extends Node3D

## <summary>某批材料落地时发出；监听者播放经节流处理的落地音效。</summary>
signal material_landed
## <summary>建筑材料全部落定并结束拼装时发出；监听者播放完工音效。</summary>
signal construction_finished
## <summary>工坊整栋触地时发出一次，由地图启动向外传播的冲击波。</summary>
signal workshop_slam

## <summary>可在检查器中设置的建筑或资源内部类型。</summary>
@export var kind: String = "town"
## <summary>该建筑使用的势力旗帜基础色。</summary>
var flag_color = Color("d1ad70")
## <summary>势力旗帜 SVG 对应的纹理资源。</summary>
var flag_texture: Texture2D
## <summary>包含建筑或资源实际网格的子节点。</summary>
var geometry: Node3D
## <summary>需要在完工后持续运动的网格对象数组。</summary>
var animated_parts: Array = []
## <summary>该对象的循环动画是否启用。</summary>
var animation_enabled = true
## <summary>是否仍处于材料拼装或工坊整栋下砸阶段。</summary>
var constructing = false
## <summary>动画累计时间，单位秒。</summary>
var clock = 0.0
## <summary>负责并行下落、缩放和完成回调的 Tween 对象。</summary>
var construction_tween: Tween
## <summary>所有网格到初始 Transform3D 的映射，用于停止拼装时恢复完整模型。</summary>
var rest_poses: Dictionary = {}

## <summary>按照 kind 生成建筑网格，应用势力旗帜，收集循环动画部件并记录初始姿态。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	geometry = BelfortModels.building(kind, flag_color)
	add_child(geometry)
	if kind == "town" and flag_texture != null:
		## <summary>市政厅旗帜对应的网格对象。</summary>
		var flag = geometry.get_node("Flag")
		## <summary>带势力旗帜图案的独立材质。</summary>
		var flag_material = StandardMaterial3D.new()
		flag_material.albedo_texture = flag_texture
		flag.material_override = flag_material
	_collect(geometry)
	clock = position.x * 0.23 + position.z * 0.57

## <summary>递归查找需要循环运动的部件，并记录每个部件的初始姿态。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <returns>无返回值；填充 animated_parts 和 rest_poses。</returns>
func _collect(parent: Node) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D:
			rest_poses[child] = child.transform
			if str(child.name).begins_with("Flag") and not str(child.name).begins_with("FlagPole") or str(child.name).begins_with("TentCloth") or str(child.name).begins_with("Crop") or str(child.name).begins_with("SawBlade") or str(child.name).begins_with("Gear") or str(child.name).begins_with("CraneArm") or str(child.name).begins_with("CraneLoad") or str(child.name).begins_with("Awning"):
				animated_parts.append(child)
				rest_poses[child] = child.transform
		_collect(child)

## <summary>每帧根据部件名称更新完工建筑动画；材料拼装或关闭动态效果时暂停循环动画。</summary>
## <param name="delta">本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。</param>
## <returns>无返回值；修改显示或交互状态，不推进游戏回合。</returns>
func _process(delta: float) -> void:
	if not animation_enabled or constructing:
		return
	clock += delta
	for piece in animated_parts:
		## <summary>动画部件的初始变换。</summary>
		var rest: Transform3D = rest_poses[piece]
		piece.transform = rest
		## <summary>当前网格节点名称，用来区分旗帜、作物和机械。</summary>
		var label = str(piece.name)
		if label.begins_with("SawBlade") or label.begins_with("Gear"):
			piece.rotate_object_local(Vector3.UP, clock * (2.5 if kind == "sawmill" else 0.8))
		elif label.begins_with("CraneLoad"):
			piece.position.y += sin(clock * 0.85) * 0.13
		elif label.begins_with("CraneArm"):
			piece.rotation.z += sin(clock * 0.85) * 0.035
		elif label.begins_with("Flag"):
			piece.rotation.y += sin(clock * 2.0) * 0.11
			piece.scale.x *= 1.0 + sin(clock * 2.8) * 0.045
		else:
			piece.rotation.z += sin(clock * 1.6 + piece.position.x * 3.0) * (0.07 if kind == "farm" else 0.018)

## <summary>把实际建筑部件抬到空中，通过并行 Tween 依次落下拼成建筑。</summary>
## <returns>无返回值；设置 constructing，完成后发出 construction_finished 信号。</returns>
func construct() -> void:
	if not animation_enabled:
		return
	constructing = true
	if kind == "workshop":
		_construct_workshop()
		return
	construction_tween = create_tween().set_parallel(true)
	## <summary>当前建筑的顶层材料网格列表。</summary>
	var parts = geometry.get_children()
	## <summary>当前循环中的序号，从 0 开始。</summary>
	var index = 0
	for piece in parts:
		if not piece is MeshInstance3D:
			continue
		## <summary>动画最终位置或找到的合法建筑地块。</summary>
		var target = piece.position
		## <summary>材料或面板动画的延迟，单位秒。</summary>
		var delay = minf(index * 0.055, 1.05)
		piece.position.y += 5.0 + fmod(index * 1.7, 3.0)
		piece.scale = Vector3.ONE * 0.7
		construction_tween.tween_property(piece, "position", target + Vector3(0, 0.07, 0), 0.48).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		construction_tween.tween_property(piece, "position", target, 0.14).set_delay(delay + 0.48).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		construction_tween.tween_property(piece, "scale", Vector3.ONE, 0.42).set_delay(delay)
		if index % 4 == 0:
			construction_tween.tween_callback(_impact).set_delay(delay + 0.48)
		index += 1
	construction_tween.chain().tween_interval(0.1)
	construction_tween.chain().tween_callback(_finish)

## <summary>工坊在离地 3.8 单位的空中拼装，悬停后整栋加速下砸。</summary>
func _construct_workshop() -> void:
	geometry.position.y = 3.8
	construction_tween = create_tween().set_parallel(true)
	var index = 0
	for piece in geometry.get_children():
		if not piece is MeshInstance3D:
			continue
		var target: Transform3D = rest_poses[piece]
		var angle = index * 2.4
		piece.position = target.origin + Vector3(cos(angle) * 1.6, 1.0 + fmod(index * 0.3, 1.2), sin(angle) * 1.6)
		piece.rotation.y += 0.45
		piece.scale = target.basis.get_scale() * 0.35
		construction_tween.tween_property(piece, "transform", target, 0.5).set_delay(minf(index * 0.035, 0.7)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		index += 1
	construction_tween.chain().tween_interval(0.18)
	construction_tween.chain().tween_property(geometry, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	construction_tween.chain().tween_callback(_slam_impact)
	construction_tween.chain().tween_property(geometry, "position:y", 0.10, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	construction_tween.chain().tween_property(geometry, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	construction_tween.chain().tween_callback(_finish)

## <summary>触地瞬间生成尘土与地块波纹；空中拼装阶段不触发地面反馈。</summary>
func _slam_impact() -> void:
	_impact()
	workshop_slam.emit()

## <summary>发出材料落地信号，并生成短暂向外扩散的尘土方块。</summary>
## <returns>无返回值；尘土动画结束后自动释放节点。</returns>
func _impact() -> void:
	material_landed.emit()
	## <summary>单次落地尘土粒子组的父节点。</summary>
	var dust = Node3D.new()
	dust.name = "ImpactDust"
	add_child(dust)
	## <summary>控制本次属性插值或回调时序的 Tween 对象。</summary>
	var tween = dust.create_tween().set_parallel(true)
	for index in range(5):
		## <summary>当前圆周位置的弧度角。</summary>
		var angle = index * TAU / 5
		## <summary>单个落地尘土方块。</summary>
		var puff = BelfortModels.box(dust, Vector3(cos(angle) * 0.15, 0.08, sin(angle) * 0.15), Vector3(0.09, 0.09, 0.09), Color("b5a78a"), "Dust")
		tween.tween_property(puff, "position", Vector3(cos(angle) * 0.7, 0.2, sin(angle) * 0.7), 0.4)
		tween.tween_property(puff, "scale", Vector3.ZERO, 0.4)
	tween.chain().tween_callback(dust.queue_free)

## <summary>结束拼装阶段，允许持续动画并通知控制器播放完工音效。</summary>
## <returns>无返回值；发出 construction_finished 信号。</returns>
func _finish() -> void:
	constructing = false
	construction_finished.emit()

## <summary>启用或关闭当前对象的持续动态效果，关闭时恢复静止姿态。</summary>
## <param name="enabled">true 启用动态效果；false 停止并恢复静止姿态。</param>
## <returns>无返回值；三维地图版本会递归通知所有建筑与资源组件。</returns>
func set_dynamic(enabled: bool) -> void:
	animation_enabled = enabled
	if not enabled:
		if construction_tween != null and construction_tween.is_valid():
			construction_tween.kill()
		geometry.position = Vector3.ZERO
		for dust in find_children("ImpactDust", "Node3D", true, false):
			dust.queue_free()
		for piece in rest_poses:
			piece.transform = rest_poses[piece]
		if constructing:
			_finish()
