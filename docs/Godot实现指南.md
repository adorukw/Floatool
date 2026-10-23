# Floatool —— Godot 实现指南（单窗口 + 标签页）

> **本文已按你的目标重写**
>
> 旧版是「一个功能一个独立 `Window`」（`NoteWindow` / `TodoWindow` / `ClipboardWindow`）。
> 现在改成「**一个悬浮窗 + 顶部三个标签**」：
>
> - **Note**（便签）
> - **Translate**（翻译）
> - **AIChat**（AI 问答）
>
> 整个程序只有 **一个** `Window` 根节点；三个功能是它内部的**页面（Control）**，由 `TabContainer` 切换。
>
> 📎 配套阅读：`docs/Godot标签页界面教程.md`
> 那篇是**标签页 UI 的细节教程**：节点选型、三个页面的完整布局、主题美化、快捷键细节。
> 本文负责**整体流程**：项目设置、目录、隐藏宿主、悬浮窗骨架、Autoload、测试、导出、全局热键。

> 目标平台：Godot 4.7 stable / Linux + Wayland 会话（应用走 XWayland）。

---

## 和旧版的主要差异

| 旧版 | 新版 |
|------|------|
| 每个功能一个 `Window`（NoteWindow / TodoWindow / ClipboardWindow） | 全局只有一个 `FloatoolWindow` |
| 不同全局快捷键唤出不同窗口 | 快捷键唤出同一个窗口，并切到对应标签页 |
| `WindowManager` 维护「功能名 → 窗口」多实例 | `WindowManager` 只管一个窗口，负责显示 + 切页 |
| 第五步 5.5「复制出其他功能窗」 | 第五步 5.5「把三个页面拆成独立场景」 |
| 页面没有标签栏 | `TabContainer` 顶部标签栏 |

---

## 总览：整个程序长什么样

### 运行时结构

```
Main (Node, 主场景)
  ├─ 隐藏主窗口
  ├─ auto_accept_quit = false
  └─ 把 Ipc 的命令转发给 WindowManager

Ipc (Autoload)
  └─ 监听 127.0.0.1:45670，收到字符串 → 发 command_received 信号

WindowManager (Autoload)
  └─ FloatoolWindow (Window)          ← 唯一的系统窗口
		└── Root (PanelContainer)
			└── Layout (VBoxContainer)
				├── TitleBar (HBoxContainer)   拖动条 + 关闭
				└── Tabs (TabContainer)
					├── Note        (MarginContainer)  便签页
					├── Translate   (MarginContainer)  翻译页
					└── AIChat      (MarginContainer)  AI 页
```

### 命令流

```
桌面环境快捷键  →  qn note  →  UDP 127.0.0.1:45670
	  →  Ipc.command_received("note")
	  →  Main._on_command_received("note")
	  →  WindowManager.toggle("note")
	  →  FloatoolWindow.show_page("note")   （显示窗口 + 切到便签页）
```

### 要做的事

| 阶段 | 做什么 | 对应本文 |
|------|--------|---------|
| 1 | 项目设置（x11 驱动、关 Subwindows 内嵌） | 第二步 |
| 2 | 建目录结构 | 第三步 |
| 3 | 隐藏宿主主场景 `Main` | 第四步 |
| 4 | 唯一的悬浮窗 `FloatoolWindow` + 标签页 | 第五步 |
| 5 | `Ipc` / `WindowManager` 两个 Autoload | 第六步 |
| 6 | 中文字体与主题 | 第七步 |
| 7 | 测试、导出、配全局热键 | 第八～十步 |

---

## 第一步：安装与新建项目

1. 去 `godotengine.org` 下载 **Godot 4.x Standard（非 .NET 版）**，固定用 **4.7 stable**（与当前 `project.godot` 的 `config/features="4.7"` 对应）。
2. 你已经建好 `Floatool` 项目，这一步可以跳过。
3. 渲染器说明：
   - 新项目建议 **Compatibility（GL Compatibility）**，2D 桌面 UI 更省资源。
   - 你当前项目是 **Forward+**，也能用，不必强行改；只是没必要。想改就 **Project → Project Settings → Rendering → Renderer → Rendering Method** 改成 `gl_compatibility`。

