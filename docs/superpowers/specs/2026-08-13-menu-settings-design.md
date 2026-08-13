# SkyBallRun 菜单与设置系统设计

## 目标

为 Windows PC 版 SkyBallRun 增加可复用的主菜单、暂停菜单和设置菜单，同时保留现有四关跑酷、坠落镜头、音乐切换和重开逻辑。

## 设计

- `scripts/settings.gd` 作为 Autoload，使用 Godot `ConfigFile` 保存 `user://sky_ball_run.cfg`。
- 设置项包含主音量、音乐开关、全屏开关；设置加载时立即应用，修改后立即保存。
- `scripts/menu_controller.gd` 只管理 Control 节点、按钮和菜单状态，通过信号调用主游戏脚本的开始、暂停、继续和退出接口。
- `scripts/main.gd` 保留现有跑酷模拟，并增加 `game_started`、`paused` 状态；未开始或暂停时不推进距离、障碍、坠落和音乐时钟。
- 主菜单显示在游戏启动时；开始游戏后隐藏。ESC/P 打开暂停菜单，暂停菜单可继续、重新开始、设置或返回主菜单。
- 设置面板提供主音量滑块、音乐开关、全屏开关和返回按钮。全屏使用 `DisplayServer.window_set_mode`，音量使用 Master 音频总线。

## 交互与错误处理

- 所有菜单按钮既支持鼠标也支持键盘焦点。
- 退出按钮调用 `get_tree().quit()`。
- 设置文件不存在或损坏时使用默认值并重新保存，不阻塞游戏启动。
- 游戏结束/通关界面保留原有空格、R、Enter 重开行为；主菜单状态不允许跑酷输入改变球体位置。

## 验证

- Godot 4.7.1 headless 启动检查。
- 手动确认主菜单、开始、暂停、继续、设置、全屏、音量和退出。
- 检查 `git diff --check`，并保存阶段性 Git 提交。
