extends Control
class_name TransmitTable


@onready var table_row = preload("res://assets/tables/table_row.tscn")
@onready var table_cell = preload("res://assets/tables/table_cell.tscn")
@onready var table_button = preload("res://assets/tables/table_button.tscn")
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
const DATA_START_IDX = 4

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


func add_new_send_entry(can_id: int, extended_id: bool, cycle_time_ms: int, data: Array) -> void:
	# Check bounds of CAN ID
	if extended_id:
		const EXTENDED_CAN_ID_MIN: int = 0
		const EXTENDED_CAN_ID_MAX: int = 536870911
		if can_id < EXTENDED_CAN_ID_MIN or can_id > EXTENDED_CAN_ID_MAX:
			printerr("CAN ID of " + str(can_id) + " is invalid for Extended CAN messages")
			return
	else:
		const STANDARD_CAN_ID_MIN: int = 0
		const STANDARD_CAN_ID_MAX: int = 2047
		if can_id < STANDARD_CAN_ID_MIN or can_id > STANDARD_CAN_ID_MAX:
			printerr("CAN ID of " + str(can_id) + " is invalid for Standard CAN messages")
			return

	# Check bounds of data elements
	const BYTE_MAX_VAL: int = 255
	for byte: int in data:
		if byte < 0:
			printerr("Attempt to pass a negative value to a CAN frame (" + str(byte) + "). Please use the two's complement if this is intentional")
			return
		if byte > BYTE_MAX_VAL:
			printerr("Data value of " + str(byte) + " cannot fit into a single byte")
			return

	var send_entry := TransmitTableEntry.new(godot_can_bridge, can_id, extended_id, cycle_time_ms, data)
	send_entries.append(send_entry)
	_generate_new_data_row(send_entry)


# Adds the header row to the table, should only be called once
func _generate_header_row() -> void:
	var header = ["", "", "Cycle Time [ms]", "CAN ID", "Data"]
	var header_row: BoxContainer = table_row.instantiate()

	for i in range(len(header)):
		var cell: PanelContainer = table_cell.instantiate()
		cell.custom_minimum_size = Vector2(CELL_WIDTHS[i], CELL_HEIGHT)

		# Set the data row to fill all remaining horizontal space
		if i == DATA_START_IDX:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		_update_label_and_font_size(cell.get_node("Label"), header[i], CELL_WIDTHS[i])
		cell.get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_row.add_child(cell)
	
	rows.add_child(header_row)


# Adds a new data row to the table, should only be called once for each new unique CAN_ID received
func _generate_new_data_row(send_entry: TransmitTableEntry):
	var row: BoxContainer = table_row.instantiate()
	rows.add_child(row)

	# Add delete button
	var delete_cell: PanelContainer = table_send_delete_button.instantiate()
	delete_cell.custom_minimum_size = Vector2(CELL_WIDTHS[DELETE_IDX], CELL_HEIGHT)
	row.add_child(delete_cell)

	# Connect the underlying button object to a lambda that deletes this send entry and GUI row
	var delete_button: Button = delete_cell.get_node("SendButton")
	delete_button.pressed.connect(
		func():
			send_entries.erase(send_entry)
			row.queue_free()
	)

	# Add check box
	var check_box_cell: PanelContainer = table_send_check_box.instantiate()
	check_box_cell.custom_minimum_size = Vector2(CELL_WIDTHS[TOGGLE_IDX], CELL_HEIGHT)
	row.add_child(check_box_cell)
	send_entry.set_checkbox(check_box_cell.get_node("CheckBox")) # Link check box to the send entry to allow the entry to check whether it should be sending

	# Add labels
	var labels := send_entry.get_labels(self)
	for label_idx in len(labels):
		# When adding the labels, the delete and toggle cells are skipped (the first label is the cycle_time_ms)
		var cell_idx := label_idx + CYCLE_TIME_IDX

		var cell: PanelContainer = table_cell.instantiate()
		var cell_width = CELL_WIDTHS[cell_idx] if cell_idx < DATA_START_IDX else CELL_WIDTHS[DATA_START_IDX]
		cell.custom_minimum_size = Vector2(cell_width, CELL_HEIGHT)

		var label := labels[label_idx]

		# Ensure CAN ID labels are right aligned
		if cell_idx == CAN_ID_IDX:
			cell.get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		_update_label_and_font_size(cell.get_node("Label"), label, cell_width)

		row.add_child(cell)


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
	for entry_idx in range(len(send_entries)):
		var send_entry: TransmitTableEntry = send_entries[entry_idx]
		var entry_row: Node = rows.get_child(1 + entry_idx) # Skip the first child which is the header row
		var entry_cells: Array = entry_row.get_children()
		var updated_labels: Array = send_entry.get_labels(self)

		# Only reformat CAN ID cell and onwards
		for cell_idx in range(CAN_ID_IDX, len(entry_cells)):
			var cell_width = CELL_WIDTHS[cell_idx] if cell_idx < DATA_START_IDX else CELL_WIDTHS[DATA_START_IDX]
			_update_label_and_font_size(entry_cells[cell_idx].get_node("Label"), updated_labels[cell_idx - CYCLE_TIME_IDX], cell_width)


func format_can_id(can_id: int, is_ext_can: bool) -> String:
	if can_format_button.use_hex():
		return "0x" + ("%08x" % can_id).to_upper() if is_ext_can else "0x" + ("%03x" % can_id).to_upper()
	else:
		return "0d" + ("%09x" % can_id).to_upper() if is_ext_can else "0d" + ("%04x" % can_id).to_upper()


func format_can_data_byte(can_id: int) -> String:
	# Assumes 8 bit length
	if can_format_button.use_hex():
		return "0x" + ("%02x" % can_id).to_upper()
	else:
		return "0d" + ("%03d" % can_id)


class TransmitTableEntry:
	var _godot_can_bridge: GodotCanBridge
	var _can_id: int
	var _cycle_time_ms: int
	var _data: Array
	var _last_send_time_ms: float
	var _check_box: CheckBox
	var _extended_id: bool

	func _init(godot_can_bridge: GodotCanBridge, can_id: int, extended_id: bool, cycle_time_ms: int, data: Array) -> void:
		_godot_can_bridge = godot_can_bridge
		_can_id = can_id
		_extended_id = extended_id
		_cycle_time_ms = cycle_time_ms
		_data = data
		_last_send_time_ms = Time.get_ticks_msec()

	func is_ext_can() -> bool:
		return _extended_id

	# Returns true if this entry should be currently transmitting
	func enabled() -> bool:
		return _check_box.button_pressed

	# Sets the checkbox used by the entry to check whether the entry is enabled
	func set_checkbox(check_box: CheckBox) -> void:
		_check_box = check_box

	# Sends this entry over the CAN interface if cycle time has been exceeded
	func send_if_ready() -> void:
		var current_time_ms := Time.get_ticks_msec()
		if (current_time_ms - _last_send_time_ms) > _cycle_time_ms:
			if is_ext_can():
				_godot_can_bridge.send_extended_can(_can_id, _data)
			else:
				_godot_can_bridge.send_standard_can(_can_id, _data)
			
			_last_send_time_ms = current_time_ms
		
		# A cycle time of 0ms should be treated as 'one shot', so disable itself after sending the message
		if _cycle_time_ms == 0:
			_check_box.button_pressed = false

	# Returns the labels of this entry for display
	func get_labels(table: TransmitTable) -> Array[String]:
		var labels: Array[String] = [str(_cycle_time_ms), table.format_can_id(_can_id, is_ext_can())]
		for byte in _data:
			labels.append(table.format_can_data_byte(int(byte)))

		return labels
