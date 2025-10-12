extends Control
class_name TransmitTable


@export_category("Node References")
@export var godot_can_bridge: GodotCanBridge

@onready var table_row = preload("res://assets/tables/table_row.tscn")
@onready var table_cell = preload("res://assets/tables/table_cell.tscn")
@onready var table_button = preload("res://assets/tables/table_button.tscn")
@onready var table_send_text_cell = preload("res://assets/tables/transmit_table/send_text_cell.tscn")
@onready var table_send_check_box = preload("res://assets/tables/transmit_table/send_checkbox_cell.tscn")
@onready var table_send_delete_button = preload("res://assets/tables/transmit_table/send_delete_cell.tscn")
@onready var send_entries: Array = []
@onready var rows: Control = get_node("Rows")

const DELETE_IDX = 0
const TOGGLE_IDX = 1
const CYCLE_TIME_IDX = 2
const EXTENDED_ID_IDX = 3
const CAN_ID_IDX = 4
const DATA_IDX = 5

const CELL_HEIGHT = 25
const CELL_WIDTHS = [60, 60, 120, 60, 120, 250]


func _ready() -> void:
	_generate_header_row()


func _physics_process(_delta: float) -> void:
	for send_entry: TransmitTableEntry in send_entries:
		if send_entry.enabled():
			send_entry.send_if_ready()


func add_new_send_entry() -> void:
	send_entries.append(TransmitTableEntry.new(godot_can_bridge, self))


