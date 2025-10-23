extends Button
class_name PauseButton

@export_category("Node References")
@export var _can_bridge: GodotCanBridge
@export var _interface_box: LineEdit
@export var _tab_container: TabContainer
@export var _receive_table: ReceiveTable
@export var _dbc_line_edit: LineEdit
@export var _dbc_open_button: Button

var _is_paused: bool


func _ready() -> void:
	self.pressed.connect(_button_pressed)
	_is_paused = true
	_update_text()
	_update_tab_selectability()
	_update_dbc_editability()


func _process(_delta: float) -> void:
	if not is_paused():
		if not _can_bridge.is_alive():
			_toggle_pause()


func is_paused() -> bool:
	return _is_paused


func close_connection() -> void:
	if not _is_paused:
		_can_bridge.close_bus()
		_toggle_pause()


func _button_pressed() -> void:
	# Handle CAN bus interaction
	if _is_paused:
		var dbc_load_success: bool = _can_bridge.load_dbc_file(_dbc_line_edit.text)
		if not dbc_load_success:
			return

		var can_up_success: bool = _can_bridge.configure_bus(_interface_box.text)
		if not can_up_success:
			return
	else:
		_can_bridge.close_bus()

	_toggle_pause()


# Toggle the paused state and update the button text
func _toggle_pause() -> void:
	_is_paused = not _is_paused
	_update_text()
	_update_tab_selectability()
	_update_dbc_editability()


func _update_text() -> void:
	if _is_paused:
		text = "Start"
	else:
		text = "Pause"


# Updates the selectability of the tabs (Can only use the tabs when an interface is actively connected)
func _update_tab_selectability() -> void:
	var should_disable_tabs: bool = _is_paused and _receive_table.is_empty()

	const NUM_TABS: int = 3
	for i in range(1, NUM_TABS):
		_tab_container.set_tab_disabled(i, should_disable_tabs)


func _update_dbc_editability() -> void:
	_dbc_line_edit.editable = _is_paused
	_dbc_open_button.disabled = not _is_paused
