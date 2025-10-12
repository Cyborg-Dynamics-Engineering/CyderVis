extends Button
class_name CanFormatButton

@export var on_label: String
@export var off_label: String

@export_category("Node References")
@export var receive_table: ReceiveTable
@export var transmit_table: TransmitTable

var _can_format_on: bool


func _ready() -> void:
	_can_format_on = true
	self.pressed.connect(_toggle_formatting)


func _toggle_formatting() -> void:
	_can_format_on = not _can_format_on
	self.text = on_label if _can_format_on else off_label

	receive_table.update_formatting()
	transmit_table.update_formatting()


func format_on() -> bool:
	return _can_format_on