# Adds the header row to the table, should only be called once
func _generate_header_row() -> void:
	const HEADER = ["Delete", "Send", "Cycle Time [ms]", "EXT ID", "CAN ID [hex]", "Data [hex]"]
	var header_row: BoxContainer = table_row.instantiate()

	for i in range(len(HEADER)):
		var cell: PanelContainer = table_cell.instantiate()
		cell.custom_minimum_size = Vector2(CELL_WIDTHS[i], CELL_HEIGHT)

		# Set the data row to fill all remaining horizontal space
		if i == DATA_IDX:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		_update_label_and_font_size(cell.get_node("Label"), HEADER[i], CELL_WIDTHS[i])
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
	var _extended_id_check_box: CheckBox
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
		_transmit_table._update_label_and_font_size(_cycle_time_box, "0", CELL_WIDTHS[CYCLE_TIME_IDX])
		_row.add_child(cycle_time_cell)

		# Only allow numeric characters for cycle time box
		_cycle_time_box.max_length = 4
		_cycle_time_box.text_changed.connect(
			func(new_text: String):
				var filtered := ""
				for c in new_text:
					if c.is_valid_int():
						filtered += c
				
				# Update the text with the invalid characters removed, maintaining the old cursor position
				var old_cursor_pos := _cycle_time_box.caret_column
				_cycle_time_box.text = filtered
				_cycle_time_box.caret_column = min(old_cursor_pos - (new_text.length() - filtered.length()), _cycle_time_box.text.length())
		)

		# Add extended id check box
		var extended_id_cell: PanelContainer = _transmit_table.table_send_check_box.instantiate()
		extended_id_cell.custom_minimum_size = Vector2(CELL_WIDTHS[EXTENDED_ID_IDX], CELL_HEIGHT)
		_row.add_child(extended_id_cell)
		_extended_id_check_box = extended_id_cell.get_node("CheckBox") # Link extended id check box to the send entry

		# Add Can ID box
		var can_id_cell: PanelContainer = _transmit_table.table_send_text_cell.instantiate()
		can_id_cell.custom_minimum_size = Vector2(CELL_WIDTHS[CAN_ID_IDX], CELL_HEIGHT)
		_can_id_box = can_id_cell.get_node("LineEdit")
		_can_id_box.placeholder_text = "0"
		_transmit_table._update_label_and_font_size(_can_id_box, "", CELL_WIDTHS[CAN_ID_IDX])
		_row.add_child(can_id_cell)

		# Only allow valid hex characters for CAN ID box
		_can_id_box.max_length = 8
		_can_id_box.text_changed.connect(
			func(new_text: String):
				var filtered := ""
				for c in new_text:
					if c.is_valid_hex_number():
						filtered += c
				
				# Update the text with the invalid characters removed, maintaining the old cursor position
				var old_cursor_pos := _can_id_box.caret_column
				_can_id_box.text = filtered
				_can_id_box.caret_column = min(old_cursor_pos - (new_text.length() - filtered.length()), _can_id_box.text.length())
		)

		# Add Data box
		var data_cell: PanelContainer = _transmit_table.table_send_text_cell.instantiate()
		data_cell.custom_minimum_size = Vector2(CELL_WIDTHS[DATA_IDX], CELL_HEIGHT)
		data_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_data_box = data_cell.get_node("LineEdit")
		_transmit_table._update_label_and_font_size(_data_box, "", CELL_WIDTHS[DATA_IDX])
		_row.add_child(data_cell)

		# Add byte seperation formatting and character validation for Data box
		_data_box.max_length = 23
		_data_box.text_changed.connect(
			func(new_text: String):
				# Filter out non-hex characters
				var filtered := ""
				for c in new_text:
					if c.is_valid_hex_number():
						filtered += c

				# Add seperation spaces between every byte
				var bytes := []
				var start := filtered.length() % 2 # 1 if odd, 0 if even
				if start == 1:
					bytes.append(filtered[0]) # first lone char
				for i in range(start, filtered.length(), 2):
					bytes.append(filtered.substr(i, 2))
				filtered = " ".join(bytes)

				# Update the text with the invalid characters removed, maintaining the old cursor position
				var old_cursor_pos := _data_box.caret_column
				_data_box.text = filtered
				_data_box.caret_column = min(old_cursor_pos - (new_text.length() - filtered.length()), _data_box.text.length())
		)


	func can_id() -> int:
		return _can_id_box.text.replace(" ", "").hex_to_int()


	func can_id_valid() -> bool:
		return _can_id_box.text.replace(" ", "").is_valid_hex_number()


	func is_ext_can() -> bool:
		return _extended_id_check_box.button_pressed


	func cycle_time_ms() -> int:
		return int(_cycle_time_box.text)


	# Returns true if this entry should be currently transmitting
	func enabled() -> bool:
		return _check_box.button_pressed


	# Returns the payload data stored in this entry in its original hex format
	func hex_data() -> String:
		return _data_box.text.replace(" ", "")
	

	func hex_data_valid() -> bool:
		return hex_data().is_empty() or hex_data().is_valid_hex_number()


	# Returns the payload data stored in this entry converted into a byte array representation
	func data() -> Array:
		return hex_to_byte_array(hex_data())


	# Sends this entry over the CAN interface if cycle time has been exceeded
	func send_if_ready() -> void:
		var cycle_time = cycle_time_ms()
		var current_time_ms := Time.get_ticks_msec()
		if (current_time_ms - _last_send_time_ms) > cycle_time:
			if not hex_data_valid():
				_check_box.button_pressed = false
				AlertHandler.display_error("Invalid hex data provided")
				return
			
			if not can_id_valid():
				_check_box.button_pressed = false
				AlertHandler.display_error("Invalid CAN ID provided")
				return
			
			const STANDARD_CAN_ID_MAX: int = 2047
			if (not is_ext_can()) and (can_id() > STANDARD_CAN_ID_MAX):
				_check_box.button_pressed = false
				AlertHandler.display_error("CAN ID is greater than the max Standard CAN ID")
				return
			
			const EXTENDED_CAN_ID_MAX: int = 536870911
			if is_ext_can() and (can_id() > EXTENDED_CAN_ID_MAX):
				_check_box.button_pressed = false
				AlertHandler.display_error("CAN ID is greater than the max Extended CAN ID")
				return

			_godot_can_bridge.send_can_frame(can_id(), is_ext_can(), data())
			_last_send_time_ms = current_time_ms
		
		# A cycle time of 0ms should be treated as 'one shot', so disable itself after sending the message
		if cycle_time == 0:
			_check_box.button_pressed = false


	# Converts a hex string into a u8 byte array
	func hex_to_byte_array(hex_str: String) -> Array:
		var bytes: Array = []
		
		# Ensure an even number of characters (each byte = 2 hex digits)
		if hex_str.length() % 2 != 0:
			hex_str = "0" + hex_str

		# Walk through the string in steps of 2
		for i in range(0, hex_str.length(), 2):
			var byte_str := hex_str.substr(i, 2)
			var byte_val = byte_str.hex_to_int() # parse as hex
			bytes.append(byte_val)
		
		return bytes
