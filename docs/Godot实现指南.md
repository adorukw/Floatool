# QuickNote —— Godot 编辑器实现指南

> 目标：用 Godot 4 复刻 QuickNote —— 打开软件后常驻后台，按不同全局快捷键切换不同功能的悬浮窗口。
> 目标平台：Linux + Wayland 会话（应用以 XWayland / X11 驱动运行）。
> 本文是**纯编辑器操作指南**：每一步点哪里、加什么节点、在 Inspector 里改什么属性。不贴完整代码，只在"必须挂脚本"的地方说明脚本职责与挂载位置。

---

## 总览：要在编辑器里做的 5 件事

| 阶段 | 在编辑器里做什么 | 对应面板 |
|------|-----------------|---------|
| 1 | 建项目、定渲染器、改项目设置 | Project Settings |
| 2 | 定目录结构 | FileSystem |
| 3 | 搭主场景（隐藏宿主窗口） | Scene + Inspector |
| 4 | 搭悬浮窗场景（Window 根节点 + 界面） | Scene + Inspector |
| 5 | 配 Autoload、信号、导出 | Project Settings / Node / Export |

---

## 第一步：安装与新建项目

1. 去 `godotengine.org` 下载 **Godot 4.x Standard（非 .NET 版）**，建议 **4.4 或 4.5 stable**，只下载一个版本并固定用它（后面 API 名称和你兜底文档都靠它）。
2. 打开后是 **Project Manager（项目管理器）** → 右上 **`+ Create`** 或 **New Project**。
3. 填：
   - **Project Name**：`QuickNote`
   - **Project Path**：选一个空文件夹
   - **Renderer**：选 **Compatibility**（GL Compatibility）——你这是 2D 轻量桌面 UI，Compatibility 更省资源、对老显卡友好，不需要 Forward+ 的 3D 能力。
4. 点 **Create & Edit** 进入编辑器。

### 先认一下编辑器界面

- 左上 **Scene（场景）**面板：节点树，`+` 加节点。
- 左下 **FileSystem（文件系统）**面板：工程文件。
- 右侧 **Inspector（检查器）**：改选中节点的属性。
- 右侧还有 **Node（节点）**面板，里面有 **Signals（信号）** 和 **Groups（分组）** 两个标签页。
- 顶部中间是运行按钮（▶）和 **F5 / F6 / F8**。

---

## 第二步：项目设置（Project Settings）

菜单 **Project → Project Settings**，逐项改：

1. **Display → Display Server**
   - 找到 **Driver → linuxbsd**（下拉），改成 **`x11`**。
   - 这是全局最关键的一项：让程序在 Wayland 会话下走 **XWayland**，否则置顶和多窗口都会失效。

2. **Display → Window**
   - **Size → Viewport Width / Height**：先填 `320 × 480`（主窗口反正会被隐藏，这里只是方便编辑器预览）。
   - **Flag → Borderless**：打开。
   - **Flag → Always on Top**：先不开（主窗口不需要）。

3. **Display → Window → Subwindows**
   - **Embed Subwindows**：**关闭**。
   - 这一项必须关，否则 `Window` 节点会被塞进主窗口里，而不是生成独立的系统窗口。

4. **Display → Window → Per Pixel Transparency**
   - **Allowed**：可开可不开。只有你想做圆角/异形悬浮窗时才打开（有性能开销）。

5. 改完点右下 **Close**。如果提示重启编辑器，就重启。

---

## 第三步：建目录结构

在左下 **FileSystem** 面板：

1. 右键 `res://` → **New Folder**，依次建：`autoload`、`windows`、`panels`、`assets`。
2. 后面新建的脚本/场景，都用右键 → **New Script** / **New Scene** 建在对应目录里（也可以建完用 **Move To** 移动）。

---

## 第四步：搭主场景（隐藏的宿主窗口）

主场景本身不显示内容，只负责"常驻 + 接收命令"。

1. **Scene → New Scene**（或 `Ctrl+N`）。
2. 在 Scene 面板点 **Other Node** 按钮（不是 "User Interface" 那个）→ 搜索框输入 `Node` → **Create**。
3. 选中它按 **F2** 改名 **`Main`**。
4. 右键 `Main` → **Attach Script**，路径填 `res://main.gd`。
   - 脚本职责（不写全）：`_ready` 里把主窗口 `visible` 设为 `false`、把 `get_tree().auto_accept_quit` 设为 `false`，并连接 IPC 信号。
5. **`Ctrl+S`** 保存为 `res://main.tscn`。
6. 把它设为主场景：菜单 **Project → Set as Main Scene**（或 Project Settings → Application → Run → Main Scene 里选 `main.tscn`）。

> 说明：这里的"主窗口"就是 Godot 为这个场景创建的那个 OS 窗口。你在脚本里隐藏它，进程仍然在跑——这就是"后台常驻"。

---

## 第五步：搭第一个悬浮窗场景（重点）

