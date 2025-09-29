extends Button
class_name SendButton

var transmit_table: TransmitTable


func _ready() -> void:
	# Resolve scene connections
	transmit_table = get_tree().current_scene.get_node("Background/TabContainer/Transmit/Table")

	self.pressed.connect(_button_pressed)


func _button_pressed() -> void:
	# Add a new send entry to the transmission table (Does not actually send any CAN data yet)
	transmit_table.add_new_send_entry()
