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

	if _window.visible and _window.current_command() == command:
		_window.hide()
	else:
		_window.show_page(command)
