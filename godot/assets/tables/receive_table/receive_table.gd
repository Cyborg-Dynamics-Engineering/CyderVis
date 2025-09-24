extends Control
class_name ReceiveTable


@onready var table_row = preload("res://assets/tables/table_row.tscn")
@onready var table_cell = preload("res://assets/tables/table_cell.tscn")
@onready var table_button = preload("res://assets/tables/table_button.tscn")
@onready var rows: Control = get_node("Rows")
@onready var right_click_context_menu: PopupMenu = get_node("PopupMenu")
@onready var godot_can_bridge: GodotCanBridge = get_tree().current_scene.get_node("GodotCanBridge")
@onready var pause_button: PauseButton = get_tree().current_scene.get_node("Background/TabContainer/Interface/PauseButton")
@onready var can_graph: CanGraph = get_tree().current_scene.get_node("Background/TabContainer/Plot/Graph2D")
@onready var can_format_button: CanFormatButton = get_tree().current_scene.get_node("Background/TabContainer/Interface/CanFormatButton")
@onready var existing_can_entries: Dictionary[int, ReceiveTableEntry] = {}
@onready var starting_timestamp: int = -1

const TIMESTAMP_IDX = 0
const FREQUENCY_IDX = 1
const CAN_ID_IDX = 2
const MSG_NAME_IDX = 3
const DATA_START_IDX = 4
const IS_EXTENDED_IDX = -1

const CELL_HEIGHT = 25
const CELL_WIDTHS = [100, 80, 100, 100, 80]
const HEADER_LABELS = ["TIMESTAMP", "FREQ [Hz]", "CAN ID", "MSG NAME", "DATA"]


func _ready() -> void:
	_generate_header_row()

	# Attach the 'Clear' element in the context menu at index 0 to the clear table method
	right_click_context_menu.index_pressed.connect(func(index): if index == 0: self.clear())


func _process(_delta: float) -> void:
	if not pause_button.is_paused():
		render(godot_can_bridge.get_can_table())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		var last_mouse_pos = get_global_mouse_position()
		right_click_context_menu.popup(Rect2(last_mouse_pos.x, last_mouse_pos.y, right_click_context_menu.size.x, right_click_context_menu.size.y))


# Updates the rows in the table with incoming data
func render(data: Array) -> void:
	# Do nothing if no data received
	if not data:
		return

	# Set starting timestamp if not set yet
	if starting_timestamp == -1:
		starting_timestamp = int(data[0][TIMESTAMP_IDX])

	# Update current timestamp for realtime plot
	can_graph.update_current_time(_get_largest_timestamp(data))

	# For each data item
	for data_entry: Array in data:
		var can_id := int(data_entry[CAN_ID_IDX])

		# If a new CAN_ID, create new row
		if not existing_can_entries.has(can_id):
			existing_can_entries[int(data_entry[CAN_ID_IDX])] = ReceiveTableEntry.new(self, data_entry)
			sort_entries()

		# Else, we have already discovered this CAN_ID
		else:
			existing_can_entries.get(can_id).update(data_entry)


# Clears all rows from the table
func clear() -> void:
	# Clear rows and entries from Godot side
	for entry: ReceiveTableEntry in existing_can_entries.values():
		entry.get_row().queue_free()
	existing_can_entries.clear()

	# Clear entries from rust side
	godot_can_bridge.clear_can_table()


# Re-renders every CAN entry. Useful for updating the table on formatting state changes.
func update_formatting() -> void:
	for entry: ReceiveTableEntry in existing_can_entries.values():
		entry.update_labels()


# Converts a microsecond system timestamp to seconds from start of program
func timestamp_to_s(timestamp: String) -> float:
	return (int(timestamp) - starting_timestamp) * 1e-6


# Returns the most recent timestamp from an array of incoming CAN messages
func _get_largest_timestamp(data: Array) -> float:
	var largest_stamp: float = 0.0

	for entry: Array in data:
		if timestamp_to_s(entry[TIMESTAMP_IDX]) > largest_stamp:
			largest_stamp = timestamp_to_s(entry[TIMESTAMP_IDX])
	
	return largest_stamp


# Adds the header row to the table, should only be called once
func _generate_header_row() -> void:
	var header_row: BoxContainer = table_row.instantiate()
	rows.add_child(header_row)
	for i in range(len(HEADER_LABELS)):
		var cell: PanelContainer = table_cell.instantiate()
		cell.custom_minimum_size = Vector2(CELL_WIDTHS[i], CELL_HEIGHT)
		if i == DATA_START_IDX:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_update_label_and_font_size(cell.get_node("Label"), str(HEADER_LABELS[i]), CELL_WIDTHS[i])
		cell.get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_row.add_child(cell)


# Updates the text and tooltip of a label, making adjustments to size and concatonating the label if neccesary
static func _update_label_and_font_size(label, new_text: String, width: int) -> void:
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


# Sorts the row nodes in the table to be in order of lowest to highest CAN ID
func sort_entries() -> void:
	var can_ids = existing_can_entries.keys()
	can_ids.sort()

	for i in range(len(can_ids)):
		rows.move_child(existing_can_entries.get(can_ids[i]).get_row(), i + 1)


