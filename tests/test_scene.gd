## <summary>无窗口场景集成测试入口。验证真实场景中的界面流程、射线拾取、建筑与资源模型、动画及音效导入。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
extends SceneTree

## <summary>当前测试已执行的检查数量。</summary>
var checks = 0

## <summary>测试脚本的 SceneTree 初始化入口，将测试延迟到场景树可用后执行。</summary>
## <returns>无返回值；通过 call_deferred 调用 run。</returns>
func _initialize() -> void:
	call_deferred("run")

## <summary>累加检查次数；条件失败时记录错误并以非零状态结束。</summary>
## <param name="condition">本次检查应满足的布尔表达式。</param>
## <param name="message">显示的中文反馈或测试失败说明。</param>
## <returns>无返回值；成功继续执行后续检查。</returns>
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAILED: " + message)
		quit(1)
		assert(condition, message)

## <summary>执行当前测试脚本中的规则或真实场景集成用例。</summary>
## <returns>无返回值；全部通过时输出检查数并以状态 0 退出。</returns>
func run() -> void:
	## <summary>集成测试中的真实游戏控制器实例。</summary>
	var game: BelfortGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.hud.scene_file_path == "res://scenes/start_menu.tscn" and game.scene == "menu", "standalone start scene")
	check(game.world == null and game.hud.map_container == null and not game.hud.overlay.visible, "start has no map or modal")
	check(game.hud.find_child("GameLogo", true, false).texture != null, "original logo imported")
	game.hud.action_requested.emit("settings")
	game._setting("effects", false)
	check(not game.hud.dynamic_effects and game.world == null, "settings work before world exists")
	game._action("back")
	game._load_file("user://missing-startup-test.json")
	check(game.scene == "menu" and game.hud.notice_panel.visible and game.world == null, "failed load stays on start with visible reason")
	game.hud.find_child("StartButton", true, false).pressed.emit()
	await process_frame
	check(game.hud.scene_file_path == "res://scenes/faction_selection.tscn", "start signal enters separate faction scene")
	check(game.hud.faction_cards.size() == 4 and not game.hud.overlay.visible and game.world == null, "four factions without modal or background map")
	game.hud.faction_cards[2].pressed.emit()
	check(game.hud.faction_draft.id == "guild" and game.state.faction.id != "guild", "selection changes draft only")
	game.hud.faction_name.text = "新贝尔福工匠"
	game.hud.faction_description.text = "在边地重建家园的工匠。"
	game.hud.find_child("ConfirmFaction", true, false).pressed.emit()
	await process_frame
	await physics_frame
	check(game.scene == "game" and game.hud.scene_file_path == "res://scenes/game.tscn" and not game.hud.overlay.visible, "confirmation enters independent game scene")
	check(game.state.faction.id == "guild" and game.state.faction.name == "新贝尔福工匠", "confirmed custom identity reaches model")
	check(not game.world.dynamic_effects, "game inherits effects preference")
	game._setting("effects", true)
	## <summary>射线起点或测试中的市政厅坐标。</summary>
	var origin = Vector2i(10, 8)
	## <summary>射线投影坐标或模型局部位置。</summary>
	var point = game.world.camera.unproject_position(BelfortState.cell_position(origin))
	check(game.world.pick(point) == origin, "ray picking selects original town")
	## <summary>地块网格的法线数组，用于检查顶面朝向。</summary>
	var normals = game.world.hex_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(normals[0].y > 0.99, "hex top faces upward")
	var vertices = game.world.hex_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(absf(normals[9].y) < 0.001 and normals[9].dot(vertices[9]) > 0.5, "hex side faces outward with hard planar normals")
	check(normals[9].dot(normals[27]) < 0.8, "adjacent hex walls keep sharp corners")
	## <summary>建造预览轮廓的法线数组。</summary>
	var ring_normals = game.world.ring_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(ring_normals[0].y > 0.99, "preview outline faces upward")
	check(game.world.tile_nodes.size() == 169, "radius seven hex has an independent body per cell")
	check(not game.world.tile_nodes.has(Vector2i(0, 0)), "rectangle corners have no hidden collision")
	check(game.world.map_root.find_child("MapPlinth", true, false) == null, "rectangular base removed")
	## <summary>集成测试中被点击的独立六边形地块对象。</summary>
	var pressed_tile = game.world.tile_nodes[origin]
	## <summary>测试中地块点击前的原始高度。</summary>
	var resting_y = pressed_tile.position.y
	game.world.press_cell(origin)
	await create_timer(0.11).timeout
	check(pressed_tile.position.y < resting_y - 0.08, "tile presses downward")
	game.world.press_cell(origin)
	await create_timer(0.4).timeout
	check(is_equal_approx(pressed_tile.position.y, resting_y), "repeated press returns to original height")
	game.world.set_dynamic(false)
	game.world.press_cell(origin)
	await create_timer(0.11).timeout
	check(is_equal_approx(pressed_tile.position.y, resting_y), "reduced motion disables tile press")
	game.world.set_dynamic(true)
	check(game.hud.next_button.has_meta("tactical_chrome"), "turn button uses shared tactical decoration")
	check(game.hud.build_buttons.workshop.has_meta("tactical_chrome"), "build cards use shared tactical decoration")

	for type in BelfortWorld.RESOURCE_SCENES:
		## <summary>当前测试的资源模型实例。</summary>
		var resource = BelfortWorld.RESOURCE_SCENES[type].instantiate()
		game.world.add_child(resource)
		check(resource.geometry.get_child_count() > 0, "3D resource model " + type)
		resource.queue_free()
	## <summary>集成测试中需要检查的所有建筑实例。</summary>
	var visuals: Array = []
	for type in BelfortWorld.BUILDING_SCENES:
		## <summary>一座建筑的 BelfortBuildingVisual 实例。</summary>
		var visual: BelfortBuildingVisual = BelfortWorld.BUILDING_SCENES[type].instantiate()
		game.world.add_child(visual)
		check(visual.animated_parts.size() > 0, "post-build animated parts " + type)
		visual.construct()
		check(visual.constructing, "material drop starts " + type)
		visuals.append(visual)
	await create_timer(2.2).timeout
	for visual in visuals:
		check(not visual.constructing, "construction completes " + visual.kind)
		## <summary>测试中用于观察运动的第一个动画网格。</summary>
		var first = visual.animated_parts[0]
		## <summary>动画测试中变化前的姿态。</summary>
		var initial = first.transform
		await create_timer(0.15).timeout
		check(first.transform != initial, "idle animation moves " + visual.kind)
		visual.set_dynamic(false)
		## <summary>关闭动画后的固定姿态快照。</summary>
		var stopped = first.transform
		await create_timer(0.1).timeout
		check(first.transform == stopped, "reduced motion stops idle " + visual.kind)
		visual.queue_free()
	game._action("pause")
	check(game.scene == "pause" and game.hud.overlay.visible, "pause opens modal")
	game._action("resume")
	check(game.scene == "game" and not game.hud.overlay.visible, "resume closes modal")
	game._choose("house")
	game._action("rotate")
	check(game.rotation_value == 1, "rotate uses sixty-degree steps")
	game._cancel_build()
	check(game.chosen.is_empty(), "cancel build clears mode")
	game.hud.build_buttons["farm"].pressed.emit()
	check(game.chosen == "farm", "build button signal reaches controller")
	## <summary>通过实际地图输入测试放置农场的目标地块。</summary>
	var farm_cell = Vector2i(11, 8)
	## <summary>农场目标格投影到三维子视口后的坐标。</summary>
	var farm_point = game.world.camera.unproject_position(BelfortState.cell_position(farm_cell))
	## <summary>模拟玩家左键点击的 InputEventMouseButton 事件。</summary>
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = farm_point * game.hud.map_container.size / Vector2(game.map_viewport.size)
	## <summary>通过界面建造前的木材数量快照。</summary>
	var wood_before = game.state.resources.wood
	game._map_input(click_event)
	check(game.state.occupied.has(farm_cell) and game.state.resources.wood == wood_before - 9, "viewport coordinate input places real farm")
	check(game.world.building_nodes.has(farm_cell), "successful placement creates 3D building")
	game._action("undo")
	check(not game.state.occupied.has(farm_cell) and not game.world.building_nodes.has(farm_cell), "undo removes animated building")
	check(game.state.resources.wood == wood_before, "controller undo refunds all wood")
	for cell in [Vector2i(3, 8), Vector2i(17, 8), Vector2i(13, 3), Vector2i(10, 8)]:
		## <summary>测试地块中心投影到屏幕后的二维坐标。</summary>
		var screen_point = game.world.camera.unproject_position(BelfortState.cell_position(cell) + Vector3(0, game.world.elevation(cell), 0))
		check(game.world.pick(screen_point) == cell, "expanded hex picking " + str(cell))
	## <summary>测试以鼠标位置为中心缩放的子视口坐标。</summary>
	var zoom_pointer = Vector2(game.map_viewport.size) * Vector2(0.35, 0.4)
	## <summary>缩放开始前鼠标指向的世界平面位置。</summary>
	var zoom_anchor = game.world.ground_point(zoom_pointer)
	game.world.zoom_at(-1, zoom_pointer)
	check(game.world.ground_point(zoom_pointer).distance_to(zoom_anchor) < 0.001, "zoom remains anchored under cursor")
	# 真实工坊触地信号驱动地图波纹，空中组装期间不能提前触发。
	game.state.terrain[8][11] = "grass"
	check(game.state.place(farm_cell, "workshop", 0).is_empty(), "place workshop for impact integration")
	game.world.spawn_building(farm_cell, true)
	var workshop: BelfortBuildingVisual = game.world.building_nodes[farm_cell].get_child(0)
	var slams: Array = []
	workshop.workshop_slam.connect(func(): slams.append(true))
	await create_timer(0.75).timeout
	check(workshop.geometry.position.y > 3.5 and slams.is_empty(), "workshop assembles above ground without early impact")
	await workshop.workshop_slam
	check(slams.size() == 1, "whole workshop produces exactly one ground impact")
	await create_timer(0.08).timeout
	check(game.world.tile_nodes[farm_cell].position.y > game.world.elevation(farm_cell) + 0.4, "single wave uses doubled amplitude")
	check(is_equal_approx(game.world.tile_nodes[Vector2i(14, 8)].position.y, game.world.elevation(Vector2i(14, 8))), "distant tile waits for wave arrival")
	await create_timer(0.25).timeout
	check(not is_equal_approx(game.world.tile_nodes[Vector2i(14, 8)].position.y, game.world.elevation(Vector2i(14, 8))), "wave reaches distant tile after delay")
	var town_visual = game.world.building_nodes[origin].get_child(0)
	check(is_equal_approx(town_visual.position.y - 0.02, game.world.tile_nodes[origin].position.y), "existing building follows the tile wave")
	await create_timer(1.6).timeout
	for cell in game.world.tile_nodes:
		check(is_equal_approx(game.world.tile_nodes[cell].position.y, game.world.elevation(cell)), "wave restores tile height " + str(cell))
	check(not workshop.constructing and is_zero_approx(workshop.geometry.position.y), "workshop settles after slam")
	game.world.impact_wave(farm_cell)
	await create_timer(0.1).timeout
	game.world.set_dynamic(false)
	for cell in game.world.tile_nodes:
		check(is_equal_approx(game.world.tile_nodes[cell].position.y, game.world.elevation(cell)), "turning effects off restores active wave " + str(cell))
	game.world.set_dynamic(true)
	# 在空中拼装时关闭动态效果，应直接显示完整静止建筑。
	workshop.construct()
	await create_timer(0.2).timeout
	workshop.set_dynamic(false)
	check(not workshop.constructing and is_zero_approx(workshop.geometry.position.y), "reduced motion settles unfinished airborne workshop")
	game.hud.set_dynamic(false)
	for chrome in game.hud.chromes:
		if is_instance_valid(chrome):
			check(not chrome.animation_enabled, "reduced motion disables tactical UI")

	for cue in BelfortAudio.CLIPS:
		check(BelfortAudio.CLIPS[cue].get_length() > 0, "audio clip imported " + cue)
	# 在有会话的情况下经过势力返回与继续，检查地图复用、草稿隔离及读档。
	var retained_world = game.world
	var retained_turn = game.state.turn
	game._action("menu")
	check(game.scene == "menu" and not game.game_hud.visible, "return to independent start")
	check(game.game_hud.process_mode == Node.PROCESS_MODE_DISABLED and game.map_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden gameplay stops processing and rendering")
	game._action("factions")
	game.hud.faction_cards[3].pressed.emit()
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	check(game.scene == "menu" and game.state.faction.id == "guild", "escape abandons faction draft")
	game._action("resume")
	check(game.world == retained_world and game.state.turn == retained_turn and game.hud.visible, "resume restores existing world and rules")
	game._action("menu")
	game._action("continue")
	check(game.scene == "game" and game.state.faction.name == "新贝尔福工匠", "continue loads auto save from start")
	# 验证冷启动读档无需先经过势力确认。
	var cold_game: BelfortGame = load("res://scenes/main.tscn").instantiate()
	root.add_child(cold_game)
	cold_game._action("continue")
	check(cold_game.scene == "game" and cold_game.world != null and cold_game.state.faction.id == "guild", "cold continue creates gameplay directly after validation")
	cold_game.queue_free()
	print("SCENE TESTS PASSED: ", checks)
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit(0)
