extends Node


func _ready() -> void:
	get_tree().auto_accept_quit = false

	get_window().unfocusable = true
	get_window().mode = Window.MODE_MINIMIZED

	Ipc.command_received.connect(_on_command_received)

	await get_tree().process_frame
	WindowManager.toggle("note")


func _on_command_received(cmd: String) -> void:
	WindowManager.toggle(cmd)
