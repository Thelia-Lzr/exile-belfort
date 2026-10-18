## <summary>工业终端风格界面。构造资源栏、建筑卡片、地块检查器、菜单、设置和势力档案，通过信号向控制器报告操作。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortHUD
extends Control

## <summary>界面请求执行命名操作；action 为 save、pause、next_turn 等字符串。</summary>
## <param name="action">按钮或菜单操作标识，例如 save、pause、next_turn。</param>
signal action_requested(action: String)
## <summary>玩家选择建造卡片时发出；type 为六种可建建筑的内部键。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
signal build_requested(type: String)
## <summary>玩家确认势力草稿时发出；faction 包含旗帜标识、名称、配色和背景。</summary>
## <param name="faction">玩家已确认的势力字典，包含 id、name、color、description。</param>
signal faction_confirmed(faction: Dictionary)
## <summary>玩家修改设置时发出；key 指定设置名称，value 提供新值。</summary>
## <param name="key">图标资源名、资源内部键或设置项内部名称，按调用方法决定。</param>
## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
signal setting_changed(key: String, value: Variant)

## <summary>四个原创势力的身份、旗帜标识、背景及颜色。</summary>
const FACTIONS = [
	{"id": "exiles", "name": "贝尔福流亡者", "color": "#d1ad70", "description": "来自远方的流亡者，在贝尔福重建家园。每一座建筑，都是重新开始的证明。", "code": "BLF / 01"},
	{"id": "foresters", "name": "林地守望者", "color": "#82ac80", "description": "群山与森林之间的守望者。以木材和土地为生，用耐心维系聚落的未来。", "code": "FRS / 02"},
	{"id": "guild", "name": "蓝石工匠会", "color": "#6599c2", "description": "聚集在古老矿道周围的工匠。石材、工具和交换，让陌生人逐渐成为同伴。", "code": "GLD / 03"},
	{"id": "cinder", "name": "余烬商旅", "color": "#b97468", "description": "沿着商路抵达边地的旅人。火光照亮帐篷，贸易将孤立的营地连接起来。", "code": "ASH / 04"}
]
## <summary>工业界面的最深背景色。</summary>
const INK = Color("11171d")
## <summary>工业面板底色。</summary>
const PANEL = Color("20272e")
## <summary>面板细线与边框颜色。</summary>
const LINE = Color("45515b")
## <summary>关键操作和重点信息使用的金色。</summary>
const GOLD = Color("e6c45b")
## <summary>主要文字颜色。</summary>
const TEXT = Color("e4e9e5")
## <summary>次要说明文字颜色。</summary>
const MUTED = Color("90a5ab")
## <summary>选中、有效建造与收益提示颜色。</summary>
const CYAN = Color("83cfbf")

## <summary>承载三维子视口的界面容器。</summary>
var map_container: SubViewportContainer
## <summary>拦截地图操作的全屏菜单遮罩。</summary>
var overlay: Control
## <summary>当前菜单的主要面板对象。</summary>
var overlay_panel: PanelContainer
## <summary>资源键到库存数值 Label 的映射。</summary>
var resource_values: Dictionary = {}
## <summary>资源键到下回合净变化 Label 的映射。</summary>
var resource_deltas: Dictionary = {}
## <summary>建筑类型到建造卡片 Button 的映射。</summary>
var build_buttons: Dictionary = {}
## <summary>显示地形、建筑和坐标的标题标签。</summary>
var inspector_title: Label
## <summary>显示地块说明或建造预览的标签。</summary>
var inspector_body: Label
## <summary>承载地块或建筑产出图标的横向容器。</summary>
var inspector_yields: HBoxContainer
## <summary>显示最近行动记录的标签。</summary>
var journal_label: Label
## <summary>始终位于界面最前方的操作反馈面板，确保菜单中的错误也可见。</summary>
var notice_panel: PanelContainer
## <summary>显示短暂操作反馈的标签。</summary>
var notice_label: Label
## <summary>控制操作反馈自动消失的一次性计时器。</summary>
var notice_timer: Timer
## <summary>显示建造有效性、原因和方向的标签。</summary>
var status_label: Label
## <summary>显示当前回合数的标签。</summary>
var turn_label: Label
## <summary>显示当前势力名称的标签。</summary>
var faction_label: Label
## <summary>撤销最近一次本回合建造的按钮。</summary>
var undo_button: Button
## <summary>旋转当前待建建筑的按钮。</summary>
var rotate_button: Button
## <summary>结束回合的主要操作按钮。</summary>
var next_button: Button
## <summary>控制放置后是否继续保留建筑类型的复选框。</summary>
var continuous: CheckBox
## <summary>势力选择中的临时数据，确认后才交给规则模型。</summary>
var faction_draft: Dictionary
## <summary>四个势力选择卡片的按钮数组。</summary>
var faction_cards: Array = []
## <summary>编辑势力名称的单行输入对象。</summary>
var faction_name: LineEdit
## <summary>编辑势力背景的多行输入对象。</summary>
var faction_description: TextEdit
## <summary>当前建筑分类过滤条件。</summary>
var filter_value = "全部"
## <summary>全局动态效果开关，控制建造、完工与界面动画。</summary>
var dynamic_effects = true
## <summary>界面当前高亮的建筑类型。</summary>
var selected_build = ""
var chromes: Array[BelfortTacticalChrome] = []
var intro_serial = 0

