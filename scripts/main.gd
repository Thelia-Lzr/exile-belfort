## <summary>游戏流程控制器。连接规则模型、三维地图、界面和声音，把玩家输入转换为建造、回合、存档等操作。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortGame
extends Node

## <summary>手动快速存档路径，user:// 表示 Godot 的用户数据目录。</summary>
const SAVE_PATH = "user://belfort_save.json"
## <summary>自动存档路径，与手动存档分开保存。</summary>
const AUTO_PATH = "user://belfort_autosave.json"
## <summary>音量、静音、动态效果和全屏偏好的配置路径。</summary>
const PREFS_PATH = "user://settings.cfg"

## <summary>规则模型对象，作为游戏数据的唯一来源。</summary>
var state = BelfortState.new()
## <summary>界面对象，负责展示数据和发出交互信号。</summary>
var hud: BelfortHUD
## <summary>三维地图对象，负责相机、模型和拾取。</summary>
var world: BelfortWorld
## <summary>管理合成音效的 BelfortAudio 对象。</summary>
var audio: BelfortAudio
## <summary>独立三维子视口，与界面点击区域分离。</summary>
var map_viewport: SubViewport
## <summary>导入或另存 JSON 的文件选择窗口。</summary>
var file_dialog: FileDialog
## <summary>当前流程状态，menu、factions、game、pause 或 settings。</summary>
var scene = "menu"
## <summary>进入设置前的流程状态，用于正确返回。</summary>
var return_scene = "menu"
## <summary>是否已经建立或读取一个可继续的聚落。</summary>
var session_started = false
## <summary>该卡片是否处于选中状态。</summary>
var selected = Vector2i(10, 8)
## <summary>鼠标当前悬停的地块坐标，负坐标代表地图外。</summary>
var hovered = Vector2i(-1, -1)
## <summary>当前待建建筑类型，空字符串表示选择模式。</summary>
var chosen = ""
## <summary>当前建筑旋转档位，0 到 5 对应六个 60 度方向。</summary>
var rotation_value = 0
## <summary>是否正在通过鼠标拖动镜头。</summary>
var dragging = false
## <summary>本次拖动累计像素距离，用于区分右键点击和拖动。</summary>
var drag_distance = 0.0
## <summary>当前拖动是否由右键启动。</summary>
var right_down = false
## <summary>全局动态效果开关，控制建造、完工与界面动画。</summary>
var dynamic_effects = true
## <summary>上次结束回合的毫秒时间，避免连续重复触发。</summary>
var last_turn_msec = -1000
## <summary>上次射线悬停检测时间，降低不必要的检测频率。</summary>
var last_hover_msec = 0

## <summary>引擎首次将主节点加入场景树后执行；创建并连接模型、界面、三维子视口、声音和信号，读取设置并显示主菜单。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	state.reset()
	audio = BelfortAudio.new()
	audio.name = "Audio"
	add_child(audio)
	hud = BelfortHUD.new()
	hud.name = "HUD"
	add_child(hud)
	map_viewport = SubViewport.new()
	map_viewport.name = "WorldViewport"
	map_viewport.own_world_3d = true
	map_viewport.handle_input_locally = false
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_viewport.msaa_3d = Viewport.MSAA_2X
	hud.map_container.add_child(map_viewport)
	world = BelfortWorld.new()
	world.name = "World"
	map_viewport.add_child(world)
	## <summary>三维动画事件到达时播放对应的材料落地或建筑完工音效。</summary>
	## <returns>无返回值；通过信号或对象属性产生效果。</returns>
	world.material_landed.connect(func(): audio.play("land"))
	## <summary>三维动画事件到达时播放对应的材料落地或建筑完工音效。</summary>
	## <returns>无返回值；通过信号或对象属性产生效果。</returns>
	world.building_finished.connect(func(): audio.play("build"))
	hud.map_container.gui_input.connect(_map_input)
	hud.map_container.mouse_exited.connect(_map_exited)
	hud.action_requested.connect(_action)
	hud.build_requested.connect(_choose)
	hud.faction_confirmed.connect(_start_game)
	hud.setting_changed.connect(_setting)
	_load_preferences()
	world.rebuild(state)
	_refresh()
	_show_menu()
	get_tree().auto_accept_quit = false

