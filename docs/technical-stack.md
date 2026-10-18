# 技术栈与工程组织

## 运行环境

| 项目 | 当前实现 |
|---|---|
| 引擎 | Godot 4.7 系列，`project.godot` 声明 `4.7`；本机已验证 4.7.2 |
| 游戏逻辑 | GDScript，无 C# / .NET 依赖 |
| 渲染 | `gl_compatibility`，三维正交镜头，MSAA 2× |
| 界面 | Godot Control、容器、Theme、StyleBoxFlat 与程序绘制装饰 |
| 存档 | JSON；偏好设置使用 ConfigFile，数据写入 `user://` |
| 模型 | 程序化基础网格，通过 `.tscn` 封装建筑和资源 |
| 图标与声音 | 仓库内 SVG 与 WAV，运行时不下载外部素材 |
| 字体 | SystemFont，依次尝试 PingFang SC、Heiti SC、Noto Sans CJK SC、Microsoft YaHei、Arial；需系统具备可显示中文的字体 |
| 开发辅助 | `tools/` 下 Python 标准库脚本，用于生成部分资源和初版注释；运行游戏不需要 Python |

当前窗口设计视口为 1440×900，默认窗口为 1280×800，最小窗口为 1100×720，使用 `canvas_items` 拉伸。主入口为 `scenes/main.tscn`，UI 和世界节点多数在运行时创建。

当前验证范围为 macOS / Apple Silicon / Compatibility。仓库尚无导出预设，不把 Windows、Linux、移动端或 Web 写为已验证发布平台。

## 目录

```text
project.godot          # 工程配置
scenes/main.tscn       # 主场景
scripts/              # 规则、流程、世界、模型、HUD、动画与音频
models/buildings/     # 市政厅和六种可建建筑的场景入口
models/resources/     # 金币、粮食、木材和石材场景入口
assets/icons/         # SVG 图标、旗帜和徽记
assets/audio/         # WAV 合成音效
data/original_map.json # 固定地形数据
tests/                # 规则、场景集成和渲染截图脚本
tools/                # 素材与注释开发辅助工具
previews/             # 已有预览截图
artifacts/hex7-ui/     # 视觉检查截图
docs/                 # 技术、设计和验证文档
```

`.godot/` 是本机导入与编辑器缓存，由 Godot 重建，不提交 Git。资源旁的 `.import` 保存导入设置，`.gd.uid` 保存脚本身份，应随资源提交以保持引用稳定。

## 数据与模块约束

规则数据以 `BelfortState` 为中心，建筑参数在 `CATALOG` 中定义。当前资源初值为金币 65、粮食 30、木材 65、石材 32，人口 5，回合 1。新地图显示市政厅周围七圈共 169 格，内部地形数组为 23×17；边界以 `contains_cell` 为准。

存档支持当前地图形状及已有 JSON 导入逻辑。调整字段或地图格式时必须明确旧存档处理方式；不要把存档数据耦合到动画播放进度。模块职责和事件流见 [架构](architecture.md)，实际检查命令见 [贡献说明](../CONTRIBUTING.md)。
