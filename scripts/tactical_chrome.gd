## <summary>统一战术终端装饰：斜纹、切角标记、扫描条与交互反馈。Node2D 不占容器布局或鼠标输入。</summary>
class_name BelfortTacticalChrome
extends Node2D

var host: Control
var animation_enabled = true
var accent = Color("e6c45b")
var clock = 0.0
var hover = 0.0
var hovered = false
var flash = 0.0
var selected = false
var redraw_clock = 0.0

func _ready() -> void:
	host = get_parent() as Control
	host.resized.connect(queue_redraw)
	host.mouse_entered.connect(func(): hovered = true)
	host.mouse_exited.connect(func(): hovered = false)
	if host is BaseButton:
		host.button_down.connect(func(): flash = 1.0 if animation_enabled else 0.0)
	queue_redraw()

func set_dynamic(enabled: bool) -> void:
	animation_enabled = enabled
	if not enabled:
		hover = 0.0
		flash = 0.0
		clock = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not animation_enabled or not host.is_visible_in_tree():
		return
	clock += delta
	var active = hovered and not (host is BaseButton and host.disabled)
	hover = move_toward(hover, 1.0 if active else 0.0, delta * 8.0)
	flash = move_toward(flash, 0.0, delta * 3.5)
	redraw_clock += delta
	if redraw_clock >= 1.0 / 30.0:
		redraw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	if host == null or host.size.x < 12 or host.size.y < 12:
		return
	var extent = host.size
	var is_panel = host is PanelContainer
	var disabled = host is BaseButton and host.disabled
	var tint = Color("697274") if disabled else accent
	var stripe_width = minf(extent.x * 0.30, 100.0 if is_panel else 48.0)
	var stripe_height = 6.0 if is_panel else 4.0
	var edge = extent.x - 5.0
	var left = edge - stripe_width
	var y = 4.0 if is_panel else extent.y - 6.0
	# 条纹被限制在内容内边距；保持文字、费用与图标清晰。
	draw_rect(Rect2(left, y, stripe_width, stripe_height), Color(tint, 0.10))
	var shift = fmod(clock * 8.0, 10.0) if animation_enabled else 0.0
	for index in range(-1, int(stripe_width / 10.0) + 2):
		var x = left + index * 10.0 + shift
		var a = Vector2(clampf(x, left, edge), y + stripe_height)
		var b = Vector2(clampf(x + stripe_height, left, edge), y)
		if a.x < edge and b.x > left:
			draw_line(a, b, Color(tint, 0.42 + hover * 0.4), 2.0)
	var corner = 13.0 if is_panel else 7.0
	var color = Color(tint, 0.65 if selected else 0.27 + hover * 0.5)
	draw_polyline(PackedVector2Array([Vector2(2, corner + 2), Vector2(2, 2), Vector2(corner + 2, 2)]), color, 1.0)
	draw_polyline(PackedVector2Array([extent - Vector2(corner + 2, 2), extent - Vector2(2, 2), extent - Vector2(2, corner + 2)]), color, 1.0)
	if is_panel:
		draw_line(Vector2(18, 1), Vector2(minf(extent.x * 0.22, 100), 1), Color(tint, 0.8), 2.0)
		if animation_enabled:
			var x = 18.0 + fmod(clock * 22.0, maxf(extent.x - 40.0, 1.0))
			draw_line(Vector2(x, extent.y - 1), Vector2(minf(x + 28, extent.x - 2), extent.y - 1), Color("8ccdd2"), 1.0)
	else:
		if selected:
			draw_rect(Rect2(1, 10, 3, maxf(1, extent.y - 20)), tint)
		if hover > 0.01:
			draw_rect(Rect2(1, 1, extent.x - 2, extent.y - 2), Color(0.78, 0.88, 0.9, hover * 0.045))
			var x = fmod(clock * 100, extent.x + 30) - 30
			var start = clampf(x, 2, extent.x - 2)
			var end = clampf(x + 18, 2, extent.x - 2)
			draw_polygon(PackedVector2Array([Vector2(start, 2), Vector2(end, 2), Vector2(clampf(end - 18, 2, extent.x - 2), extent.y - 2), Vector2(clampf(start - 18, 2, extent.x - 2), extent.y - 2)]), PackedColorArray([Color(1, 1, 1, hover * 0.06)]))
		if flash > 0:
			draw_rect(Rect2(1, 1, extent.x - 2, extent.y - 2), Color(tint, flash * 0.13))
