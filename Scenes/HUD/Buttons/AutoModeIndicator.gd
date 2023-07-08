class_name AutoModeIndicator extends Control


var _autocast: Autocast = null


func set_autocast(autocast: Autocast):
	_autocast = autocast


func _process(_delta: float):
	visible = _autocast != null && _autocast._auto_mode
