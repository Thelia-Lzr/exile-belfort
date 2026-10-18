# 贡献说明

贡献范围为本仓库的 Godot 2.5D 游戏工程。开始前请阅读 [README](README.md)、[Agent 约定](AGENTS.md) 和 [文档索引](docs/README.md)。人工贡献者同样遵循其中的代码注释、设计风格和文档要求。

## 分支与 PR

**所有改动必须通过 Pull Request（PR）进入主分支。不要直接推送主分支，也不要强制覆盖主分支历史。** 该约定同样适用于文档、资源、紧急修复和 Agent 提交。

1. 从最新默认分支建立独立分支，例如 `docs/project-guidelines`、`feat/building-preview` 或 `fix/save-validation`。下例假设默认分支为 `main`；若不同请替换。
2. 没有仓库写权限时，先 Fork，在自己的分支提交后向原仓库提出 PR。
3. 每个 PR 聚焦一个目的，提交前检查 diff，不混入编辑器缓存、用户存档及无关改动。
4. 推送工作分支并创建 PR，说明具体行为变化、相关文档与验证结果；修复问题时关联 Issue。
5. 由维护者审核并通过 GitHub 合并。若有冲突，在工作分支解决后重新验证，不绕过 PR 直接推送主分支。

在仓库根目录执行：

```bash
git switch main
git pull --ff-only origin main
git switch -c docs/project-guidelines
# 编辑并检查改动，然后明确选择文件提交
git add README.md AGENTS.md CONTRIBUTING.md CHANGELOG.md docs/
git commit -m "docs: 补齐项目与协作说明"
git push -u origin docs/project-guidelines
```

随后在 GitHub 创建 PR；安装并登录 GitHub CLI 的贡献者也可使用 `gh pr create`。工作区已有改动时先妥善保存，不直接照抄切换分支命令。

本文件定义协作规则；它本身不会在 GitHub 上启用分支保护。

## 开发与验证

使用 Godot 4.7 系列，当前记录的本机验证版本为 4.7.2。导入根目录 `project.godot`，按 F5 运行。以下命令在**仓库根目录**执行，`godot` 应指向你的 Godot 可执行文件；macOS 可使用 `/Applications/Godot.app/Contents/MacOS/Godot` 的完整路径。

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_model.gd
godot --headless --path . --script res://tests/test_scene.gd
```

| 改动范围 | 必须检查 |
|---|---|
| 纯文档 | 相对链接、源码路径、命令、实际功能说明；`git diff --check` |
| 规则、经济、占地、存档 | 导入检查、规则测试；跨模块变化同时运行场景测试 |
| 输入、UI、模型、动画、音效 | 导入检查、场景测试；影响规则时同时运行规则测试 |
| 视觉与动效 | 以上相关检查，以及实际渲染后目视检查中文、遮挡、拾取和关闭动态效果 |

重新导出视觉截图时执行以下命令，需要图形环境，不能添加 `--headless`：

```bash
godot --path . --script res://tests/capture_visuals.gd
```

截图写入 `artifacts/hex7-ui/`。只提交与改动相关且经检查的截图；音效变更还需实际试听。测试失败时记录失败原因；无法运行时如实写明环境和未验证项，不填“通过”。

## 代码、资源与文档

- GDScript 格式与中文 XML 注释遵循 [AGENTS.md](AGENTS.md)，模块边界见 [架构](docs/architecture.md)。
- UI、模型和动态效果沿用 [设计风格](docs/design-style.md)，引入外部依赖或素材时说明必要性、来源及许可。
- 每个 PR 更新 `CHANGELOG.md` 的 `Unreleased`，并同步受影响的 README 或专题文档。
- `.godot/` 为本机导入缓存，不入库；`.gd.uid` 和资源旁的 `.import` 元数据应保留。不要提交私人存档、账号凭据、临时日志或无关生成文件。
- 项目尚未声明开源许可证；提交贡献不代表可以任意复制、分发项目或第三方素材。许可证由维护者另行决定。

## PR 提交前

- [ ] 使用独立分支，目标是仓库默认分支。
- [ ] 改动范围清晰，源码、注释、文档与 CHANGELOG 一致。
- [ ] 完成相应检查，并在 PR 中写出命令、结果及未验证项。
- [ ] 视觉变化提供截图，涉及存档变化说明兼容策略。
- [ ] diff 不包含缓存、私人数据、密钥或无关改动。