### 先认一下编辑器

- 左上 **Scene**：节点树，`+` 加节点。
- 左下 **FileSystem**：工程文件。
- 右侧 **Inspector**：改属性。
- 右侧 **Node**：Signals / Groups。
- 顶部中间：运行按钮、`F5` / `F6` / `F8`。

---

## 第二步：项目设置（Project Settings）

菜单 **Project → Project Settings**，逐项改：

### 2.1 Display → Display Server

- **Driver → linuxbsd**：改成 **`x11`**。

> 这是 Wayland 会话下最关键的一项：让程序走 **XWayland**。否则 `Always On Top`、多窗口都会失效。

### 2.2 Display → Window

| 设置 | 值 | 说明 |
|------|----|------|
| Size → Viewport Width / Height | `420 × 560` | 主窗口反正会隐藏，这里只影响编辑器预览 |
| Flag → Borderless | 开 | |
| Flag → Always on Top | 先关 | 主窗口不需要 |

### 2.3 Display → Window → Subwindows

- **Embed Subwindows**：**关闭**。

> 必须关。否则 `Window` 节点会被塞进主窗口内部，而不是生成独立的系统窗口。

### 2.4 Display → Window → Per Pixel Transparency

- **Allowed**：可选。只有想做圆角/异形悬浮窗时才开，有性能开销。

改完点 **Close**。提示重启就重启。

---

## 第三步：建目录结构

在 **FileSystem** 面板右键 `res://` → **New Folder**，建：

```
res://
├── main.tscn / main.gd             # 隐藏的宿主主场景
├── autoload/
│   ├── ipc.gd                      # UDP 收命令
│   └── window_manager.gd           # 管理唯一悬浮窗 + 切页
├── windows/
│   └── floatool_window.tscn / .gd  # ★ 唯一的系统窗口（带标签页）
├── panels/                         # 三个标签页各自独立成场景
│   ├── note_panel.tscn / .gd
│   ├── translate_panel.tscn / .gd
│   ├── ai_chat_panel.tscn / .gd
│   └── chat_bubble.tscn            # AI 聊天气泡（可选）
└── assets/
	├── fonts/                      # 中文字体
	└── ui_theme.tres               # 全局主题
```

> **为什么页面要独立成场景？**
> 和 Qt 里把每个页面写成独立 `QWidget` 一个道理：互不干扰、能单独调试、主窗口只负责切换。三个页面以后各自长大也不会挤在一个文件里。

---

## 第四步：搭隐藏的宿主主场景

`Main` 不显示任何 UI，只负责「常驻 + 收命令」。

### 4.1 建场景

1. **Scene → New Scene**（`Ctrl+N`）。
2. Scene 面板点 **Other Node**（不是 "User Interface"）→ 搜 `Node` → **Create**。
3. `F2` 改名 **`Main`**。
4. 右键 `Main` → **Attach Script**，路径填 `res://main.gd`。
5. `Ctrl+S` 保存为 `res://main.tscn`。

> 这里必须用 `Node`，不是 `Control` 也不是 `Window`：`Main` 本身不显示任何东西，只是进程的锚点。真正的系统窗口是第五步的 `FloatoolWindow`。

### 4.2 `main.gd`

