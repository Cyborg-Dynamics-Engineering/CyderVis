extends Button
class_name CanFormatButton

@onready var receive_table: ReceiveTable = get_tree().current_scene.get_node("Background/Table")
@onready var transmit_table: TransmitTable = get_tree().current_scene.get_node("Background/TabContainer/Transmit/Table")

var _can_format_using_hex: bool


func _ready() -> void:
	_can_format_using_hex = true
	self.pressed.connect(_toggle_formatting)


func _toggle_formatting() -> void:
	_can_format_using_hex = not _can_format_using_hex
	self.text = "Hexadecimal" if _can_format_using_hex else "Decimal"

	receive_table.update_formatting()
	transmit_table.update_formatting()


func use_hex() -> bool:
	return _can_format_using_hex
