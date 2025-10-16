extends Node
class_name AlertHandler

static var _handler_instance: AlertHandler

var prev_alert_box: AcceptDialog


func _ready() -> void:
	_handler_instance = self
	prev_alert_box = null


static func singleton() -> AlertHandler:
	return _handler_instance


static func display_error(msg: String) -> void:
	var handler_ref := singleton()
	if handler_ref == null:
		return
	
	# Delete any existing alert boxes if present
	if is_instance_valid(handler_ref.prev_alert_box):
		handler_ref.prev_alert_box.queue_free()

	var alert_box: AcceptDialog = AcceptDialog.new()
	alert_box.title = ""
	alert_box.dialog_text = msg

	singleton().get_tree().current_scene.add_child(alert_box)

	alert_box.show()
	alert_box.exclusive = false
	alert_box.position = Vector2i((_handler_instance.get_viewport().size.x - alert_box.size.x) / 2, (_handler_instance.get_viewport().size.y - alert_box.size.y) - 50)

	handler_ref.prev_alert_box = alert_box