```gdscript
extends Node

func _ready() -> void:
	# 1) 关掉"窗口一关就自动退出"的行为
	get_tree().auto_accept_quit = false

	# 2) 让宿主主窗口"隐身"。
	#    ⚠️ 不能写 get_window().visible = false，Godot 会报
	#    "Can't change visibility of main window"（主窗口是根窗口，没有父窗口）。
	#    官方推荐做法：设为不可聚焦（从任务栏/任务切换器隐藏）+ 最小化。
	get_window().unfocusable = true
	get_window().mode = Window.MODE_MINIMIZED

	# 3) 把 IPC 命令转发给窗口管理器
	#    注意：Ipc / WindowManager 要先按第六步注册成 Autoload，否则这里会报"标识符未定义"
	Ipc.command_received.connect(_on_command_received)

func _on_command_received(cmd: String) -> void:
	WindowManager.toggle(cmd)
```

> 如果你现在还没做第六步，先把第 3 行和 `_on_command_received` 注释掉，只保留前两行，先验证「后台常驻」。

### 4.3 设为主场景

菜单 **Project → Set as Main Scene**，或 **Project Settings → Application → Run → Main Scene** 里选 `main.tscn`。

### 4.4 关键理解

| 代码 | 作用 |
|------|------|
| `get_tree().auto_accept_quit = false` | 关掉「关闭窗口 = 自动退出」。之后必须手动 `get_tree().quit()` 才退出 |
| `get_window().unfocusable = true` + `get_window().mode = Window.MODE_MINIMIZED` | **不能直接 `visible = false`**（会报 "Can't change visibility of main window"）。官方做法是最小化 + 不可聚焦：主窗口从任务栏/任务切换器里消失，进程和 `_process` 继续在后台运行 |
| `Ipc.command_received.connect(...)` | 接收外部命令，转给 `WindowManager` |

真正的退出出口是 `cmd == "quit"` 分支（见第六步），因为 `auto_accept_quit` 已经关掉了普通关闭退出的行为。

### 4.5 GNOME 用户：主窗口还会出现在 Activities 概览里

`unfocusable + 最小化` 能让主窗口从**任务栏 / Dock** 消失，但 **GNOME 的 Activities（活动概览）会列出所有最小化的窗口**，所以你仍然能在概览里看到一个空的 `Floatool` 窗口。这是 GNOME 的行为，不是 Godot 的 bug。

要让它在概览里也几乎看不见，把主窗口做成 **1×1 全透明**：

| Project Settings | 值 |
|------------------|----|
| Display → Window → Size → **Window Width Override** | `1` |
| Display → Window → Size → **Window Height Override** | `1` |
| Display → Window → Size → **Borderless** | 开 |
| Display → Window → Size → **Transparent** | 开 |
| Display → Window → Size → **No Focus** | 开 |
| Display → Window → **Per Pixel Transparency → Allowed** | 开 |
| Rendering → **Viewport → Transparent Background** | 开 |
| Application → **Boot Splash → Show Image** | 关 |
| Application → **Boot Splash → Bg Color** | 全透明（Alpha = 0） |

`main.gd` 里的 `unfocusable + MODE_MINIMIZED` 保留不动。

这样即使概览里还残留一个 1×1 的条目，视觉上也等于不存在。

> 不推荐依赖 GNOME 扩展（如 "Hide Minimized"）来解决，因为用户环境不一定装了。

---

## 第五步：搭唯一的悬浮窗（重点）

> ⚠️ **和旧版最大的区别在这里**：整个程序只建**一个** `Window`。
> 便签、翻译、AI 问答都只是它内部的**页面**，不是窗口。
> 旧版的 5.5「复制出 TodoWindow / ClipboardWindow」**已删除**。

### 5.1 用正确的根节点类型

1. **Scene → New Scene**。
2. Scene 面板点 **Other Node** → 搜 `Window` → **Create**。
   - ⚠️ 不能用 "User Interface" 或 "2D Scene" 起手——那样根节点是 `Control`/`Node2D`，**不是真正的系统窗口**。
3. `F2` 改名 **`FloatoolWindow`**。

