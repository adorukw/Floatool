class_name FloatoolWindow
extends Window

const COMMAND_TO_TAB = { "note": 0, "translate": 1, "aichat": 2, "settings": 3 }
const PAGE_TITLES = ["便签", "翻译", "AI问答", "设置"]

@onready var tabs: TabContainer = $Root/Layout/Tabs


func _ready() -> void:
	for i in PAGE_TITLES.size():
		tabs.set_tab_title(i, PAGE_TITLES[i])
	close_requested.connect(hide)

	tabs.current_tab = 0

	tabs.tab_changed.connect(_on_tab_changed)
	focus_entered.connect(_on_focus_entered)


func _on_tab_changed(idx: int) -> void:
	var page := tabs.get_tab_control(idx)
	if page and page.has_method("activate"):
		page.activate()


func _on_focus_entered() -> void:
	var page := tabs.get_tab_control(tabs.current_tab)
	if page and page.has_method("activate"):
		page.activate()


func show_page(command: String) -> void:
	tabs.current_tab = COMMAND_TO_TAB.get(command, 0)
	show()
	grab_focus()
	_on_tab_changed(tabs.current_tab)


func current_command() -> String:
	for cmd in COMMAND_TO_TAB:
		if COMMAND_TO_TAB[cmd] == tabs.current_tab:
			return cmd
	return ""
