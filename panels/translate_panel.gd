extends MarginContainer

const LANG_CODES = { 0: "EN", 1: "ZH", 2: "JA" }

@onready var from_lang: OptionButton = $Layout/LangBar/FromLang
@onready var to_lang: OptionButton = $Layout/LangBar/ToLang
@onready var swap_button: Button = $Layout/LangBar/SwapButton
@onready var source: TextEdit = $Layout/Split/Source
@onready var result: RichTextLabel = $Layout/Split/Result
@onready var translate_button: Button = $Layout/BottomBar/TranslateButton
@onready var http: HTTPRequest = $HTTPRequest


func _ready() -> void:
	translate_button.pressed.connect(_translate)
	swap_button.pressed.connect(_swap_languages)
	http.request_completed.connect(_on_request_completed)

	from_lang.selected = 0
	to_lang.selected = 1
	from_lang.add_item("自动检测", 99)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey and event.pressed and not event.echo
		and event.keycode == KEY_ENTER and event.ctrl_pressed
	):
		_translate()
		get_viewport().set_input_as_handled()


const DEEPL_URL = "https://api-free.deepl.com/v2/translate"
const DEEPL_KEY = "96c209d3-6ea5-4cc1-baaa-07a80c6bce68:fx"


func _translate() -> void:
	var text := source.text.strip_edges()
	if text.is_empty():
		result.text = "请输入要翻译的内容"
		return

	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var from_code: String = LANG_CODES.get(from_lang.get_selected_id(), "AUTO")
	var to_code: String = LANG_CODES.get(to_lang.get_selected_id(), "EN")

	var body := "text=%s&target_lang=%s" % [text.uri_encode(), to_code]
	if from_code != "AUTO":
		body += "&source_lang=" + from_code

	var headers := [
		"Authorization: DeepL-Auth-Key " + DEEPL_KEY,
		"Content-Type: application/x-www-form-urlencoded",
	]

	result.text = "翻译中..."
	translate_button.disabled = true

	var err := http.request(DEEPL_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		result.text = "请求失败 : %s" % error_string(err)
		translate_button.disabled = false


func _on_request_completed(
	result_code: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	translate_button.disabled = false

	if result_code != HTTPRequest.RESULT_SUCCESS:
		result.text = "网络错误（错误码 %d）" % result_code
		return

	match response_code:
		200:
			pass
		401:
			result.text = "DeepL Key 无效"
			return
		403:
			result.text = "Key 与接口不匹配（Free/Pro）"
			return
		429:
			result.text = "请求太频繁，稍后再试"
			return
		456:
			result.text = "DeepL 本月免费额度已用完"
			return
		_:
			result.text = "HTTP 错误：%d" % response_code
			return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		result.text = "返回数据格式异常"
		return

	var translations = data.get("translations", [])
	if typeof(translations) != TYPE_ARRAY or translations.is_empty():
		result.text = "没有拿到翻译结果"
		return

	var first = translations[0]

	if typeof(first) != TYPE_DICTIONARY:
		result.text = "返回数据格式异常"
		return

	result.text = str(first.get("text", ""))


func _swap_languages() -> void:
	var a := from_lang.selected
	var b := to_lang.selected
	from_lang.selected = b
	to_lang.selected = a

	if not result.text.is_empty():
		var temp := source.text
		source.text = result.text
		result.text = temp
