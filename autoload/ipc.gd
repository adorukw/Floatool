extends Node

signal command_received(command: String)

const PORT = 45670

var _udp := PacketPeerUDP.new()


func _ready() -> void:
	var err := _udp.bind(PORT, "127.0.0.1")
	if err != OK:
		push_error("IPC 端口绑定失败: %s" % error_string(err))


func _process(_delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		var cmd := _udp.get_packet().get_string_from_utf8().strip_edges()
		if not cmd.is_empty():
			command_received.emit(cmd)
