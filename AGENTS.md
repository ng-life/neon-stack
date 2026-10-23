# 项目协作指南

本文件适用于整个仓库。默认使用中文沟通、编写文档和界面文案，保留 Swift 标识符、配置键和命令的原文。

## 项目概况

Neon Stack 是原生 macOS 俄罗斯方块游戏，支持单人挑战和本地同屏双人对战。

- 使用 Swift 6、Swift Package Manager、SwiftUI、RealityKit、GameController 和 AVFoundation。
- 最低支持 macOS 15；Liquid Glass 使用 macOS 26 可用性检查，较早系统保留原生回退样式。
- SwiftPM 包和可执行产品名为 `NeonTetris`，应用显示名为 `Neon Stack`。
- 应用标识为 `com.nglife.neon-tetris`，应用包输出到 `dist/NeonTetris.app`。
- 当前构建脚本使用本地临时签名，不代表已完成正式签名或公证。

## 目录与职责

| 路径 | 职责 |
| --- | --- |
| `Sources/TetrisCore/` | 确定性棋盘规则、七袋序列、SRS、计分、攻击路由、倒计时和音频数据合成 |
| `Sources/NeonTetris/App/` | SwiftUI 场景、应用生命周期与启动入口 |
| `Sources/NeonTetris/Services/` | 对局状态、输入、手柄绑定、菜单导航、音频播放、成绩保存和诊断日志 |
| `Sources/NeonTetris/Views/` | 游戏菜单、设置、结果统计、RealityKit 场景与动效 |
| `Tests/TetrisCoreTests/` | 游戏规则与统计的确定性测试 |
| `Tests/NeonTetrisTests/` | 输入、菜单、持久化、真实音频播放器和表现层测试 |
| `Assets/` | 图标源图与生成的 ICNS |
| `script/` | 构建、运行、图标生成和实体手柄探测脚本 |
| `docs/` | Roadmap、手柄验收记录与崩溃排查说明 |

规则变更优先放入 `TetrisCore`。SwiftUI、RealityKit 和音频播放不得决定碰撞、计分或胜负。应用状态由 `@MainActor` 服务管理；视图调用服务接口，不复制规则或另建一套对局状态。

当前游戏内设置与 macOS 设置场景共用 `GameSettingsView` 和 `GameMenuSettings`。修改设置前检查实际调用入口，不将旧的 `SettingsView` 当作当前界面。

## 常用命令

在仓库根目录执行：

```sh
swift build
swift test
swift test --filter GameSessionTests
swift test --filter NavigationTests
swift test --filter ResultTests
xcrun swift-format format --in-place <修改的 Swift 文件>
git diff --check
```

运行脚本会先停止已有 `NeonTetris` 进程，包括 `--verify`、`--debug` 和日志模式。执行前检查是否有用户正在进行的对局；有对局时先完成构建和测试，保留当前进程，不直接运行会结束对局的脚本。

```sh
./script/build_and_run.sh             # 构建应用包并启动
./script/build_and_run.sh --verify    # 启动后检查进程
./script/build_and_run.sh --debug     # 使用 LLDB 启动
./script/build_and_run.sh --logs      # 查看进程日志
./script/build_and_run.sh --telemetry # 查看项目 OSLog 日志
./script/build_icon.sh               # 从 Assets/AppIcon.png 生成图标
swift script/controller_probe.swift  # 探测真实手柄设备
```

`--verify` 只检查进程存在，不能代替真实窗口、游戏交互或手柄验收。新应用包已构建也不代表运行中的旧进程已经加载新代码。

## 游戏与交互约定

