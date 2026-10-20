## <summary>独立开始界面，展示原创城门徽记与新建、继续、读取、设置入口。</summary>
extends BelfortFrontScreen

## <summary>本地是否存在可尝试读取的存档，由控制器入树前提供。</summary>
var has_save = false
## <summary>是否已有保留中的聚落，由控制器入树前提供。</summary>
var has_session = false

## <summary>构建可独立预览的开始页，入口状态由当前会话决定。</summary>
func _make_content() -> void:
	super._make_content()
	var row = hbox(page, 64)
	var identity = vbox(row, 18)
	identity.custom_minimum_size.x = 470
	var logo = icon(identity, "belfort_logo", 270)
	logo.name = "GameLogo"
	label(identity, "流亡者：贝尔福", 40, TEXT)
	label(identity, "EXILE / BELFORT", 22, GOLD)
	label(identity, "越过边地，重建家园。", 19, MUTED)
	label(identity, "六边形建设  /  资源经营  /  回合制", 14, CYAN)
	var actions = vbox(row, 12)
	actions.custom_minimum_size.x = 380
	label(actions, "01 / 启程", 16, GOLD)
	var start = button(actions, "开始  /  建立新聚落  →", "factions", Vector2(380, 64))
	start.name = "StartButton"
	for state_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		start.add_theme_color_override(state_name, INK)
	start.add_theme_stylebox_override("normal", style(GOLD, GOLD, 1, 14))
	if has_session:
		button(actions, "继续当前聚落", "resume")
	if has_save:
		button(actions, "继续存档", "continue")
	button(actions, "读取 / 导入存档", "load")
	button(actions, "声音与显示设置", "settings")
	button(actions, "退出游戏", "quit")
	start.grab_focus()