> **如果你已经按旧版建了 `note_window.tscn`**，不用删：
> 1. FileSystem 里右键它 → **Move To…** → 移到 `windows/floatool_window.tscn`；
> 2. 打开场景，把根节点 `F2` 改名 `FloatoolWindow`；
> 3. Inspector 里把 `Title` 从 `Note` 改成 `Floatool`、`Size` 改成 `420 × 560`；
> 4. 根节点上已有的 `Borderless / Always On Top / Unresizable` 保留，多余的子节点删掉；
> 5. 从 5.3 开始往里面加 `Root / Layout / TitleBar / Tabs`。

### 5.2 在 Inspector 里设置窗口属性

| 属性 | 值 | 说明 |
|------|----|------|
| **Borderless** | 开 | 无系统标题栏 |
| **Unresizable** | 开 | 禁止拖边缩放 |
| **Always On Top** | 开 | 置顶（XWayland 下生效） |
| **Transient** | **关** | ⚠️ 一旦打开，Always On Top 会失效 |
| **Transparent** | 关 | 除非要做圆角 |
| **Size** | `420 × 560` | 初始大小 |
| **Title** | `Floatool` | |

### 5.3 铺根布局和标题栏

`Window` 根节点自己**不会**自动排版，所以要先加一个撑满的容器：

```
FloatoolWindow (Window)
└── Root (PanelContainer)            ← Full Rect，铺满窗口
	└── Layout (VBoxContainer)
		├── TitleBar (HBoxContainer)  ← 拖动条
		│   ├── Title (Label)         "Floatool"
		│   ├── Spacer (Control)      Expand Fill
		│   ├── PinButton (Button)    "📌"
		│   └── CloseButton (Button)  "✕"
		└── Tabs (TabContainer)       ← 第五步 5.4 的内容放这里
```

操作：

1. 右键 `FloatoolWindow` → **Add Child Node** → 搜 `PanelContainer` → 创建，改名 `Root`。
2. 选中 `Root` → 顶部工具栏 **Layout → Anchors Preset → Full Rect**。
   - 这一步是「铺满窗口」的关键。**不做的话界面尺寸是 0，运行后什么都看不到。**
3. 右键 `Root` → 加 `VBoxContainer`，改名 `Layout`。
   - `PanelContainer` 会自动把唯一子节点撑满，不用手动设锚点。
   - 选中 `Layout`，在 **Theme Overrides → Constants** 里新增 `separation`，值设 `0`。
4. 右键 `Layout` → 加 `HBoxContainer`，改名 `TitleBar`。
5. 右键 `TitleBar` 依次加：
   - `Label` → 改名 `Title`，`text = "Floatool"`。
   - `Control` → 改名 `Spacer`，**Size Flags Horizontal = Expand Fill**（把后面的按钮推到最右）。
   - `Button` → 改名 `PinButton`，`text = "📌"`，`flat = true`（置顶开关，可选）。
   - `Button` → 改名 `CloseButton`，`text = "✕"`，`flat = true`。

> 容器规则：`PanelContainer` 和 `MarginContainer` 是「单子节点容器」，只能放一个直接子节点；要放多个东西，里面先放一个 `VBoxContainer` / `HBoxContainer`。

### 5.4 加 TabContainer 和三个页面

1. 右键 `Layout` → 加 `TabContainer`，改名 `Tabs`。
2. 选中 `Tabs`，Inspector 里设：

| 属性 | 值 | 说明 |
|------|----|------|
| Layout → Size Flags Vertical | **Expand Fill** | 吃掉标题栏以下的全部高度 |
| Tab Alignment | Left（默认） | 标签靠左 |
| Clip Tabs | 开 | 标签多了也不撑大窗口 |
| Tab Focus Mode | `All` | 允许 Tab 键聚焦标签栏，用方向键切换 |
| Tabs Position | Top（默认） | 标签栏在上 |

3. 右键 `Tabs` 三次，分别加 3 个 `MarginContainer`，改名：
   - `Note`
   - `Translate`
   - `AIChat`

   每加一个 Control 子节点，标签栏就自动多一个标签。**此时运行已经能点标签切页了**，`TabContainer` 帮你搞定。

