class_name FloatoolWindow
extends Window

const COMMAND_TO_TAB = { "note": 0, "translate": 1, "aichat": 2 }
const PAGE_TITLES = ["便签", "翻译", "AI问答"]

@onready var tabs: TabContainer = $Root/Layout/Tabs
@onready var close_button: Button = $Root/Layout/TitleBar/CloseButton


func _ready() -> void:
	for i in PAGE_TITLES.size():
		tabs.set_tab_title(i, PAGE_TITLES[i])

	close_button.pressed.connect(hide)
	close_requested.connect(hide)

	tabs.current_tab = 0


func show_page(command: String) -> void:
	tabs.current_tab = COMMAND_TO_TAB.get(command, 0)
	show()
	grab_focus()


func current_command() -> String:
	for cmd in COMMAND_TO_TAB:
		if COMMAND_TO_TAB[cmd] == tabs.current_tab:
			return cmd
	return ""
