# Floatool 界面教程：顶部标签页（Note / Translate / AIChat）

> 承接 `docs/Godot实现指南.md`。那篇讲的是**窗口层**的东西：后台常驻、隐藏宿主窗口、独立置顶悬浮窗、IPC 全局热键、XWayland。
> 这一篇只讲**窗口内部**的东西：怎么在一个悬浮窗里做出"顶部一排标签 + 下面切换页面"的界面。
>
> 目标平台：Godot 4.7 stable（与 `project.godot` 里的 `config/features` 一致）/ Linux + Wayland 会话（应用走 XWayland）。
> 本文尽量做到"照着点就能搭出来"，关键处给最小可用的 GDScript。

---

## 目录

- [0. 最终界面长什么样](#0-最终界面长什么样)
- [1. 节点选型：为什么用 TabContainer](#1-节点选型为什么用-tabcontainer)
- [2. 目录结构](#2-目录结构)
- [3. 主悬浮窗场景结构](#3-主悬浮窗场景结构)
- [4. 编辑器逐步操作](#4-编辑器逐步操作)
- [5. 三个页面的具体布局](#5-三个页面的具体布局)
- [6. 脚本：点击切换 + 快捷键切换](#6-脚本点击切换--快捷键切换)
- [7. 主题美化：让标签像"顶部按钮"](#7-主题美化让标签像顶部按钮)
- [8. 窗口行为：拖动 / 置顶 / 关闭=隐藏](#8-窗口行为拖动--置顶--关闭隐藏)
- [9. 运行与验证](#9-运行与验证)
- [10. 常见坑速查](#10-常见坑速查)
- [11. 备选方案：TabBar + 手动切页](#11-备选方案tabbar--手动切页)
- [附录 A：节点速查表](#附录-a节点速查表)

---

## 0. 最终界面长什么样

```
┌────────────────────────────────────────────────┐
│  Floatool                             📌   ✕   │  ← TitleBar（按住可拖动窗口）
├────────────────────────────────────────────────┤
│ ╭──────╮ ┌──────┐ ┌────────┐                   │  ← TabContainer 自带的标签栏
│ │ 便签 │ │ 翻译 │ │ AI问答 │                   │     （点击切换 / 快捷键切换）
│ ╰──────╯ └──────┘ └────────┘                   │
│ ┌────────────────────────────────────────────┐ │
│ │                                            │ │
│ │            当前标签对应的页面内容            │ │
│ │        （Note / Translate / AIChat）        │ │
│ │                                            │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

想要的行为：

1. 三个标签：**便签(Note)** / **翻译(Translate)** / **AI 问答(AIChat)**。
2. 点标签 → 切到对应页面。
3. 按快捷键（建议 `Ctrl+1 / Ctrl+2 / Ctrl+3`）→ 切到对应页面，即使焦点在输入框里也要生效。
4. 每个页面自己记住自己的状态（输入了一半的内容不丢）。

---

## 1. 节点选型：为什么用 TabContainer

Godot 里做"标签页"有三条路，从省事到自由排列：

| 方案 | 节点 | 优点 | 缺点 | 适用 |
|------|------|------|------|------|
| **A. 内置标签容器** | `TabContainer` | 零代码就能点标签切页；自带键盘方向键导航；主题可改 | 标签栏和内容绑在一个节点里，样式自由度中等 | ✅ **本教程首选** |
| B. 只画标签栏 | `TabBar` + 手动切 `visible` | 标签栏与内容分离，布局自由 | 切换逻辑要自己写 | 想把标签栏放到标题栏里时 |
| C. 纯按钮 | 一排 `Button` + 自己管 `visible` | 最自由，最像 Qt 的 `QToolBar + QStackedWidget` | 全手写 | 要做出完全自定义的分段控件时 |

`TabContainer` 就等价于 Qt 里的 `QTabWidget`：**它的每一个直接子 Control 节点会自动变成一页**，非 Control 子节点会被忽略。标签标题默认取子节点名，可以用 `set_tab_title()` 覆盖。

### 会用到的节点清单

| 节点 | 作用 |
|------|------|
| `Window` | 场景根，真正的独立系统窗口（悬浮窗） |
| `PanelContainer` | 铺满窗口，提供背景色 / 圆角 |
| `VBoxContainer` | 纵向排：标题栏 + 标签区 |
| `HBoxContainer` | 标题栏：标题 + 占位 + 按钮 |
| `TabContainer` | **核心**：顶部标签 + 页面切换 |
| `MarginContainer` | 给页面留内边距 |
| `TextEdit` | 多行输入（笔记内容、翻译原文、AI 输入框） |
| `RichTextLabel` | 富文本显示（Markdown 预览、翻译结果、AI 回复气泡） |
| `HSplitContainer` | 左右分栏（编辑 / 预览） |
| `ScrollContainer` | 聊天记录滚动区 |
| `Button` / `OptionButton` | 按钮 / 下拉选择（语言、模型） |
| `HTTPRequest` | 调翻译 / AI 接口 |

---

## 2. 目录结构

在 FileSystem 面板里建好这些目录（`res://` 右键 → New Folder）：

```
res://
├── main.tscn / main.gd             # 隐藏宿主窗口（见《Godot实现指南》第四步）
├── autoload/
│   ├── ipc.gd                      # 接收 UDP 全局命令
│   └── window_manager.gd           # 功能名 → 窗口实例的映射与 toggle
├── windows/
│   ├── base_window.gd              # 通用窗口基类：无边框/置顶/关闭=隐藏
│   └── floatool_window.tscn/.gd    # ★ 本教程主角：带标签页的主悬浮窗
├── panels/                         # 三个标签页各自独立成场景
│   ├── note_panel.tscn/.gd
│   ├── translate_panel.tscn/.gd
│   └── ai_chat_panel.tscn/.gd
└── assets/
    ├── fonts/                      # 中文字体（避免豆腐块）
    └── ui_theme.tres               # 全局主题
```

> **为什么每个页面独立成一个场景？** 和 Qt 里把每个页面写成独立 `QWidget` 一个道理：互不干扰、可以单独打开调试、主窗口只负责"切换"。三个页面以后各自长大也不会挤在一个文件里。

---

## 3. 主悬浮窗场景结构

```
FloatoolWindow (Window)                 ← 真正的系统窗口，Borderless + Always On Top
└── Root (PanelContainer)               ← 锚点 = Full Rect，铺满窗口
    └── Layout (VBoxContainer)
        ├── TitleBar (HBoxContainer)    ← 按住这里拖动窗口
        │   ├── Title (Label)           "Floatool"
        │   ├── Spacer (Control)        size_flags_horizontal = Expand Fill（把后面按钮顶到右边）
        │   ├── PinButton (Button)      "📌" 切换置顶（可选）
        │   └── CloseButton (Button)    "✕"  关闭 = 隐藏窗口
        └── Tabs (TabContainer)         ← ★ 标签栏 + 页面，size_flags_vertical = Expand Fill
            ├── Note (MarginContainer)      ← 子节点名 = 英文，标题用 set_tab_title 显示中文
            │   └── （见 5.1，实际内容建议换成实例化的 note_panel.tscn）
            ├── Translate (MarginContainer) ← 见 5.2
            └── AIChat (MarginContainer)    ← 见 5.3
```

三个要点：

1. **`Window` 不会自动给子节点排版**，所以 `Root` 必须设成 Full Rect 锚点，否则界面尺寸是 0，什么都看不见。
2. `TabContainer` 的 `size_flags_vertical` 要设成 **Expand Fill**，它才会"吃掉"标题栏以下的全部高度。
3. 标签页子节点**用英文名**（`Note`/`Translate`/`AIChat`），显示中文交给代码里的 `set_tab_title()`——这样以后要做多语言也不用改节点名。

---

## 4. 编辑器逐步操作

### 4.1 新建主窗口场景

1. `Ctrl+N` 新建场景。
2. Scene 面板点 **Other Node**（不是 "User Interface"）→ 搜 `Window` → **Create**。
   - ⚠️ 必须用 `Window` 当根，不能用 `Control`/`Node2D`。理由见《Godot实现指南》5.1。
3. `F2` 改名 `FloatoolWindow`。
4. 选中它，Inspector 里设：

| 属性 | 值 |
|------|----|
| Title | `Floatool` |
| Size | `420 × 560`（初始值，之后可由代码改） |
| Borderless | 开 |
| Unresizable | 开 |
| Always On Top | 开 |
| Transient | **关**（开了置顶会失效） |
| Transparent | 关 |

### 4.2 铺 Root 与 Layout

1. 右键 `FloatoolWindow` → **Add Child Node** → 搜 `PanelContainer` → 创建，改名 `Root`。
2. 选中 `Root` → 顶部工具栏 **Layout → Anchors Preset → Full Rect**（四角对齐那个图标）。这一步是"铺满窗口"的关键。
3. 右键 `Root` → 加一个 `VBoxContainer`，改名 `Layout`（`PanelContainer` 会自动撑满它，不用手动设锚点）。
4. 选中 `Layout`，在 Inspector 的 **Theme Overrides → Constants** 里新增 `separation`，值设 `0`（让标题栏和标签区贴紧）。

### 4.3 加标题栏

1. 右键 `Layout` → 加 `HBoxContainer`，改名 `TitleBar`。
2. 右键 `TitleBar` 依次加：
   - `Label`，改名 `Title`，`text = "Floatool"`（左侧留白可用 `TitleBar` 的 theme constant `separation` 或给 Label 加 MarginContainer）。
   - `Control`，改名 `Spacer`，Inspector → Layout → **Size Flags Horizontal = Expand Fill**（点那个"→|"图标）。它会把后面的按钮推到最右。
   - `Button`，改名 `PinButton`，`text = "📌"`，`flat = true`。
   - `Button`，改名 `CloseButton`，`text = "✕"`，`flat = true`。

### 4.4 加 TabContainer 和三个页面

1. 右键 `Layout` → 加 `TabContainer`，改名 `Tabs`。
2. 选中 `Tabs`，Inspector 里设：

| 属性 | 值 | 说明 |
|------|----|------|
| Layout → Size Flags Vertical | **Expand Fill** | 吃掉剩余高度 |
| Tab Alignment | Left（默认） | 标签靠左 |
| Clip Tabs | 开 | 标签多了也不撑大窗口 |
| Tab Focus Mode | `All`（或 `Click`） | 允许 Tab 键聚焦到标签栏，然后用方向键切换 |
| Tabs Position | Top（默认） | 标签栏在上 |

3. 右键 `Tabs` 三次，分别加 3 个 `MarginContainer`（或直接 `VBoxContainer`），改名：
   - `Note`
   - `Translate`
   - `AIChat`

   每加一个 Control 子节点，标签栏就自动多一个标签。此时**运行就能点标签切页了**——`TabContainer` 已经帮你搞定。
4. 给每个 `MarginContainer` 设 **Theme Overrides → Constants** 的 `margin_*`（如 8），做出页面内边距。

> **提示**：单个页面内容多起来之后，建议把 `Note` 这个节点右键 → **Change Type** 换成实例化场景，或者删掉后 **Instantiate Child Scene** 选 `panels/note_panel.tscn`。`TabContainer` 只要求子节点是 Control，实例化场景一样能当标签页。

### 4.5 保存

`Ctrl+S`，保存为 `res://windows/floatool_window.tscn`。

---

## 5. 三个页面的具体布局

### 5.1 便签页 Note

```
Note (MarginContainer)
└── VBox (VBoxContainer)
    ├── Toolbar (HBoxContainer)
    │   ├── TogglePreview (Button)  "👁 预览"
    │   ├── Spacer (Control)        Expand Fill
    │   └── StatusLabel (Label)     "已保存"
    └── Split (HSplitContainer)     size_flags_vertical = Expand Fill
        ├── Editor (TextEdit)       placeholder = "在这里输入 Markdown..."
        └── Preview (RichTextLabel) bbcode_enabled = 开, fit_content = 开, scroll_active = 开
```

几个设置：

- `HSplitContainer` 两个子节点都要能横向伸展（`size_flags_horizontal` 默认就是 Fill；把 `Split` 的 `split_offset` 调成一半宽度做初始比例）。
- `TextEdit` 里 `wrap_mode = Boundary`（自动换行），`placeholder_text` 写提示。
- **Markdown 注意**：`RichTextLabel` 渲染的是 **BBCode**，不是 Markdown。要么自己写一个简单的 md→bbcode 转换，要么先用 `RichTextLabel` 显示纯文本/自己渲染。想要真正的 Markdown 渲染，需要自己实现或用社区插件（Godot 没有内置 md 渲染器）。

便签页脚本要点（`panels/note_panel.gd`，`extends MarginContainer`）：

```gdscript
extends MarginContainer

const SAVE_PATH = "user://note.md"

@onready var editor: TextEdit = $VBox/Split/Editor

func _ready() -> void:
    _load()
    editor.text_changed.connect(_on_text_changed)
    $VBox/Toolbar/TogglePreview.pressed.connect(_toggle_preview)

func _load() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        editor.text = FileAccess.get_file_as_string(SAVE_PATH)

func _on_text_changed() -> void:
    $VBox/Toolbar/StatusLabel.text = "未保存"

func _toggle_preview() -> void:
    var preview := $VBox/Split/Preview as RichTextLabel
    preview.visible = not preview.visible

# 页面被切走时调用（由主窗口脚本触发）
func deactivate() -> void:
    _save()

func _save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(editor.text)
        f.close()
    $VBox/Toolbar/StatusLabel.text = "已保存"
```

### 5.2 翻译页 Translate

```
Translate (MarginContainer)
└── VBox (VBoxContainer)
    ├── LangBar (HBoxContainer)
    │   ├── FromLang (OptionButton)   源语言
    │   ├── SwapButton (Button)       "⇄"
    │   ├── ToLang (OptionButton)     目标语言
    │   └── Spacer (Control)          Expand Fill
    ├── Split (HSplitContainer)       size_flags_vertical = Expand Fill
    │   ├── Source (TextEdit)
    │   └── Result (RichTextLabel)
    └── BottomBar (HBoxContainer)
        ├── Spacer (Control)          Expand Fill
        └── TranslateButton (Button)  "翻译"
```

- `OptionButton` 的选项在 Inspector → **Items** 里逐条加（Text / Id）。
- 网络请求：在这个页面的节点树里加一个 `HTTPRequest` 子节点。它的 `request_completed` 信号连到脚本，收到 JSON 后填到 `Result`。
- 交换语言按钮：把两个 `OptionButton.selected` 交换即可。

```gdscript
extends MarginContainer

@onready var source: TextEdit = $VBox/Split/Source
@onready var result: RichTextLabel = $VBox/Split/Result
@onready var http: HTTPRequest = $HTTPRequest

func _ready() -> void:
    $VBox/BottomBar/TranslateButton.pressed.connect(_translate)

func _translate() -> void:
    # 以某种翻译 API 为例，具体 URL / 参数按你的服务改
    var body := JSON.stringify({"q": source.text, "target": "en"})
    var headers := ["Content-Type: application/json"]
    http.request("https://example.com/api/translate", headers, HTTPClient.METHOD_POST, body)

func _on_http_request_completed(result_code: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result_code != HTTPRequest.RESULT_SUCCESS or code != 200:
        result.text = "请求失败"
        return
    var data = JSON.parse_string(body.get_string_from_utf8())
    result.text = str(data.get("translatedText", ""))
```

> **快捷键**：在 `TextEdit` 里按 `Ctrl+Enter` 触发翻译是个好习惯。见 6.4。

### 5.3 AI 问答页 AIChat

聊天记录是"动态列表"，所以用 `ScrollContainer` + 一个 `VBoxContainer` 当容器，运行时往里塞"气泡"。

```
AIChat (VBoxContainer)
├── Scroll (ScrollContainer)          size_flags_vertical = Expand Fill
│   └── Messages (VBoxContainer)      size_flags_horizontal = Expand Fill
└── InputBar (HBoxContainer)
    ├── Input (TextEdit)              custom_minimum_size.y = 48, Expand Fill
    └── SendButton (Button)           "发送"
```

气泡建议单独做一个场景 `panels/chat_bubble.tscn`：

```
ChatBubble (PanelContainer)
└── Margin (MarginContainer)
    └── Text (RichTextLabel)   fit_content = 开, bbcode_enabled = 开
```

运行时实例化并加入：

```gdscript
extends VBoxContainer

const BUBBLE = preload("res://panels/chat_bubble.tscn")

@onready var messages: VBoxContainer = $Scroll/Messages
@onready var input: TextEdit = $InputBar/Input
@onready var scroll: ScrollContainer = $Scroll

func _ready() -> void:
    $InputBar/SendButton.pressed.connect(_send)

func add_bubble(text: String, from_user: bool) -> void:
    var b := BUBBLE.instantiate()
    b.get_node("Margin/Text").text = text
    b.size_flags_horizontal = Control.SIZE_SHRINK_END if from_user else Control.SIZE_SHRINK_BEGIN
    messages.add_child(b)
    # 让滚动条自动到底
    await get_tree().process_frame
    scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _send() -> void:
    var t := input.text.strip_edges()
    if t.is_empty():
        return
    add_bubble(t, true)
    input.text = ""
    # 这里调用 AI 接口，拿到回复后 add_bubble(reply, false)
```

> **流式输出提醒**：`HTTPRequest` 是"一次性拿完整响应"，**不支持 SSE 逐字返回**。要做打字机效果，得改用 `HTTPClient` 手动读分块，或用 `StreamPeerTCP` 自己处理。第一版先用 `HTTPRequest` 拿完整结果即可。

---

## 6. 脚本：点击切换 + 快捷键切换

点击切换 `TabContainer` 天然就支持，你什么都不用写。真正要写的是**快捷键**和**页面激活/失活回调**。

### 6.1 主窗口脚本（`windows/floatool_window.gd`，`extends Window`）

```gdscript
extends Window

const PAGE_TITLES = ["便签", "翻译", "AI 问答"]

@onready var tabs: TabContainer = $Root/Layout/Tabs
@onready var close_button: Button = $Root/Layout/TitleBar/CloseButton

func _ready() -> void:
    # 1) 节点名保持英文，这里显示中文标题
    for i in PAGE_TITLES.size():
        tabs.set_tab_title(i, PAGE_TITLES[i])

    # 2) 切换时通知对应页面
    tabs.tab_changed.connect(_on_tab_changed)

    # 3) 关闭 = 隐藏，不退出进程
    close_button.pressed.connect(hide)

    # 4) 默认停在便签页
    tabs.current_tab = 0
    _on_tab_changed(0)

func _on_tab_changed(idx: int) -> void:
    # 让被切走的页面有机会保存
    for i in tabs.get_tab_count():
        var page := tabs.get_tab_control(i)
        if i == idx:
            if page.has_method("activate"):
                page.activate()
        else:
            if page.has_method("deactivate"):
                page.deactivate()
```

每个页面的脚本里按需实现这两个方法（没有也不影响，`has_method` 会兜底）：

```gdscript
func activate() -> void:
    # 页面出现时：聚焦输入框、刷新数据等
    $VBox/Split/Editor.grab_focus()

func deactivate() -> void:
    # 页面被切走时：保存、暂停请求等
    pass
```

### 6.2 定义快捷键动作（Input Map）

菜单 **Project → Project Settings → Input Map**：

1. 在输入框里填 `tab_note`，点 **Add**。
2. 展开 `tab_note`，点 **+**，按下 `Ctrl+1`，OK。
3. 同样加：
   - `tab_translate` → `Ctrl+2`
   - `tab_aichat` → `Ctrl+3`
   - `tab_next` → `Ctrl+Tab`
   - `tab_prev` → `Ctrl+Shift+Tab`
   - `toggle_window` → `Ctrl+Shift+Space`（可选，窗口显示/隐藏）

### 6.3 用 `_input()` 处理切换（**推荐**）

在 `floatool_window.gd` 里加：

```gdscript
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("tab_note"):
        _select(0)
    elif event.is_action_pressed("tab_translate"):
        _select(1)
    elif event.is_action_pressed("tab_aichat"):
        _select(2)
    elif event.is_action_pressed("tab_next"):
        tabs.select_next_available()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("tab_prev"):
        tabs.select_previous_available()
        get_viewport().set_input_as_handled()

func _select(idx: int) -> void:
    tabs.current_tab = idx
    get_viewport().set_input_as_handled()
```

**为什么用 `_input()` 而不是 `_unhandled_input()`？**

事件传播顺序是：`_input()` → GUI（`_gui_input()`，含 `TextEdit`）→ `_shortcut_input()` → `_unhandled_key_input()` → `_unhandled_input()`。

`TextEdit`／`LineEdit` 获得焦点时，会把**一部分**按键事件在 GUI 阶段就消费掉（`Ctrl+Tab` 是典型例子——社区一直有人抱怨"在输入框里按 `Ctrl+Tab` 切不出去"）。而便签页、AI 输入框这些 `TextEdit` 常年霸占焦点，所以：

- 用 `_input()` 能在 GUI 之前拦到按键 → **无论焦点在哪都稳定生效**。✅
- 用 `_unhandled_input()` 时，凡是被输入框吃掉的那部分组合键就收不到了，行为不稳定 → ⚠️ 不推荐

安全性：`Ctrl+1/2/3`、`Ctrl+Tab` 这些组合不会产生文字输入，在 `_input()` 里拦截**不会**影响正常打字。记得处理完调 `set_input_as_handled()`，避免重复触发。

> 如果你更想走"GUI 优先"的路线，也可以用 `_unhandled_input()`，但要把这些快捷键避开会被输入框吃掉的组合，风险更高，不推荐。

### 6.4 页面内的快捷键

同样的道理，页面里的"`Ctrl+Enter` 发送/翻译"也建议用 `_input()`（或给 `TextEdit` 连 `text_submitted`，但那需要 `Enter` 提交）：

```gdscript
# 在 translate_panel.gd / ai_chat_panel.gd 里
func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and event.ctrl_pressed:
        _translate()   # 或 _send()
        get_viewport().set_input_as_handled()
```

注意加 `if not visible: return`——否则三个页面会同时响应同一个组合键。

### 6.5 记忆上次所在的标签（可选）

用 `ConfigFile` 存到 `user://settings.cfg`：

```gdscript
const CFG = "user://settings.cfg"

func _save_tab(idx: int) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("ui", "last_tab", idx)
    cfg.save(CFG)

func _load_tab() -> int:
    var cfg := ConfigFile.new()
    if cfg.load(CFG) == OK:
        return cfg.get_value("ui", "last_tab", 0)
    return 0
```

在 `_ready()` 里 `tabs.current_tab = _load_tab()`，在 `_on_tab_changed()` 里 `_save_tab(idx)`。

---

## 7. 主题美化：让标签像"顶部按钮"

默认的 `TabContainer` 标签偏"方盒子"，想做成现代桌面应用那种"顶部一排按钮"，用 **Theme 资源** 改。整个流程和《Godot实现指南》第七步一致，这里补充 `TabContainer` 相关的部分。

1. FileSystem 右键 → **New Resource** → 搜 `Theme` → 保存为 `assets/ui_theme.tres`。
2. 双击打开，底部出现 **Theme 编辑器**。左侧 **Types** 列表里找 `TabContainer`，逐项改：

| 项目 | 类型 | 建议值 | 效果 |
|------|------|--------|------|
| `panel` | StyleBoxFlat | 背景色 + 圆角 | 内容区背景 |
| `tabbar_background` | StyleBoxFlat | 与背景同色或透明 | 标签条底色 |
| `tab_selected` | StyleBoxFlat | 高亮色 + Corner Radius 6 | 选中标签 |
| `tab_unselected` | StyleBoxEmpty | 空 | 未选中不画底 |
| `tab_hovered` | StyleBoxFlat | 半透明高亮 | 悬停反馈 |
| `font_selected_color` | Color | 深色 | 选中文字 |
| `font_unselected_color` | Color | 灰色 | 未选中文字 |
| `font_hovered_color` | Color | 略深 | 悬停文字 |
| `tab_separation` | int | `4` | 标签之间留缝 |
| `side_margin` | int | `8` | 左右边距 |

3. **中文字体**：在 Theme 编辑器顶部 **Default Font** 指向你的 CJK 字体（如 Noto Sans CJK）。否则中文会是豆腐块。
4. 应用：
   - 全局：Project Settings → **Gui → Theme → Custom** → 选 `ui_theme.tres`；
   - 或只给这个窗口：选中 `FloatoolWindow`，Inspector → **Theme** → 指到该资源。

> 小技巧：`tab_unselected` 用 **`StyleBoxEmpty`**（空样式），配合 `tab_selected` 的圆角高亮，立刻就有"分段控件（segmented control）"的味道，很接近现代标签栏。

---

## 8. 窗口行为：拖动 / 置顶 / 关闭=隐藏

这几项是"悬浮窗"的通用行为，逻辑上应该抽到 `windows/base_window.gd` 里（`extends Window`），让 `FloatoolWindow` 继承它。详细说明见《Godot实现指南》第五、六步，这里只列关键点。

### 8.1 拖动窗口

给 `TitleBar`（`HBoxContainer`）挂一个很小的脚本，或者直接在 `floatool_window.gd` 里连 `TitleBar.gui_input`：

```gdscript
func _ready() -> void:
    # ...其他初始化
    var title_bar: HBoxContainer = $Root/Layout/TitleBar
    title_bar.gui_input.connect(_on_title_bar_input)

func _on_title_bar_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
            and event.button_index == MOUSE_BUTTON_LEFT \
            and event.pressed:
        if DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
            DisplayServer.window_start_drag(get_window_id())
```

- `window_start_drag` 的 `window_id` 默认是 `0`（也就是那个被隐藏的宿主主窗口）。要让"拖的是这个悬浮窗"，必须传 `get_window_id()`——漏掉它就会去拖隐藏的主窗口，表现为"按了没反应"。
- 先判 `has_feature(FEATURE_WINDOW_DRAG)` 再调用，跨平台 / 跨驱动更稳。
- 只在 `TitleBar` 上响应拖动，标题栏里的按钮要吃掉自己的点击（Button 默认就会消费鼠标事件），所以点按钮不会误触拖动。

### 8.2 关闭按钮 = 隐藏

```gdscript
close_button.pressed.connect(hide)
```

不要连 `get_tree().quit()`——那会退出整个进程，丢掉"后台常驻"。真正的退出由一个单独的出口（托盘菜单 / `toggle_window` 之外的 `quit` 命令）负责。

### 8.3 Wayland 注意（见已有文档）

- 项目设置 **Display → Display Server → Driver → linuxbsd = `x11`**，强制走 XWayland。否则 `Always On Top` 和多窗口在原生 Wayland 下不可用。
- 全局热键 Godot 没有 API，交给桌面环境注册 + UDP 发给 `Ipc` Autoload，再转发给 `WindowManager`（见《Godot实现指南》第六、十步）。

---

## 9. 运行与验证

1. **关掉编辑器内嵌游戏**：Editor → Editor Settings 搜 `embed`，把 "Embed Game on Play" 关掉（否则看不出多窗口效果）。
2. `F5` 运行。
3. 若主窗口被隐藏，看不到东西是正常的：用 Scene 面板顶部的 **Remote** 标签，把 `FloatoolWindow` 的 `visible` 勾上，确认它以独立窗口弹出并置顶。
4. 检查：
   - 点三个标签能切页；
   - `Ctrl+1/2/3` 在**输入框有焦点时**也能切；
   - 拖动标题栏能移动窗口；
   - 关闭按钮只是隐藏；
   - 中文不显示豆腐块。
5. 模拟全局命令（承接已有文档）：

   ```bash
   echo -n note | nc -u 127.0.0.1 45670
   ```

---

## 10. 常见坑速查

| 现象 | 原因 | 解决 |
|------|------|------|
| 界面完全看不到 / 尺寸是 0 | `Window` 的子 Control 没铺满 | `Root` 用 **Anchors Preset → Full Rect** |
| 标签栏把窗口撑得越来越宽 | `Clip Tabs` 关着 | 打开 `Clip Tabs` |
| 标签区没有撑满高度，下面留白 | `Tabs` 的竖向 Size Flags 没设 | 设成 **Expand Fill** |
| 标签标题是英文节点名 | 没调 `set_tab_title` | `_ready` 里循环设中文标题 |
| 输入框里按 `Ctrl+1` 不切标签 | 焦点在 `TextEdit`，`_unhandled_input` 收不到 | 改用 `_input()`，见 6.3 |
| 三个页面同时响应一个快捷键 | 没判 `visible` | 页面脚本里 `if not visible: return` |
| 拖动标题栏没反应 | `window_start_drag` 没传 window id | 传 `get_window_id()` |
| 拖动时点到了按钮也拖 | 拖动区域太大 | 只在 `TitleBar` 上响应，让 Button 吃掉点击 |
| 置顶无效 | 驱动不是 x11 / 开了 Transient | 设 `driver.linuxbsd = x11`，关 Transient |
| 中文变方块 | 没配 CJK 字体 | Theme → Default Font 指到中文字体 |
| Markdown 预览没效果 | `RichTextLabel` 只认 BBCode | 自己写 md→bbcode，或先用纯文本 |
| AI 回复是"一次性蹦出来" | `HTTPRequest` 不支持流式 | 改用 `HTTPClient` / `StreamPeerTCP` |

---

## 11. 备选方案：TabBar + 手动切页

当你希望**标签栏单独放在标题栏里**、或想完全自定义标签外观与切换动画时，可以把 `TabContainer` 拆成 `TabBar` + 手动管 `visible`：

```
Layout (VBoxContainer)
├── TitleBar (HBoxContainer)
│   ├── Title (Label)
│   └── TabBar (TabBar)              ← 只画标签，不管内容
└── Pages (Control)                  ← 手动管可见性
    ├── Note (MarginContainer)
    ├── Translate (MarginContainer)
    └── AIChat (MarginContainer)
```

```gdscript
extends Window

@onready var tab_bar: TabBar = $Layout/TitleBar/TabBar
@onready var pages: Control = $Layout/Pages

func _ready() -> void:
    tab_bar.add_tab("便签")
    tab_bar.add_tab("翻译")
    tab_bar.add_tab("AI 问答")
    tab_bar.tab_changed.connect(_show_page)
    _show_page(0)

func _show_page(idx: int) -> void:
    for i in pages.get_child_count():
        pages.get_child(i).visible = (i == idx)
    tab_bar.current_tab = idx
```

快捷切换时只需 `tab_bar.current_tab = 2`（或调 `_show_page(2)`），`tab_changed` 会回调到 `_show_page`。

> `TabBar` 和 `TabContainer` 暴露的属性/主题项基本一致（`add_tab`、`tab_changed`、`tab_selected`、`current_tab`、`select_next_available`、`tab_alignment`、`side_margin`…），迁移成本很低。
> 一句话选型：**能接受"标签栏在内容区顶部"→ 用 `TabContainer`；要把标签栏并进标题栏 → 用 `TabBar`。**

---

## 附录 A：节点速查表

| 需求 | 节点 |
|------|------|
| 真正的系统悬浮窗 | `Window` |
| 铺满窗口 / 背景与圆角 | `PanelContainer` + Full Rect 锚点 |
| 纵向 / 横向排版 | `VBoxContainer` / `HBoxContainer` |
| 把某些控件推到另一端 | `Control` + size flags **Expand Fill** |
| 页面留白 | `MarginContainer` |
| 顶部标签 + 切页 | `TabContainer`（或 `TabBar` + 手动） |
| 多行输入 | `TextEdit` |
| 富文本显示 | `RichTextLabel`（BBCode，非 Markdown） |
| 左右分栏 | `HSplitContainer` |
| 可滚动列表 | `ScrollContainer` + `VBoxContainer` |
| 下拉选择 | `OptionButton` |
| 调 HTTP 接口 | `HTTPRequest`（一次性）/ `HTTPClient`（流式） |
| 拖动窗口 | `DisplayServer.window_start_drag(get_window_id())` |
| 键盘快捷键 | Input Map 动作 + `_input()` + `is_action_pressed()` |

---

## 建议的实操顺序

1. 建 `floatool_window.tscn`：`Window` → `Root`(Full Rect) → `Layout` → `TitleBar` + `Tabs`。
2. `Tabs` 下塞 3 个 `MarginContainer`，各放一个 `Label`，先验证**点击切页**。
3. 挂 `floatool_window.gd`，`set_tab_title` 出中文，验证标题。
4. 配 Input Map，加 `_input()`，验证**快捷键切页**（重点测输入框有焦点时）。
5. 把三个页面抽成 `panels/*.tscn`，逐个填充内容。
6. 做主题（字体 + 标签样式），去掉豆腐块。
7. 接 `base_window.gd` 的拖动 / 置顶 / 关闭=隐藏，并用 IPC 全局热键唤出窗口。
8. 最后做 Translate / AIChat 的网络请求与流式输出。

按这个顺序，每一步都能单独验证，坏了好定位。
