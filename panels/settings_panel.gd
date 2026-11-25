extends MarginContainer

# 便签
@onready var note_path: LineEdit = $Layout/Scroll/Content/NoteSection/Grid/PathRow/PathField
@onready var browse_button: Button = $Layout/Scroll/Content/NoteSection/Grid/PathRow/BrowseButton
@onready var open_folder_button: Button = $Layout/Scroll/Content/NoteSection/Grid/OpenFolderButton

# 翻译
@onready var deepl_url: LineEdit = $Layout/Scroll/Content/TranslateSection/Grid/UrlField
@onready var deepl_key: LineEdit = $Layout/Scroll/Content/TranslateSection/Grid/KeyRow/KeyField
@onready var show_deepl_key_button: Button = $Layout/Scroll/Content/TranslateSection/Grid/KeyRow/ShowKeyButton
@onready var source_lang: LineEdit = $Layout/Scroll/Content/TranslateSection/Grid/SourceLang
@onready var target_lang: LineEdit = $Layout/Scroll/Content/TranslateSection/Grid/TargetLang
@onready var deepl_test_button: Button = $Layout/Scroll/Content/TranslateSection/TestRow/TestButton
@onready var deepl_test_result: Label = $Layout/Scroll/Content/TranslateSection/TestRow/TestResult
@onready var deepl_http: HTTPRequest = $DeepLTestHttp

# AI
@onready var ai_url: LineEdit = $Layout/Scroll/Content/AISection/Grid/UrlField
@onready var ai_model: LineEdit = $Layout/Scroll/Content/AISection/Grid/ModelField
@onready var ai_key: LineEdit = $Layout/Scroll/Content/AISection/Grid/KeyRow/KeyField
@onready var ai_prompt: TextEdit = $Layout/Scroll/Content/AISection/Grid/SystemPrompt
@onready var ai_history: SpinBox = $Layout/Scroll/Content/AISection/Grid/SpinBox
@onready var ai_test_button: Button = $Layout/Scroll/Content/AISection/TestRow/TestButton
@onready var ai_test_result: Label = $Layout/Scroll/Content/AISection/TestRow/TestResult
@onready var ai_http: HTTPRequest = $AITestHttp
@onready var show_ai_key_button: Button = $Layout/Scroll/Content/AISection/Grid/KeyRow/ShowKeyButton

# 底部
@onready var status_label: Label = $Layout/BottomBar/StatusLabel
@onready var save_button: Button = $Layout/BottomBar/SaveButton

# 其他
@onready var scroll: ScrollContainer = $Layout/Scroll
@onready var hotkey_label: Label = $Layout/Scroll/Content/HotKeySection/Label
@onready var copy_hotkey_button: Button = $Layout/Scroll/Content/HotKeySection/CopyButton


func _ready() -> void:
	browse_button.pressed.connect(_on_browse_pressed)
	open_folder_button.pressed.connect(_on_open_folder_pressed)
	show_deepl_key_button.pressed.connect(_on_show_deepl_key_pressed)
	save_button.pressed.connect(_on_save_pressed)
	deepl_test_button.pressed.connect(_on_deepl_test_pressed)
	ai_test_button.pressed.connect(_on_ai_test_pressed)
	copy_hotkey_button.pressed.connect(_on_copy_hotkey_pressed)

	deepl_http.request_completed.connect(_on_deepl_test_completed)
	ai_http.request_completed.connect(_on_ai_test_completed)
	show_ai_key_button.pressed.connect(_on_show_ai_key_pressed)

	_load_from_settings()


func activate() -> void:
	scroll.scroll_vertical = 0


func _load_from_settings() -> void:
	note_path.text = Settings.note_path()

	deepl_url.text = Settings.deepl_url()
	deepl_key.text = str(Settings.get_value("translate", "deepl_key", ""))
	source_lang.text = str(Settings.get_value("translate", "source_lang", "EN"))
	target_lang.text = str(Settings.get_value("translate", "target_lang", "ZH"))

	ai_url.text = Settings.ai_base_url()
	ai_model.text = Settings.ai_model()
	ai_key.text = str(Settings.get_value("ai", "api_key", ""))
	ai_prompt.text = str(Settings.get_value("ai", "system_prompt", ""))
	ai_history.value = int(Settings.get_value("ai", "max_history", 20))

	status_label.text = "已加载"


func _save_to_settings() -> void:
	Settings.set_value("note", "save_path", note_path.text.strip_edges())

	Settings.set_value("translate", "deepl_url", deepl_url.text.strip_edges())
	Settings.set_value("translate", "deepl_key", deepl_key.text.strip_edges())
	Settings.set_value("translate", "source_lang", source_lang.text.strip_edges().to_upper())
	Settings.set_value("translate", "target_lang", target_lang.text.strip_edges().to_upper())

	Settings.set_value("ai", "base_url", ai_url.text.strip_edges())
	Settings.set_value("ai", "model", ai_model.text.strip_edges())
	Settings.set_value("ai", "api_key", ai_key.text.strip_edges())
	Settings.set_value("ai", "system_prompt", ai_prompt.text)
	Settings.set_value("ai", "max_history", int(ai_history.value))

	Settings.save()
	status_label.text = "已保存"


