extends Node

const PATH = "user://settings.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != OK:
		_apply_defaults()
		save()


func _apply_defaults() -> void:
	# 笔记
	_cfg.set_value("note", "save_path", "user://note.md")

	# 翻译
	_cfg.set_value("translate", "deepl_url", "https://api-free.deepl.com/v2/translate")
	_cfg.set_value("translate", "deepl_key", "")
	_cfg.set_value("translate", "source_lang", "EN")
	_cfg.set_value("translate", "target_lang", "ZH")

	# AI
	_cfg.set_value("ai", "base_url", "https://api.deepseek.com/chat/completions")
	_cfg.set_value("ai", "model", "deepseek-chat")
	_cfg.set_value("ai", "api_key", "")
	_cfg.set_value("ai", "system_prompt", "你是一个简洁的中文助手")
	_cfg.set_value("ai", "max_history", 20)


func get_value(section: String, key: String, default = null):
	return _cfg.get_value(section, key, default)


func set_value(section: String, key: String, value) -> void:
	_cfg.set_value(section, key, value)


func save() -> void:
	_cfg.save(PATH)


func note_path() -> String:
	return str(_cfg.get_value("note", "save_path", "user://note.md"))


func deepl_url() -> String:
	return str(_cfg.get_value("translate", "deepl_url", "https://api-free.deepl.com/v2/translate"))


func deepl_key() -> String:
	var env := OS.get_environment("DEEPL_API_KEY")
	return env if not env.is_empty() else str(_cfg.get_value("translate", "deepl_key", ""))


func ai_base_url() -> String:
	return str(_cfg.get_value("ai", "base_url", "https://api.deepseek.com/chat/completions"))


func ai_model() -> String:
	return str(_cfg.get_value("ai", "model", "deepseek-chat"))


func ai_key() -> String:
	var env := OS.get_environment("DEEPSEEK_API_KEY")
	return env if not env.is_empty() else str(_cfg.get_value("ai", "api_key", ""))
