## <summary>独立前置界面的共享底板，复用 HUD 主题、反馈和设置，不创建地图。</summary>
class_name BelfortFrontScreen
extends BelfortHUD

## <summary>页面主内容容器，支持在小窗口内滚动。</summary>
var page: VBoxContainer

## <summary>构造全屏不透明网格背景、页眉和带留白的滚动内容区。</summary>
func _make_content() -> void:
	var background = ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var backdrop = BelfortFactionBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.animation_enabled = dynamic_effects
	add_child(backdrop)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	add_child(margin)
	var layout = vbox(margin, 20)
	label(layout, "BELFORT  /  边地重建计划", 14, CYAN)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	page = vbox(center, 18)
	page.custom_minimum_size.x = 960
	label(layout, "流亡者：贝尔福    /    在边地重新建立家园", 13, MUTED)

## <summary>前置页面关闭设置时仅隐藏遮罩，不访问游戏 HUD 的节点。</summary>
func hide_overlay() -> void:
	overlay.hide()

## <summary>前置页面入口支持 Tab 与确认键，游戏内按钮维持原有快捷键行为。</summary>
## <param name="parent">按钮所在的布局容器。</param>
## <param name="caption">按钮显示的文字。</param>
## <param name="action">发送给流程控制器的操作名称。</param>
## <param name="minimum">按钮的最小逻辑尺寸。</param>
## <returns>支持键盘焦点的主题按钮。</returns>
func button(parent: Node, caption: String, action: String, minimum: Vector2 = Vector2(0, 42)) -> Button:
	var result = super.button(parent, caption, action, minimum)
	result.focus_mode = Control.FOCUS_ALL
	return result
