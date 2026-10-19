extends Node


func _ready() -> void:
	get_tree().auto_accept_quit = false

	get_window().visible = false

# func _on_command_recived(cmd: String) -> void:
# 	WindowManager.toggle(cmd)