4. 给每个 `MarginContainer` 在 **Theme Overrides → Constants** 里设 `margin_left/top/right/bottom`（如 `8`），做出页面内边距。

> 标签显示名：节点名保持英文（`Note`/`Translate`/`AIChat`），中文标题在脚本里用 `set_tab_title()` 设置（见 5.6）。这样以后做多语言不用改节点名。

此时大致结构：

```
FloatoolWindow (Window)
└── Root (PanelContainer, Full Rect)
	└── Layout (VBoxContainer)
		├── TitleBar (HBoxContainer)
		│   ├── Title / Spacer / PinButton / CloseButton
		└── Tabs (TabContainer, Expand Fill)
			├── Note (MarginContainer)
			├── Translate (MarginContainer)
			└── AIChat (MarginContainer)
```

### 5.5 把三个页面拆成独立场景（推荐）

先跑通再拆也可以。拆的步骤：

1. FileSystem 右键 `panels/` → **New Scene**。
2. 根节点选 `MarginContainer`，改名 `NotePanel`。
3. **Attach Script** → `res://panels/note_panel.gd`。
4. `Ctrl+S` 保存为 `res://panels/note_panel.tscn`。
5. 同样建 `translate_panel.tscn`、`ai_chat_panel.tscn`。
6. 回到 `floatool_window.tscn`：
   - 右键 `Tabs` 下的占位 `Note` → **Delete Node**。
   - 右键 `Tabs` → **Instantiate Child Scene…** → 选 `note_panel.tscn`。
   - 把实例改名 `Note`。
   - 依次对 `Translate`、`AIChat` 做同样的事，**保持 Note → Translate → AIChat 的顺序**（顺序决定标签顺序，可在 Scene 面板里拖动调整）。

> `TabContainer` 只要求子节点是 **Control**，实例化场景的根只要是 Control 就能当标签页。

三个页面内部怎么布局（`TextEdit` / `RichTextLabel` / `HSplitContainer` / 聊天气泡等），见 `docs/Godot标签页界面教程.md` 第 5 节，这里不重复。

### 5.6 挂脚本：`windows/floatool_window.gd`

1. 选中根节点 `FloatoolWindow` → **Attach Script** → `res://windows/floatool_window.gd`。
2. 内容：

```gdscript
class_name FloatoolWindow
extends Window

# 命令名 → 标签页索引，必须和第六步的快捷键命令一致
const COMMAND_TO_TAB = {"note": 0, "translate": 1, "aichat": 2}
const PAGE_TITLES = ["便签", "翻译", "AI 问答"]

@onready var tabs: TabContainer = $Root/Layout/Tabs
@onready var close_button: Button = $Root/Layout/TitleBar/CloseButton

func _ready() -> void:
	# 节点名保持英文，这里显示中文标签
	for i in PAGE_TITLES.size():
		tabs.set_tab_title(i, PAGE_TITLES[i])

	# 关闭按钮 = 隐藏窗口，不退出进程
	close_button.pressed.connect(hide)
	# Alt+F4 / 系统关闭请求也只隐藏
	close_requested.connect(hide)

	tabs.current_tab = 0

# 供 WindowManager 调用：显示窗口并切到指定页
func show_page(command: String) -> void:
	tabs.current_tab = COMMAND_TO_TAB.get(command, 0)
	show()
	grab_focus()

# 供 WindowManager 判断"当前是不是这一页"
func current_command() -> String:
	for cmd in COMMAND_TO_TAB:
		if COMMAND_TO_TAB[cmd] == tabs.current_tab:
			return cmd
	return ""
```

3. `Ctrl+S` 保存为 `res://windows/floatool_window.tscn`。