## <summary>每帧处理 WASD 镜头平移，并以节流频率刷新镜头移动后的鼠标射线命中。菜单或文件对话框打开时不处理地图。</summary>
## <param name="delta">本帧与上一帧的间隔秒数；镜头 pan 中则表示屏幕像素方向的移动量。</param>
## <returns>无返回值；修改显示或交互状态，不推进游戏回合。</returns>
func _process(delta: float) -> void:
	if scene != "game" or file_dialog != null and file_dialog.visible:
		return
	## <summary>镜头移动方向、射线方向或帐篷方向档位。</summary>
	var direction = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.y += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if direction != Vector2.ZERO:
		world.pan(-direction.normalized() * delta * 430)
	## <summary>当前引擎运行时间，用于节流或防连击。</summary>
	var now = Time.get_ticks_msec()
	if not dragging and now - last_hover_msec > 65:
		last_hover_msec = now
		## <summary>鼠标相对地图容器左上角的二维位置。</summary>
		var local = hud.map_container.get_local_mouse_position()
		if Rect2(Vector2.ZERO, hud.map_container.size).has_point(local):
			_update_hover(_viewport_pointer(local))

## <summary>接收系统关闭窗口通知，保存当前聚落和设置后再退出。</summary>
## <param name="what">Godot 引擎发送的通知常量。</param>
## <returns>无返回值；存档失败时保留窗口，便于用户重试。</returns>
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if session_started and not _save(AUTO_PATH, false):
			return
		_save_preferences()
		get_tree().quit()

## <summary>把界面逻辑坐标换算成子视口像素坐标，兼容窗口缩放。</summary>
## <param name="local">鼠标相对地图容器左上角的界面逻辑坐标。</param>
## <returns>用于相机射线投影的 Vector2。</returns>
func _viewport_pointer(local: Vector2) -> Vector2:
	return local * Vector2(map_viewport.size) / hud.map_container.size.max(Vector2.ONE)

## <summary>处理仅发生在地图区域的鼠标、拖动、滚轮和触控板手势。</summary>
## <param name="event">引擎传入的输入事件，可包含按键、鼠标或触控板信息。</param>
## <returns>无返回值；界面按钮事件不会进入这个处理器。</returns>
func _map_input(event: InputEvent) -> void:
	if scene != "game":
		return
	if event is InputEventMouseMotion:
		if dragging:
			drag_distance += event.relative.length()
			world.pan(event.relative)
		else:
			_update_hover(_viewport_pointer(event.position))
	elif event is InputEventMouseButton:
		## <summary>换算到三维子视口像素坐标的鼠标位置。</summary>
		var pointer = _viewport_pointer(event.position)
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				dragging = true
				drag_distance = 0
				right_down = event.button_index == MOUSE_BUTTON_RIGHT
			else:
				dragging = false
				if right_down and drag_distance < 6:
					_cancel_build()
				right_down = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.zoom_at(-1, pointer)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.zoom_at(1, pointer)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			## <summary>当前待查询、占用或绘制的地块坐标。</summary>
			var cell = world.pick(pointer)
			if state.contains_cell(cell):
				_click_cell(cell)
	elif event is InputEventPanGesture:
		world.pan(event.delta * -18)
	elif event is InputEventMagnifyGesture:
		world.zoom_at(-log(event.factor) / log(1.12), _viewport_pointer(event.position))

## <summary>鼠标离开地图时清除幽灵预览并恢复固定地块信息。</summary>
## <returns>无返回值；重置悬停坐标。</returns>
func _map_exited() -> void:
	hovered = Vector2i(-1, -1)
	world.preview(hovered, "", 0)
	world.select(selected)
	hud.inspect(state, selected, chosen, rotation_value)

## <summary>根据射线命中更新悬停地块、有效性预览和地块检查器。</summary>
## <param name="pointer">相对三维子视口左上角的二维像素坐标。</param>
## <returns>无返回值；命中格未改变时直接返回以减少重绘。</returns>
func _update_hover(pointer: Vector2) -> void:
	## <summary>当前待查询、占用或绘制的地块坐标。</summary>
	var cell = world.pick(pointer)
	if cell == hovered:
		return
	hovered = cell
	world.preview(hovered, chosen, rotation_value)
	world.select(hovered if state.contains_cell(hovered) else selected)
	hud.inspect(state, hovered if state.contains_cell(hovered) else selected, chosen, rotation_value)