## <summary>创建支持中文的统一工业主题和各个主界面模块；由引擎在节点入树后调用。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## <summary>统一工业风按钮、面板和字体的 Theme 资源。</summary>
	var ui_theme = Theme.new()
	## <summary>支持中文系统字体回退的 SystemFont 对象。</summary>
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Heiti SC", "Noto Sans CJK SC", "Microsoft YaHei", "Arial"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_color("font_color", "Button", TEXT)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_color", "CheckBox", TEXT)
	ui_theme.set_stylebox("normal", "Button", style(PANEL, LINE, 1, 10))
	ui_theme.set_stylebox("hover", "Button", style(Color("2d434b"), CYAN, 1, 10))
	ui_theme.set_stylebox("pressed", "Button", style(Color("364b4c"), GOLD, 2, 10))
	ui_theme.set_stylebox("disabled", "Button", style(Color("202b31"), Color("344249"), 1, 10))
	ui_theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), CYAN, 2, 0))
	ui_theme.set_stylebox("normal", "LineEdit", style(Color("101b22"), LINE, 1, 10))
	ui_theme.set_stylebox("normal", "TextEdit", style(Color("101b22"), LINE, 1, 10))
	ui_theme.set_stylebox("focus", "LineEdit", style(Color("17252c"), GOLD, 1, 10))
	ui_theme.set_stylebox("focus", "TextEdit", style(Color("17252c"), GOLD, 1, 10))
	ui_theme.set_stylebox("panel", "AcceptDialog", style(INK, GOLD, 1, 16))
	ui_theme.set_stylebox("panel", "PopupMenu", style(INK, LINE, 1, 10))
	ui_theme.set_stylebox("selected", "PopupMenu", style(PANEL, GOLD, 1, 8))
	ui_theme.set_stylebox("panel", "Tree", style(INK, LINE, 1, 8))
	ui_theme.set_stylebox("slider", "HSlider", style(Color("343e45"), LINE, 1, 2))
	ui_theme.set_stylebox("grabber_area", "HSlider", style(GOLD, GOLD, 0, 2))
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", style(CYAN, CYAN, 0, 2))
	ui_theme.set_stylebox("panel", "TooltipPanel", style(Color("101a21"), CYAN, 1, 12))
	ui_theme.set_color("font_color", "TooltipLabel", TEXT)
	theme = ui_theme
	_make_header()
	_make_map()
	_make_sidebar()
	_make_bottom()
	_make_overlay()
	move_child(notice_panel, get_child_count() - 1)
	_decorate_tree(self)
	get_tree().node_added.connect(_node_added)

## <summary>集中装饰所有页面的控件，包括之后创建的设置、势力和存档窗口。</summary>
func _node_added(node: Node) -> void:
	if node is Control and is_ancestor_of(node):
		_decorate_control.call_deferred(node)

func _decorate_tree(node: Node) -> void:
	if node is Control:
		_decorate_control(node)
	for child in node.get_children():
		_decorate_tree(child)

func _decorate_control(control) -> void:
	if not is_instance_valid(control) or control.is_queued_for_deletion() or control.has_meta("tactical_chrome"):
		return
	if control is PanelContainer or control is BaseButton or control is LineEdit or control is TextEdit or control is HSlider:
		var chrome = BelfortTacticalChrome.new()
		chrome.name = "TacticalChrome"
		chrome.animation_enabled = dynamic_effects
		if control in build_buttons.values():
			chrome.selected = control == build_buttons.get(selected_build)
		elif control in faction_cards:
			chrome.selected = FACTIONS[faction_cards.find(control)].id == faction_draft.get("id", "exiles")
		control.set_meta("tactical_chrome", chrome)
		control.add_child(chrome)
		chromes.append(chrome)
		chrome.tree_exiting.connect(func(): chromes.erase(chrome))
		if control is PanelContainer or control is Button:
			_animate_in.call_deferred(control, minf(intro_serial % 6 * 0.035, 0.175))
			intro_serial += 1

## <summary>容器位置保持由布局管理，只对透明度与缩放播放错时入场。</summary>
func _animate_in(control, delay: float = 0.0) -> void:
	if not is_instance_valid(control) or control.is_queued_for_deletion() or not dynamic_effects:
		return
	var previous = control.get_meta("ui_intro_tween") if control.has_meta("ui_intro_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	control.pivot_offset = control.size * 0.5
	control.self_modulate.a = 0.0
	control.scale = Vector2.ONE * 0.985
	var tween = control.create_tween().set_parallel(true)
	control.set_meta("ui_intro_tween", tween)
	tween.tween_property(control, "self_modulate:a", 1.0, 0.22).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## <summary>数值变化时亮起；反复刷新相同值不会重启动效。</summary>
func _value_feedback(control: Control) -> void:
	if not dynamic_effects:
		return
	var previous = control.get_meta("ui_value_tween") if control.has_meta("ui_value_tween") else null
	if previous is Tween and previous.is_valid():
		previous.kill()
	control.self_modulate = GOLD
	var tween = control.create_tween()
	control.set_meta("ui_value_tween", tween)
	tween.tween_property(control, "self_modulate", Color.WHITE, 0.45)

## <summary>动态设置立即作用于全部 UI，并恢复未完成的入场和数值反馈。</summary>
func set_dynamic(enabled: bool) -> void:
	dynamic_effects = enabled
	chromes = chromes.filter(func(chrome): return is_instance_valid(chrome))
	for chrome in chromes:
		chrome.set_dynamic(enabled)
	for control in find_children("*", "Control", true, false):
		if control is BelfortFactionBackdrop:
			control.animation_enabled = enabled
		if not enabled:
			for key in ["ui_intro_tween", "ui_value_tween"]:
				var tween = control.get_meta(key) if control.has_meta(key) else null
				if tween is Tween and tween.is_valid():
					tween.kill()
			control.self_modulate = Color.WHITE
			control.scale = Vector2.ONE

## <summary>创建方形工业面板的填色、边框与内容内边距样式。</summary>
## <param name="fill">面板底色，支持透明度。</param>
## <param name="border">面板边框颜色。</param>
## <param name="width">边框像素宽度；菜单基础方法中表示面板最小宽度。</param>
## <param name="padding">四边内容内边距，单位为逻辑像素。</param>
## <returns>StyleBoxFlat 资源，可赋给 PanelContainer 或 Button。</returns>
static func style(fill: Color, border: Color, width: int = 1, padding: int = 16) -> StyleBoxFlat:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

## <summary>创建使用统一工业风样式的面板并加入父节点。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="fill">面板底色，支持透明度。</param>
## <param name="border">面板边框颜色。</param>
## <param name="padding">四边内容内边距，单位为逻辑像素。</param>
## <returns>PanelContainer 控件对象。</returns>
func panel(parent: Node, fill: Color = PANEL, border: Color = LINE, padding: int = 16) -> PanelContainer:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(fill, border, 1, padding))
	parent.add_child(result)
	return result