> **`class_name FloatoolWindow` 是什么？** 它把这个脚本注册成一个全局类型。这样第六步的 `window_manager.gd` 里就能写 `var _window: FloatoolWindow`，并直接调用 `show_page()` / `current_command()`；否则 `Window` 类型上找不到这些自定义方法，会编译报错。

> 标签页的**快捷键切换**（`Ctrl+1/2/3`）不在这个窗口脚本里做，统一由第六步的全局命令 + `InputMap` 处理；细节见 `Godot标签页界面教程.md` 第 6 节。

---

## 第六步：注册 Autoload（全局单例）

菜单 **Project → Project Settings → Globals（Autoload）**。

### 6.1 `Ipc`：UDP 收命令

1. 新建脚本 `res://autoload/ipc.gd`：

```gdscript
extends Node

signal command_received(command: String)

const PORT = 45670

var _udp := PacketPeerUDP.new()

func _ready() -> void:
	var err := _udp.bind(PORT, "127.0.0.1")
	if err != OK:
		push_error("IPC 端口绑定失败：%s" % error_string(err))

func _process(_delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		var cmd := _udp.get_packet().get_string_from_utf8().strip_edges()
		if not cmd.is_empty():
			command_received.emit(cmd)
```

2. 在 Autoload 里添加：
   - **Path**：`res://autoload/ipc.gd`
   - **Node Name**：`Ipc`
   - 右侧 **Global Variable** 打开（这样代码里能直接写 `Ipc`）
   - 点 **Add**

> ⚠️ Autoload 脚本必须 `extends Node`，否则报错。

### 6.2 `WindowManager`：管理唯一悬浮窗 + 切页

1. 新建脚本 `res://autoload/window_manager.gd`：

```gdscript
extends Node

const WINDOW_SCENE = preload("res://windows/floatool_window.tscn")

var _window: FloatoolWindow

func _ready() -> void:
	_window = WINDOW_SCENE.instantiate() as FloatoolWindow
	add_child(_window)
	_window.hide()

func toggle(command: String) -> void:
	if command == "quit":
		get_tree().quit()
		return

	# 已经显示在同一页 → 再按一次就隐藏（切换语义）
	if _window.visible and _window.current_command() == command:
		_window.hide()
	else:
		_window.show_page(command)
```

2. 在 Autoload 里添加：
   - **Path**：`res://autoload/window_manager.gd`
   - **Node Name**：`WindowManager`
   - 同样打开 **Global Variable**
   - 点 **Add**

> 添加顺序：先 `Ipc`，后 `WindowManager`。

### 6.3 命令表

| 命令字符串 | 行为 |
|-----------|------|
| `note` | 显示窗口并切到「便签」；已在该页时再按则隐藏 |
| `translate` | 显示窗口并切到「翻译」；同上 |
| `aichat` | 显示窗口并切到「AI 问答」；同上 |
| `quit` | 真正退出进程 |

### 6.4 整体串联

```gdscript
# main.gd 里
func _on_command_received(cmd: String) -> void:
	WindowManager.toggle(cmd)
```

至此：`UDP → Ipc → Main → WindowManager → FloatoolWindow` 全链路打通。

---

## 第七步：中文与主题（避免豆腐块）

1. 把中文字体（如 Noto Sans CJK 的 `.ttf/.otf`）拖进 `assets/fonts/`，Godot 会自动生成 `FontFile`。
2. 新建主题：FileSystem 右键 → **New Resource** → 搜 `Theme` → 保存为 `assets/ui_theme.tres`。
3. 双击打开，在底部 **Theme 编辑器**：
   - **Default Font** 指向你的中文字体。
   - 左侧 **Types** 选 `PanelContainer` → `panel` → **StyleBoxFlat**，调 Corner Radius / Background Color。
   - 左侧选 `TabContainer`，按下表改（想做「顶部按钮」风格）：

