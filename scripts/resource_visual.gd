## <summary>可复用资源视觉组件。根据 kind 创建金币、粮食、木材或石材模型，并提供轻微的展示动画。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortResourceVisual
extends Node3D

## <summary>可在检查器中设置的建筑或资源内部类型。</summary>
@export_enum("gold", "food", "wood", "stone") var kind: String = "gold"
## <summary>包含建筑或资源实际网格的子节点。</summary>
var geometry: Node3D
## <summary>该对象的循环动画是否启用。</summary>
var animation_enabled = true
## <summary>动画累计时间，单位秒。</summary>
var clock = 0.0

## <summary>按照 kind 创建资源模型并加入当前资源组件。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	geometry = BelfortModels.resource_model(kind)
	add_child(geometry)

## <summary>每帧轻微转动金币或摇动粮食资源，木材与石材保持稳定。</summary>
## <param name="delta">本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。</param>
## <returns>无返回值；修改显示或交互状态，不推进游戏回合。</returns>
func _process(delta: float) -> void:
	if not animation_enabled:
		return
	clock += delta
	if kind == "gold":
		geometry.rotation.y = sin(clock * 0.65) * 0.16
	elif kind == "food":
		geometry.rotation.z = sin(clock * 1.5) * 0.025

## <summary>启用或关闭当前对象的持续动态效果，关闭时恢复静止姿态。</summary>
## <param name="enabled">true 启用动态效果；false 停止并恢复静止姿态。</param>
## <returns>无返回值；三维地图版本会递归通知所有建筑与资源组件。</returns>
func set_dynamic(enabled: bool) -> void:
	animation_enabled = enabled
	if not enabled:
		geometry.rotation = Vector3.ZERO
