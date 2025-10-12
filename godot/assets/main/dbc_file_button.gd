extends Button
class_name DbcFileButton

@export_category("Node References")
@export var _can_bridge: GodotCanBridge
@export var _receive_table: ReceiveTable
@export var _dbc_file_box: LineEdit
@export var _pause_button: PauseButton


func _ready() -> void:
	self.pressed.connect(_button_pressed)

func _button_pressed() -> void:
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.set_file_mode(file_dialog.FILE_MODE_OPEN_FILE)
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.dbc; CAN DBC Files"]
	file_dialog.popup()
	file_dialog.file_selected.connect(_process_file)

func _process_file(x: String) -> void:
	var dbc_success = _can_bridge.load_dbc_file(x) # This emits an alert if bad file
	_dbc_file_box.text = x
	if dbc_success:
		# If you attempt, it would be a fail
		_pause_button.close_connection()
		_receive_table.clear_all()
