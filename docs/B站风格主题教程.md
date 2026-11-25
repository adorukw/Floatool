# Floatool —— B 站风格主题教程

> 目标：把 Floatool 的配色、圆角、标签、按钮、输入框、聊天气泡、设置卡片，统一改成接近 B 站（bilibili）的视觉风格。
>
> 方法：只用 **一个 Theme 资源 + StyleBoxFlat + Type Variation**，不要逐个节点写 `theme_override_*`。
>
> 适用：`assets/ui_theme.tres` 已经存在，并在 Project Settings → Gui → Theme → Custom 里生效。

---

## 目录

- [0. B 站设计语言速查](#0-b-站设计语言速查)
- [1. Godot 主题的三层结构](#1-godot-主题的三层结构)
- [2. 准备工作](#2-准备工作)
- [3. 全局字体与字号](#3-全局字体与字号)
- [4. StyleBoxFlat 常用配方](#4-styleboxflat-常用配方)
- [5. 逐类型配置](#5-逐类型配置)
  - [5.1 PanelContainer](#51-panelcontainer)
  - [5.2 TabContainer](#52-tabcontainer)
  - [5.3 Button 与三套变体](#53-button-与三套变体)
  - [5.4 LineEdit / TextEdit](#54-lineedit--textedit)
  - [5.5 Label 与文字变体](#55-label-与文字变体)
  - [5.6 RichTextLabel](#56-richtextlabel)
  - [5.7 HSeparator](#57-hseparator)
  - [5.8 ScrollBar](#58-scrollbar)
  - [5.9 OptionButton / PopupMenu](#59-optionbutton--popupmenu)
  - [5.10 CheckBox / SpinBox](#510-checkbox--spinbox)
- [6. 各面板怎么套](#6-各面板怎么套)
- [7. 类型变体怎么用](#7-类型变体怎么用)
- [8. 深色模式（可选）](#8-深色模式可选)
- [9. 推荐实施顺序](#9-推荐实施顺序)
- [10. 常见坑](#10-常见坑)
- [11. 验收清单](#11-验收清单)

---

## 0. B 站设计语言速查

### 亮色配色

| 用途 | 颜色 | 说明 |
|------|------|------|
| 主蓝 | `#00AEEC` | 品牌蓝：主按钮、选中、焦点 |
| 经典蓝 | `#00A1D6` | 旧版 B 站蓝，可做 hover |
| 品牌粉 | `#FB7299` | 强调色、用户气泡、Logo 粉 |
| 粉 hover | `#FC8BAB` | 粉色悬停 |
| 主文字 | `#18191C` | 标题/正文 |
| 次文字 | `#61666D` | 说明文字 |
| 弱文字 | `#9499A0` | 占位符/提示 |
| 页面背景 | `#F6F7F8` | 浅灰底 |
| 悬停背景 | `#F1F2F3` | hover / 次级按钮 |
| 卡片/输入框底 | `#FFFFFF` | 白底 |
| 边框/分割线 | `#E3E5E7` | 1px |
| 禁用 | `#C9CCD0` | 灰 |

### 深色配色（备用）

| 用途 | 颜色 |
|------|------|
| 页面背景 | `#17181A` |
| 卡片 | `#1F2023` |
| 次级背景 | `#232427` |
| 边框 | `#2F3134` |
| 主文字 | `#E3E5E7` |
| 次文字 | `#9499A0` |
| 主蓝 | `#00AEEC` |
| 品牌粉 | `#FB7299` |

### 尺寸规范

| 项目 | 建议值 |
|------|--------|
| 基础字号 | `14` 或 `15` |
| 标题字号 | `20`～`22` |
| 小节标题 | `16` |
| 提示文字 | `12` |
| 圆角 | `6`～`8` |
| 控件内边距 | `8`～`12` |
| 按钮高度 | `32`～`36` |
| 标签高度 | `40` 左右 |
| 分割线 | `1px` |

---

## 1. Godot 主题的三层结构

| 层 | 用什么 | 作用 |
|---|---|---|
| 全局主题 | `Theme`（`assets/ui_theme.tres`） | 统一字体、颜色、控件样式 |
| 形状 | `StyleBoxFlat` | 背景色、边框、圆角、内边距、阴影 |
| 变体 | `Theme Type Variation` | 主按钮、次按钮、标题、卡片等 |

运行时关系：

```
Project Settings → Gui → Theme → Custom
        ↓
assets/ui_theme.tres
        ↓
所有 Control 节点自动套用
        ↓
需要特殊样式的节点 → Theme → Type Variation
```

---

## 2. 准备工作

### 2.1 字体

你已经有：

```
assets/fonts/NotoSansCJK-Regular.ttc
assets/fonts/NotoSansCJK-Bold.ttc
```

- Regular 用于正文；
- Bold 用于标题、小节标题、按钮强调。

### 2.2 打开 Theme

双击 `assets/ui_theme.tres`，底部会出现 **Theme 编辑器**。

左侧是 **Types** 列表：

- 点 **Add Type** 可以添加类型（如 `Button`、`LineEdit`）；
- 选中某个类型后，点 **Add Variation** 可以建变体（如 `PrimaryButton`）。

右侧/下方会显示：

- Constants
- Colors
- Fonts
- Font Sizes
- Icons
- Styles

### 2.3 记住一个原则

> **基类保持中性，特殊样式用变体。**
>
> `Button` 基类做成「普通灰按钮」；
> `PrimaryButton`、`SecondaryButton`、`GhostButton` 作为变体。
>
> 这样不会出现「所有按钮都变主蓝」的情况。

---

## 3. 全局字体与字号

选中 Theme 资源本身（不是某个类型），在 Inspector 里设：

| 属性 | 值 |
|------|----|
| `default_font` | `NotoSansCJK-Regular.ttc` |
| `default_font_size` | `14` 或 `15` |

> 如果 Theme 编辑器里看不到 `default_font_size`，直接在 Inspector 的资源属性里加。

---

## 4. StyleBoxFlat 常用配方

在 Theme 编辑器里，点某个 Styles 属性 → **New StyleBoxFlat**，然后在 Inspector 里改。

### 4.1 卡片

| 属性 | 值 |
|------|----|
| `bg_color` | `#FFFFFF` |
| `border_width_left/top/right/bottom` | `1` |
| `border_color` | `#E3E5E7` |
| `corner_radius_*` | `8` |
| `content_margin_left/right` | `12` |
| `content_margin_top/bottom` | `12` |
| `shadow_color` | `#00000012` |
| `shadow_size` | `6` |
| `shadow_offset` | `(0, 2)` |

### 4.2 输入框常态

| 属性 | 值 |
|------|----|
| `bg_color` | `#F6F7F8` |
| `border_width_*` | `1` |
| `border_color` | `#E3E5E7` |
| `corner_radius_*` | `6` |
| `content_margin_left/right` | `8` |
| `content_margin_top/bottom` | `6` |

### 4.3 输入框焦点

| 属性 | 值 |
|------|----|
| `bg_color` | `#FFFFFF` |
| `border_width_*` | `1`（想更明显就 `2`） |
| `border_color` | `#00AEEC` |
| `corner_radius_*` | `6` |
| `content_margin_*` | 与常态一致 |

### 4.4 主按钮

| 状态 | `bg_color` | 说明 |
|------|-----------|------|
| normal | `#00AEEC` | |
| hover | `#00C3FF` | 亮一点 |
| pressed | `#0099D4` | 暗一点 |
| disabled | `#F1F2F3` | 文字用 `#C9CCD0` |

共同：圆角 `6`，`content_margin_left/right = 14`，`top/bottom = 6`。

### 4.5 次按钮

| 状态 | `bg_color` |
|------|-----------|
| normal | `#F1F2F3` |
| hover | `#E3E5E7` |
| pressed | `#D9DDE1` |
| disabled | `#F6F7F8` |

文字：`#18191C`；禁用文字：`#C9CCD0`。

### 4.6 幽灵按钮

- normal / pressed：`StyleBoxEmpty`
- hover：`#F1F2F3`，圆角 `6`
- 文字：`#00AEEC`

### 4.7 选中标签（底部蓝边）

| 属性 | 值 |
|------|----|
| `bg_color` | `#FFFFFF` |
| `border_width_bottom` | `2` |
| `border_color` | `#00AEEC` |
| `corner_radius_top_left/top_right` | `6` |
| `content_margin_left/right` | `12` |
| `content_margin_top/bottom` | `8` |

> 这就是最常见 B 站标签样式：白底 + 底部 2px 蓝边。

---

## 5. 逐类型配置

### 5.1 PanelContainer

Styles → `panel` → 用「4.1 卡片」。

再建一个变体 **`CardPanel`**：

- 同样用 4.1；
- 用于设置页每个区块、翻译结果区、聊天外层。

用法：

- 普通背景：`PanelContainer` 默认；
- 卡片：节点 Inspector → Theme → Type Variation → `CardPanel`。

---

### 5.2 TabContainer

这是 B 站风格最显眼的部分。

在 Theme 编辑器左侧添加 `TabContainer`。

#### Styles

| 属性 | 建议 |
|------|------|
| `panel` | 白底 `#FFFFFF`，圆角 `8` |
| `tabbar_background` | 透明或 `#FFFFFF` |
| `tab_selected` | 用「4.7 选中标签」 |
| `tab_unselected` | `StyleBoxEmpty` |
| `tab_hovered` | `#F1F2F3` 底，圆角 `6` |
| `tab_focus` | `StyleBoxEmpty` 或淡蓝细边 |
| `tab_disabled` | `StyleBoxEmpty` |

#### Colors

| 属性 | 值 |
|------|----|
| `font_selected_color` | `#00AEEC` |
| `font_unselected_color` | `#61666D` |
| `font_hovered_color` | `#00AEEC` |
| `font_disabled_color` | `#C9CCD0` |

#### Constants

| 属性 | 值 |
|------|----|
| `tab_separation` | `4` |
| `side_margin` | `8` |

#### 字体

- `font`：Noto Sans CJK Regular；
- `font_size`：`14` 或 `15`。

> 如果想要「蓝色药丸」风格：
> `tab_selected` 改成 `bg_color = #00AEEC`，`font_selected_color = #FFFFFF`，圆角 6。

---

### 5.3 Button 与三套变体

在 Theme 编辑器里：

1. 添加 `Button` 类型；
2. 配置基类为「普通灰按钮」；
3. 选中 `Button` → **Add Variation** → `PrimaryButton`；
4. 再建 `SecondaryButton`、`GhostButton`。

#### 基类 Button

用「4.5 次按钮」的配方，作为默认按钮。

#### PrimaryButton

- 用「4.4 主按钮」；
- `font_color/hover/pressed` = `#FFFFFF`；
- `font_disabled_color` = `#C9CCD0`。

#### SecondaryButton

- 用「4.5 次按钮」；
- `font_color` = `#18191C`。

#### GhostButton

- 用「4.6 幽灵按钮」；
- `font_color` = `#00AEEC`；
- 注意：节点的 `flat` 要关掉，否则 StyleBox 不生效。

#### 通用 Colors

| 属性 | 值 |
|------|----|
| `font_color` | 按变体 |
| `font_hover_color` | 按变体 |
| `font_pressed_color` | 按变体 |
| `font_disabled_color` | `#C9CCD0` |
| `font_focus_color` | 与 `font_color` 一致 |

---

### 5.4 LineEdit / TextEdit

两个类型分别配，但配方一样。

#### Styles

| 属性 | 用哪个配方 |
|------|-----------|
| `normal` | 4.2 输入框常态 |
| `focus` | 4.3 输入框焦点 |
| `read_only` | `#F1F2F3` 底、`#E3E5E7` 边框、文字 `#9499A0` |

#### Colors

| 属性 | 值 |
|------|----|
| `font_color` | `#18191C` |
| `font_placeholder_color` | `#9499A0` |
| `font_selected_color` | `#FFFFFF` |
| `caret_color` | `#00AEEC` |
| `selection_color` | `#00AEEC` + 低透明度（如 `40`） |
| `current_line_color`（TextEdit） | `#F1F2F3` |

#### Constants

- `line_spacing` = `2`～`4`（TextEdit）
- `caret_width` = `2`

---

### 5.5 Label 与文字变体

#### 基类 Label

- `font_color` = `#18191C`
- `font` = Noto Sans CJK Regular
- `font_size` = `14`

#### 变体

| 变体 | 字号 | 字体 | 颜色 |
|------|------|------|------|
| `TitleLabel` | `22` | Bold | `#18191C` |
| `SectionLabel` | `16` | Bold | `#18191C` |
| `HintLabel` | `12` | Regular | `#9499A0` |

用法：

- 页面大标题 → `TitleLabel`；
- 设置页每个区块标题（便签/翻译/AI 助手/快捷键）→ `SectionLabel`；
- 占位、说明、测试结果 → `HintLabel`。

> 你现在的 Header 是直接写了 `theme_override_font_sizes/font_size = 20`，建议改成 `SectionLabel` 变体，统一管理。

---

### 5.6 RichTextLabel

- `default_color` = `#18191C`
- `normal` StyleBox：
  - 笔记预览：透明；
  - 卡片内：`#FFFFFF`。
- `selection_color` = `#00AEEC` + 低透明度。

如果使用 **MarkdownLabel**（它继承 RichTextLabel），主题会自动套用 `RichTextLabel` 的配置。

---

### 5.7 HSeparator

- Styles → `separator` → 新建 **StyleBoxLine**：
  - `color` = `#E3E5E7`
  - `thickness` = `1`

---

### 5.8 ScrollBar

给 `VScrollBar` 和 `HScrollBar` 分别配（或只配 V）。

| 属性 | 值 |
|------|----|
| `scroll` | `#F1F2F3`，圆角 `4` |
| `grabber` | `#C9CCD0`，圆角 `4` |
| `grabber_highlight` | `#9499A0` |
| `grabber_pressed` | `#61666D` |

想要更细，可以在节点上设 `custom_minimum_size.x = 8`。

---

### 5.9 OptionButton / PopupMenu

#### OptionButton

继承 Button，但通常更矮。建议：

- 用 `SecondaryButton` 的样式；
- `arrow` 图标保持默认；
- `arrow_margin` = `8`。

#### PopupMenu

| 属性 | 值 |
|------|----|
| `panel` | 白底、`#E3E5E7` 边框、圆角 `6`、内容边距 `6` |
| `hover` | `#F1F2F3`，圆角 `4` |
| `separator` | `#E3E5E7` |
| `font_color` | `#18191C` |
| `font_hover_color` | `#00AEEC` |
| `font_disabled_color` | `#C9CCD0` |

Constants：

- `v_separation` = `6`
- `h_separation` = `8`
- `item_start_padding` / `item_end_padding` = `8`

---

### 5.10 CheckBox / SpinBox

#### CheckBox

- `font_color` = `#18191C`
- `font_hover_color` = `#00AEEC`
- 选中图标可以用默认，或者换成蓝色勾。

#### SpinBox

- 它内部的输入部分会套用 `LineEdit` 的样式；
- 上下箭头图标可以保持默认；
- `custom_minimum_size.x` 可设为 `80`～`100`，避免太窄。

---

## 6. 各面板怎么套

### 6.1 主窗口

`windows/floatool_window.tscn`：

| 节点 | 建议 |
|------|------|
| `Root`（PanelContainer） | 默认 `PanelContainer`，白底或 `#F6F7F8` |
| `Layout`（VBox） | 不用改 |
| `Tabs`（TabContainer） | 套用 5.2 的标签样式 |

效果：

- 顶部标签：白底 + 选中蓝边；
- 内容区：白底；
- 整体留白 12px（由 `MarginContainer` 控制）。

### 6.2 便签页

`panels/note_panel.tscn`：

| 节点 | 建议 |
|------|------|
| `TogglePreview`（Button） | `SecondaryButton` 或 `GhostButton` |
| `Editor`（TextEdit） | 套用 5.4 |
| `Preview`（MarkdownLabel/RichTextLabel） | 白底、`#18191C` 文字 |
| `HSplitContainer` | 分割线 `#E3E5E7` |
| `StatusLabel` | `HintLabel` |

### 6.3 翻译页

`panels/translate_panel.tscn`：

| 节点 | 建议 |
|------|------|
| `TranslateButton` | `PrimaryButton` |
| `SwapButton` | `GhostButton` |
| `FromLang` / `ToLang`（OptionButton） | `SecondaryButton` 风格 |
| `Source`（TextEdit） | 5.4 |
| `Result`（RichTextLabel） | 白底卡片、`#18191C`、圆角 8 |
| `TestResult` | `HintLabel` |

### 6.4 AI 页

`panels/ai_chat_panel.tscn` + `components/chat_bubble.tscn`：

| 节点 | 建议 |
|------|------|
| `Input`（TextEdit） | 5.4 |
| `SendButton` | `PrimaryButton` |
| 用户气泡 | `#00AEEC` 或 `#FB7299` 底，白字 |
| AI 气泡 | `#F1F2F3` 底，`#18191C` 字 |

气泡可以在 `ai_chat_panel.gd` 里覆盖：

```gdscript
func _add_bubble(text: String, from_user: bool) -> RichTextLabel:
	var b := BUBBLE.instantiate()
	var label := b.get_node("Margin/Text") as RichTextLabel
	label.text = text

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#00AEEC") if from_user else Color("#F1F2F3")
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6

	b.add_theme_stylebox_override("panel", sb)
	label.add_theme_color_override(
		"default_color",
		Color.WHITE if from_user else Color("#18191C")
	)

	b.size_flags_horizontal = (
		Control.SIZE_SHRINK_END if from_user
		else Control.SIZE_SHRINK_BEGIN
	)
	messages.add_child(b)
	_scroll_to_bottom()
	return label
```

也可以给气泡场景建两个变体：

- `UserBubble`：蓝底白字；
- `AssistantBubble`：浅灰底深字。

然后在 `_add_bubble` 里设 `b.theme_type_variation = "UserBubble"`。

### 6.5 设置页

`panels/settings_panel.tscn`：

| 节点 | 建议 |
|------|------|
| `NoteSection` / `TranslateSection` / `AISection` / `HotKeySection` | 外面包一个 `PanelContainer`，套 `CardPanel` |
| `Header`（Label） | 改成 `SectionLabel` 变体 |
| 所有 `LineEdit` / `TextEdit` / `SpinBox` | 5.4 / 5.10 |
| `SaveButton` | `PrimaryButton` |
| `TestButton` | `SecondaryButton` |
| `TestResult` | `HintLabel` |
| `StatusLabel` | `HintLabel` |

如果不想改结构，也可以直接给 `VBoxContainer` 加 `theme_override`，但不如 `CardPanel` 统一。

---

## 7. 类型变体怎么用

1. 在 Theme 编辑器里选中基类（如 `Button`）；
2. 点 **Add Variation**；
3. 命名 `PrimaryButton`；
4. 配置它的 Styles/Colors；
5. 回到场景，选中目标节点；
6. Inspector → **Theme → Type Variation** → 选 `PrimaryButton`。

同理：

- `Label` → `TitleLabel` / `SectionLabel` / `HintLabel`
- `PanelContainer` → `CardPanel`
- `Button` → `PrimaryButton` / `SecondaryButton` / `GhostButton`
- 气泡 → `UserBubble` / `AssistantBubble`

> 变体是「继承基类 + 覆盖部分属性」。基类改了，变体没覆盖的部分会跟着变。

---

## 8. 深色模式（可选）

准备两份 Theme：

```
assets/ui_theme_light.tres
assets/ui_theme_dark.tres
```

在设置页加一个「深色模式」开关，保存到 `Settings`：

```gdscript
Settings.set_value("ui", "dark_mode", enabled)
Settings.save()
```

运行时切换：

```gdscript
var path := "res://assets/ui_theme_dark.tres" if enabled \
	else "res://assets/ui_theme_light.tres"
get_window().theme = load(path)
```

因为 `FloatoolWindow` 是独立 `Window`，给它设 `theme` 即可。
如果主窗口也要换，再给 `get_tree().root.theme` 设一次。

深色配色参考第 0 节。

---

## 9. 推荐实施顺序

1. 设 `default_font_size`；
2. 配 `PanelContainer` + `TabContainer`（整体观感立刻变）；
3. 配 `Button` 三套变体 + `LineEdit/TextEdit`；
4. 配 `Label` 三个变体；
5. 调 AI 气泡、设置卡片；
6. 最后调滚动条、分割线、PopupMenu 这些细节；
7. 有余力再做深色模式。

每做完一步就运行一次，避免一次性改太多不知道哪里坏了。

---

## 10. 常见坑

| 现象 | 原因 | 解决 |
|------|------|------|
| 按钮颜色没变 | 节点开了 `flat = true` | 关掉 flat，或用 `GhostButton` |
| 输入框焦点没蓝边 | 只配了 `normal`，没配 `focus` | 给 `focus` 也建 StyleBoxFlat |
| 标签选中色不生效 | 改的是 `Label` 颜色 | 要改 `TabContainer` 的 `font_selected_color` |
| 变体在节点上找不到 | Theme 里没建 Type Variation | 在 Theme 编辑器里 Add Variation |
| 所有按钮都变主蓝 | 直接改了 `Button` 基类 | 基类保持中性，用变体 |
| 圆角被裁 | 父节点 `clip_contents` 或背景不透明 | 调整父容器背景/裁剪 |
| 中文变方块 | 字体没设 | Default Font 指到 Noto Sans CJK |
| 输入框文字看不见 | `font_color` 和背景同色 | 检查 LineEdit/TextEdit 的 `font_color` |
| 设置页 Header 字号不统一 | 每个 Label 单独 override | 改用 `SectionLabel` 变体 |
| 滚动条太粗 | 没配 ScrollBar | 用 5.8 的细滚动条 |

---

## 11. 验收清单

- [ ] 顶部标签：未选中灰字、选中蓝字 + 底部蓝边
- [ ] 主按钮：蓝底白字、hover 变亮、pressed 变暗
- [ ] 次按钮：浅灰底深字
- [ ] 输入框：浅灰底、聚焦蓝边
- [ ] 占位符：`#9499A0`
- [ ] 卡片：白底、1px 边框、8px 圆角
- [ ] 分割线：`#E3E5E7`、1px
- [ ] AI 用户气泡：蓝/粉底白字；AI 气泡：浅灰底深字
- [ ] 设置页每个区块有卡片感
- [ ] 中文显示正常，不出现方块
- [ ] 拉伸窗口时布局不破

---

## 一句话总结

**B 站风格 = 蓝 `#00AEEC` + 粉 `#FB7299` + 白/浅灰底 + 1px `#E3E5E7` 边框 + 6～8px 圆角。**
用 **Theme + StyleBoxFlat + Type Variation** 统一管理，先配 Panel/Tab/Button/LineEdit，再配气泡和卡片，最后调细节。不要逐个节点写 `theme_override_*`。
