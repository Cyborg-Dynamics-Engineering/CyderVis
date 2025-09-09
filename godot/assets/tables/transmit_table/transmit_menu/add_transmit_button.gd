extends Button
class_name SendButton

var godot_can_bridge: GodotCanBridge
var transmit_table: TransmitTable
var transmit_menu: TransmitMenu
var can_id_box: LineEdit
var cycle_time_box: LineEdit
var length_option: OptionButton
var extended_can_id_checkbox: CheckBox
var data_boxes: Array[LineEdit]


func _ready() -> void:
	# Resolve scene connections
	godot_can_bridge = get_tree().current_scene.get_node("GodotCanBridge")
	transmit_table = get_tree().current_scene.get_node("Background/TabContainer/Transmit/Table")
	transmit_menu = get_parent().get_parent()
	can_id_box = get_parent().get_node("CAN ID Box")
	cycle_time_box = get_parent().get_node("Cycle Time Box")
	length_option = get_parent().get_node("Length Option")
	extended_can_id_checkbox = get_parent().get_node("ExtCanCheckBox")
	for i in range(8):
		data_boxes.append(get_parent().get_node("Data Box " + str(i + 1)))

	self.pressed.connect(_button_pressed)


func _button_pressed() -> void:
	# Add a new send entry to the transmission table (Does not actually send any CAN data yet)
	var can_id := can_id_box.text.hex_to_int()
	var cycle_time_ms := int(cycle_time_box.text)
	var is_extended := extended_can_id_checkbox.button_pressed
	transmit_table.add_new_send_entry(can_id, is_extended, cycle_time_ms, _get_data())
	transmit_menu.hide()


# Returns the data from the data table boxes as a single array
func _get_data() -> Array:
	var data: Array = []

	var data_length: int = (length_option.selected + 1)
	for i in data_length:
		data.append(int(data_boxes[i].text))

	return data