- 主菜单 → 开始游戏 → 单人／双人模式选择 → 3、2、1 倒计时 → 游戏。
- 倒计时期间屏蔽棋盘操作和重力；暂停冻结倒计时，有效用时不包含暂停与倒计时。
- 游戏中 Menu / Esc 打开暂停菜单，提供继续游戏、结束游戏和设置。设置返回后保持暂停。
- 菜单响应任一手柄；单人棋盘只响应第一只手柄，双人按各自槽位操作。断连不得导致另一位玩家串位。
- 菜单按键固定：方向键／左摇杆选择，A 确认；模式页和设置页 B 返回。跨界面保留按键边沿并等待释放，避免长按确认造成开局硬降或重复激活。
- 设置手柄用 LB / RB 切页；键盘用 PgUp / PgDn 切页、方向键选择和调整、Enter 确认、Esc 返回。
- 有手柄时显示手柄提示，否则显示键盘提示；棋盘提示遵循对应玩家的设备与实际映射。
- 当前设置 Tab 使用青色描边与文字高亮，项目焦点使用黄色描边，并提供可访问性选中状态。
- 设置按类型选择原生控件：开关、滑块、下拉选择、数值 Stepper、按键绑定和操作按钮。不要统一替换为加减按钮。
- 默认棋盘手柄映射为 X 顺时针、Y 逆时针、A 硬降、B 暂存；用户自定义映射与迁移兼容性必须保留。

## 成绩、统计与存储

- `AudioSettings`、`InputSettings`、`ScoreStore` 使用 `UserDefaults`；测试使用独立 suite，并在结束后清理测试域。
- 成绩按模式保存，只记录已结束的对局，每个模式保留最近 100 局；最高分不随历史裁剪丢失。中途结束不保存成绩。
- 结果统计包括得分、有效用时、消行数、每分钟消行数和四行消除次数。双人补充抵消后实际发送的攻击行数与累计胜局比分。
- 局分在结果页连续重开时保留，结束游戏或切换模式后重置；平局不加分。累计局分不等于三局两胜赛制。
- 新增持久化字段必须兼容旧成绩。旧记录缺失的统计显示「—」，不要补造为零；零秒对局的消行速率须避免除零。
- 成绩清理保留二次确认，切换项目或返回时取消确认。不得通过验证功能清理用户真实成绩或配置。

## 音频与异常排查

- 短音效通过有上限的 `SoundVoicePool` 保留并复用播放器。不要仅凭 `isPlaying == false`、停止或重开就释放播放器，结束回调可能仍在队列中。
- 音频设置分别保存 BGM、消行音效和操作音效的开关与音量。消行压低 BGM 只影响临时混音增益，不修改用户保存的音量。
- 本机日志位于 `~/Library/Logs/NeonStack`，由 `DiagnosticLog` 按大小轮转。记录关键状态与异常，不记录凭据或无关输入内容，不自动上传日志。
- 保留日志和 macOS 崩溃报告，以会话、对局、时间及操作前后事件关联分析。未正常关闭也可能来自强制退出，不能单独证明崩溃。
- 音频生命周期测试通过不等于原始崩溃已稳定复现或彻底解决。诊断证据与限制见 `docs/CRASH_DIAGNOSIS.md`。

## 验证与交付

1. 修改规则、输入或存储时，运行对应的确定性测试；涉及共用状态或多个模块时运行完整测试。
2. 修改界面时，在安全重启后的真实窗口检查布局、焦点、高亮、快捷键、设置返回和结果页。无法重启或未完成检查时，明确记录待验证范围。
3. 实体手柄测试与自动化测试分开报告。用户确认的验收注明来源，不补造设备型号、连接方式或逐项结果。
4. 音频测试验证播放与生命周期，实际听感另行验证；RealityKit 动效检查高强度场景和减少动效模式。
5. 功能完成后同步更新 `README.md`、`docs/ROADMAP.md` 和相关验收文档。已有文档与当前代码冲突时，以代码确认行为，再修正文档，不能把旧说明当作当前事实。
6. 保留已有未提交和未跟踪的工作，不覆盖或回退用户修改。提交、推送与公开发布按用户授权范围执行；生成文件 `.build/`、`dist/` 不纳入版本控制。

## 编码规范

- 使用专业、格式一致的代码；提交前格式化修改的 Swift 文件。注释解释规则边界、生命周期和设计原因，不复述代码。
- 避免不必要的依赖和业务 Mock；游戏规则测试可以构造固定种子与棋盘夹具，不能用模拟手柄结果替代实体设备验收。
- 本项目使用 SwiftPM。若新增辅助 Python、Node.js 或 Java 项目，分别优先使用 uv、pnpm、Maven 管理依赖。
- 如另建 Web 原型，按用户约定基于 Ant Design Pro；当前原生 macOS 游戏沿用 SwiftUI 和系统控件。