## <summary>创建指定文字、字号和颜色的标签，默认不拦截鼠标。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="caption">控件显示的文本。</param>
## <param name="font_size">文字字号。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <returns>Label 控件对象。</returns>
func label(parent: Node, caption: String, font_size: int = 16, color: Color = TEXT) -> Label:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = Label.new()
	result.text = caption
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

## <summary>创建指定间隔的纵向布局容器。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="separation">相邻布局子控件的间隔像素数。</param>
## <returns>已加入父节点的 VBoxContainer。</returns>
func vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	parent.add_child(result)
	return result

## <summary>创建指定间隔的横向布局容器。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="separation">相邻布局子控件的间隔像素数。</param>
## <returns>已加入父节点的 HBoxContainer。</returns>
func hbox(parent: Node, separation: int = 10) -> HBoxContainer:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = HBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	parent.add_child(result)
	return result

## <summary>加载本地 SVG 并创建保持比例的图标控件。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="key">图标资源名、资源内部键或设置项内部名称，按调用方法决定。</param>
## <param name="pixels">图标最小显示边长，单位为逻辑像素。</param>
## <returns>TextureRect 控件，图像使用矢量资源导入。</returns>
func icon(parent: Node, key: String, pixels: int = 26) -> TextureRect:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = TextureRect.new()
	result.texture = load("res://assets/icons/" + key + ".svg")
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(pixels, pixels)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

## <summary>创建不抢键盘焦点的按钮，按下时发出 action_requested 信号。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="caption">控件显示的文本。</param>
## <param name="action">按钮或菜单操作标识，例如 save、pause、next_turn。</param>
## <param name="minimum">允许的最小整数，包含此边界。</param>
## <returns>Button 控件对象；通过返回值继续设置样式或提示。</returns>
func button(parent: Node, caption: String, action: String, minimum: Vector2 = Vector2(0, 42)) -> Button:
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = Button.new()
	result.text = caption
	result.custom_minimum_size = minimum
	result.focus_mode = Control.FOCUS_NONE
	## <summary>按钮被按下时，将绑定的操作标识发送给主控制器。</summary>
	## <returns>无返回值；通过信号或对象属性产生效果。</returns>
	result.pressed.connect(func(): action_requested.emit(action))
	parent.add_child(result)
	return result

## <summary>创建资源图标加数值的横向组合，并提供悬停名称。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <param name="key">图标资源名、资源内部键或设置项内部名称，按调用方法决定。</param>
## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
## <param name="pixels">图标最小显示边长，单位为逻辑像素。</param>
## <param name="color">颜色值，使用 Godot Color，分量通常为 0 到 1。</param>
## <returns>数值对应的 Label，调用者可随后更新其 text。</returns>
func resource_pair(parent: Node, key: String, value: String, pixels: int = 19, color: Color = TEXT) -> Label:
	## <summary>横向界面容器或当前地形行。</summary>
	var row = hbox(parent, 4)
	icon(row, key, pixels)
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = label(row, value, 15, color)
	row.tooltip_text = BelfortState.RESOURCE_NAMES.get(key, "人口")
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	return result

## <summary>构建游戏名称、五个图标资源单元、回合数和暂停按钮。</summary>
## <returns>无返回值；将库存与收益标签注册进字典。</returns>
func _make_header() -> void:
	## <summary>顶部资源与回合面板。</summary>
	var header = panel(self, INK, LINE, 18)
	header.name = "ResourceHeader"
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 88
	## <summary>横向界面容器或当前地形行。</summary>
	var row = hbox(header, 20)
	## <summary>顶部游戏名称与势力副标题容器。</summary>
	var wordmark = vbox(row, 0)
	wordmark.custom_minimum_size.x = 270
	label(wordmark, "流亡者 / 贝尔福", 26, TEXT)
	faction_label = label(wordmark, "EXILE IN BELFORT  //  2.5D", 12, MUTED)
	for key in ["gold", "food", "wood", "stone", "population"]:
		## <summary>当前待查询、占用或绘制的地块坐标。</summary>
		var cell = hbox(row, 6)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon(cell, key, 34)
		## <summary>界面卡片或资源单元内的内容容器。</summary>
		var content = vbox(cell, 0)
		resource_values[key] = label(content, "0", 25)
		resource_deltas[key] = label(content, "+0 / 回合", 12, CYAN)
		cell.tooltip_text = BelfortState.RESOURCE_NAMES.get(key, "人口") + "\n上行：现有数量；下行：下回合净变化。"
	## <summary>顶部回合图标与数值的横向容器。</summary>
	var turn_box = hbox(row, 6)
	icon(turn_box, "turn", 30)
	turn_label = label(turn_box, "01", 24, GOLD)
	## <summary>顶部暂停按钮。</summary>
	var menu_button = button(row, "Ⅱ", "pause", Vector2(42, 42))
	menu_button.tooltip_text = "暂停 / 设置 · Esc"