### 5.1 用正确的根节点类型

1. **Scene → New Scene**。
2. Scene 面板点 **Other Node** → 搜索 `Window` → **Create**。
   - ⚠️ 千万别用 "User Interface" 或 "2D Scene" 起手——那样根节点是 `Control`/`Node2D`，**不是真正的系统窗口**。必须选 `Window` 作为场景根。
3. 选中根节点，**F2** 改名 **`NoteWindow`**。

### 5.2 在 Inspector 里设置窗口属性

选中 `NoteWindow` 后，在 Inspector 顶部搜索框里逐个搜并设置：

| 属性 | 值 | 说明 |
|------|----|------|
| **Borderless** | 开 | 无系统标题栏 |
| **Unresizable** | 开 | 禁止拖边缩放 |
| **Always On Top** | 开 | 置顶（XWayland 下生效） |
| **Transient** | **关** | ⚠️ 一旦打开，Always On Top 会失效 |
| **Transparent** | 关（除非要圆角） | |
| **Size** | `360 × 460` | 初始大小 |
| **Title** | `QuickNote` | |

### 5.3 铺界面

`Window` 根节点自己**不会**自动排版，所以先加一个撑满的容器：

1. 右键 `NoteWindow` → **Add Child Node** → 搜 `PanelContainer` → 创建。
2. 选中这个 `PanelContainer`，点顶部工具栏的 **Layout → Anchors Preset → Full Rect**（锚点预设按钮，图标是四角对齐），让它铺满窗口。
3. 在它下面继续加：
   - `MarginContainer`（在 Inspector 的 Theme Overrides → Constants 里调四边留白）
   - → `VBoxContainer`
   - → `HBoxContainer`（当顶部拖动条）
   - → `TextEdit`（笔记内容区）
4. 顶部条里放一个 `Label`（标题）和一个 `Button`（关闭）。

**窗口拖动**：选中顶部那个 `HBoxContainer`，切到右侧 **Node → Signals** 标签，双击 **`gui_input`**，编辑器会问要不要新建接收函数——同意，它会自动在脚本里生成一个函数。在这个函数里做一件事：当按下鼠标左键时调用窗口拖动 API（`DisplayServer.window_start_drag()`）。这是唯一躲不掉的一小段代码。

### 5.4 挂脚本

1. 选中根 `NoteWindow` → **Attach Script** → 用 `res://windows/note_window.gd`（它继承 `BaseWindow`，而 `BaseWindow` 里统一设置 borderless/always_on_top、以及 `close_requested → hide`）。
2. 关闭按钮的 **pressed** 信号 → 连到 `hide()`（在 Signals 面板里连，或连到脚本函数里调 `hide`）。目的：**关闭 = 隐藏，不退出进程**。
3. **`Ctrl+S`** 保存为 `res://windows/note_window.tscn`。

### 5.5 复制出其他功能窗

在 FileSystem 里右键 `note_window.tscn` → **Duplicate**，改名 `todo_window.tscn`、`clipboard_window.tscn`，分别把内部内容换掉即可。窗口的通用行为都在 `BaseWindow` 里，不用重复。

---

## 第六步：注册 Autoload（全局单例）

菜单 **Project → Project Settings → Globals（Autoload）** 标签页：

1. **Path** 选 `res://autoload/ipc.gd`，**Node Name** 填 `Ipc`，点 **Add**；
   - 右侧 **Global Variable**（那个 `*` 按钮）要**打开**，这样全局就能直接用 `Ipc`。
   - 脚本职责：在 `_ready` 里用 `PacketPeerUDP` 绑定 `127.0.0.1:45670`，在 `_process` 里轮询收到的数据报，发一个 `command_received` 信号。
2. 再添加 `res://autoload/window_manager.gd`，**Node Name** 填 `WindowManager`，同样打开全局变量。
   - 脚本职责：维护"功能名 → 场景"的映射，提供 `toggle(name)`：没创建就实例化并 `add_child`，已存在就 `show/hide` 切换。
   - ⚠️ Autoload 脚本必须 `extends Node`，否则会报错。

主场景 `main.gd` 里则把 `Ipc.command_received` 连到自己的处理函数，转发给 `WindowManager.toggle(cmd)`。

---

## 第七步：中文与主题（避免豆腐块）

1. 把中文字体（如 Noto Sans CJK 的 `.ttf/.otf`）拖进 **FileSystem** 的 `assets/`，Godot 会自动生成 `FontFile` 资源。
2. 新建主题：FileSystem 右键 → **New Resource** → 搜 `Theme` → 保存为 `assets/ui_theme.tres`，双击打开底部 **Theme 编辑器**：
   - **Default Font** 指向你的字体。
   - 想圆角/配色：左侧选 `PanelContainer` → **StyleBoxFlat**，调 Corner Radius、Background Color。
