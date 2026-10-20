## <summary>用实际渲染器导出地图、工坊动画和各 UI 页面的截图，用于视觉复核。</summary>
extends SceneTree

var game: BelfortGame
const OUTPUT = "res://artifacts/hex7-ui"

func _initialize() -> void:
	call_deferred("run")

func capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + file_name + ".png")

## <summary>在控件实际布局中心发送鼠标事件，验证点击能到达按钮。</summary>
## <param name="control">已经完成布局的可点击控件。</param>
func click(control: Control) -> void:
	var point = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
		await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.hud.set_dynamic(true)
	game._setting("effects", true)
	await create_timer(0.7).timeout
	await capture("01-menu")
	var window_size = root.size
	root.size = Vector2i(1100, 720)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	assert(root.size == Vector2i(1100, 720), "minimum window size applied")
	await capture("01-menu-small")
	await click(game.hud.find_child("StartButton", true, false))
	assert(game.scene == "factions")
	await create_timer(0.7).timeout
	await capture("02-factions-small")
	root.size = window_size
	await create_timer(0.4).timeout
	await capture("02-factions")
	await click(game.hud.faction_cards[2])
	assert(game.hud.faction_draft.id == "guild")
	await click(game.hud.find_child("ConfirmFaction", true, false))
	assert(game.scene == "game" and game.state.faction.id == "guild")
	await create_timer(1.2).timeout
	game.hud.notice_panel.hide()
	await capture("03-hex-map")
	game.world.target_zoom = 19.0
	await create_timer(0.7).timeout
	var cell = Vector2i(11, 8)
	game.state.terrain[8][11] = "grass"
	assert(game.state.place(cell, "workshop", 0).is_empty())
	game.world.spawn_building(cell, true)
	game._refresh()
	var workshop = game.world.building_nodes[cell].get_child(0)
	await create_timer(0.8).timeout
	await capture("04-workshop-air")
	await workshop.workshop_slam
	await create_timer(0.22).timeout
	await capture("05-workshop-wave")
	await create_timer(1.5).timeout
	await capture("06-workshop-complete")
	game._action("pause")
	await create_timer(0.6).timeout
	await capture("07-pause")
	game._action("settings")
	await create_timer(0.6).timeout
	await capture("08-settings")
	game._open_file_dialog(false)
	await create_timer(0.6).timeout
	# 存档窗口使用独立 Window，检查实际渲染而非只截父窗口。
	await RenderingServer.frame_post_draw
	game.file_dialog.get_texture().get_image().save_png(OUTPUT + "/09-file-dialog.png")
	game.file_dialog.hide()
	game.queue_free()
	await process_frame
	print("VISUAL FLOW PASSED: start / faction card / confirm mouse clicks")
	quit()