## <summary>构建独立地图视口容器、镜头提示和短暂反馈标签。</summary>
## <returns>无返回值；三维世界由控制器随后加入该容器。</returns>
func _make_map() -> void:
	## <summary>包裹地图视口的工业风边框面板。</summary>
	var map_frame = panel(self, Color("152b33"), LINE, 0)
	map_frame.name = "MapFrame"
	map_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_frame.offset_left = 20
	map_frame.offset_top = 108
	map_frame.offset_right = -358
	map_frame.offset_bottom = -158
	map_container = SubViewportContainer.new()
	map_container.name = "MapViewportContainer"
	map_container.stretch = true
	map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_container.mouse_filter = Control.MOUSE_FILTER_STOP
	map_frame.add_child(map_container)
	## <summary>地图上方的镜头操作提示标签。</summary>
	var hint = label(self, "SECTOR 01 / 贝尔福    ·    拖动右键 / 中键移动    滚轮缩放    Q E 转向    F 全图", 12, MUTED)
	hint.position = Vector2(30, 90)
	notice_panel = panel(self, Color(0.06, 0.1, 0.13, 0.96), GOLD, 12)
	notice_panel.position = Vector2(36, 124)
	notice_panel.visible = false
	notice_label = label(notice_panel, "", 16, TEXT)
	notice_label.custom_minimum_size.x = 520
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ignore_mouse(notice_panel)
	notice_label.add_theme_color_override("font_shadow_color", Color("0c151b"))
	notice_label.add_theme_constant_override("shadow_offset_x", 2)
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	notice_timer = Timer.new()
	notice_timer.one_shot = true
	## <summary>通知计时结束后隐藏反馈面板。</summary>
	## <returns>无返回值；通过信号或对象属性产生效果。</returns>
	notice_timer.timeout.connect(func(): notice_panel.visible = false)
	add_child(notice_timer)

## <summary>构建分类、六种建造卡片、连续建造、撤销和回合按钮。</summary>
## <returns>无返回值；建筑列表可滚动，较小窗口也能访问全部建筑。</returns>
func _make_sidebar() -> void:
	## <summary>右侧建造与回合控制面板。</summary>
	var sidebar = panel(self, INK, LINE, 16)
	sidebar.name = "BuildSidebar"
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sidebar.offset_left = -338
	sidebar.offset_right = -20
	sidebar.offset_top = 108
	sidebar.offset_bottom = -22
	## <summary>纵向排列界面元素的容器。</summary>
	var column = vbox(sidebar, 10)
	label(column, "建设 / DEVELOPMENT", 21, TEXT)
	label(column, "连接聚落，规划每一格土地", 12, MUTED)
	## <summary>建筑分类按钮的横向容器。</summary>
	var filters = hbox(column, 6)
	for category in ["全部", "生产", "经济"]:
		## <summary>建筑分类筛选按钮。</summary>
		var tab = Button.new()
		tab.text = category
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.focus_mode = Control.FOCUS_NONE
		filters.add_child(tab)
		## <summary>信号触发后执行局部回调，将当前控件或动画事件转发给所属系统。</summary>
		## <returns>无返回值；通过信号或对象属性产生效果。</returns>
		tab.pressed.connect(func(): _filter(category))
	## <summary>使建筑卡片在较小窗口中仍可访问的滚动容器。</summary>
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	## <summary>纵向排列建筑卡片的容器。</summary>
	var list = vbox(scroll, 7)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(BelfortState.ORDER.size()):
		## <summary>建筑或资源的内部类型字符串。</summary>
		var type: String = BelfortState.ORDER[index]
		## <summary>当前建筑、势力或存档字段的详细信息。</summary>
		var info = BelfortState.CATALOG[type]
		## <summary>当前建筑或势力的按钮卡片。</summary>
		var card = Button.new()
		card.name = "Build_" + type
		card.custom_minimum_size.y = 78
		card.focus_mode = Control.FOCUS_NONE
		card.tooltip_text = "%s\n%s\n%s\n快捷键 %d · R 旋转 · 右键 / Esc 取消\n必须与已有建筑相邻" % [info.name, info.hint, _yield_text(type), index + 1]
		list.add_child(card)
		## <summary>控制卡片内容内边距的容器。</summary>
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)
		## <summary>建筑卡片内部的图标与文字横向排列。</summary>
		var card_row = hbox(margin, 10)
		icon(card_row, type, 37)
		## <summary>界面卡片或资源单元内的内容容器。</summary>
		var content = vbox(card_row, 4)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label(content, "%s    /  0%d" % [info.name, index + 1], 17)
		## <summary>建筑费用图标的横向容器。</summary>
		var cost_row = hbox(content, 9)
		for key in info.cost:
			resource_pair(cost_row, key, str(info.cost[key]), 17)
		_ignore_mouse(margin)
		## <summary>信号触发后执行局部回调，将当前控件或动画事件转发给所属系统。</summary>
		## <returns>无返回值；通过信号或对象属性产生效果。</returns>
		card.pressed.connect(func(): build_requested.emit(type))
		build_buttons[type] = card
	continuous = CheckBox.new()
	continuous.text = "连续建造"
	continuous.button_pressed = true
	continuous.tooltip_text = "放置后保留选中的建筑；右键或 Esc 取消"
	continuous.focus_mode = Control.FOCUS_NONE
	column.add_child(continuous)
	## <summary>旋转与撤销按钮的横向容器。</summary>
	var tools = hbox(column, 8)
	undo_button = button(tools, "撤销", "undo")
	undo_button.icon = load("res://assets/icons/undo.svg")
	undo_button.expand_icon = true
	undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_button.tooltip_text = "撤销本回合最近的建造并退还资源 · ⌘Z / Ctrl+Z"
	rotate_button = button(tools, "旋转", "rotate")
	rotate_button.icon = load("res://assets/icons/rotate.svg")
	rotate_button.expand_icon = true
	rotate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate_button.tooltip_text = "六边形方向每次旋转 60° · R"
	status_label = label(column, "选择建筑，再点击相邻地块", 14, CYAN)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 42
	next_button = button(column, "结束回合   →", "next_turn", Vector2(0, 66))
	next_button.add_theme_font_size_override("font_size", 22)
	next_button.add_theme_stylebox_override("normal", style(Color("b89859"), GOLD, 1, 14))
	next_button.add_theme_color_override("font_color", INK)
	next_button.tooltip_text = "结算所有建筑收益与人口粮食消耗 · Enter\n每回合结束时自动保存"
	## <summary>保存、读取和设置按钮的横向容器。</summary>
	var controls = hbox(column, 8)
	button(controls, "保存", "save").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(controls, "读取", "load").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(controls, "设置", "settings").size_flags_horizontal = Control.SIZE_EXPAND_FILL