class ReceiveTableEntry:
	var _last_receive_time_ms: float
	var _frequency_hz: float
	var _can_id: int
	var _msg_name: String
	var _is_extended: bool
	var _data: Array[String]
	var _row: Node
	var _receive_table: ReceiveTable

	func _init(receive_table: ReceiveTable, frame: Array) -> void:
		_receive_table = receive_table
		update(frame)


	# Instantiates the table cell nodes holding the labels into this entry's row
	func _instantiate_labels(frame: Array):
		_row = _receive_table.table_row.instantiate()
		_receive_table.rows.add_child(_row)

		if self.is_deserialised():
			# For deserialised data we need to add buttons to enable logging
			for i in len(frame) - 1:
				var cell_width = CELL_WIDTHS[i] if i < DATA_START_IDX else CELL_WIDTHS[DATA_START_IDX]
				var cell_size = Vector2(cell_width, CELL_HEIGHT)

				var cell: Node
				var is_button = (i >= DATA_START_IDX) and (i % 2 == 0)
				if is_button:
					cell = _receive_table.table_button.instantiate()
					cell.pressed.connect(_receive_table.can_graph.toggle_plot_element.bind(str(_can_id), str(frame[i])))
				else:
					cell = _receive_table.table_cell.instantiate()

				cell.custom_minimum_size = cell_size
				
				_row.add_child(cell)

		else:
			# For unknown data we just print the raw bytes as labels
			for i in len(frame) - 1:
				var cell_width = CELL_WIDTHS[i] if i < DATA_START_IDX else CELL_WIDTHS[DATA_START_IDX]
				var cell_size = Vector2(cell_width, CELL_HEIGHT)

				var cell: PanelContainer = _receive_table.table_cell.instantiate()
				cell.custom_minimum_size = cell_size
				
				_row.add_child(cell)
		
		# Set right alignment for specific cells
		_row.get_child(TIMESTAMP_IDX).get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_row.get_child(FREQUENCY_IDX).get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_row.get_child(CAN_ID_IDX).get_node("Label").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		# Apply the correct label text and formatting to each cell
		update_labels()


	func update(new_frame: Array):
		var prev_data_size: int = _data.size()

		_last_receive_time_ms = _receive_table.timestamp_to_s(new_frame[TIMESTAMP_IDX])
		_frequency_hz = float(new_frame[FREQUENCY_IDX])
		_can_id = int(new_frame[CAN_ID_IDX])
		_msg_name = new_frame[MSG_NAME_IDX]
		_is_extended = new_frame[IS_EXTENDED_IDX].to_lower() == "true"
		_data = []
		for i in range(DATA_START_IDX, len(new_frame) - 1):
			_data.append(new_frame[i])

		# If the message has changed size, regenerate the data row
		if prev_data_size != _data.size():
			if is_instance_valid(_row):
				_row.queue_free()
			
			_instantiate_labels(new_frame)

		# Else, update the existing labels
		else:
			update_labels()


	func is_deserialised() -> bool:
		return not _msg_name.is_empty()


	func is_ext_can() -> bool:
		return _is_extended


	func get_row() -> Node:
		return _row


	func update_labels() -> void:
		var entry_row_cells := _row.get_children()

		ReceiveTable._update_label_and_font_size(entry_row_cells[TIMESTAMP_IDX].get_node("Label"), "%.3f" % _last_receive_time_ms, CELL_WIDTHS[TIMESTAMP_IDX])
		ReceiveTable._update_label_and_font_size(entry_row_cells[FREQUENCY_IDX].get_node("Label"), "%.2f" % _frequency_hz, CELL_WIDTHS[FREQUENCY_IDX])
		ReceiveTable._update_label_and_font_size(entry_row_cells[CAN_ID_IDX].get_node("Label"), _format_can_id(_can_id), CELL_WIDTHS[CAN_ID_IDX])
		ReceiveTable._update_label_and_font_size(entry_row_cells[MSG_NAME_IDX].get_node("Label"), _msg_name, CELL_WIDTHS[MSG_NAME_IDX])

		for i in range(len(_data)):
			# If this data has been deserialised, format the button cells as strings instead of data bytes
			if self.is_deserialised():
				var is_button = (i % 2 == 0)
				if is_button:
					ReceiveTable._update_label_and_font_size(entry_row_cells[DATA_START_IDX + i], _data[i], CELL_WIDTHS[DATA_START_IDX])
				else:
					ReceiveTable._update_label_and_font_size(entry_row_cells[DATA_START_IDX + i].get_node("Label"), _data[i], CELL_WIDTHS[DATA_START_IDX])

					# If the can graph is plotting this data point, forward it to the graph
					var element_identifier: String = str(_can_id) + _data[i - 1]
					if _receive_table.can_graph.has_plot_element(element_identifier):
						_receive_table.can_graph.add_data_point(element_identifier, _last_receive_time_ms, float(_data[i]))
			else:
				# For regular labels, update with CAN byte formatting
				ReceiveTable._update_label_and_font_size(entry_row_cells[DATA_START_IDX + i].get_node("Label"), _format_can_data_byte(int(_data[i])), CELL_WIDTHS[DATA_START_IDX])


	func _format_can_id(can_id: int) -> String:
		# Assumes 31 bit length
		if _receive_table.can_format_button.use_hex():
			return "0x" + ("%08x" % can_id).to_upper() if is_ext_can() else "0x" + ("%03x" % can_id).to_upper()
		else:
			return "0d" + ("%09d" % can_id) if is_ext_can() else "0d" + ("%04d" % can_id)


	func _format_can_data_byte(can_id: int) -> String:
		# Assumes 8 bit length
		if _receive_table.can_format_button.use_hex():
			return "0x" + ("%02x" % can_id).to_upper()
		else:
			return "0d" + ("%03d" % can_id)
