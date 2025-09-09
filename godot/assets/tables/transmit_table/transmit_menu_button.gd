extends Button
class_name TransmitMenuButton

var _transmit_menu: TransmitMenu


func _ready() -> void:
	_transmit_menu = get_tree().current_scene.get_node("TransmitMenu")
	self.pressed.connect(_transmit_menu.show)