## <summary>构建地块信息、产出图标和最近行动记录面板。</summary>
## <returns>无返回值；保存相关标签引用以便后续刷新。</returns>
func _make_bottom() -> void:
	## <summary>底部地块检查与日志面板。</summary>
	var bottom = panel(self, INK, LINE, 14)
	bottom.name = "FieldInspector"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -140
	bottom.offset_bottom = -22
	bottom.offset_left = 20
	bottom.offset_right = -358
	## <summary>横向界面容器或当前地形行。</summary>
	var row = hbox(bottom, 24)
	## <summary>底部地块信息的纵向容器。</summary>
	var inspection = vbox(row, 4)
	inspection.custom_minimum_size.x = 320
	inspector_title = label(inspection, "地块 / INSPECT", 18, GOLD)
	inspector_body = label(inspection, "悬停查看，点击固定地块信息", 14, MUTED)
	inspector_yields = hbox(inspection, 10)
	## <summary>行动记录字符串数组，存档保留最近十五条。</summary>
	var journal = vbox(row, 4)
	journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(journal, "行动记录 / FIELD LOG", 12, MUTED)
	journal_label = label(journal, "", 13)
	journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_label.max_lines_visible = 3

## <summary>创建全屏菜单根控件，菜单出现时拦截地图操作。</summary>
## <returns>无返回值；初始遮罩隐藏。</returns>
func _make_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

## <summary>递归设置装饰控件为忽略鼠标，使卡片按钮完整接收点击。</summary>
## <param name="parent">接收新节点或需要递归处理的父节点。</param>
## <returns>无返回值；仅改变指定子树的 mouse_filter。</returns>
func _ignore_mouse(parent: Node) -> void:
	if parent is Control:
		parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in parent.get_children():
		_ignore_mouse(child)

## <summary>根据工业界面分类筛选显示的建筑卡片。</summary>
## <param name="category">建筑筛选分类，全部、生产或经济。</param>
## <returns>无返回值；更新卡片 visible 并报告点击动作。</returns>
func _filter(category: String) -> void:
	filter_value = category
	for type in build_buttons:
		build_buttons[type].visible = category == "全部" or BelfortState.CATALOG[type].tag == category
	action_requested.emit("click")

## <summary>把建筑的回合产出和人口增长转成中文悬停说明。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>供 tooltip_text 使用的说明字符串。</returns>
func _yield_text(type: String) -> String:
	## <summary>当前建筑、势力或存档字段的详细信息。</summary>
	var info = BelfortState.CATALOG[type]
	## <summary>当前建筑产出说明的文字片段数组。</summary>
	var pieces: Array = []
	for key in info["yield"]:
		pieces.append("%s +%d" % [BelfortState.RESOURCE_NAMES[key], info["yield"][key]])
	if info.population > 0:
		pieces.append("人口 +%d（粮食充足时）" % info.population)
	return "每回合：" + " / ".join(pieces)