| 主题项 | 建议 |
|--------|------|
| `panel` | StyleBoxFlat，背景色 + 圆角 |
| `tabbar_background` | 与背景同色或透明 |
| `tab_selected` | StyleBoxFlat，高亮色 + 圆角 6 |
| `tab_unselected` | **StyleBoxEmpty**（空样式） |
| `tab_hovered` | StyleBoxFlat，半透明高亮 |
| `font_selected_color` | 深色 |
| `font_unselected_color` | 灰色 |
| `tab_separation` | `4` |
| `side_margin` | `8` |

4. 应用：
   - 全局：Project Settings → **Gui → Theme → Custom** → 选 `ui_theme.tres`
   - 或只给这个窗口：选中 `FloatoolWindow`，Inspector → **Theme**

> `tab_unselected` 用 `StyleBoxEmpty` + `tab_selected` 圆角高亮，立刻有「分段控件」的感觉。细节见标签页教程第 7 节。

---

## 第八步：测试运行

1. **先关掉编辑器内嵌游戏**：Editor → Editor Settings 搜 `embed`，把 **Embed Game on Play** 关掉。
2. `F5` 运行。
3. 主窗口被隐藏，**什么都看不到是正常的**。
4. 用 Scene 面板顶部的 **Remote** 标签，把 `FloatoolWindow` 的 `visible` 勾上，确认它作为独立窗口弹出并置顶。
5. 检查：
   - 点三个标签能切页；
   - `CloseButton` 只是隐藏，进程不退；
   - 中文不显示豆腐块；
   - 拖动标题栏能移动窗口（见 `Godot标签页界面教程.md` 第 8 节）。

### 模拟全局命令

另开终端：

```bash
echo -n note | nc -u 127.0.0.1 45670
echo -n translate | nc -u 127.0.0.1 45670
echo -n aichat | nc -u 127.0.0.1 45670
echo -n quit | nc -u 127.0.0.1 45670
```

没有 `nc` 就用：

```bash
bash -c 'printf "%s" note > /dev/udp/127.0.0.1/45670'
```

---

## 第九步：导出（Export）

1. 菜单 **Editor → Manage Export Templates → Download**，装与 Godot 版本对应的模板（你已有 `4.7.2.stable`）。
2. 菜单 **Project → Export → Add… → Linux**。
3. 设置 **Export Path**，如 `build/Floatool.x86_64`。
4. **Export Project**。
5. 运行产物时强制 XWayland：

```bash
./Floatool.x86_64 --display-driver x11
```

> 4.7+ 可能改为 `--display-server x11`，以你版本的 `--help` 为准。

> AppImage 需要导出后用 `linuxdeploy` 手动打包，Godot 没有官方 AppImage 流程。

---

## 第十步：编辑器外的一次性配置（全局热键）

这部分不在 Godot 里，但「后台全局热键」全靠它。

### 10.1 建一个发命令的小脚本

新建 `~/.local/bin/qn`：

```bash
#!/usr/bin/env bash
# 用法：qn note | qn translate | qn aichat | qn quit
cmd="${1:-note}"
printf '%s' "$cmd" > /dev/udp/127.0.0.1/45670
```

```bash
chmod +x ~/.local/bin/qn
```

确保 `~/.local/bin` 在 `PATH` 里（多数发行版默认已加）。

### 10.2 在桌面环境绑定快捷键

- **KDE**：系统设置 → 快捷键 → 自定义 → 新建 → 命令
- **GNOME**：设置 → 键盘 → 自定义快捷键

分别绑定：

| 快捷键示例 | 命令 |
|-----------|------|
| `Ctrl+Alt+N` | `qn note` |
| `Ctrl+Alt+T` | `qn translate` |
| `Ctrl+Alt+A` | `qn aichat` |
| `Ctrl+Alt+Q` | `qn quit` |

### 10.3 开机自启（可选）

新建 `~/.config/autostart/floatool.desktop`：

```ini
[Desktop Entry]
Type=Application
Name=Floatool
Exec=/path/to/Floatool.x86_64 --display-driver x11
Terminal=false
X-GNOME-Autostart-enabled=true
```

