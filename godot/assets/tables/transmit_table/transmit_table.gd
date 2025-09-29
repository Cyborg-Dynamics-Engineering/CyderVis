extends Control
class_name TransmitTable


@onready var table_row = preload("res://assets/tables/table_row.tscn")
@onready var table_cell = preload("res://assets/tables/table_cell.tscn")
@onready var table_button = preload("res://assets/tables/table_button.tscn")
@onready var table_send_text_cell = preload("res://assets/tables/transmit_table/send_text_cell.tscn")
@onready var table_send_check_box = preload("res://assets/tables/transmit_table/send_checkbox_cell.tscn")
@onready var table_send_delete_button = preload("res://assets/tables/transmit_table/send_delete_cell.tscn")
@onready var can_format_button: CanFormatButton = get_tree().current_scene.get_node("Background/TabContainer/Interface/CanFormatButton")
@onready var send_entries: Array = []

var rows: Control
var godot_can_bridge: GodotCanBridge

const DELETE_IDX = 0
const TOGGLE_IDX = 1
const CYCLE_TIME_IDX = 2
const CAN_ID_IDX = 3
const DATA_IDX = 4

const CELL_HEIGHT = 25
const CELL_WIDTHS = [25, 25, 120, 100, 60]


func _ready() -> void:
	rows = get_node("Rows")
	godot_can_bridge = get_tree().current_scene.get_node("GodotCanBridge")
	_generate_header_row()


func _physics_process(_delta: float) -> void:
	for send_entry: TransmitTableEntry in send_entries:
		if send_entry.enabled():
			send_entry.send_if_ready()


func add_new_send_entry() -> void:
	send_entries.append(TransmitTableEntry.new(godot_can_bridge, self))


# Adds the header row to the table, should only be called once
func _generate_header_row() -> void:
	var header = ["", "", "Cycle Time [ms]", "CAN ID", "Data"]
	var header_row: BoxContainer = table_row.instantiate()

	for i in range(len(header)):
		var cell: PanelContainer = table_cell.instantiate()
		cell.custom_minimum_size = Vector2(CELL_WIDTHS[i], CELL_HEIGHT)

		# Set the data row to fill all remaining horizontal space
		if i == DATA_IDX:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		_update_label_and_font_size(cell.get_node("Label"), header[i], CELL_WIDTHS[i])
		cell.get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_row.add_child(cell)
	
	rows.add_child(header_row)