## <summary>刷新库存、净收益、回合、卡片高亮、撤销状态和建造提示。</summary>
## <param name="state">要展示或测试的规则模型。</param>
## <param name="chosen">当前待建建筑类型；空字符串表示选择模式。</param>
## <param name="rotation_value">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <returns>无返回值；不重建三维地图，仅更新界面对象。</returns>
func refresh(state: BelfortState, chosen: String, rotation_value: int) -> void:
	selected_build = chosen
	## <summary>用于预览或核对的回合收入字典。</summary>
	var income = state.income()
	for key in resource_values:
		## <summary>当前显示、保存或应用的参数值。</summary>
		var value = state.population if key == "population" else state.resources[key]
		if resource_values[key].text != str(value):
			_value_feedback(resource_values[key])
		resource_values[key].text = str(value)
		## <summary>本次帧间隔或当前资源的回合净变化。</summary>
		var delta = income[key]
		if key == "population" and state.resources.food + income.food < 0:
			delta = 0
		resource_deltas[key].text = "%+d / 回合" % delta
		resource_deltas[key].modulate = Color("ed9986") if delta < 0 else CYAN
	if turn_label.text != "%02d" % state.turn:
		_value_feedback(turn_label)
	turn_label.text = "%02d" % state.turn
	faction_label.text = state.faction.name + "  //  SECTOR 01"
	undo_button.disabled = state.undo_stack.is_empty()
	rotate_button.disabled = chosen.is_empty()
	for type in build_buttons:
		## <summary>该卡片是否处于选中状态。</summary>
		var selected = type == chosen
		build_buttons[type].add_theme_stylebox_override("normal", style(Color("29443f") if selected else PANEL, CYAN if selected else LINE, 2 if selected else 1, 10))
		build_buttons[type].modulate = Color.WHITE if state.missing_cost(type).is_empty() else Color("879396")
		if build_buttons[type].has_meta("tactical_chrome"):
			var chrome: BelfortTacticalChrome = build_buttons[type].get_meta("tactical_chrome")
			chrome.selected = selected
			chrome.queue_redraw()
	journal_label.text = "\n".join(state.journal.slice(-3))
	if not chosen.is_empty():
		status_label.text = "%s · 朝向 %d°\nR 旋转 / 右键取消" % [BelfortState.CATALOG[chosen].name, rotation_value * 60]
	else:
		status_label.text = "选择建筑，再点击相邻地块"
	status_label.modulate = CYAN
	if state.resources.food + income.food < 0:
		next_button.text = "粮食不足 · 结束回合 →"
	else:
		next_button.text = "结束回合   →"

## <summary>显示悬停或固定地块的信息，并解释当前建筑能否放置。</summary>
## <param name="state">要展示或测试的规则模型。</param>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <param name="chosen">当前待建建筑类型；空字符串表示选择模式。</param>
## <param name="rotation_value">六方向旋转档位，整数 0 到 5；每档为 60 度。</param>
## <returns>无返回值；更新标题、说明和回合产出图标。</returns>
func inspect(state: BelfortState, cell: Vector2i, chosen: String, rotation_value: int) -> void:
	for child in inspector_yields.get_children():
		inspector_yields.remove_child(child)
		child.queue_free()
	if not state.contains_cell(cell):
		inspector_title.text = "地块 / INSPECT"
		inspector_body.text = "悬停查看，点击固定地块信息"
		return
	## <summary>当前地块的地形内部标识。</summary>
	var ground = state.terrain_at(cell)
	## <summary>当前遍历或查询到的建筑记录。</summary>
	var building = state.building_at(cell)
	## <summary>地块检查器中显示的建筑名称。</summary>
	var name_value = BelfortState.CATALOG[building.type].name if not building.is_empty() else "空地"
	inspector_title.text = "%s / %s   [%02d, %02d]" % [BelfortState.TERRAIN_NAMES[ground], name_value, cell.x + 1, cell.y + 1]
	if not chosen.is_empty():
		## <summary>规则或文件操作返回的错误说明。</summary>
		var error = state.placement_error(cell, chosen, rotation_value)
		status_label.text = "可建造 · 点击确认" if error.is_empty() else error
		status_label.modulate = CYAN if error.is_empty() else Color("ed9986")
		inspector_body.text = "预览：" + BelfortState.CATALOG[chosen].name + " · " + str(state.footprint(cell, chosen, rotation_value).size()) + " 格占地"
		_add_yields(chosen)
	elif not building.is_empty():
		inspector_body.text = "已连接聚落 · 下回合产出"
		_add_yields(building.type)
	else:
		inspector_body.text = "水域无法建造" if ground == "water" else "可扩展地块 · 需要连接已有建筑"

## <summary>将指定建筑的资源与人口产出添加为图标加数值。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>无返回值；新控件加入 inspector_yields。</returns>
func _add_yields(type: String) -> void:
	## <summary>当前建筑、势力或存档字段的详细信息。</summary>
	var info = BelfortState.CATALOG[type]
	for key in info["yield"]:
		resource_pair(inspector_yields, key, "+" + str(info["yield"][key]), 20, CYAN)
	if info.population > 0:
		resource_pair(inspector_yields, "population", "+1", 20, CYAN)

## <summary>展示短暂的成功或失败反馈，并启动自动隐藏计时。</summary>
## <param name="message">显示的中文反馈或测试失败说明。</param>
## <param name="is_error">true 使用错误状态色；false 使用普通反馈色。</param>
## <returns>无返回值；错误用暖红色，普通信息用浅金色。</returns>
func notify(message: String, is_error: bool = false) -> void:
	notice_panel.visible = true
	notice_label.text = message
	notice_label.modulate = Color("ffac94") if is_error else Color("e7d7ad")
	notice_timer.start(4.5)
	_animate_in(notice_panel)

