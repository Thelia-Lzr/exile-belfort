## <summary>势力与菜单背景动效。用二维绘制 API 生成网格、扫描线与斜线，不拦截玩家点击。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortFactionBackdrop
extends Control

## <summary>动画累计时间，单位秒。</summary>
var clock = 0.0
## <summary>该对象的循环动画是否启用。</summary>
var animation_enabled = true

## <summary>初始化背景控件，使其只负责绘制而不抢占鼠标事件。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## <summary>每帧推进扫描线时间并请求重绘，关闭动态效果时保持静止。</summary>
## <param name="delta">本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。</param>
## <returns>无返回值；修改显示或交互状态，不推进游戏回合。</returns>
func _process(delta: float) -> void:
	if animation_enabled:
		clock += delta
		queue_redraw()

## <summary>使用 CanvasItem 绘图 API 画出工业网格、扫描线和斜线。</summary>
## <returns>无返回值；由引擎在 queue_redraw 后调用。</returns>
func _draw() -> void:
	## <summary>背景网格线的低透明度颜色。</summary>
	var grid_color = Color(0.35, 0.65, 0.68, 0.09)
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color)
	## <summary>随时间向下移动的扫描线纵坐标。</summary>
	var scan_y = fmod(clock * 65, maxf(1, size.y))
	draw_rect(Rect2(0, scan_y, size.x, 2), Color(0.42, 0.86, 0.84, 0.16))
	for index in range(6):
		## <summary>当前列坐标或模型半宽。</summary>
		var x = size.x * 0.82 + index * 11
		draw_line(Vector2(x, 0), Vector2(x - size.y * 0.35, size.y), Color(0.8, 0.72, 0.49, 0.06), 3)