3. 应用：Project Settings → **Gui → Theme → Custom** 指向该 `.tres`（全局生效），或每个窗口的 `theme` 属性单独指定。

---

## 第八步：测试运行（编辑器里的坑都在这）

1. **先关掉"游戏内嵌"**，否则多窗口效果看不出来：
   - 菜单 **Editor → Editor Settings**，搜索 `embed`，把 **Embed Game on Play / Game Embed** 之类的选项**关掉**。
2. 按 **F5** 运行。
3. 因为主窗口被隐藏，你**什么都不会看到，这是正常的**。
4. 用 **Scene 面板**顶部的 **Remote** 标签（运行时会出现），查看实时节点树，手动把某个 `NoteWindow` 的 `visible` 勾上，确认它能作为独立系统窗口弹出来、并且置顶。
5. 按 **F8** 停止。

**模拟全局命令**：另开一个终端敲

```
echo -n note | nc -u 127.0.0.1 45670
```

如果 `NoteWindow` 被唤出/隐藏，说明 IPC 通了。没有 `nc` 就用：

```
bash -c 'exec 3<>/dev/udp/127.0.0.1/45670; printf note >&3'
```

---

## 第九步：导出（Export）

1. 菜单 **Editor → Manage Export Templates → Download**，装对应 Godot 版本的导出模板。
2. 菜单 **Project → Export → Add… → Linux**（4.x 里就是 Linux，含 X11/Wayland）。
3. 设置 **Export Path**，如 `build/QuickNote.x86_64`；其余默认。
4. **Export Project**。
5. 运行产出的可执行文件时，若想强制走 XWayland：`./QuickNote.x86_64 --display-driver x11`（4.7+ 可能改为 `--display-server x11`，以你版本的 `--help` 为准）。

> 要做 AppImage，需要你手动把导出产物配合 linuxdeploy 打包；Godot 没有官方 AppImage 流程，这一步在编辑器外做。

---

## 第十步：编辑器外的一次性配置（全局热键）

这部分不在 Godot 里，但项目能不能"后台全局热键"全靠它：

1. 新建 `~/.local/bin/qn`（可执行），内容是从命令行把参数写一行 UDP 到 `127.0.0.1:45670`。
2. 打开桌面环境的快捷键设置：
   - **KDE**：系统设置 → 快捷键 → 自定义 → 新建 → 命令。
   - **GNOME**：设置 → 键盘 → 自定义快捷键。
   - 分别绑定：`qn note`、`qn todo`、`qn clip`、`qn quit`。
3. 可选：写 `~/.config/autostart/quicknote.desktop` 实现开机自启（`Exec` 指向导出产物并带 `--display-driver x11`）。

---

## 常见编辑器坑速查

| 现象 | 原因 | 解决 |
|------|------|------|
| 悬浮窗被塞进主窗口里 | `Embed Subwindows` 没关 | 项目设置里关掉 |
| 界面内容尺寸是 0 | `Window` 下的 Control 没铺满 | 用 Full Rect 锚点预设 |
| 置顶无效 | 没走 x11 驱动 / 开了 Transient | 设 `driver.linuxbsd = x11`；关掉 Transient |
| 运行后什么都没看到 | 主窗口被脚本隐藏了 | 用 Remote 面板手动显示窗口，属正常 |
| Autoload 报错 | 脚本没继承 `Node` | 改成 `extends Node` |
| 中文显示成方块 | 没配 CJK 字体 | 加 FontFile + Theme 默认字体 |
| 多窗口预览看不出效果 | 游戏被内嵌进编辑器 | 关掉 Editor Settings 里的 Embed Game |
| 改驱动没生效 | 编辑器/游戏需重启 | 重启编辑器再跑 |

---

## 建议的实操顺序

1. 建项目 → 改项目设置（驱动 x11、关 Subwindows 内嵌）
2. 主场景 + 隐藏窗口脚本 → F5 跑通"后台常驻"
3. 第一个 `Window` 场景 + Full Rect 界面 → 用 Remote 面板验证独立窗口与置顶
4. 加 `Ipc` / `WindowManager` Autoload → 用 `nc` 验证切换
5. 配 DE 快捷键 → 验证后台全局热键
6. 再做拖拽、位置记忆、其余功能窗、字体主题
7. 最后导出 + AppImage + 自启动

按这个顺序，每一步都能单独验证，不会一次性堆太多东西导致不知道哪里坏了。

---

## 附：关键前提回顾（Wayland 三大约束）

| 约束 | 事实 | 对策 |
|------|------|------|
| 置顶 | Godot 的 `always_on_top` 只在 **X11** 实现，Wayland 本身不支持 | 强制走 XWayland（x11 驱动） |
| 多窗口 | Godot 4.5 起 Wayland 接近 X11 对等，但**不支持原生子窗口** | 同上，走 XWayland |
| 全局热键 | Godot **没有**全局热键 API（Qt 也没有） | 交给桌面环境注册，程序用 UDP 接收命令 |