## <summary>选择地块；存在待建类型时请求模型建造，成功后同步三维世界。</summary>
## <param name="cell">要查询或操作的六边形坐标（列、行），从 0 开始。</param>
## <returns>无返回值；失败显示规则原因，成功按连续建造开关保留或清除类型。</returns>
func _click_cell(cell: Vector2i) -> void:
	selected = cell
	if chosen.is_empty():
		audio.play("click")
	else:
		## <summary>规则或文件操作返回的错误说明。</summary>
		var error = state.place(cell, chosen, rotation_value)
		if not error.is_empty():
			hud.notify(error, true)
			audio.play("error")
		else:
			world.spawn_building(cell, true)
			hud.notify("%s建造中 · 材料正在运抵" % BelfortState.CATALOG[chosen].name if dynamic_effects else "%s已建成" % BelfortState.CATALOG[chosen].name)
			if not dynamic_effects:
				audio.play("build")
			if not hud.continuous.button_pressed:
				chosen = ""
	_refresh()
	world.press_cell(cell)

## <summary>处理快捷键；过滤自动重复，菜单和文本输入优先消费事件。</summary>
## <param name="event">引擎传入的输入事件，可包含按键、鼠标或触控板信息。</param>
## <returns>无返回值；Esc 按取消建造、暂停、返回的层级工作。</returns>
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if file_dialog != null and file_dialog.visible:
		return
	if event.keycode == KEY_F11:
		_setting("fullscreen", DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if event.keycode == KEY_ESCAPE:
		if scene == "game":
			if not chosen.is_empty(): _cancel_build()
			else: _action("pause")
		elif scene == "pause": _action("resume")
		elif scene == "settings": _action("back")
		elif scene == "factions": _show_menu()
		get_viewport().set_input_as_handled()
		return
	if scene != "game":
		return
	## <summary>是否按下 macOS Command 或其他平台 Ctrl 修饰键。</summary>
	var command = event.ctrl_pressed or event.meta_pressed
	if command:
		match event.keycode:
			KEY_S: _action("save")
			KEY_O: _action("load")
			KEY_Z: _action("undo")
	else:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6: _choose(BelfortState.ORDER[event.keycode - KEY_1])
			KEY_R: _action("rotate")
			KEY_Q: world.target_yaw -= PI / 6
			KEY_E: world.target_yaw += PI / 6
			KEY_F: world.home()
			KEY_ENTER: _action("next_turn")

## <summary>切换待建建筑类型并重置方向；再次选择同类型会取消。</summary>
## <param name="type">内部建筑或资源键，例如 house、farm、gold；具体允许值见对应规则表。</param>
## <returns>无返回值；仅游戏状态可进入建造模式。</returns>
func _choose(type: String) -> void:
	if scene != "game":
		return
	chosen = "" if chosen == type else type
	rotation_value = 0
	audio.play("click")
	_refresh()

## <summary>取消建造模式和当前拖动，刷新预览与提示。</summary>
## <returns>无返回值；不改变已经建成的建筑。</returns>
func _cancel_build() -> void:
	chosen = ""
	dragging = false
	_refresh()

## <summary>将规则数据同步到界面、选中轮廓和建造预览。</summary>
## <returns>无返回值；不重新创建整张地图。</returns>
func _refresh() -> void:
	hud.refresh(state, chosen, rotation_value)
	hud.inspect(state, hovered if state.contains_cell(hovered) else selected, chosen, rotation_value)
	world.select(selected)
	world.preview(hovered, chosen, rotation_value)

## <summary>用已确认的势力建立新聚落，重置规则、镜头及交互状态。</summary>
## <param name="faction">玩家已确认的势力字典，包含 id、name、color、description。</param>
## <returns>无返回值；旧会话存在时先自动保存，保存失败则保留旧会话。</returns>
func _start_game(faction: Dictionary) -> void:
	if session_started and not _save(AUTO_PATH, false):
		return
	state.faction = faction
	state.reset()
	session_started = true
	scene = "game"
	chosen = ""
	selected = Vector2i(10, 8)
	hovered = Vector2i(-1, -1)
	hud.hide_overlay()
	world.rebuild(state)
	world.home()
	_refresh()
	audio.play("turn")
	hud.notify("欢迎抵达贝尔福。选择建筑，连接市政厅扩展聚落。")

## <summary>切换到主菜单并清除待建模式，保留当前会话以便继续。</summary>
## <returns>无返回值；动态决定是否显示继续按钮。</returns>
func _show_menu() -> void:
	scene = "menu"
	chosen = ""
	dragging = false
	world.preview(Vector2i(-1, -1), "", 0)
	hud.show_menu(FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(AUTO_PATH), session_started)

## <summary>统一分派菜单、建造工具、存档和回合操作。</summary>
## <param name="action">按钮或菜单操作标识，例如 save、pause、next_turn。</param>
## <returns>无返回值；回合操作有防连击，失败保存不会直接退出游戏。</returns>
func _action(action: String) -> void:
	if action != "next_turn":
		audio.play("click")
	match action:
		"click": pass
		"factions":
			scene = "factions"
			hud.show_factions(state.faction)
		"resume":
			if session_started:
				scene = "game"
				hud.hide_overlay()
				_refresh()
		"pause":
			if scene == "game":
				scene = "pause"
				dragging = false
				hud.show_pause()
		"settings":
			return_scene = scene
			scene = "settings"
			hud.show_settings(audio.volume, audio.muted, dynamic_effects, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		"back":
			scene = return_scene
			if scene == "game": hud.hide_overlay()
			elif scene == "pause": hud.show_pause()
			else: _show_menu()
		"menu":
			if not session_started or _save(AUTO_PATH, false):
				_show_menu()
		"next_turn":
			if scene != "game" or Time.get_ticks_msec() - last_turn_msec < 300:
				return
			last_turn_msec = Time.get_ticks_msec()
			## <summary>当前函数构造并最终返回的对象、数值或结果字典。</summary>
			var result = state.next_turn()
			_refresh()
			if _save(AUTO_PATH, false):
				hud.notify("第 %d 回合 · 已自动保存%s" % [state.turn, " · 粮食不足，人口停止增长" if result.starving else ""])
			audio.play("error" if result.starving else "turn")
		"rotate":
			if scene == "game" and not chosen.is_empty():
				rotation_value = (rotation_value + 1) % 6
				_refresh()
		"undo":
			if scene != "game": return
			## <summary>建筑锚点坐标，即记录建筑的主地块。</summary>
			var anchor = state.undo()
			if state.contains_cell(anchor):
				world.remove_building(anchor)
				audio.play("undo")
				hud.notify("已撤销建造，材料全部退还")
				_refresh()
		"save":
			if session_started: _save(SAVE_PATH, true)
		"save_as":
			if session_started: _open_file_dialog(true)
		"load": _open_file_dialog(false)
		"continue":
			## <summary>本次读写的完整文件路径。</summary>
			var path = SAVE_PATH
			if FileAccess.file_exists(AUTO_PATH) and (not FileAccess.file_exists(SAVE_PATH) or FileAccess.get_modified_time(AUTO_PATH) > FileAccess.get_modified_time(SAVE_PATH)):
				path = AUTO_PATH
			_load_file(path)
		"save_quit":
			if _save(SAVE_PATH, true):
				_save_preferences()
				get_tree().quit()
		"quit":
			if session_started and not _save(AUTO_PATH, false): return
			_save_preferences()
			get_tree().quit()

## <summary>调用模型安全保存，并根据请求显示反馈及播放音效。</summary>
## <param name="path">待读写文件路径，可使用 user:// 或绝对路径。</param>
## <param name="feedback">保存成功后是否显示提示和播放音效。</param>
## <returns>布尔值，true 表示成功，false 表示保存失败。</returns>
func _save(path: String, feedback: bool) -> bool:
	## <summary>规则或文件操作返回的错误说明。</summary>
	var error = state.save_to(path)
	if error != OK:
		hud.notify("保存失败：" + error_string(error), true)
		audio.play("error")
		return false
	if feedback:
		hud.notify("进度已保存 · " + path.get_file())
		audio.play("save")
	return true

## <summary>读取和解析 JSON 后交给模型校验，成功后恢复三维世界与界面。</summary>
## <param name="path">待读写文件路径，可使用 user:// 或绝对路径。</param>
## <returns>无返回值；语法或规则失败时保留当前游戏，最大接受 8 MiB 文件。</returns>
func _load_file(path: String) -> void:
	## <summary>当前打开的文件访问对象。</summary>
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		hud.notify("无法读取文件：" + error_string(FileAccess.get_open_error()), true)
		audio.play("error")
		return
	if file.get_length() > 8 * 1024 * 1024:
		hud.notify("存档过大，读取已取消", true)
		return
	## <summary>负责检测 JSON 格式的解析对象。</summary>
	var parser = JSON.new()
	## <summary>JSON 语法解析返回的错误码。</summary>
	var parse_error = parser.parse(file.get_as_text())
	if parse_error != OK:
		hud.notify("JSON 格式错误，当前进度已保留", true)
		audio.play("error")
		return
	## <summary>规则或文件操作返回的错误说明。</summary>
	var error = state.load_data(parser.data)
	if not error.is_empty():
		hud.notify("读取失败：" + error, true)
		audio.play("error")
		return
	session_started = true
	scene = "game"
	chosen = ""
	selected = Vector2i(10, 8)
	hovered = Vector2i(-1, -1)
	hud.hide_overlay()
	world.rebuild(state)
	world.home()
	_refresh()
	hud.notify("存档读取成功 · 第 %d 回合" % state.turn)
	audio.play("save")

## <summary>打开导入或另存 JSON 窗口，并连接对应文件选择回调。</summary>
## <param name="saving">true 打开保存窗口；false 打开读取窗口。</param>
## <returns>无返回值；文件窗口可见时地图快捷键暂不处理。</returns>
func _open_file_dialog(saving: bool) -> void:
	if file_dialog != null:
		file_dialog.queue_free()
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.json ; 贝尔福存档"])
	file_dialog.title = "另存为贝尔福存档" if saving else "读取 / 导入原版存档"
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if saving:
		file_dialog.current_file = "belfort_save.json"
		## <summary>信号触发后执行局部回调，将当前控件或动画事件转发给所属系统。</summary>
		## <param name="path">待读写文件路径，可使用 user:// 或绝对路径。</param>
		## <returns>无返回值；通过信号或对象属性产生效果。</returns>
		file_dialog.file_selected.connect(func(path): _save(path, true))
	else:
		file_dialog.file_selected.connect(_load_file)
	hud.add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

## <summary>应用单个设置项，并立即保存偏好配置。</summary>
## <param name="key">图标资源名、资源内部键或设置项内部名称，按调用方法决定。</param>
## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
## <returns>无返回值；支持音量、静音、动态效果和全屏。</returns>
func _setting(key: String, value: Variant) -> void:
	match key:
		"volume": audio.set_volume(float(value))
		"muted": audio.muted = bool(value)
		"effects":
			dynamic_effects = bool(value)
			hud.set_dynamic(dynamic_effects)
			world.set_dynamic(dynamic_effects)
			for backdrop in hud.overlay.find_children("*", "Control", true, false):
				if backdrop is BelfortFactionBackdrop:
					backdrop.animation_enabled = dynamic_effects
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_preferences()

## <summary>把声音与显示偏好写入用户数据目录。</summary>
## <returns>无返回值；只保存设置，不保存地图进度。</returns>
func _save_preferences() -> void:
	## <summary>读取和写入偏好的 ConfigFile 对象。</summary>
	var config = ConfigFile.new()
	config.set_value("audio", "volume", audio.volume)
	config.set_value("audio", "muted", audio.muted)
	config.set_value("display", "effects", dynamic_effects)
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save(PREFS_PATH)

## <summary>读取本地偏好并应用到声音、地图动画和显示模式。</summary>
## <returns>无返回值；配置不存在时保留默认值。</returns>
func _load_preferences() -> void:
	## <summary>读取和写入偏好的 ConfigFile 对象。</summary>
	var config = ConfigFile.new()
	if config.load(PREFS_PATH) != OK:
		return
	audio.set_volume(float(config.get_value("audio", "volume", 0.65)))
	audio.muted = bool(config.get_value("audio", "muted", false))
	dynamic_effects = bool(config.get_value("display", "effects", true))
	world.set_dynamic(dynamic_effects)
	hud.set_dynamic(dynamic_effects)
	if config.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
