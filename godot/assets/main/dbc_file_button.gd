extends Button
class_name DbcFileButton

@onready var _can_bridge: GodotCanBridge = get_tree().current_scene.get_node("GodotCanBridge")
@onready var _receive_table: ReceiveTable = get_tree().current_scene.get_node("Background/Table")
@onready var _dbc_file_box: LineEdit = get_parent().get_node("DbcFileBox")
@onready var _pause_button: PauseButton = get_parent().get_node("PauseButton")


func _ready() -> void:
	self.pressed.connect(_button_pressed)


func _button_pressed() -> void:
	var dbc_success := _can_bridge.load_dbc_file(_dbc_file_box.text)

	# If no changes to DBC config
	if not dbc_success:
		return


	_pause_button.close_connection()
	_receive_table.clear()
