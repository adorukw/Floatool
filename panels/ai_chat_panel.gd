extends MarginContainer

const BUBBLE = preload("res://components/chat_bubble.tscn")

@onready var messages: VBoxContainer = $Layout/Scroll/Messages
@onready var input: TextEdit = $Layout/InputBar/Input
@onready var scroll: ScrollContainer = $Layout/Scroll
@onready var send_button: Button = $Layout/InputBar/SendButton
@onready var http: HTTPRequest = $HTTPRequest

var _history: Array = [
	{ "role": "system", "content": str(Settings.get_value("ai", "system_prompt", "你是一个简洁的中文助手")) }
]

var _pending_label: RichTextLabel = null


func _ready() -> void:
	send_button.pressed.connect(_send)
	http.request_completed.connect(_on_request_completed)


func activate() -> void:
	await get_tree().process_frame
	if visible:
		input.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey and event.pressed and not event.echo
		and event.keycode == KEY_ENTER and event.ctrl_pressed
	):
		_send()
		get_viewport().set_input_as_handled()


func _add_bubble(text: String, from_user: bool) -> RichTextLabel:
	var b := BUBBLE.instantiate()
	var label := b.get_node("Margin/Text") as RichTextLabel
	label.text = text

	b.size_flags_horizontal = Control.SIZE_SHRINK_END if from_user else Control.SIZE_SHRINK_BEGIN
	messages.add_child(b)
	_scroll_to_bottom()
	return label


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _send() -> void:
	var text := input.text.strip_edges()
	if text.is_empty():
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	_add_bubble(text, true)
	_history.append({ "role": "user", "content": text })
	_trim_history()

	input.text = ""
	send_button.disabled = true
	_pending_label = _add_bubble("思考中", false)

	var url := Settings.ai_base_url()
	var model := Settings.ai_model()
	var key := Settings.ai_key()

	var body := JSON.stringify({ "model": model, "messages": _history, "stream": false })
	var headers := ["Content-Type: application/json"]
	if not key.is_empty():
		headers.append("Authorization: Bearer " + key)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		send_button.disabled = false
		if _pending_label:
			_pending_label.text = "请求失败" + error_string(err)
			_pending_label = null


func _on_request_completed(
	result_code: int,
	response_code: int,
	_hearders: PackedStringArray,
	body: PackedByteArray,
) -> void:
	send_button.disabled = false

	if result_code != HTTPRequest.RESULT_SUCCESS:
		if _pending_label:
			_pending_label.text = "网络错误（%d）" % result_code
			_pending_label = null
		return

	if response_code != 200:
		if _pending_label:
			_pending_label.text = "HTTP 错误：%d\n%s" % [response_code, body.get_string_from_utf8()]
			_pending_label = null
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		if _pending_label:
			_pending_label.text = "返回格式异常"
			_pending_label = null
		return

	var choices = data.get("choices", [])
	if typeof(choices) != TYPE_ARRAY or choices.is_empty():
		if _pending_label:
			_pending_label.text = "没有拿到回复"
			_pending_label = null
		return

	var reply := str(choices[0].get("message", { }).get("content", ""))
	_history.append({ "role": "assistant", "content": reply })

	if _pending_label:
		_pending_label.text = reply
		_pending_label = null
		_scroll_to_bottom()


func _trim_history() -> void:
	var limit := int(Settings.get_value("ai", "max_history", 20))
	while _history.size() > limit + 1:
		_history.remove_at(1)


func _api_key() -> String:
	return "sk-1951ce2d66df4432b28c8238176d22e9"
