## <summary>独立势力选择界面；草稿确认前不会改动当前聚落。</summary>
extends BelfortFrontScreen

## <summary>初始身份草稿；控制器可在入树前提供当前势力，独立预览默认使用流亡者。</summary>
var initial_faction: Dictionary = FACTIONS[0].duplicate()

## <summary>在全屏页面内复用四势力与自定义档案的既有编辑逻辑。</summary>
func _make_content() -> void:
	super._make_content()
	label(page, "02 / 选择同行者", 16, GOLD)
	make_faction_content(page, initial_faction)
	faction_cards[0].grab_focus()