## <summary>清理旧菜单，创建深色遮罩、扫描背景和居中面板。</summary>
## <param name="width">边框像素宽度；菜单基础方法中表示面板最小宽度。</param>
## <returns>面板内的 VBoxContainer，供具体菜单继续添加内容。</returns>
func _overlay_base(width: float = 520) -> VBoxContainer:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.visible = true
	## <summary>菜单全屏深色遮罩。</summary>
	var shade = ColorRect.new()
	shade.color = Color(0.035, 0.065, 0.085, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	## <summary>绘制工业网格和扫描线的背景控件。</summary>
	var backdrop = BelfortFactionBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.animation_enabled = dynamic_effects
	overlay.add_child(backdrop)
	## <summary>地图格中心位置或用于居中菜单的容器。</summary>
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_panel = panel(center, Color("14222c"), Color("607773"), 28)
	overlay_panel.custom_minimum_size.x = width
	## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
	var result = vbox(overlay_panel, 16)
	return result

## <summary>隐藏菜单遮罩，将玩家操作交还地图。</summary>
## <returns>无返回值；保留菜单节点供后续替换。</returns>
func hide_overlay() -> void:
	overlay.visible = false
	var index = 0
	for control in [get_node("ResourceHeader"), get_node("MapFrame"), get_node("BuildSidebar"), get_node("FieldInspector")]:
		_animate_in(control, index * 0.045)
		index += 1

## <summary>构建主菜单，根据是否有存档或当前聚落显示继续入口。</summary>
## <param name="has_save">本地是否存在手动或自动存档。</param>
## <param name="has_session">是否已有可继续的当前游戏会话。</param>
## <returns>无返回值；菜单按钮通过信号通知主控制器。</returns>
func show_menu(has_save: bool, has_session: bool) -> void:
	## <summary>纵向排列界面元素的容器。</summary>
	var column = _overlay_base(540)
	label(column, "BELFORT / FRONTIER PROTOCOL", 13, CYAN)
	label(column, "流亡者：贝尔福", 36, TEXT)
	label(column, "在边地建立聚落。让每一份资源，成为未来。", 16, MUTED)
	label(column, "正交 2.5D  /  六边形建设  /  回合制生存", 13, GOLD)
	if has_session:
		button(column, "继续当前聚落", "resume")
	if has_save:
		button(column, "继续存档", "continue")
	button(column, "建立新聚落  /  选择势力", "factions", Vector2(0, 58))
	button(column, "读取存档 / 导入原版 JSON", "load")
	button(column, "声音与显示设置", "settings")
	button(column, "退出游戏", "quit")
	label(column, "GODOT EDITION  //  01    ·    本地运行 / 本地存档", 12, MUTED)

## <summary>构建暂停菜单，提供继续、保存、另存、设置和退出操作。</summary>
## <returns>无返回值；显示全屏遮罩。</returns>
func show_pause() -> void:
	## <summary>纵向排列界面元素的容器。</summary>
	var column = _overlay_base()
	label(column, "SESSION / 暂停", 30, TEXT)
	label(column, "本回合建造可撤销；结束回合会自动保存。", 14, MUTED)
	button(column, "继续游戏  /  ESC", "resume", Vector2(0, 54))
	button(column, "保存进度", "save")
	button(column, "另存为 JSON", "save_as")
	button(column, "声音与显示设置", "settings")
	button(column, "返回主菜单", "menu")
	button(column, "保存并退出", "save_quit")

## <summary>构建音量、静音、动态效果、全屏设置与快捷键说明。</summary>
## <param name="volume">线性音量，范围 0 到 1。</param>
## <param name="muted">当前是否静音。</param>
## <param name="effects">当前是否启用动态效果。</param>
## <param name="fullscreen">当前是否使用全屏窗口。</param>
## <returns>无返回值；修改控件时通过 setting_changed 报告参数。</returns>
func show_settings(volume: float, muted: bool, effects: bool, fullscreen: bool) -> void:
	## <summary>纵向排列界面元素的容器。</summary>
	var column = _overlay_base(570)
	label(column, "SYSTEM / 声音与显示", 28)
	label(column, "音效音量", 17, GOLD)
	## <summary>调节线性音量的滑杆。</summary>
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = volume
	slider.custom_minimum_size.y = 34
	column.add_child(slider)
	## <summary>设置控件变化时，携带设置名称和新值通知主控制器。</summary>
	## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
	## <returns>无返回值；通过信号或对象属性产生效果。</returns>
	slider.value_changed.connect(func(value): setting_changed.emit("volume", value))
	for setting in [["muted", "静音", muted], ["effects", "建造 / 建筑 / 界面动态效果", effects], ["fullscreen", "全屏显示（F11）", fullscreen]]:
		## <summary>当前设置项对应的复选框。</summary>
		var checkbox = CheckBox.new()
		checkbox.text = setting[1]
		checkbox.button_pressed = setting[2]
		## <summary>设置控件变化时，携带设置名称和新值通知主控制器。</summary>
		## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
		## <returns>无返回值；通过信号或对象属性产生效果。</returns>
		checkbox.toggled.connect(func(value): setting_changed.emit(setting[0], value))
		column.add_child(checkbox)
	label(column, "1–6 选择建筑  ·  R 旋转  ·  Esc 取消 / 暂停\n右键 / 中键拖动  ·  滚轮缩放  ·  Q / E 转向\nWASD 移动  ·  F 归位  ·  Enter 结束回合\n⌘S 保存  ·  ⌘O 读取  ·  ⌘Z 撤销（兼容 Ctrl）", 14, MUTED)
	button(column, "返回", "back", Vector2(0, 50))

## <summary>构建四势力旗帜卡片、徽记、名称和背景编辑界面。</summary>
## <param name="current">当前势力数据，用于初始化选择草稿。</param>
## <returns>无返回值；确认时发出 faction_confirmed，选择期间只修改草稿。</returns>
func show_factions(current: Dictionary) -> void:
	faction_draft = current.duplicate()
	## <summary>纵向排列界面元素的容器。</summary>
	var column = _overlay_base(1040)
	label(column, "IDENTITY / 势力档案", 30, TEXT)
	label(column, "选择旗帜与身份。各势力使用相同规则，不附带隐藏加成。", 14, MUTED)
	## <summary>排列势力卡片的横向容器。</summary>
	var cards = hbox(column, 12)
	faction_cards.clear()
	for index in range(FACTIONS.size()):
		## <summary>当前建筑、势力或存档字段的详细信息。</summary>
		var info = FACTIONS[index]
		## <summary>当前建筑或势力的按钮卡片。</summary>
		var card = Button.new()
		card.custom_minimum_size = Vector2(230, 188)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_NONE
		cards.add_child(card)
		## <summary>界面卡片或资源单元内的内容容器。</summary>
		var content = vbox(card, 6)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_top = 14
		content.offset_right = -12
		content.offset_bottom = -12
		## <summary>市政厅旗帜对应的网格对象。</summary>
		var flag = icon(content, "flag_" + info.id, 80)
		flag.custom_minimum_size.x = 170
		label(content, info.name, 18, Color(info.color)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label(content, info.code, 12, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ignore_mouse(content)
		## <summary>信号触发后执行局部回调，将当前控件或动画事件转发给所属系统。</summary>
		## <returns>无返回值；通过信号或对象属性产生效果。</returns>
		card.pressed.connect(func(): _choose_faction(index))
		faction_cards.append(card)
	## <summary>势力徽记与编辑字段的横向容器。</summary>
	var details = hbox(column, 22)
	## <summary>当前势力徽记的 TextureRect。</summary>
	var emblem = icon(details, "emblem_" + current.get("id", "exiles"), 110)
	emblem.name = "DraftEmblem"
	## <summary>势力名称和背景编辑控件的纵向容器。</summary>
	var fields = vbox(details, 8)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(fields, "势力名称 / DESIGNATION", 12, GOLD)
	faction_name = LineEdit.new()
	faction_name.max_length = 24
	faction_name.text = current.name
	fields.add_child(faction_name)
	label(fields, "背景 / DOSSIER", 12, GOLD)
	faction_description = TextEdit.new()
	faction_description.custom_minimum_size.y = 90
	faction_description.text = current.description
	fields.add_child(faction_description)
	## <summary>排列确认与返回按钮的横向容器。</summary>
	var actions = hbox(column, 14)
	button(actions, "返回", "menu").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## <summary>确认势力并建立聚落的按钮。</summary>
	var begin = Button.new()
	begin.text = "确认身份 / 建立聚落  →"
	begin.custom_minimum_size = Vector2(420, 55)
	begin.focus_mode = Control.FOCUS_NONE
	begin.add_theme_stylebox_override("normal", style(Color("376054"), CYAN, 1, 14))
	actions.add_child(begin)
	## <summary>确认势力时整理名称和背景，再将势力草稿提交给主控制器。</summary>
	## <returns>无返回值；通过信号或对象属性产生效果。</returns>
	begin.pressed.connect(func():
		faction_draft.name = faction_name.text.strip_edges().left(24)
		if faction_draft.name.is_empty():
			faction_draft.name = "贝尔福流亡者"
		faction_draft.description = faction_description.text.strip_edges().left(160)
		faction_confirmed.emit(faction_draft.duplicate())
	)
	_highlight_faction()

## <summary>把指定预设复制到势力草稿并更新编辑框与徽记。</summary>
## <param name="index">数组索引，从 0 开始。</param>
## <returns>无返回值；尚未修改正在运行的游戏规则模型。</returns>
func _choose_faction(index: int) -> void:
	faction_draft = FACTIONS[index].duplicate()
	faction_name.text = faction_draft.name
	faction_description.text = faction_draft.description
	## <summary>当前势力徽记的 TextureRect。</summary>
	var emblem = overlay.find_child("DraftEmblem", true, false)
	emblem.texture = load("res://assets/icons/emblem_" + faction_draft.id + ".svg")
	_highlight_faction()
	action_requested.emit("click")

## <summary>根据草稿势力标识刷新四张势力卡片的选中边框。</summary>
## <returns>无返回值；仅影响卡片样式。</returns>
func _highlight_faction() -> void:
	for index in range(faction_cards.size()):
		## <summary>该卡片是否处于选中状态。</summary>
		var selected = FACTIONS[index].id == faction_draft.get("id", "exiles")
		faction_cards[index].add_theme_stylebox_override("normal", style(Color("293c40") if selected else PANEL, Color(FACTIONS[index].color) if selected else LINE, 2 if selected else 1, 10))
		if faction_cards[index].has_meta("tactical_chrome"):
			var chrome: BelfortTacticalChrome = faction_cards[index].get_meta("tactical_chrome")
			chrome.selected = selected
			chrome.queue_redraw()
