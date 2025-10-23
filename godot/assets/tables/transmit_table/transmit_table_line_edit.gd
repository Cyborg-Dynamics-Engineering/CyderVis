extends LineEdit
class_name TransmitTableLineEdit

var _transmit_table: TransmitTable
var _row: Control
var _send_text_cell: Control


func _ready() -> void:
	# TransmitTable -> Rows -> TableRow -> SendTextCell -> TransmitTableLineEdit
	_send_text_cell = get_parent()
	_row = _send_text_cell.get_parent()
	_transmit_table = _row.get_parent().get_parent()

	# Add movement up and down the transmit table rows using the Enter and Enter + Shift keys
	text_submitted.connect(
		func(_new_text: String):
			# Find the next row that should be focused
			var next_index: int
			if Input.is_key_pressed(KEY_SHIFT):
				# Move focus up a row, but if at the top already move focus to the bottom
				next_index = _row.get_index() - 1
				if next_index == 0:
					next_index = _transmit_table.rows.get_child_count() - 1
			else:
				# Move focus down a row, but if at the bottom already move focus to the top
				next_index = _row.get_index() + 1
				if next_index == _transmit_table.rows.get_child_count():
					next_index = 1

			# Change focus to this row
			var next_row = _transmit_table.rows.get_child(next_index)
			if next_row:
				next_row.get_child(_send_text_cell.get_index()).get_node("LineEdit").grab_focus()
	)

	# Select all text when entering focus
	focus_entered.connect(select_all)