func _on_save_pressed() -> void:
	_save_to_settings()


func _on_browse_pressed() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.add_filter("*.md", "Markdown")

	var current := note_path.text.strip_edges()
	if not current.is_empty():
		dlg.current_path = ProjectSettings.globalize_path(current)

	dlg.file_selected.connect(
		func(path: String) -> void:
			note_path.text = path
			dlg.queue_free(),
	)
	dlg.canceled.connect(dlg.queue_free)

	add_child(dlg)
	dlg.popup_centered_ratio(0.6)


func _on_open_folder_pressed() -> void:
	var path := note_path.text.strip_edges()
	if path.is_empty():
		path = "user://note.md"

	var absolute := ProjectSettings.globalize_path(path)
	var dir := absolute.get_base_dir()

	if DirAccess.dir_exists_absolute(dir):
		OS.shell_open(dir)
	else:
		status_label.text = "文件夹不存在：" + dir


func _on_show_deepl_key_pressed() -> void:
	deepl_key.secret = not deepl_key.secret
	show_deepl_key_button.text = "🙈" if deepl_key.secret else "👁"


func _on_copy_hotkey_pressed() -> void:
	DisplayServer.clipboard_set(hotkey_label.text)
	status_label.text = "命令已复制"


func _on_deepl_test_pressed() -> void:
	var url := deepl_url.text.strip_edges()
	var key := deepl_key.text.strip_edges()

	if url.is_empty() or key.is_empty():
		deepl_test_result.text = "请先填写接口地址和 Key"
		return
	if deepl_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	deepl_test_button.disabled = true
	deepl_test_result.text = "测试中…"

	var body := "text=hello&target_lang=ZH"
	var headers := [
		"Authorization: DeepL-Auth-Key " + key,
		"Content-Type: application/x-www-form-urlencoded",
	]

	var err := deepl_http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		deepl_test_button.disabled = false
		deepl_test_result.text = "请求失败：" + error_string(err)


func _on_deepl_test_completed(
	result_code: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	deepl_test_button.disabled = false

	if result_code != HTTPRequest.RESULT_SUCCESS:
		deepl_test_result.text = "网络错误（%d）" % result_code
		return

	match response_code:
		200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			var text := ""
			if typeof(data) == TYPE_DICTIONARY:
				var translations = data.get("translations", [])
				if typeof(translations) == TYPE_ARRAY and not translations.is_empty():
					text = str(translations[0].get("text", ""))
			deepl_test_result.text = "成功：hello → " + text
		401:
			deepl_test_result.text = "Key 无效（401）"
		403:
			deepl_test_result.text = "Key 与接口不匹配（403）"
		456:
			deepl_test_result.text = "本月额度已用完（456）"
		_:
			deepl_test_result.text = "HTTP 错误：%d" % response_code


func _on_show_ai_key_pressed() -> void:
	ai_key.secret = not ai_key.secret
	show_ai_key_button.text = "🙈" if ai_key.secret else "👁"


func _on_ai_test_pressed() -> void:
	if ai_http == null:
		ai_test_result.text = "缺少 AITestHttp 节点"
		return

	var url := ai_url.text.strip_edges()
	var model := ai_model.text.strip_edges()
	var key := ai_key.text.strip_edges()

	if url.is_empty() or model.is_empty():
		ai_test_result.text = "请先填写 Base URL 和 Model"
		return
	if ai_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	ai_test_button.disabled = true
	ai_test_result.text = "测试中…"

	var body := JSON.stringify(
		{ "model": model, "messages": [{ "role": "user", "content": "ping" }], "stream": false }
	)
	var headers := ["Content-Type: application/json"]
	if not key.is_empty():
		headers.append("Authorization: Bearer " + key)

	var err := ai_http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		ai_test_button.disabled = false
		ai_test_result.text = "请求失败：" + error_string(err)


func _on_ai_test_completed(
	result_code: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	ai_test_button.disabled = false

	if result_code != HTTPRequest.RESULT_SUCCESS:
		ai_test_result.text = "网络错误（%d）" % result_code
		return

	if response_code != 200:
		ai_test_result.text = "HTTP 错误：%d\n%s" % [response_code, body.get_string_from_utf8()]
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	var reply := ""
	if typeof(data) == TYPE_DICTIONARY:
		var choices = data.get("choices", [])
		if typeof(choices) == TYPE_ARRAY and not choices.is_empty():
			reply = str(choices[0].get("message", { }).get("content", ""))

	ai_test_result.text = "成功：" + reply.left(60)