---

## 常见坑速查

| 现象 | 原因 | 解决 |
|------|------|------|
| 悬浮窗被塞进主窗口里 | `Embed Subwindows` 没关 | 项目设置里关掉 |
| 界面尺寸是 0 / 什么都没看到 | `Root` 没铺满，或主窗口被隐藏 | `Root` 用 **Full Rect**；用 Remote 面板显示窗口 |
| 标签区下面留白 | `Tabs` 的竖向 Size Flags 没设 | 设成 **Expand Fill** |
| 标签标题是英文节点名 | 没调 `set_tab_title` | `_ready` 里循环设中文 |
| 置顶无效 / 悬浮窗不是独立窗口 | `driver.linuxbsd` 设成了 `wayland`，或开了 Transient | 改成 **`x11`**（走 XWayland）；关 Transient |
| 报错 `Can't change visibility of main window` | 对根窗口用了 `visible = false` | 改用 `unfocusable = true` + `mode = Window.MODE_MINIMIZED` |
| GNOME Activities 概览里还能看到空的主窗口 | GNOME 会列出最小化窗口；`unfocusable` 只管任务栏/Dock | 主窗口做成 **1×1 全透明**，见 4.5 |
| 关闭后进程退出了 | 用 `get_tree().quit()` 连了关闭按钮 | 关闭只连 `hide` |
| 运行后什么都没看到 | 主窗口被脚本隐藏了 | 用 Remote 面板手动显示，属正常 |
| Autoload 报错 | 脚本没继承 `Node` | 改成 `extends Node` |
| `Ipc` / `WindowManager` 未定义 | 没注册 Autoload | Project Settings → Globals 里添加 |
| 中文显示成方块 | 没配 CJK 字体 | Theme → Default Font 指到中文字体 |
| 多窗口预览看不出效果 | 游戏被内嵌进编辑器 | 关掉 Editor Settings 里的 Embed Game |
| 改驱动没生效 | 编辑器/游戏需重启 | 重启编辑器再跑 |
| 快捷键在输入框里失效 | 焦点在 `TextEdit` | 详见标签页教程 6.3（用 `_input()`） |

---

## 建议的实操顺序

1. 项目设置：驱动 `x11`、关 `Embed Subwindows`。
2. 建目录 → 建 `main.tscn` + `main.gd` → 先只做「隐藏窗口 + 后台常驻」，`F5` 验证进程不退出。
3. 建 `floatool_window.tscn`：`Window → Root(Full Rect) → Layout → TitleBar + Tabs`。
4. `Tabs` 下放三个 `MarginContainer` → 运行验证**点击切标签**。
5. 挂 `floatool_window.gd`，`set_tab_title` 出中文，验证标题。
6. 建 `Ipc` / `WindowManager` Autoload → 用 `nc` 验证 `note` / `translate` / `aichat` / `quit`。
7. 在 `main.gd` 里接上 `Ipc.command_received` → 验证全链路。
8. 把三个页面拆成 `panels/*.tscn`，逐个填内容。
9. 做主题（字体 + 标签样式），去掉豆腐块。
10. 配桌面环境快捷键 → 验证后台全局热键。
11. 最后做 Translate / AIChat 的网络请求、导出、自启动。

按这个顺序，每一步都能单独验证，坏了好定位。

---

## 附：关键前提回顾（Wayland 三大约束）

| 约束 | 事实 | 对策 |
|------|------|------|
| 置顶 | Godot 的 `always_on_top` 只在 **X11** 实现，Wayland 本身不支持 | 强制走 XWayland（x11 驱动） |
| 多窗口 | Godot 4.5 起 Wayland 接近 X11 对等，但**不支持原生子窗口** | 同上，走 XWayland |
| 全局热键 | Godot **没有**全局热键 API | 交给桌面环境注册，程序用 UDP 接收命令 |
