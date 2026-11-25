extends MarginContainer

@onready var editor: TextEdit = $Layout/Split/Editor


func _note_path() -> String:
	return Settings.note_path()


func _apply_mode(editing: bool) -> void:
	editor.visible = editing
	$Layout/ToolBar/TogglePreview.text = "👁预览" if editing else "✏编辑"


func _ready() -> void:
	_load()
	_update_preview()
	editor.text_changed.connect(_on_text_changed)
	$Layout/ToolBar/TogglePreview.pressed.connect(_toggle_preview)
	_apply_mode(false)


func _on_text_changed() -> void:
	$Layout/ToolBar/StatusLabel.text = "未保存"
	_update_preview()


func _update_preview() -> void:
	var preview := $Layout/Split/Preview as RichTextLabel
	preview.markdown_text = editor.text


func _load() -> void:
	var path := _note_path()
	if FileAccess.file_exists(path):
		editor.text = FileAccess.get_file_as_string(path)


func _toggle_preview() -> void:
	_apply_mode(not editor.visible)


func _save() -> void:
	var path := _note_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(editor.text)
		f.close()
	$Layout/ToolBar/StatusLabel.text = "已保存"


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey and event.pressed and not event.echo
		and event.keycode == KEY_S and event.ctrl_pressed
	):
		_save()
		get_viewport().set_input_as_handled()
