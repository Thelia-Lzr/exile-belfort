## <summary>音效管理器。八个播放通道允许音效重叠，落地声采用节流避免过密，并支持音量和静音。</summary>
## <remarks>GDScript 使用 ## 保存文档注释。此处采用 XML 标签帮助初学者识别用途、参数与返回值；Godot 不会像 C# 一样原生生成 XML 文档。</remarks>
class_name BelfortAudio
extends Node

## <summary>音效名称到 AudioStreamWAV 文件的映射。</summary>
const CLIPS = {
	"click": preload("res://assets/audio/click.wav"), "error": preload("res://assets/audio/error.wav"),
	"land": preload("res://assets/audio/land.wav"), "build": preload("res://assets/audio/build.wav"),
	"turn": preload("res://assets/audio/turn.wav"), "save": preload("res://assets/audio/save.wav"), "undo": preload("res://assets/audio/undo.wav")
}
## <summary>复用的音效播放通道数组。</summary>
var players: Array = []
## <summary>线性音量，范围 0 到 1。</summary>
var volume = 0.65
## <summary>是否静音。</summary>
var muted = false
## <summary>最近一次材料落地音效的时间，单位秒。</summary>
var last_impact = -1.0

## <summary>创建八个可重叠播放的音效通道，供后续 play 调用复用。</summary>
## <returns>无返回值；由 Godot 场景树生命周期自动调用。</returns>
func _ready() -> void:
	for index in range(8):
		## <summary>当前被选中的 AudioStreamPlayer 通道。</summary>
		var player = AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

## <summary>在空闲音效通道中播放指定提示，落地声受时间节流保护。</summary>
## <param name="cue">音效内部键，如 click、land、build、turn、error、save、undo。</param>
## <returns>无返回值；静音、零音量或未知音效会直接忽略。</returns>
func play(cue: String) -> void:
	if muted or volume <= 0 or not CLIPS.has(cue):
		return
	if cue == "land":
		## <summary>当前引擎运行时间，用于节流或防连击。</summary>
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_impact < 0.09:
			return
		last_impact = now
	for player in players:
		if not player.playing:
			player.stream = CLIPS[cue]
			player.volume_db = linear_to_db(volume) - (5.0 if cue == "land" else 0.0)
			player.pitch_scale = randf_range(0.9, 1.1) if cue == "land" else 1.0
			player.play()
			return

## <summary>限制并应用线性音量，将它换算成音频通道使用的分贝。</summary>
## <param name="value">要应用或检查的值；设置回调中的类型由 key 决定。</param>
## <returns>无返回值；修改音量并更新现有播放通道。</returns>
func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	for player in players:
		player.volume_db = linear_to_db(maxf(volume, 0.0001))

## <summary>音频管理器退出场景树前停止播放并释放流引用，避免退出时残留播放对象。</summary>
## <returns>无返回值；由 Godot 在节点移出场景树时调用。</returns>
func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null
