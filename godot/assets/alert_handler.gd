extends Node
class_name AlertHandler

static var _handler_instance: AlertHandler


func _ready() -> void:
	_handler_instance = self


static func singleton() -> AlertHandler:
	return _handler_instance


static func display_error(msg: String) -> void:
	var handler_ref := singleton()
	if handler_ref == null:
		return

	var alert_box: AcceptDialog = AcceptDialog.new()
	alert_box.title = ""
	alert_box.dialog_text = msg

	singleton().get_tree().current_scene.add_child(alert_box)

	alert_box.popup()
	alert_box.position = Vector2i((_handler_instance.get_viewport().size.x - alert_box.size.x) / 2, (_handler_instance.get_viewport().size.y - alert_box.size.y) - 50)