# Updates the text and tooltip of a label, making adjustments to size and concatonating the label if neccesary
func _update_label_and_font_size(label, new_text: String, width: int) -> void:
	const PADDING_PX: int = 10
	const MIN_FONT_SIZE: int = 10
	const MAX_FONT_SIZE: int = 14

	# Use the full text as a tooltip (mouse hover)
	label.tooltip_text = new_text

	# Adjust name's font size (and potentially truncate string) to fit within the allowed width.
	var truncated_text := new_text
	var font_size = MAX_FONT_SIZE
	while ThemeDB.fallback_font.get_string_size(truncated_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x > (width - PADDING_PX):
		if font_size > MIN_FONT_SIZE:
			font_size -= 1
		else:
			truncated_text = truncated_text.left(-1)

	label.text = truncated_text
	label.add_theme_font_size_override("font_size", font_size)


func update_formatting() -> void:
	# Send entries only have hex mode supported right now so do nothing
	pass


class TransmitTableEntry:
	var _godot_can_bridge: GodotCanBridge
	var _transmit_table: TransmitTable

	var _last_send_time_ms: float

	var _row: BoxContainer
	var _check_box: CheckBox
	var _can_id_box: LineEdit
	var _data_box: LineEdit
	var _cycle_time_box: LineEdit


	func _init(godot_can_bridge: GodotCanBridge, transmit_table: TransmitTable) -> void:
		_godot_can_bridge = godot_can_bridge
		_transmit_table = transmit_table

		_last_send_time_ms = Time.get_ticks_msec()
		_instantiate_labels()


	# Instantiates the table cell nodes holding the labels into this entry's row
	func _instantiate_labels():
		_row = _transmit_table.table_row.instantiate()
		_transmit_table.rows.add_child(_row)

		# Add delete button
		var delete_cell: PanelContainer = _transmit_table.table_send_delete_button.instantiate()
		delete_cell.custom_minimum_size = Vector2(CELL_WIDTHS[DELETE_IDX], CELL_HEIGHT)
		_row.add_child(delete_cell)

		# Connect the underlying button object to a lambda that deletes this send entry and GUI row
		var delete_button: Button = delete_cell.get_node("SendButton")
		delete_button.pressed.connect(
			func():
				_row.queue_free()
				_transmit_table.send_entries.erase(self)
		)

		# Add check box
		var check_box_cell: PanelContainer = _transmit_table.table_send_check_box.instantiate()
		check_box_cell.custom_minimum_size = Vector2(CELL_WIDTHS[TOGGLE_IDX], CELL_HEIGHT)
		_row.add_child(check_box_cell)
		_check_box = check_box_cell.get_node("CheckBox") # Link check box to the send entry to allow the entry to check whether it should be sending

		# Add cycle time box
		var cycle_time_cell: PanelContainer = _transmit_table.table_send_text_cell.instantiate()
		cycle_time_cell.custom_minimum_size = Vector2(CELL_WIDTHS[CYCLE_TIME_IDX], CELL_HEIGHT)
		_cycle_time_box = cycle_time_cell.get_node("LineEdit")
		_transmit_table._update_label_and_font_size(_cycle_time_box, "0", 120)
		_row.add_child(cycle_time_cell)

		# Add Can ID box
		var can_id_cell: PanelContainer = _transmit_table.table_send_text_cell.instantiate()
		can_id_cell.custom_minimum_size = Vector2(CELL_WIDTHS[CAN_ID_IDX], CELL_HEIGHT)
		_can_id_box = can_id_cell.get_node("LineEdit")
		_transmit_table._update_label_and_font_size(_can_id_box, "000", 120)
		_row.add_child(can_id_cell)

		# Add Data box
		var data_cell: PanelContainer = _transmit_table.table_send_text_cell.instantiate()
		data_cell.custom_minimum_size = Vector2(CELL_WIDTHS[DATA_IDX], CELL_HEIGHT)
		_data_box = data_cell.get_node("LineEdit")
		_transmit_table._update_label_and_font_size(_data_box, "", 250)
		_row.add_child(data_cell)


	func can_id() -> int:
		return int(_can_id_box.text)


	func is_ext_can() -> bool:
		const STANDARD_CAN_ID_MAX: int = 2047
		return (can_id() > STANDARD_CAN_ID_MAX) or (_can_id_box.text.length() > 3)


	func cycle_time_ms() -> int:
		return int(_cycle_time_box.text)


	# Returns true if this entry should be currently transmitting
	func enabled() -> bool:
		return _check_box.button_pressed


	# Returns the payload data stored in this entry in its original hex format
	func hex_data() -> String:
		return _data_box.text


	# Returns the payload data stored in this entry converted into a byte array representation
	func data() -> Array:
		return _int_to_bytes(hex_data().hex_to_int())


	# Sends this entry over the CAN interface if cycle time has been exceeded
	func send_if_ready() -> void:
		var cycle_time = cycle_time_ms()
		var current_time_ms := Time.get_ticks_msec()
		if (current_time_ms - _last_send_time_ms) > cycle_time:
			print(data())
			_godot_can_bridge.send_can_frame(can_id(), is_ext_can(), data())
			_last_send_time_ms = current_time_ms
		
		# A cycle time of 0ms should be treated as 'one shot', so disable itself after sending the message
		if cycle_time == 0:
			_check_box.button_pressed = false


	# Converts a 64 bit signed integer into a u8 byte array
	func _int_to_bytes(value: int) -> Array:
		var result: Array = []
		var v := value
		
		# Handle zero explicitly
		if v == 0:
			return []
		
		# Work with absolute value for byte extraction
		var negative := v < 0
		if negative:
			v = -v
		
		while v > 0:
			result.append(v & 0xFF) # extract lowest byte
			v >>= 8
		
		# At this point, result is little-endian. Reverse for big-endian if needed.
		# Minimal length is already guaranteed because we stopped when v == 0.
		
		if negative:
			# Store a sign indicator (convention: prepend 0x80 to first byte)
			# Or use two's complement encoding – depends on your use case.
			# Here’s two’s complement with minimal length:
			var nbytes = result.size()
			var carry = 1
			for i in range(nbytes):
				result[i] = (~result[i] & 0xFF) + carry
				if result[i] > 0xFF:
					result[i] &= 0xFF
					carry = 1
				else:
					carry = 0
			if carry > 0:
				result.append(1)
		
		return result
